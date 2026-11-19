#!/usr/bin/env python
"""
**cleanup_tracelog.py:** clean up tracelog files for dumps monitoring

:Author: w. aaron ( william.aaron@cfa.harvard.edu)
:Last Updated: Nov 16, 2026

"""
import argparse
from datetime import datetime, timedelta
import os
from pathlib import Path
import json

if os.getenv('DUMPS_PROCESS_ROOT') is not None:
    DUMPS_PROCESS_ROOT = Path(os.getenv('DUMPS_PROCESS_ROOT'))
else:
    #: Running script is in a script subdirectory to the Dumps processing root.
    DUMPS_PROCESS_ROOT = Path(__file__).resolve().parent.parent

SCRIPT_STATE_DIR = DUMPS_PROCESS_ROOT / 'scripts' / 'state'

if os.getenv("DUMPS_TRACELOG_DIR") is not None:
    DUMPS_TRACELOG_DIR = Path(os.getenv("DUMPS_TRACELOG_DIR"))
else:
    DUMPS_TRACELOG_DIR = DUMPS_PROCESS_ROOT / 'tracelog'
DUMPS_TRACELOG_DIR.mkdir(exist_ok=True)

def grab_now():
    return datetime.now()

def cleanup_tracelog_files(verbose=False):
    """
    Clean up the tracelog files in the DUMPS_TRACELOG_DIR directory by removing any files that are older than 10 days as determined by the filename.
    """
    now = grab_now()
    cutoff = now - timedelta(days=10)

    tracelog_state_file = SCRIPT_STATE_DIR / "processed_tracelogs.json"
    tracelog_state = pull_process_tracelog_state(tracelog_state_file)
    processed_files = tracelog_state.get("processed_files", {})
    
    for file in DUMPS_TRACELOG_DIR.glob("*.tl"):
        file_data = processed_files.get(str(file))
        if file_data is not None:
            #: File processed by dumps mon, check if it is older than 10 days
            dt = datetime.fromtimestamp(file_data.get("processed_epoch"))
            if dt < cutoff:
                if verbose:
                    print(f"Removing old tracelog file: {file}")
                file.unlink()
                del processed_files[str(file)]
        else:
            #: File is not processed by the dumps alert monitor, but might be an old state file.
            #: Remove if the access time is more than 10 days.
            _stat = os.stat(str(file))
            dt = datetime.fromtimestamp(_stat.st_atime)
            if dt < cutoff:
                if verbose:
                    print(f"Removing old tracelog file: {file}")
                file.unlink()

    tracelog_state["processed_files"] = processed_files
    #: Save the updated tracelog state
    with open(tracelog_state_file, 'w') as f:
        json.dump(tracelog_state, f)

def pull_process_tracelog_state(state_file):
    """
    Load the processed_tracelogs.json state file and return a dictionary of processed tracelog files.
    """
    if not state_file.exists():
        return {}
    with open(state_file, 'r') as f:
        state = json.load(f)
    return state

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action=argparse.BooleanOptionalAction, default=False, help = "Print status update messages")
    args = parser.parse_args()
    cleanup_tracelog_files(verbose=args.verbose)