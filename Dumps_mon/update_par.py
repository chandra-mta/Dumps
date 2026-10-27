#!/proj/sot/ska3/flight/bin/python
"""
**update_par.py:** read op_limits.db database to update .par files for dumps monitoring

:Author: w. aaron ( william.aaron@cfa.harvard.edu)
:Last Updated: Nov 08, 2023

# /// testing
# tested-ska-release = "2026.1"
# ///
"""

import os
import time

#
#--- Globals
#

OP_LIMITS_DATABASE = "/data/mta/Script/MSID_limit/op_limits.db"
ACIS_THERMAL_LIMITS = "/proj/web-cxc/htdocs/acis/Thermal/MSID_Limits.txt"
MAIN_DIR = "/data/mta/Script/Dumps/Dumps_mon"
OUT_DIR = MAIN_DIR
PAR_FILE_LIST = [f"{MAIN_DIR}/aca_check.par",f"{MAIN_DIR}/acis_check.par",f"{MAIN_DIR}/acis_temp.par"]
OVERWRITE_WITH_OP_LIMITS = True
OVERWRITE_WITH_ACIS = True
CHANDRA_TIME_DIFF = 883612730.816

def update_par():
    """
    update_par - Permute across .par files and pull data for updating file
    input: none, but read from list of .par files and op_limits_db to update .par files
    output: updated .par files (locally saved)
    """
    for file in PAR_FILE_LIST:
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
        
        ofile = f"{OUT_DIR}/{os.path.basename(file)}"
        with open(ofile,'w') as f:
            for line in header:
                f.write(line)
            for k,v in par_dict.items():
                line = f"{k}    {'    '.join(v[0])}\n"
                f.write(line)


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
            update_time = time.time() - CHANDRA_TIME_DIFF
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
    update_par()