# Dumps Parsing

This repository handles the parsing of dumps files into tracelog intermediary file for downstream resources
as well as running a Dumps_mon monitoring perl apparatus to send notifications of abnormal MSID behavior.

## Dependencies

The following dependencies must be accessible for the Dumps processing software to run properly:
- GOT Dumps file archive file directory
- A Ska3 Conda environment with Perl: (This doesn't have to be the flight isntallation. WE can create a copy of this environment)
- Data systems software: (Specifically the acorn tool)
- A file copy of the MTA op_limits.db limit database (for the update_par.py script updating alert parameters)
- A file copy of the ACIS MSID_Limits.txt limit database (for the update_par.py script updating alert parameters)
- A file copy of the Snapshot .scs107alert marker file (used in a small subsection of the Dumps alert monitor)
- A local mail sever with the ability to email the mtadude@cfa.harvard.edu and acisdude@cfa.harvard.edu distribution lists.

## Scripts

- install.sh: Installs the MTA Dumps processing software and dependencies into a preconfigured primary or secondary location or a specified file path.
    
    Installation must also include configuring the instance/.env environment file with the appropriate environment variables for the instance, such as enabling emails, and specifying the MTA, ACIS email addresses for sending notifications.

### Processing Scripts

The following scripts require the definition of the environment variable `DUMPS_PROCESS_ROOT` to point to the root directory of the Dumps processing software.
If this variable is not defined by the running wrapper script, then it will determine the root directory by the location of the script itself. These scripts must be run on a system which can view the DSOPS GOT directory and have access to the dumps files (c3po-v, r2d2-v, colossus-v).

- parse_dumps.sh: Parses dumps files into tracelog intermediary files for downstream resources.
    - parse_dump_files.py: Python script for unzipping the Dumps files and running acorn to parse data into tracelog intermediary files.
- dumps_alert_monitor.sh: Runs the Dumps alert monitor perl script to send notifications of abnormal MSID behavior.
    - dumps_alert_monitor.pl: Perl script for Dumps alert monitoring the tracelog intermediary files and sending notifications of abnormal MSID behavior.
    - cleanup_tracelog.py: Cleans up the tracelog intermediary files that are older than 10 days.
- update_par.py: Updates the parameters used in Dumps alerts.

## Notable Directories

- DUMPS_PROCESS_ROOT: Application software root
    - data: Intermediary directory for unzipped Dump Files ready for acorn processing
    - tracelog: Tracelog files form Acorn processed dump files
    - instance: installation-specific directory for configuration files
    - report: Intermediary directory for Dumps alert monitor reports and lock files.
    - scripts/: contains executable source code and libary modules.
    - scripts/parameter: periodically updated parameter files used by the dumps_alert_monitor.pl
    - scripts/resource: software resource library. Template text files and msid list for the acorn processing of a dump file
    - scripts/state: installation-specific directory to keep software state inforamtion of which dump and tracelog files have been processed.
## Crontab mta@c3pov-v

```
DUMPS_PROCESS_ROOT=/data/mta/Script/Dumps

32 */3 * * * ${ENV_FLIGHT}/bin/skare ${DUMPS_PROCESS_ROOT}/scripts/parse_dumps.sh >> ${HOME}/Logs/parse_dumps.cron 2>&1
35 1 1 * * cd ${DUMPS_PROCESS_ROOT}/scripts; ${ENV_FLIGHT}/bin/skare python update_par.py >> ${HOME}/Logs/update_dumps_mon_par.cron 2>&1
40 */3 * * *  ${ENV_FLIGHT}/bin/skare ${DUMPS_PROCESS_ROOT}/scripts/dumps_alert_monitor.sh >> ${HOME}/Logs/dumps_alert_mon.cron 2>&1
```