# Dumps Monitoring Development


## Historical Comments
- 02/09/01 BS Chex_tst allows 0=360 for ra and roll
- 10/25/01 BS change alerts to sot_yellow, but only send once
-             delete ./.dumps_mon_lock to rearm
- 04/12/02 BS added alerts on Reaction Wheel speeds < $spdlim
- 06/26/02 BS added alerts on ACIS temps
- 04/03/03 BS added IRU current alert
- 04/25/03 BS added ACIS DEA HK TEMP alerts
- 05/07/03 BS added Dither alerts
- 06/26/03 BS change IRU alert to 2-hour mode calculation
- 12/16/03 BS add alert for tephin (in iru files, for convenience)
- 12/19/03 BS add alert for HKP27V (in iru files, for convenience)
- 03/29/04 BS send HKP27V to sot_yellow_alert, resend TEPHIN if > 102 F
- 06/03/04 BS added ephin 5EHSE300
- 02/10/05 BS added PLINE04
- 11/17/09 BS change EPHIN EBOX and TEPHIN limits
- 09/15/10 BS report max/mins in alerts
- 01/10/11 BS increase tephin limit

## Historical Parameter Settings
- allowable lag time for moves (seconds) # obsolete in v2.0
    - $tsclagtime = 500;
    - $falagtime = 200;
    - $gratlagtime = 1000;
    - $qtlagtime = 2000;
- added 11/28 BS allowable recover time
    - do not report violations that exhibit recovery within rectime seconds
    - $rectime = 340;

- gratings parameters # inactive
    - $gratinpar = 20;  # position where gratings is considered inserted
    - $gratoutpar = 65;  # position where gratings is considered retracted
    - $gratlim = 10;    # allowable disagreement between A and B readings