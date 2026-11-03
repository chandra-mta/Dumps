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
import re
import numpy
import time
from pathlib import Path
from glob import glob
import json
from datetime import datetime, timedelta
import shutil

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

def grab_now():
    return datetime.now()

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

def determine_unprocessed_dumps():
    """
    Scan through the DUMP_SOURCE_DIR directory and state/processed_dumps.json data files
    to determine which Dump files need to be processed in this run
    """
    all_dump_files = glob(f"{DUMP_SOURCE_DIR}/*Dump_EM*.gz")
    
    processed_state_file = SCRIPT_STATE_DIR / "processed_dumps.json"
    if not processed_state_file.is_file():
        processed_state_file = SCRIPT_STATE_DIR / "processed_dumps.json~"
    
    with open(processed_state_file) as f:
        processed_dumps = json.load(f)

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


#-----------------------------------------------------------------------------------
#-- run_filter_script: collect data and run otg and ccdm filter scripts          ---
#-----------------------------------------------------------------------------------

def run_filter_script():
    """
    collect data and run otg and ccdm filter scripts
    input:  none, but read from /dsops/GOT/input/*Dump_EM*.gz
    outout: <working_dir>/*.tl files
    """
#
#--- find which dump data  are new
#
    unprocessed_data = copy_unprocessed_dump_em_files()

    if len(unprocessed_data) < 1:
        exit(1)
#
#--- prep and run filtering process
#
    for category_file in PROCESS_SELECT:
        if not os.path.isfile(f"./{category_file}"):
            os.system(f"cp -f {house_keeping}/{category_file} .")
        filters_cat(category_file, unprocessed_data)
#
#--- remove the local copy of dump files
#
    for ent in unprocessed_data:
        mcf.rm_files(ent)
#
#--- move *.tl files to working dir
#
    mv_files()

#-----------------------------------------------------------------------------------
#-- filters_cat: run acorn for filter determined by category files               ---
#-----------------------------------------------------------------------------------

def filters_cat(category_file, unprocessed_data):
    """
    run acorn for category filter
    input:  unprocessed_data    --- list of data
    output: various *.tl files
    """
    for ent in unprocessed_data:
        cmd = f"/usr/bin/env PERL5LIB='' /home/ascds/DS.release/bin/acorn -nOC {category_file} -f {ent}"
        try:
            bash(cmd, env=ascdsenv)
        except:
            pass

#-----------------------------------------------------------------------------------
#-- copy_unprocessed_dump_em_files: collect unporcessed data and make a list     ---
#-----------------------------------------------------------------------------------

def copy_unprocessed_dump_em_files():
    """
    collect unporcessed data and make a list
    input:  none, but copy data from /dsops/GOT/input/*Dump_EM_*
    output: unprocessed_data    ---- a list of data
            unzipped copies of the data in the current directoy
    """
#
#--- set cut tiime to process the data
#
    today = time.strftime('%Y:%j:00:00:00', time.gmtime())
    cut_time = Chandra.Time.DateTime(today).secs - 86400.0 * 10
#
#--- read the list of dump data already processed
#
    pfile = house_keeping + 'processed_list'
    plist = mcf.read_data_file(pfile)
#
#--- read the all dump data located in /dsops/GOT/input/ sites
#
    cmd = 'ls /dsops/GOT/input/*Dump_EM*gz > '+  zspace
    os.system(cmd)

    flist = mcf.read_data_file(zspace, remove=1)
#
#--- update processed data list file
#
    cmd = 'mv ' + pfile + ' ' + pfile + '~'
    os.system(cmd)

    line = ''
    for ent in flist:
        line = line + ent + '\n'

    with open(pfile, 'w') as fo:
        fo.write(line)
#
#--- find new entries
#
    try:
        new_data = numpy.setdiff1d(flist, plist)
    except:
        new_data = []

    unprocessed_data = []

    for ent in new_data:
        try:
            ctime = get_file_time(ent)
            if ctime < cut_time:
                continue

            atemp = re.split('\/', ent)
            fname = atemp[-1]
            os.system(f"cp {ent} . ; gzip -d {fname}")
            fname = fname.replace('.gz', '')
            unprocessed_data.append(fname)
        except:
            pass
#
#--- write out today dump data list
#
    line = ''
    for ent in unprocessed_data:
        line = ent + '\t'

    outfile = house_keeping + 'today_dump_files'
    with open(outfile, 'w') as fo:
        fo.write(line)

    return unprocessed_data

#---------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------

def get_file_time(ifile):

    atemp = re.split('\/', ifile)
    btemp = re.split('_', atemp[-1])
    date  = btemp[0] + ':' + btemp[1] + ':00:00:00'
    out   = Chandra.Time.DateTime(date).secs

    return out

#---------------------------------------------------------------------------------------
#-- mv_files: move *.tl files to Dump directory                                       --
#---------------------------------------------------------------------------------------

def mv_files():
    """   
    move *.tl files to Dump directory
    """
#
#--- check systemlog is in working directory and if it does, move to <house_keeping>
#
    lfile = work_dir + 'systemlog'
    if os.path.isfile(lfile):
        cmd = 'mv -f ' + lfile + ' '  + house_keeping + '.'
        os.system(cmd)

    cmd = 'mv -f *.tl ' + main_dir 
    os.system(cmd)

#-------------------------------------------------------------------------------------------
 
if __name__ == "__main__":

    #run_filter_script()

    print(determine_unprocessed_dumps())

