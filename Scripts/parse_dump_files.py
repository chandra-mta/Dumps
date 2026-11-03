#!/usr/bin/env python

"""

**parse_dump_files.py:** Copy GOT Dump files and run acorn to parse Dumps into telemetry files

:Author: w. aaron (william.aaron@sao.si.edu)
:Last Updated: 2026-11-02

:NOTE: Acorn can only generate the telemetry files for parsing a dump file into the current working directory,
    so this should be determined by shell script or cron job calling the parse_dump_files.py scripts.
    Note that this limitation does not apply to file paths for config files or input Dump file.

"""

import os
import sys
from pathlib import Path
from glob import glob
import json
from datetime import datetime, timedelta
import subprocess
import shutil
import traceback

#
#--- Global Directory Pathing
#
DUMP_SOURCE_DIR = Path(os.getenv("DUMP_SOURCE_DIR") or "/dsops/critical/GOT/input")
#: Warning for nonexistent DUMP_SOURCE_DIR
if not DUMP_SOURCE_DIR.is_dir():
    raise FileNotFoundError(f"DUMP_SOURCE_DIR: {DUMP_SOURCE_DIR} not found.\nEnsure script runs on machine able to see DSOPS (c3po-v, r2d2-v, colossus-v).")

if os.getenv('SCRIPT_ROOT') is not None:
    SCRIPT_ROOT = Path(os.getenv('SCRIPT_ROOT'))
else:
    SCRIPT_ROOT = Path(__file__).resolve().parent

SCRIPT_STATE_DIR = SCRIPT_ROOT / 'state'
SCRIPT_RESOURCE_DIR = SCRIPT_ROOT / 'resource'

if os.getenv("DUMP_DATA_DIR") is not None:
    DUMP_DATA_DIR = Path(os.getenv("DUMP_DATA_DIR"))
else:
    DUMP_DATA_DIR = SCRIPT_ROOT / 'data'
DUMP_DATA_DIR.mkdir(exist_ok=True)

if os.getenv("DUMP_TRACELOG_DIR") is not None:
    DUMP_TRACELOG_DIR = Path(os.getenv("DUMP_TRACELOG_DIR"))
else:
    DUMP_TRACELOG_DIR = SCRIPT_ROOT / 'tracelog'
DUMP_TRACELOG_DIR.mkdir(exist_ok=True)

def grab_now():
    return datetime.now()

def subprocess_wrapper(cmds):
    """
    When shell is True, must pass all commands as a single string.
    """
    result = subprocess.run(
        cmds,
        shell=True,
        executable='/bin/tcsh',
        capture_output=True,
        text=True,
        check=True
    )
    return result

def _filename_2_time_interval(file):
    """
    Parse Dump file name to time interval of data
    """
    name = os.path.basename(file)
    #: Parse the datetime interval of data from the filename
    _dt = name.split('_')
    #: [year, start_doy, start_hhmm, stop_doy, stop_hhmm, ...]
    start = datetime.strptime(f"{_dt[0]}:{_dt[1]}:{_dt[2]}","%Y:%j:%H%M")
    if int(_dt[1]) > int(_dt[3]):
        #: Year Change
        stop = datetime.strptime(f"{int(_dt[0])+1}:{_dt[3]}:{_dt[4]}","%Y:%j:%H%M")
    else:
        stop = datetime.strptime(f"{_dt[0]}:{_dt[3]}:{_dt[4]}","%Y:%j:%H%M")
    return start, stop

def determine_unprocessed_dumps(processed_dumps : list) -> list:
    """
    Scan through the DUMP_SOURCE_DIR directory and state/processed_dumps.json data files
    to determine which Dump files need to be processed in this run
    """
    all_dump_files = glob(f"{DUMP_SOURCE_DIR}/*Dump_EM*.gz")

    all_dump_files_set = set(all_dump_files)
    processed_dumps_set = set(processed_dumps)

    unprocessed_set = all_dump_files_set - processed_dumps_set
    unprocessed_list = []
    cutoff = grab_now() - timedelta(days=10)
    for file in unprocessed_set:
        start, stop = _filename_2_time_interval(file)
        if start > cutoff:
            unprocessed_list.append(file)
    
    return sorted(unprocessed_list)

def unzip(gzipped_files: list) -> list:
    """
    Run the gzip command with adjustable file location

    Returns the unzipped file locations as a list following processing
    """
    unzipped_files = []
    for file in gzipped_files:
        outfile = DUMP_DATA_DIR / os.path.basename(file).replace('.gz','')
        try:
            subprocess_wrapper(f"cd {DUMP_DATA_DIR}; gzip -dc {file} > {outfile}")
            unzipped_files.append(outfile)
        except subprocess.CalledProcessError as e:
            #: Print traceback then continue processing
            traceback.print_exc()

    return unzipped_files

def run_acorn(dump_files):
    """
    Run the DS acorn tool on the unzipped dump files.
    """
    now = grab_now()
    #: Initial setup of command
    cmd = f"cd {DUMP_DATA_DIR}; source /home/ascds/.ascrc; "
    #: Individual acorn runs per dump files
    for file in dump_files:
        #: Output is CWD of process run, which is set to DUMP_DATA_DIR above.
        cmd += f"acorn -nOC {SCRIPT_RESOURCE_DIR}/msids.list -f {file}; "
    try:
        subprocess_wrapper(cmd)
    except subprocess.CalledProcessError as e:
        e.add_note(f"Acorn parsing failed at {now.isoformat()}.")
        e.add_note(f"Check {DUMP_DATA_DIR}/systemlog.")
        raise e

def parse_dump_files():
    """
    Parse the available Dump files into tracelog files into relevant directories
    """
    processed_state_file = SCRIPT_STATE_DIR / "processed_dumps.json"
    if not processed_state_file.is_file():
        #: Load previous version
        os.replace(SCRIPT_STATE_DIR / "processed_dumps.json~", SCRIPT_STATE_DIR / "processed_dumps.json")
    
    with open(processed_state_file) as f:
        processed_dumps = json.load(f)

    unprocessed_dumps = determine_unprocessed_dumps(processed_dumps)
    if len(unprocessed_dumps) < 1:
        #: No Dumps to process
        sys.exit(0)

    unzipped_dump_files = unzip(unprocessed_dumps)

    try:
        run_acorn(unzipped_dump_files)
    except subprocess.CalledProcessError as e:
        #: Don't delete the Dump files which were not successfully parsed
        raise e
    #: No error, perform cleanup.
    #: Remove the Dump files in data directory
    for _file in unzipped_dump_files:
        Path(_file).unlink(missing_ok=True)
    #: Move the tracelog files
    tl_files = glob(f"{DUMP_DATA_DIR}/*.tl")
    for _file in tl_files:
        shutil.move(_file, DUMP_TRACELOG_DIR)
    #: Update the processed list
    os.replace(SCRIPT_STATE_DIR / "processed_dumps.json", SCRIPT_STATE_DIR / "processed_dumps.json~")
    latest_processed = processed_dumps + unprocessed_dumps
    with open(processed_state_file,'w') as f:
        json.dump(latest_processed, f, indent = 2)
 
if __name__ == "__main__":

    parse_dump_files()

