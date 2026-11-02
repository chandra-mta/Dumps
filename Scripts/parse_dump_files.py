#!/usr/bin/env /data/mta/Script/Python3.8/envs/ska3-shiny/bin/python

#############################################################################################
#                                                                                           #
#       run_filter_scripts.py:  collect data and run otg and ccdm filter scripts            #
#                                                                                           #
#               author: t. isobe (tisobe@cfa.harvard.edu)                                   #
#                                                                                           #
#               last update: Mar 04, 2021                                                   #
#                                                                                           #
#############################################################################################

import os
import sys
import re
import string
import random
import operator
import math
import numpy
import time
import Chandra.Time
import unittest
#
#--- from ska
#
from Ska.Shell import getenv, bash
ascdsenv = getenv('source /home/ascds/.ascrc -r release; source /home/mta/bin/reset_param', shell='tcsh')
#
#--- read directory path
#
path = '/data/mta/Script/Dumps/Scripts/house_keeping/dir_list'
with open(path, 'r') as f:
    data = [line.strip() for line in f.readlines()]

for ent in data:
    atemp = re.split(':', ent)
    var  = atemp[1].strip()
    line = atemp[0].strip()
    exec("%s = %s" %(var, line))

sys.path.append(bin_dir)
sys.path.append(mta_dir)
import mta_common_functions as mcf
#
#--- temp writing file name
#
rtail  = int(time.time()* random.random())
zspace = '/tmp/zspace' + str(rtail)

PROCESS_SELECT = ['otg-msids.list', 'msids.list']
#otg-msids.list is the OTG category
#msids.list is the CCDM category
#msids_sim.list is the SIM category


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

    run_filter_script()

