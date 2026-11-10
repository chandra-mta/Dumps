#!/usr/bin/env python
"""
**update_par.py:** read op_limits.db database to update .par files for dumps monitoring

:Author: w. aaron ( william.aaron@cfa.harvard.edu)
:Last Updated: Nov 09, 2026

# /// testing
# tested-ska-release = "2026.1"
# ///
"""

import os
from cxotime import CxoTime
from pathlib import Path
import argparse
#
#--- Globals
#
#: TODO Improve resource files for this script set. Topology changes will prevent reading this in current state.
#: maybe consider having these two files in the resource directory,
#: then on the OCC LAN we have an rsync command to periodically fetch this resource
OP_LIMITS_DATABASE = Path("/data/mta/Script/MSID_limit/op_limits.db")
ACIS_THERMAL_LIMITS = Path("/proj/web-cxc/htdocs/acis/Thermal/MSID_Limits.txt")

if os.getenv('DUMPS_PROCESS_ROOT') is not None:
    DUMPS_PROCESS_ROOT = Path(os.getenv('DUMPS_PROCESS_ROOT'))
else:
    #: Running script is in a script subdirectory to the Dumps processing root.
    DUMPS_PROCESS_ROOT = Path(__file__).resolve().parent.parent

SCRIPT_RESOURCE_DIR = DUMPS_PROCESS_ROOT / 'Scripts' / 'resource'
DUMPS_MON_PARAMETER_DIR = DUMPS_PROCESS_ROOT / 'Scripts' / 'parameter'
DUMPS_MON_PARAMETER_DIR.mkdir(exist_ok=True)

if os.getenv("DUMP_TRACELOG_DIR") is not None:
    DUMP_TRACELOG_DIR = Path(os.getenv("DUMP_TRACELOG_DIR"))
else:
    DUMP_TRACELOG_DIR = DUMPS_PROCESS_ROOT / 'tracelog'

PAR_FILE_TEMPLATE_LIST = [
    Path(f"{SCRIPT_RESOURCE_DIR}/aca_check.template"),
    Path(f"{SCRIPT_RESOURCE_DIR}/acis_check.template"),
    Path(f"{SCRIPT_RESOURCE_DIR}/acis_temp.template")
]
OVERWRITE_WITH_OP_LIMITS = True
OVERWRITE_WITH_ACIS = True

_HEADER = "		Health & Safety 		Data Quality\nmnemonic	yel lo	yel hi	red lo	red hi	yel lo	yel hi	red lo	red hi	descriptions\n"

class FileWriter:
    """Write text contents out to text files in configured directory"""
    def __init__(self, directory):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True)
    def write(self, filename, content):
        with open(self.directory / filename, "w") as f:
            f.write(content)

class StdoutWriter:
    """Write text contents to stdout, typically for a test run of the script"""
    def write(self, filename, content):
        print(f"===== {filename} =====")
        print(content, end="")

def _grab_cxonow():
    return CxoTime()

def update_par(writer):
    """
    update_par - Permute across .par files and pull data for updating file
    input: none, but read from list of .par files and op_limits_db to update .par files
    output: updated .par files (locally saved)
    """
    for file in PAR_FILE_TEMPLATE_LIST:
        with open(file,'r') as f:
            raw_data =  f.readlines()
        #Maintain header as the same format of content
        header = raw_data[:2]
        data = [x.strip().split() for x in raw_data[2:]]
        par_data = []
        #Formatted by space separation, but that includes comments separation
        #therefore clean with expectation that comment is all data past index 9 inclusive
        for entry in data:
            comment = " ".join(entry[9:])
            par_data.append(entry[:9] + [comment])
        par_dict = {}
        #generate dictionary of limit/comments and assume the parameter is a old version of the data
        for entry in par_data:
            par_dict[entry[0]] = [entry[1:],0]
            #The second list value will record the time this limit was defined, thereby keeping track of the most up to date limit entry.
        
        if OVERWRITE_WITH_OP_LIMITS:
            par_dict = update_par_file_data(par_dict)
        #Overwrite Limits with Acis Team preferences for their alert categories
        if OVERWRITE_WITH_ACIS:
            par_dict = update_acis_ver_par(par_dict)
        
        content = _HEADER
        for k,v in par_dict.items():
            content += f"{k}    {'    '.join(v[0])}\n"
        
        writer.write(file.with_suffix('.par').name, content)

def update_par_file_data(par_dict):
    """
    update_par_file_data: iterate over parameter dictionary, updating with OP_LIMITS_DATABASE file
    input: par_dict - dictionary of parameter values
    output: par_dict - dictionary of parameter values (updated)
    """
    msid_list = list(par_dict.keys())

    with open(OP_LIMITS_DATABASE,'r') as f:
        data = [x.strip().split() for x in f.readlines() if x[0] != '#']
    #Formatted by space separation, but that includes comments separation
    #therefore clean with expectation that comment is all data past index 6 inclusive
    limit_data = []
    for entry in data:
        comment = " ".join(entry[6:])
        limit_data.append(entry[:6] + [comment])
    
    for entry_list in limit_data:
        if entry_list[0] in msid_list:
            msid = entry_list[0]
            recent_time = par_dict[msid][1]
            update_time = float(entry_list[5])
            if update_time > recent_time:
                comment = entry_list[6]
                if comment[0] != "#":
                    comment = f"#{comment}"
                chk = False
                if " K " in comment:
                    #Description when specified as kelvin will contain single space separated K
                    #Spaces important as string formatted varies throughout the file.
                    comment = comment.replace(" K ", " C ")
                    chk = True
                yel_min = format_K_to_C(entry_list[1],chk)
                yel_max = format_K_to_C(entry_list[2],chk)
                red_min = format_K_to_C(entry_list[3],chk)
                red_max = format_K_to_C(entry_list[4],chk)
                par_dict[msid] = [[yel_min, yel_max, red_min, red_max, yel_min, yel_max, red_min, red_max, comment] , update_time]
    
    return par_dict

def update_acis_ver_par(par_dict):
    """
    update_par_file_data: iterate over parameter dictionary, updating with OP_LIMITS_DATABASE file
    input: par_dict - dictionary of parameter values
    output: par_dict - dictionary of parameter values (updated)
    """
    #Note that the acis text file does not specify temperature units, consistently using celcius only.
    msid_list = list(par_dict.keys())
    now = _grab_cxonow()

    with open(ACIS_THERMAL_LIMITS,'r') as f:
        data = [x.strip().split() for x in f.readlines() if x[0] != '#']

    #Formatted by space separation, but that includes comments separation
    #therefore clean with expectation that comment is all data past index 6 inclusive
    limit_data = []
    for entry in data:
        comment = " ".join(entry[6:])
        limit_data.append(entry[:6] + [comment])
    

    for entry_list in limit_data:
        if entry_list[0] in msid_list:
            msid = entry_list[0]
            yel_min = entry_list[2]
            yel_max = entry_list[3]
            red_min = entry_list[4]
            red_max = entry_list[5]
            comment = entry_list[6]
            if comment[0] != "#":
                comment = f"#{comment}"
            update_time = float(now.secs)
            par_dict[msid] = [[yel_min, yel_max, red_min, red_max, yel_min, yel_max, red_min, red_max, comment] , update_time]
    
    return par_dict

def format_K_to_C(val, chk):
    """
    format_K_to_C: Simple script to convert Kelvin fomratted limits to Celcius, maintaining the string formatting
    input: val - string or float of kelvin value
    output: val - string of celcius value
    """
    if type(val) == str:
        val = float(val)
    if chk:
        val = val - 273.15
    return str(round(val,2))
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--path", help = "Determine data output path. Write stdout for standard out.")
    args = parser.parse_args()

    if args.path == "stdout":
        writer = StdoutWriter()
    else:
        writer = FileWriter(args.path or DUMPS_MON_PARAMETER_DIR)

    update_par(writer)