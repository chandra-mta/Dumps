#!/proj/sot/ska3/flight/bin/python

import sys, os
import pytest
import warnings

#Path altering to import script which is undergoing testing
TEST_DIR = os.path.dirname(os.path.realpath(__file__))
PARENT_DIR = os.path.dirname(TEST_DIR)
OUT_DIR = f"{TEST_DIR}/outTest"
sys.path.insert(0,PARENT_DIR)

NEW_DIR_LIST = [OUT_DIR]
for dir in NEW_DIR_LIST:
    os.system(f"mkdir -p {dir}")

import update_par as up

MOD_GROUP = [up]

for mod in MOD_GROUP:
    if hasattr(mod,'MAIN_DIR'):
        mod.MAIN_DIR = f"{PARENT_DIR}"
    if hasattr(mod,'OUT_DIR'):
        mod.OUT_DIR = f"{OUT_DIR}"
    if hasattr(mod,'PAR_FILE_LIST'):
        mod.PAR_FILE_LIST = [f"{PARENT_DIR}/acis_temp.par"]
    if hasattr(mod,'OVERWRITE_WITH_OP_LIMITS'):
        mod.OVERWRITE_WITH_OP_LIMITS = True
    if hasattr(mod,'OVERWRITE_WITH_ACIS'):
        mod.OVERWRITE_WITH_ACIS = True

up.update_par()