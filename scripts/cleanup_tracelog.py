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
