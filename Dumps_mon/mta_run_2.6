#! /bin/sh
# this script looks for IN/ccdmlist and IN/pcadlist
#  produced by Dumps/filters
# If these files exist there is new telemetry 
#  to send to dumps_mon (aka config_mon)
#  to check for violations.

ls /data/mta/Script/Dumps/Dumps_mon/IN | grep 'CCDM' | sed 's/^/IN\//' > ccdmlist
ls /data/mta/Script/Dumps/Dumps_mon/IN | grep 'PCAD' | sed 's/^/IN\//' > pcadlist
ls /data/mta/Script/Dumps/Dumps_mon/IN | grep 'ACIS' | sed 's/^/IN\//' > acislist
ls /data/mta/Script/Dumps/Dumps_mon/IN | grep 'IRU' | sed 's/^/IN\//' > irulist
ls /data/mta/Script/Dumps/Dumps_mon/IN | grep 'MUPS2' | sed 's/^/IN\//' > mupslist
if (test -s ccdmlist); then
  if (test -s pcadlist); then

    ./dumps_mon_2.6.pl -c @ccdmlist -p @pcadlist -a @acislist -g @irulist -d IN/deahk_temp_in.tmp -m @mupslist
    #dumps_mon_2.1.pl -c @ccdmlist -p @pcadlist -a @acislist
    #dumps_mon_2.0.pl -c @ccdmlist -p @pcadlist

    ./pred_state.ed
    #dumps_mon_1.2.pl -c @ccdmlist -p @pcadlist
    #dumps_mon_1.0.pl -c @ccdmlist -p @pcadlist

    mv ccdmlist IN/ccdmlist.last
    mv pcadlist IN/pcadlist.last
    mv acislist IN/acislist.last
    mv irulist IN/irulist.last
    mv mupslist IN/mupslist.last
    # clean up
    mv IN/*.tl /data/mta/Script/Dumps/Dumps_mon/Done 2> /dev/null
    /bin/gzip  -q IN/*.tl
    #mv IN/*.tl.gz /home/brad/Dumps/TLfiles
    #mv IN/*.tl.gz /data/mta/Script/Dumps/TLfiles
    mv IN/*.tl.gz /data/mta/Script/Dumps/Dumps_mon/Done 2> /dev/null
    if (test -s IN/xtmpnew); then
      rm IN/xtmpnew
    fi
  fi
fi

