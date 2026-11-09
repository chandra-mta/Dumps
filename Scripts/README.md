# Dumps Parsing

This repository handles the parsing of dumps files into tracelog intermediary file for downstream resources
as well as running a Dumps_mon monitoring perl apparatus to send notifications of abnormal MSID behavior.

## Crontab mta@c3pov-v

```
DUMPS_PROCESS_ROOT=/data/mta/Script/Dumps

32 */3 * * * ${ENV_FLIGHT}/bin/skare ${DUMPS_PROCESS_ROOT}/Scripts/parse_dumps.sh >> ${HOME}/Logs/parse_dumps.cron 2>&1
40 * * * *   cd /data/mta/Script/Dumps/Dumps_mon; ./mta_run_2.6 >> $HOME/Logs/dumps_mon.cron 2>&1
35 1 1 * * cd /data/mta/Script/Dumps/Dumps_mon; /data/mta/Script/Dumps/Dumps_mon/update_par_wrap_script >> $HOME/Logs/update_par.cron 2>&1
```