#!/usr/bin/env /usr/bin/perl
##!/proj/axaf/bin/perl -w

# dumps_mon  aka  config_mon
# This program is called whenever new telemetry dumps 
#  are found in /dsops/GOT/input  (currently done by /Dumps/filters
#  Input is dumps_mon.pl -c<ccdm> -p<pcad>
#   where ccdm is acorn output containing TSCPOS, FAPOS and gratings data
#         pcad is acorn output containing quaternion data
#  This program compares this input with expected MP values.
#  Expected values come from pred_state.rdb,
#        see HEAD://proj/gads6/ops/Chex
#  If descrepencies are found, e-mail is sent to sot_yellow_alert

#use Chex;
# 02/09/01 BS Chex_tst allows 0=360 for ra and roll
#use Chex_tst;
use Chex;
# 10/25/01 BS change alerts to sot_yellow, but only send once
#             delete ./.dumps_mon_lock to rearm
# 04/12/02 BS added alerts on Reaction Wheel speeds < $spdlim
# 06/26/02 BS added alerts on ACIS temps
# 04/03/03 BS added IRU current alert
# 04/25/03 BS added ACIS DEA HK TEMP alerts
# 05/07/03 BS added Dither alerts
# 06/26/03 BS change IRU alert to 2-hour mode calculation
#use Statistics::Descriptive::Discrete;
use Discrete;
# 12/16/03 BS add alert for tephin (in iru files, for convenience)
# 12/19/03 BS add alert for HKP27V (in iru files, for convenience)
# 03/29/04 BS send HKP27V to sot_yellow_alert, resend TEPHIN if > 102 F
# 06/03/04 BS added ephin 5EHSE300
# 02/10/05 BS added PLINE04
# 11/17/09 BS change EPHIN EBOX and TEPHIN limits
# 09/15/10 BS report max/mins in alerts
# 01/10/11 BS increase tephin limit

# ************** Program Parameters ***************************

#  allowable lag time for moves (seconds) # obsolete in v2.0
#$tsclagtime = 500;
#$falagtime = 200;
#$gratlagtime = 1000;
#$qtlagtime = 2000;

#  added 11/28 BS allowable recover time
#   do not report violations that exhibit recovery within rectime seconds
#$rectime = 340;
$rectime = 1200;

#  violation limits
$tscposlim = 5;  # steps
$faposlim = 5;   # steps
$ralim = 0.05;   # degrees
#$ralim = 0.000001;   # degrees #debug
$declim = 0.05;  # degrees
$rolllim = 0.05; # degrees

$spdlim = 52.4;  # reaction speed alert limt rad/sec
$tratlim = 60 ;  # 3TRMTRAT (SIM temp) limit
$tratmax = 60 ;  # 3TRMTRAT (SIM temp) limit
#$spdlim = 205;  # test reaction speed alert limt rad/sec

#  gratings parameters # inactive
#$gratinpar = 20;  # position where gratings is considered inserted
#$gratoutpar = 65;  # position where gratings is considered retracted
$gratlim = 10;    # allowable disagreement between A and B readings

# iru limits
$airu1g1i_lim=200;
$tephin_lim=158.00;  # F
$tephin_max=158.00;  # F
$eph27v_lim=26.0;  # alert below 26V
$ebox_lim=75.0; # C

# pline temp limits
$pline04_lim=42.5;  #lower limit F

#  predicted state file
#$pred_file = "/home/brad/Dumps/Dumps_mon/pred_state.txt";

#  output file (temporary file, if non empty will be e-mailed)
$outfile = "dumps_mon.out";
$aoutfile = "dumps_mon_acis.out"; #temp out for acis violations
$acafile = "dumps_mon_aca.out"; #temp out for acis violations
$atoutfile = "dumps_mon_acis_temp.out"; #temp out for acis violations
$ioutfile = "dumps_mon_iru.out"; #temp out for iru violations
$eoutfile = "dumps_mon_eph.out"; #temp out for eph temp violations
$evoutfile = "dumps_mon_ephv.out"; #temp out for eph voltage violations
$doutfile = "dumps_mon_dea.out"; #temp out for dea violations
$poutfile = "dumps_mon_pline.out"; #temp out for pline violations

#  hack to get name of dump file(s) processed
$dumpname = "/data/mta/Script/Dumps/Dumps_mon/IN/xtmpnew";
# ************** End Program Parameters ***************************
 
#  get most recent predicted state file from HEAD network
#   must have .netrc in home directory
#system "source pred_state.get";

# *****************************************************************
$verbose = 0;

# Parse input arguments
&parse_args;

if ($verbose >= 2) {
    print "$0 args:\n";
    print "\tccdm infile:\t\t$cinfile\n";
    print "\tpcad infile:\t\t$pinfile\n";
    print "\tverbose:\t\t$verbose\n";
}  

my @ccdmfiles;
my @pcadfiles;
my @acisfiles;
my @irufiles;
my @deatfiles;
my @mupsfiles;
my $pcadfile;
my $ccdmfile;
my $acisfile;
my $irufile;
my $deatfile;
my $mupsfile;
my $counter;

my @timearr; #ccdm times
my @qttimearr; #pcad times
my @atimearr; #acis times
my @itimearr; #iru times
my @dttimearr; #dea temp times
my @mtimearr; #mups temp times
my @tscposarr;
my @faposarr;
my @tratarr;
my @grathaarr;
my @grathbarr;
my @gratlaarr;
my @gratlbarr;
my @pmodarr; # for rwheel checks
my @aseqarr; # for rwheel checks
my @spd1arr;
my @spd2arr;
my @spd3arr;
my @spd4arr;
my @spd5arr;
my @spd6arr;
my @raarr;
my @decarr;
my @rollarr;
my @ditharr;
my @deatemp1 ; # acis dea temps
my @deatemp2 ; # acis dea temps
my @deatemp3 ; # acis dea temps
my @deatemp4 ; # acis dea temps
my @deatemp5 ; # acis dea temps
my @deatemp6 ; # acis dea temps
my @deatemp7 ; # acis dea temps
my @deatemp8 ; # acis dea temps
my @deatemp9 ; # acis dea temps
my @deatemp10 ; # acis dea temps
my @deatemp11 ; # acis dea temps
my @deatemp12 ; # acis dea temps
my @airu1g1iarr; #iru A g1 current
my @tephinarr; #TEPHIN
my @eph27varr; # ephin 27v V & I
my @eph27sarr; #ephin 27v switch
my @eboxarr; #ephin ebox
my @pline04arr; #mups pline04
my @mnframarr; #minor frame number

if ($cinfile =~ /^\@/) {
    $cinfile = substr($cinfile, 1);

    my @patharr = split("/", $cinfile);
    my $path = "";
    
    for ($ii = 0; $ii < $#patharr; $ii++) {
	$path .= "/$patharr[$ii]";
    }

    open CFILE, "<$cinfile";
    
    $counter = 0;
    while($ccdmfile = <CFILE>) {
	chomp $ccdmfile;
	#$ccdmfiles[$counter++] = $path . $ccdmfile;
	$ccdmfiles[$counter++] = $ccdmfile;
    }
    close CFILE;
}
else {
    $ccdmfiles[0] = $cinfile;
}

if ($pinfile =~ /^\@/) {
    $pinfile = substr($pinfile, 1);

    my @patharr = split("/", $pinfile);
    my $path = "";
    
    for ($ii = 0; $ii < $#patharr; $ii++) {
	$path .= "/$patharr[$ii]";
    }

    open PFILE, "<$pinfile";
    
    $counter = 0;
    while($pcadfile = <PFILE>) {
	chomp $pcadfile;
	#$pcadfiles[$counter++] = $path . $pcadfile;
	$pcadfiles[$counter++] = $pcadfile;
    }
    close PFILE;
}
else {
    $pcadfiles[0] = $pinfile;
}

if ($ainfile =~ /^\@/) {
    $ainfile = substr($ainfile, 1);

    my @patharr = split("/", $ainfile);
    my $path = "";
    
    for ($ii = 0; $ii < $#patharr; $ii++) {
	$path .= "/$patharr[$ii]";
    }

    open AFILE, "<$ainfile";
    
    $counter = 0;
    while($acisfile = <AFILE>) {
	chomp $acisfile;
	$acisfiles[$counter++] = $acisfile;
    }
    close AFILE;
}
else {
    $acisfiles[0] = $ainfile;
}

if ($ginfile =~ /^\@/) {
    $ginfile = substr($ginfile, 1);

    my @patharr = split("/", $ginfile);
    my $path = "";
    
    for ($ii = 0; $ii < $#patharr; $ii++) {
	$path .= "/$patharr[$ii]";
    }

    open GFILE, "<$ginfile";
    
    $counter = 0;
    while($irufile = <GFILE>) {
	chomp $irufile;
	$irufiles[$counter++] = $irufile;
    }
    close GFILE;
}
else {
    $irufiles[0] = $ginfile;
}

if ($dtinfile =~ /^\@/) {
    $dtinfile = substr($dtinfile, 1);

    my @patharr = split("/", $dtinfile);
    my $path = "";
    
    for ($ii = 0; $ii < $#patharr; $ii++) {
	$path .= "/$patharr[$ii]";
    }

    open DTFILE, "<$dtinfile";
    
    $counter = 0;
    while($deatfile = <DTFILE>) {
	chomp $deatfile;
	$deatfiles[$counter++] = $deatfile;
    }
    close DTFILE;
}
else {
    $deatfiles[0] = $dtinfile;
}

if ($mupsfile =~ /^\@/) {
    $mupsfile = substr($mupsfile, 1);

    my @patharr = split("/", $mupsfile);
    my $path = "";
    
    for ($ii = 0; $ii < $#patharr; $ii++) {
	$path .= "/$patharr[$ii]";
    }

    open DTFILE, "<$mupsfile";
    
    $counter = 0;
    while($mupsfile = <DTFILE>) {
	chomp $mupsfile;
	$mupsfiles[$counter++] = $mupsfile;
    }
    close DTFILE;
}
else {
    $mupsfiles[0] = $mupsfile;
}

# *********************************************************
# read dump data
# *********************************************************
# read dump data
my $hdr;
my @hdrline;
my $intimecol = 0;
# CCDM columns
my $in3tscposcol  = 0;
my $in3faposcol  = 0;
my $intratcol  = 0;
my $ingrathacol  = 0;
my $ingrathbcol  = 0;
my $ingratlacol  = 0;
my $ingratlbcol  = 0;
my $inpmodcol = 0;
my $inaseqcol = 0;
my $inspd1col = 0;
my $inspd2col = 0;
my $inspd3col = 0;
my $inspd4col = 0;
my $inspd5col = 0;
my $inspd6col = 0;

my $j = 0; # counter (indexer) for ccdm obs

foreach $file (@ccdmfiles) {

  open CCDMFILE, "$file" or die "can not open $file";

  $hdr = <CCDMFILE>;
  chomp $hdr;
  # Get column information on the input PRIMARYCCDM file
  @hdrline = split ("\t", $hdr);

  for ($ii=0; $ii<=$#hdrline; $ii++) {
    if ($hdrline[$ii] eq "TIME") {
      $intimecol = $ii;
    }    
    elsif ($hdrline[$ii] eq "3TSCPOS") {
      $in3tscposcol = $ii;
    }
    elsif ($hdrline[$ii] eq "3FAPOS") {
      $in3faposcol = $ii;
    }
    elsif ($hdrline[$ii] eq "3TRMTRAT") {
      $intratcol = $ii;
    }
    elsif ($hdrline[$ii] eq "4HPOSARO") {
      $ingrathacol = $ii;
    }
    elsif ($hdrline[$ii] eq "4HPOSBRO") {
      $ingrathbcol = $ii;
    }
    elsif ($hdrline[$ii] eq "4LPOSARO") {
      $ingratlacol = $ii;
    }
    elsif ($hdrline[$ii] eq "4LPOSBRO") {
      $ingratlbcol = $ii;
    }
    elsif ($hdrline[$ii] eq "AOPCADMD") {
      $inpmodcol = $ii;
    }
    elsif ($hdrline[$ii] eq "AOACASEQ") {
      $inaseqcol = $ii;
    }
    elsif ($hdrline[$ii] eq "AORWSPD1") {
      $inspd1col = $ii;
    }
    elsif ($hdrline[$ii] eq "AORWSPD2") {
      $inspd2col = $ii;
    }
    elsif ($hdrline[$ii] eq "AORWSPD3") {
      $inspd3col = $ii;
    }
    elsif ($hdrline[$ii] eq "AORWSPD4") {
      $inspd4col = $ii;
    }
    elsif ($hdrline[$ii] eq "AORWSPD5") {
      $inspd5col = $ii;
    }
    elsif ($hdrline[$ii] eq "AORWSPD6") {
      $inspd6col = $ii;
    }

  } # for ($ii=0; $ii<=$#hdrline; $ii++)

  my @inarr;
  my $inline;

  # remove whitespace line
  $inline = <CCDMFILE>;
  # read ccdm data
  while ( defined ($inline = <CCDMFILE>)) {
    chomp ($inline);
    @inarr = split ("\t", $inline);
    # fix acorn y2k bug
    my @time = split (" ", $inarr[$intimecol]);
    if ($time[0] < 1900) {
      $time[0] = $time[0] + 1900;
    }
    $timearr[$j] = join (":", @time);
    #$timearr[$j] = $inarr[$intimecol];
    my @tmptime = split ("::", $timearr[$j]);
    $timearr[$j] = join (":", @tmptime);
    $tscposarr[$j] = $inarr[$in3tscposcol];
    $faposarr[$j] = $inarr[$in3faposcol];
    $tratarr[$j] = $inarr[$intratcol];
    $grathaarr[$j] = $inarr[$ingrathacol];
    $grathbarr[$j] = $inarr[$ingrathbcol];
    $gratlaarr[$j] = $inarr[$ingratlacol];
    $gratlbarr[$j] = $inarr[$ingratlbcol];
    $pmodarr[$j] = $inarr[$inpmodcol];
    $pmodarr[$j] =~ s/\s+//;
    $aseqarr[$j] = $inarr[$inaseqcol];
    $aseqarr[$j] =~ s/\s+//;
    $spd1arr[$j] = $inarr[$inspd1col];
    $spd2arr[$j] = $inarr[$inspd2col];
    $spd3arr[$j] = $inarr[$inspd3col];
    $spd4arr[$j] = $inarr[$inspd4col];
    $spd5arr[$j] = $inarr[$inspd5col];
    $spd6arr[$j] = $inarr[$inspd6col];
    ++$j;
  } # read ccdm data

  close CCDMFILE;
}

my $inqt1col = 0;
my $inqt2col = 0;
my $inqt3col = 0;
my $inqt4col = 0;
my $indithcol = 0;
$intimecol = 0;
$j = 0; # counter (indexer) for pcad obs
foreach $file (@pcadfiles) {

  open PCADFILE, "$file" or die;

  $hdr = <PCADFILE>;
  chomp $hdr;
  # Get column information on the input PRIMARYPCAD file
  @hdrline = split ("\t", $hdr);

  for ($ii=0; $ii<=$#hdrline; $ii++) {
    if ($hdrline[$ii] eq "TIME") {
      $intimecol = $ii;
    }    
    elsif ($hdrline[$ii] eq "AOATTQT1") {
      $inqt1col = $ii;
    }
    elsif ($hdrline[$ii] eq "AOATTQT2") {
      $inqt2col = $ii;
    }
    elsif ($hdrline[$ii] eq "AOATTQT3") {
      $inqt3col = $ii;
    }
    elsif ($hdrline[$ii] eq "AOATTQT4") {
      $inqt4col = $ii;
    }
    elsif ($hdrline[$ii] eq "AODITHEN") {
      $indithcol = $ii;
    }
  } # for ($ii=0; $ii<=$#hdrline; $ii++)

  my @inarr;
  my $inline;

  # remove whitespace line
  $inline = <PCADFILE>;
  # read pcad data
  while ( defined ($inline = <PCADFILE>)) {
    chomp ($inline);
    @inarr = split ("\t", $inline);
    # fix acorn y2k bug
    my @time = split (" ", $inarr[$intimecol]);
    if ($time[0] < 1900) {
      $time[0] = $time[0] + 1900;
    }
    $qttimearr[$j] = join (":", @time);
    #$qttimearr[$j] = $inarr[$intimecol];
    my @tmptime = split ("::", $qttimearr[$j]);
    $qttimearr[$j] = join (":", @tmptime);
    %raddecroll = &quat_to_euler($inarr[$inqt1col],
                                 $inarr[$inqt2col],
                                 $inarr[$inqt3col],
                                 $inarr[$inqt4col]);
    $raarr[$j] = $raddecroll{ra};
    $decarr[$j] = $raddecroll{dec};
    $rollarr[$j] = $raddecroll{roll};
    $ditharr[$j] = $inarr[$indithcol];
    $ditharr[$j] =~ s/ //g; # remove acorn's spaces or chex won't match
    ++$j;
  } # read pcad data

  close PCADFILE;
}

my $airu1g1icol = 0;
my $tephincol = 0;
my $eph27vcol = 0;
my $eph27scol = 0;
my $eboxcol = 0;
my $mnframcol = 0;
$intimecol = 0;
$j = 0; # counter (indexer) for acis obs
foreach $file (@irufiles) {

  open IRUFILE, "$file" or die;

  $hdr = <IRUFILE>;
  chomp $hdr;
  # Get column information on the input PRIMARYACIS file
  @hdrline = split ("\t", $hdr);

  for ($ii=0; $ii<=$#hdrline; $ii++) {
    if ($hdrline[$ii] eq "TIME") {
      $intimecol = $ii;
    }    
    elsif ($hdrline[$ii] eq "AIRU1G1I") {
      $airu1g1icol = $ii;
    }
    elsif ($hdrline[$ii] eq "TEPHIN") {
      $tephincol = $ii;
    }
    elsif ($hdrline[$ii] eq "5HSE202") {
      $eph27vcol = $ii;
    }
    elsif ($hdrline[$ii] eq "5EHSE106") {
      $eph27scol = $ii;
    }
    elsif ($hdrline[$ii] eq "5EHSE300") {
      $eboxcol = $ii;
    }
    # also must use minor frame #
    #  don't use first few minor frames
    #  acorn can take several mn frames to change 5HSE202
    elsif ($hdrline[$ii] eq "CVCMNCTR") {
      $mnframcol = $ii;
    }
  } # for ($ii=0; $ii<=$#hdrline; $ii++)

  my @inarr;
  my $inline;

  # remove whitespace line
  $inline = <IRUFILE>;
  # read iru data
  while ( defined ($inline = <IRUFILE>)) {
    chomp ($inline);
    @inarr = split ("\t", $inline);
    # fix acorn y2k bug
    my @time = split (" ", $inarr[$intimecol]);
    if ($time[0] < 1900) {
      $time[0] = $time[0] + 1900;
    }
    $itimearr[$j] = join (":", @time);
    #$qttimearr[$j] = $inarr[$intimecol];
    my @tmptime = split ("::", $itimearr[$j]);
    $itimearr[$j] = join (":", @tmptime);
    $airu1g1iarr[$j] = $inarr[$airu1g1icol];
    $tephinarr[$j] = $inarr[$tephincol];
    $eph27varr[$j] = $inarr[$eph27vcol];
    $eph27sarr[$j] = $inarr[$eph27scol];
    $eboxarr[$j] = $inarr[$eboxcol];
    $mnframarr[$j] = $inarr[$mnframcol];
    ++$j;
  } # read iru data

  close IRUFILE;
}

my $pline04col = 0;
$intimecol = 0;
$j = 0; # counter (indexer) for acis obs
foreach $file (@mupsfiles) {

  open MUPSFILE, "$file" or die;

  $hdr = <MUPSFILE>;
  chomp $hdr;
  # Get column information on the input PRIMARYMUPS2 file
  @hdrline = split ("\t", $hdr);

  for ($ii=0; $ii<=$#hdrline; $ii++) {
    if ($hdrline[$ii] eq "TIME") {
      $mintimecol = $ii;
    }    
    elsif ($hdrline[$ii] eq "PLINE04T") {
      $pline04col = $ii;
    }
  } # for ($ii=0; $ii<=$#hdrline; $ii++)

  my @inarr;
  my $inline;

  # remove whitespace line
  $inline = <MUPSFILE>;
  # read MUPS data
  while ( defined ($inline = <MUPSFILE>)) {
    chomp ($inline);
    @inarr = split ("\t", $inline);
    # fix acorn y2k bug
    my @time = split (" ", $inarr[$mintimecol]);
    if ($time[0] < 1900) {
      $time[0] = $time[0] + 1900;
    }
    $mtimearr[$j] = join (":", @time);
    my @tmptime = split ("::", $mtimearr[$j]);
    $mtimearr[$j] = join (":", @tmptime);
    $pline04arr[$j] = $inarr[$pline04col];
    ++$j;
  } # read iru data

  close MUPSFILE;
}

#  dea hkp temperatures - this one's different than the others
#    since input does not come from acorn
my $dttimecol = 0;
my $deahk1col = 1;
my $deahk2col = 2;
my $deahk3col = 3;
my $deahk4col = 4;
my $deahk5col = 5;
my $deahk6col = 6;
my $deahk7col = 7;
my $deahk8col = 8;
my $deahk9col = 9;
my $deahk10col = 10;
my $deahk11col = 11;
my $deahk12col = 12;
$j = 0; # counter (indexer) for acis obs
foreach $file (@deatfiles) {

  open DEAFILE, "$file" or die;
  my @inarr;
  my $inline;

  # remove whitespace line
  #$inline = <DEAFILE>;
  # read dea data
  while ( defined ($inline = <DEAFILE>)) {
    chomp ($inline);
    @inarr = split ("\t", $inline);
    $dttimearr[$j] = $inarr[$dttimecol];
    $deatemp1[$j] = $inarr[$deahk1col];
    $deatemp2[$j] = $inarr[$deahk2col];
    $deatemp3[$j] = $inarr[$deahk3col];
    $deatemp4[$j] = $inarr[$deahk4col];
    $deatemp5[$j] = $inarr[$deahk5col];
    $deatemp6[$j] = $inarr[$deahk6col];
    $deatemp7[$j] = $inarr[$deahk7col];
    $deatemp8[$j] = $inarr[$deahk8col];
    $deatemp9[$j] = $inarr[$deahk9col];
    $deatemp10[$j] = $inarr[$deahk10col];
    $deatemp11[$j] = $inarr[$deahk11col];
    $deatemp12[$j] = $inarr[$deahk12col];
    ++$j;
  } # read dea data

  close DEAFILE;
}
# *****************************************************************
# **************** Compare actual to predicted ********************
#$chex = Chex->new('/home/brad/Dumps/Dumps_mon/pred_state.rdb');
#$chex = Chex->new('/data/mta/Script/Dumps/Dumps_mon/pred_state.rdb');

  ######### check SIM temp ########
  if ( ($tratarr[$i]) > $tratmax) {
    $tratmax = $tratarr[$i];
    $tratmaxtime = $timearr[$i];
    $tratmaxpos = $tratarr[$i];
  }
  if ( ($tratarr[$i]) > $tratlim && $tratviol == 0) {
    $tratviol = 1;
    $trattmptime = $timearr[$i];
    $trattmppos = $tratarr[$i];
  } elsif ( ($tratarr[$i]) < $tratlim && $tratviol == 1) {
    $tratviol = 0;
    if ( convert_time($timearr[$i]) - convert_time($trattmptime) > $rectime ) {
      printf REPORT " 3TRMTRAT    Violation at %19s Actual: %4.1f Expected: \< %4.1f deg C\n", $trattmptime, $trattmppos, $tratlim;
      printf REPORT " 3TRMTRAT    Maximum temperature at %19s Value: %4.1f deg C\n", $tratmaxtime, $tratmaxpos;
      printf REPORT " 3TRMTRAT    Recovery at %19s Actual: %4.1f Expected: \< %4.1f deg C\n", $timearr[$i], $tratarr[$i], $tratlim;
    }
  }
  ######### check rw speeds ########
  if ( $aseqarr[$i] eq "KALM" && $pmodarr[$i] eq "NPNT") {
    if ( abs($spd1arr[$i]) < $spdlim && $spd1viol == 0) {
      $spd1viol = 1;
      $spd1tmptime = $timearr[$i];
      $spd1tmppos = $spd1arr[$i];
    } elsif ( abs($spd1arr[$i]) > $spdlim && $spd1viol == 1) {
      $spd1viol = 0;
      if ( convert_time($timearr[$i]) - convert_time($spd1tmptime) > $rectime ) {
        printf REPORT " AORWSPD1    Violation at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $spd1tmptime, $spd1tmppos, $spdlim;
        printf REPORT " AORWSPD1    Recovery at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $timearr[$i], $spd1arr[$i], $spdlim;
      }
    }
    if ( abs($spd2arr[$i]) < $spdlim && $spd2viol == 0) {
      $spd2viol = 1;
      $spd2tmptime = $timearr[$i];
      $spd2tmppos = $spd2arr[$i];
    } elsif ( abs($spd2arr[$i]) > $spdlim && $spd2viol == 1) {
      $spd2viol = 0;
      if ( convert_time($timearr[$i]) - convert_time($spd2tmptime) > $rectime ) {
        printf REPORT " AORWSPD2    Violation at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $spd2tmptime, $spd2tmppos, $spdlim;
        printf REPORT " AORWSPD2    Recovery at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $timearr[$i], $spd2arr[$i], $spdlim;
      }
    }
    if ( abs($spd3arr[$i]) < $spdlim && $spd3viol == 0) {
      $spd3viol = 1;
      $spd3tmptime = $timearr[$i];
      $spd3tmppos = $spd3arr[$i];
    } elsif ( abs($spd3arr[$i]) > $spdlim && $spd3viol == 1) {
      $spd3viol = 0;
      if ( convert_time($timearr[$i]) - convert_time($spd3tmptime) > $rectime ) {
        printf REPORT " AORWSPD3    Violation at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $spd3tmptime, $spd3tmppos, $spdlim;
        printf REPORT " AORWSPD3    Recovery at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $timearr[$i], $spd3arr[$i], $spdlim;
      }
    }
    if ( abs($spd4arr[$i]) < $spdlim && $spd4viol == 0) {
      $spd4viol = 1;
      $spd4tmptime = $timearr[$i];
      $spd4tmppos = $spd4arr[$i];
    } elsif ( abs($spd4arr[$i]) > $spdlim && $spd4viol == 1) {
      $spd4viol = 0;
      if ( convert_time($timearr[$i]) - convert_time($spd4tmptime) > $rectime ) {
        printf REPORT " AORWSPD4    Violation at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $spd4tmptime, $spd4tmppos, $spdlim;
        printf REPORT " AORWSPD4    Recovery at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $timearr[$i], $spd4arr[$i], $spdlim;
      }
    }
    if ( abs($spd5arr[$i]) < $spdlim && $spd5viol == 0) {
      $spd5viol = 1;
      $spd5tmptime = $timearr[$i];
      $spd5tmppos = $spd5arr[$i];
    } elsif ( abs($spd5arr[$i]) > $spdlim && $spd5viol == 1) {
      $spd5viol = 0;
      if ( convert_time($timearr[$i]) - convert_time($spd5tmptime) > $rectime ) {
        printf REPORT " AORWSPD5    Violation at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $spd5tmptime, $spd5tmppos, $spdlim;
        printf REPORT " AORWSPD5    Recovery at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $timearr[$i], $spd5arr[$i], $spdlim;
      }
    }
    if ( abs($spd6arr[$i]) < $spdlim && $spd6viol == 0) {
      $spd6viol = 1;
      $spd6tmptime = $timearr[$i];
      $spd6tmppos = $spd6arr[$i];
    } elsif ( abs($spd6arr[$i]) > $spdlim && $spd6viol == 1) {
      $spd6viol = 0;
      if ( convert_time($timearr[$i]) - convert_time($spd6tmptime) > $rectime ) {
        printf REPORT " AORWSPD6    Violation at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $spd6tmptime, $spd6tmppos, $spdlim;
        printf REPORT " AORWSPD6    Recovery at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $timearr[$i], $spd6arr[$i], $spdlim;
      }
    }
} # for #timearr
# Report violations that do not exhibit recovery
if ( $tscviol == 1 ) {
  printf REPORT " TSC   Violation at %19s Actual: %8.1f Expected: %8.1f\n", $tsctmptime, $tsctmppos, @tsctmppred;
}
if ( $faviol == 1 ) {
  printf REPORT " FA    Violation at %19s Actual: %8.1f Expected: %8.1f\n", $fatmptime, $fatmppos, @fatmppred;
}
if ( $tratviol == 1 ) {
  printf REPORT " 3TRMTRAT    Violation at %19s Actual: %8.1f Expected: \< %8.1f deg C\n", $trattmptime, $trattmppos, $tratlim;
}
if ( $spd1viol == 1 ) {
  printf REPORT " AORWSPD1    Violation at %19s Actual: %8.1f Expected: \> %4.1f rad/s\n", $spd1tmptime, $spd1tmppos, $spdlim;
}
if ( $spd2viol == 1 ) {
  printf REPORT " AORWSPD2    Violation at %19s Actual: %8.1f Expected: \> %4.1f rad/s\n", $spd2tmptime, $spd2tmppos, $spdlim;
}
if ( $spd3viol == 1 ) {
  printf REPORT " AORWSPD3    Violation at %19s Actual: %8.1f Expected: \> %4.1f rad/s\n", $spd3tmptime, $spd3tmppos, $spdlim;
}
if ( $spd4viol == 1 ) {
  printf REPORT " AORWSPD4    Violation at %19s Actual: %8.1f Expected: \> %4.1f rad/s\n", $spd4tmptime, $spd4tmppos, $spdlim;
}
if ( $spd5viol == 1 ) {
  printf REPORT " AORWSPD5    Violation at %19s Actual: %8.1f Expected: \> %4.1f rad/s\n", $spd5tmptime, $spd5tmppos, $spdlim;
}
if ( $spd6viol == 1 ) {
  printf REPORT " AORWSPD6    Violation at %19s Actual: %8.1f Expected: \> %4.1f rad/s\n", $spd6tmptime, $spd6tmppos, $spdlim;
}

# ******************************************************************

# pcad comparisons
#  separate loop because different times
my $raviol = 0;
my $decviol = 0;
my $rollviol = 0;
my $dithviol = 0;
$j = 0;
#open PTEST, ">>pcadtest.out"; # debugpcad
for ( $i=0; $i<$#qttimearr; $i++ ) {
 #print "PCAD $i $#qttimearr\n"; #debugggg
#for ( $i=0; $i<20; $i++ ) { # debug
  #printf PTEST "$qttimearr[$i] $raarr[$i] $decarr[$i] $rollarr[$i]\n"; #debugpcad

  ######## check ra ########

  ######## check dither ########
#dither_check  $match = $chex->match(var => 'dither',
#dither_check                        val => $ditharr[$i],
#dither_check                        tol => 'MATCH',
#dither_check                        date=> $qttimearr[$i]);
#dither_check  if ( $match == 0 && $dithviol == 0) {
#dither_check    $dithviol = 1;
#dither_check    $dithtmptime = $qttimearr[$i];
#dither_check    $dithtmppos = $ditharr[$i];
#dither_check    @dithtmppred = @{$chex->{chex}{dither}};
#dither_check  }
#dither_check  if ( $match == 1 && $dithviol == 1) {
#dither_check    $dithviol = 0;
#dither_check    if ( convert_time($qttimearr[$i]) - convert_time($dithtmptime) > $rectime ) {
#dither_check      printf DREPORT " DITHER  Violation at %19s Actual: %5s Expected: %5s\n", $dithtmptime, $dithtmppos, @dithtmppred;
#dither_check      @recpos = @{$chex->{chex}{dither}};
#dither_check      $m = &index_match($ditharr[$i], 0, @recpos);
#dither_check      printf DREPORT " DITHER  Recovery at %19s Actual: %5s Expected: %5s\n", $qttimearr[$i], $ditharr[$i], $recpos[$m];
#dither_check    }
#dither_check  }

} # for #qttimearr
# Report violations that do not exhibit recovery
if ( $raviol == 1 ) {
      printf REPORT " RA    Violation at %19s Actual: %8.4f Expected: %8.4f\n", $ratmptime, $ratmppos, @ratmppred;
}
if ( $decviol == 1 ) {
      printf REPORT " DEC   Violation at %19s Actual: %8.4f Expected: %8.4f\n", $dectmptime, $dectmppos, @dectmppred;
}
if ( $rollviol == 1 ) {
      printf REPORT " ROLL  Violation at %19s Actual: %8.4f Expected: %8.4f\n", $rolltmptime, $rolltmppos, @rolltmppred;
}
#dither_checkif ( $dithviol == 1 ) {
#dither_check      printf DREPORT " DITHER  Violation at %19s Actual: %5s Expected: %5s\n", $dithtmptime, $dithtmppos, @dithtmppred;
#dither_check}

#close PTEST; #debugpcad
close REPORT;
close DREPORT;

# ******************************************************************
# acis checks
open REPORT, "> $aoutfile";
my %acish;
foreach $file (@acisfiles) {

  open ACISFILE, "$file" or die;

  $hdr = <ACISFILE>;
  chomp $hdr;
  # Get column information on the input PRIMARYACIS file
  @hdrline = split ("\t", $hdr);

  my @inarr;
  my $inline;

  # remove whitespace line
  $inline = <ACISFILE>;
  # read acis data
  while ( defined ($inline = <ACISFILE>)) {
    chomp ($inline);
    @inarr = split ("\t", $inline);
    # fix acorn y2k bug
    my @time = split (" ", $inarr[0]);
    if ($time[0] < 1900) {
      $time[0] = $time[0] + 1900;
    }
    $atime = join (":", @time);
    my @tmptime = split ("::", $atime);
    $atime = join (":", @tmptime);
    push @{$acish{"$hdrline[0]"}}, $atime;
    for ($acisi=1;$acisi<=$#hdrline;$acisi++) {
      push @{$acish{"$hdrline[$acisi]"}},$inarr[$acisi];
    } # for ($acisi=1;$acisi<=$#hdrline;$acisi++) {
  } # read acis data

  close ACISFILE;
}
open(ACAPAR,"<aca_check.par");
my %acapar;
<ACAPAR>;
<ACAPAR>;
while (<ACAPAR>) {
  chomp;
  @parline=split; 
  @acapar{"$parline[0]"}=[$parline[1],$parline[2],$parline[5],$parline[6],0,0,0,0,$parline[6]];
} # while (<ACISPAR>) {
close ACAPAR;

$j = 0;
open REPORT, "> $acafile";
@akeys=keys(%acapar);
@time=@{$acish{"TIME"}};
for ( $i=0; $i<=$#{$acish{TIME}}; $i++ ) {
  for ( $j=0; $j<=$#akeys; $j++ ) {
    $acish{AACCCDPT}[$i] = (${$acish{AACCCDPT}}[$i] - 32)*5/9;
    if ( ${$acish{"$akeys[$j]"}}[$i] != 0 && (${$acish{"$akeys[$j]"}}[$i] > ${$acapar{"$akeys[$j]"}}[3]) && (${$acish{"$akeys[$j]"}}[$i] > ${$acapar{"$akeys[$j]"}}[8])) {
      $acapar{$akeys[$j]}[7]=${$acish{"TIME"}}[$i];
      $acapar{$akeys[$j]}[8]=${$acish{"$akeys[$j]"}}[$i];
    }
    if ( ${$acish{"$akeys[$j]"}}[$i] != 0 && (${$acish{"$akeys[$j]"}}[$i] < ${$acapar{"$akeys[$j]"}}[2]) && (${$acish{"$akeys[$j]"}}[$i] < ${$acapar{"$akeys[$j]"}}[8])) {
      $acapar{$akeys[$j]}[7]=${$acish{"TIME"}}[$i];
      $acapar{$akeys[$j]}[8]=${$acish{"$akeys[$j]"}}[$i];
    }
    if ( ${$acish{"$akeys[$j]"}}[$i] != 0 && (${$acish{"$akeys[$j]"}}[$i] <= ${$acapar{"$akeys[$j]"}}[2] || ${$acish{"$akeys[$j]"}}[$i] >= ${$acapar{"$akeys[$j]"}}[3]) && ${$acapar{"$akeys[$j]"}}[4] == 0) {
      $acapar{$akeys[$j]}[4]=1;
      $acapar{$akeys[$j]}[5]=${$acish{"TIME"}}[$i];
      $acapar{$akeys[$j]}[6]=${$acish{"$akeys[$j]"}}[$i];
    }
    if ( ${$acish{"$akeys[$j]"}}[$i] ne "" && (${$acish{"$akeys[$j]"}}[$i] > ${$acapar{"$akeys[$j]"}}[2] && ${$acish{"$akeys[$j]"}}[$i] < ${$acapar{"$akeys[$j]"}}[3]) && ${$acapar{"$akeys[$j]"}}[4] == 1) {
      $acapar{"$akeys[$j]"}[4]=0;
      $tdiff = convert_time(${$acish{"TIME"}}[$i]) - convert_time(${$acapar{"$akeys[$j]"}}[5]);
      print "\n $j $i ${$acish{\"$akeys[$j]\"}}[$i] ${$acapar{\"$akeys[$j]\"}}[2] ${$acapar{\"$akeys[$j]\"}}[3] $akeys[$j]\n";
      if ( convert_time(${$acish{"TIME"}}[$i]) - convert_time(${$acapar{"$akeys[$j]"}}[5]) > 300 ) {
        printf REPORT "$akeys[$j]  Violation at %19s Value: %7.2f Limit: %7.2f \n", ${$acapar{"$akeys[$j]"}}[5],${$acapar{"$akeys[$j]"}}[6],${$acapar{"$akeys[$j]"}}[3];
        printf REPORT "$akeys[$j]  Maximum Violation at %19s Value: %7.2f\n", ${$acapar{"$akeys[$j]"}}[7],${$acapar{"$akeys[$j]"}}[8];
        printf REPORT "$akeys[$j]  Recovery at %19s Value: %7.2f Limit: %7.2f \n", ${$acish{"TIME"}}[$i],${$acish{"$akeys[$j]"}}[$i],${$acapar{"$akeys[$j]"}}[3];
      }
    }
  } #for ( $j=0; $j<=$keys; $j++ ) {
} #for ( $i=0; $i<=$#acish; $i++ ) {
for ( $j=0; $j<=$#akeys; $j++ ) {
  if ( ${$acapar{"$akeys[$j]"}}[4] == 1) {
    printf REPORT "$akeys[$j]  Violation at %19s Value: %7.2f Limit: %7.2f \n", ${$acapar{"$akeys[$j]"}}[5],${$acapar{"$akeys[$j]"}}[6],${$acapar{"$akeys[$j]"}}[3];
    printf REPORT "$akeys[$j]  Maximum Violation at %19s Value: %7.2f\n", ${$acapar{"$akeys[$j]"}}[7],${$acapar{"$akeys[$j]"}}[8];
  } #
} #for ( $j=0; $j<=$keys; $j++ ) {
close REPORT;
# ----------- end aca checks

open(ACISPAR,"<acis_check.par");
my %acispar;
<ACISPAR>;
<ACISPAR>;
while (<ACISPAR>) {
  chomp;
  @parline=split; 
  @acispar{"$parline[0]"}=[$parline[3],$parline[4],$parline[7],$parline[8],0,0,0,0,$parline[8]];
} # while (<ACISPAR>) {
close ACISPAR;

$j = 0;
open REPORT, "> $aoutfile";
@akeys=keys(%acispar);
@time=@{$acish{"TIME"}};
for ( $i=0; $i<=$#{$acish{TIME}}; $i++ ) {
  for ( $j=0; $j<=$#akeys; $j++ ) {
    if ( ${$acish{"$akeys[$j]"}}[$i] != 0 && (${$acish{"$akeys[$j]"}}[$i] > ${$acispar{"$akeys[$j]"}}[3]) && (${$acish{"$akeys[$j]"}}[$i] > ${$acispar{"$akeys[$j]"}}[8])) {
      $acispar{$akeys[$j]}[7]=${$acish{"TIME"}}[$i];
      $acispar{$akeys[$j]}[8]=${$acish{"$akeys[$j]"}}[$i];
    }
    if ( ${$acish{"$akeys[$j]"}}[$i] != 0 && (${$acish{"$akeys[$j]"}}[$i] < ${$acispar{"$akeys[$j]"}}[2]) && (${$acish{"$akeys[$j]"}}[$i] < ${$acispar{"$akeys[$j]"}}[8])) {
      $acispar{$akeys[$j]}[7]=${$acish{"TIME"}}[$i];
      $acispar{$akeys[$j]}[8]=${$acish{"$akeys[$j]"}}[$i];
    }
    if ( ${$acish{"$akeys[$j]"}}[$i] != 0 && (${$acish{"$akeys[$j]"}}[$i] <= ${$acispar{"$akeys[$j]"}}[2] || ${$acish{"$akeys[$j]"}}[$i] >= ${$acispar{"$akeys[$j]"}}[3]) && ${$acispar{"$akeys[$j]"}}[4] == 0) {
      $acispar{$akeys[$j]}[4]=1;
      $acispar{$akeys[$j]}[5]=${$acish{"TIME"}}[$i];
      $acispar{$akeys[$j]}[6]=${$acish{"$akeys[$j]"}}[$i];
    }
    if ( ${$acish{"$akeys[$j]"}}[$i] ne "" && (${$acish{"$akeys[$j]"}}[$i] > ${$acispar{"$akeys[$j]"}}[2] && ${$acish{"$akeys[$j]"}}[$i] < ${$acispar{"$akeys[$j]"}}[3]) && ${$acispar{"$akeys[$j]"}}[4] == 1) {
      $acispar{"$akeys[$j]"}[4]=0;
      $tdiff = convert_time(${$acish{"TIME"}}[$i]) - convert_time(${$acispar{"$akeys[$j]"}}[5]);
      print "\n $j $i ${$acish{\"$akeys[$j]\"}}[$i] ${$acispar{\"$akeys[$j]\"}}[2] ${$acispar{\"$akeys[$j]\"}}[3] $akeys[$j]\n";
      if ( convert_time(${$acish{"TIME"}}[$i]) - convert_time(${$acispar{"$akeys[$j]"}}[5]) > 300 ) {
        printf REPORT "$akeys[$j]  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", ${$acispar{"$akeys[$j]"}}[5],${$acispar{"$akeys[$j]"}}[6],${$acispar{"$akeys[$j]"}}[2],${$acispar{"$akeys[$j]"}}[3],${$acispar{"$akeys[$j]"}}[0],${$acispar{"$akeys[$j]"}}[1];
        printf REPORT "$akeys[$j]  Maximum Violation at %19s Value: %7.2f\n", ${$acispar{"$akeys[$j]"}}[7],${$acispar{"$akeys[$j]"}}[8];
        printf REPORT "$akeys[$j]  Recovery at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", ${$acish{"TIME"}}[$i],${$acish{"$akeys[$j]"}}[$i],${$acispar{"$akeys[$j]"}}[2],${$acispar{"$akeys[$j]"}}[3],${$acispar{"$akeys[$j]"}}[0],${$acispar{"$akeys[$j]"}}[1];
      }
    }
  } #for ( $j=0; $j<=$keys; $j++ ) {
} #for ( $i=0; $i<=$#acish; $i++ ) {
for ( $j=0; $j<=$#akeys; $j++ ) {
  if ( ${$acispar{"$akeys[$j]"}}[4] == 1) {
    printf REPORT "$akeys[$j]  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", ${$acispar{"$akeys[$j]"}}[5],${$acispar{"$akeys[$j]"}}[6],${$acispar{"$akeys[$j]"}}[2],${$acispar{"$akeys[$j]"}}[3],${$acispar{"$akeys[$j]"}}[0],${$acispar{"$akeys[$j]"}}[1];
    printf REPORT "$akeys[$j]  Maximum Violation at %19s Value: %7.2f\n", ${$acispar{"$akeys[$j]"}}[7],${$acispar{"$akeys[$j]"}}[8];
  } #
} #for ( $j=0; $j<=$keys; $j++ ) {
close REPORT;

# ******************************************************************
# acis extra checks
open REPORT, "> $atoutfile";
my %acish;
foreach $file (@acisfiles) {

  open ACISFILE, "$file" or die;

  $hdr = <ACISFILE>;
  chomp $hdr;
  # Get column information on the input PRIMARYACIS file
  @hdrline = split ("\t", $hdr);

  my @inarr;
  my $inline;

  # remove whitespace line
  $inline = <ACISFILE>;
  # read acis data
  while ( defined ($inline = <ACISFILE>)) {
    chomp ($inline);
    @inarr = split ("\t", $inline);
    # fix acorn y2k bug
    my @time = split (" ", $inarr[0]);
    if ($time[0] < 1900) {
      $time[0] = $time[0] + 1900;
    }
    $atime = join (":", @time);
    my @tmptime = split ("::", $atime);
    $atime = join (":", @tmptime);
    push @{$acish{"$hdrline[0]"}}, $atime;
    for ($acisi=1;$acisi<=$#hdrline;$acisi++) {
      push @{$acish{"$hdrline[$acisi]"}},$inarr[$acisi];
    } # for ($acisi=1;$acisi<=$#hdrline;$acisi++) {
  } # read acis data

  close ACISFILE;
}
open(ACISPAR,"<acis_temp.par");
my %acispar;
<ACISPAR>;
<ACISPAR>;
while (<ACISPAR>) {
  chomp;
  @parline=split; 
  @acispar{"$parline[0]"}=[$parline[1],$parline[2],$parline[5],$parline[6],0,0,0];
} # while (<ACISPAR>) {
close ACISPAR;

$j = 0;
open REPORT, "> $atoutfile";
@akeys=keys(%acispar);
@time=@{$acish{"TIME"}};
for ( $i=0; $i<=$#{$acish{TIME}}; $i++ ) {
  for ( $j=0; $j<=$#akeys; $j++ ) {
    if ( ${$acish{"$akeys[$j]"}}[$i] != 0 && (${$acish{"$akeys[$j]"}}[$i] <= ${$acispar{"$akeys[$j]"}}[2] || ${$acish{"$akeys[$j]"}}[$i] >= ${$acispar{"$akeys[$j]"}}[3]) && ${$acispar{"$akeys[$j]"}}[4] == 0) {
      $acispar{$akeys[$j]}[4]=1;
      $acispar{$akeys[$j]}[5]=${$acish{"TIME"}}[$i];
      $acispar{$akeys[$j]}[6]=${$acish{"$akeys[$j]"}}[$i];
    }
    if ( ${$acish{"$akeys[$j]"}}[$i] ne "" && (${$acish{"$akeys[$j]"}}[$i] > ${$acispar{"$akeys[$j]"}}[2] && ${$acish{"$akeys[$j]"}}[$i] < ${$acispar{"$akeys[$j]"}}[3]) && ${$acispar{"$akeys[$j]"}}[4] == 1) {
      $acispar{"$akeys[$j]"}[4]=0;
      $tdiff = convert_time(${$acish{"TIME"}}[$i]) - convert_time(${$acispar{"$akeys[$j]"}}[5]);
      print "\n $j $i ${$acish{\"$akeys[$j]\"}}[$i] ${$acispar{\"$akeys[$j]\"}}[2] ${$acispar{\"$akeys[$j]\"}}[3] $akeys[$j]\n";
      if ( convert_time(${$acish{"TIME"}}[$i]) - convert_time(${$acispar{"$akeys[$j]"}}[5]) > 300 ) {
        printf REPORT "$akeys[$j]  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", ${$acispar{"$akeys[$j]"}}[5],${$acispar{"$akeys[$j]"}}[6],${$acispar{"$akeys[$j]"}}[2],${$acispar{"$akeys[$j]"}}[3],${$acispar{"$akeys[$j]"}}[0],${$acispar{"$akeys[$j]"}}[1];
        printf REPORT "$akeys[$j]  Recovery at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", ${$acish{"TIME"}}[$i],${$acish{"$akeys[$j]"}}[$i],${$acispar{"$akeys[$j]"}}[2],${$acispar{"$akeys[$j]"}}[3],${$acispar{"$akeys[$j]"}}[0],${$acispar{"$akeys[$j]"}}[1];
      }
    }
  } #for ( $j=0; $j<=$keys; $j++ ) {
} #for ( $i=0; $i<=$#acish; $i++ ) {
for ( $j=0; $j<=$#akeys; $j++ ) {
  if ( ${$acispar{"$akeys[$j]"}}[4] == 1) {
    printf REPORT "$akeys[$j]  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", ${$acispar{"$akeys[$j]"}}[5],${$acispar{"$akeys[$j]"}}[6],${$acispar{"$akeys[$j]"}}[2],${$acispar{"$akeys[$j]"}}[3],${$acispar{"$akeys[$j]"}}[0],${$acispar{"$akeys[$j]"}}[1];
  } #
} #for ( $j=0; $j<=$keys; $j++ ) {
close REPORT;

# ******************************************************************
# iru checks
#  gyro current gets noisy above its limit, so we treat differently
#   than the others.  Here look for 2-hour mode above the limit 
#   instead of $rectime above limit.
my $iruviol = 0;
my $maxairu1g1i = 0;
my $maxirutmptime = 0;
my @sec_itimearr;
for ($i=0;$i<=$#itimearr;$i++) {
  $sec_itimearr[$i]=convert_time($itimearr[$i]);
}
#@sec_itimearr = map convert_time, @itimearr;
open REPORT, "> $ioutfile";
$starti=0;
$stopi=0;
$itimespan=7200; # sec over which to compute mode
while ($sec_itimearr[$stopi]-$sec_itimearr[$starti] < $itimespan && $stopi < $#itimearr) {
  $stopi++;
  #print "m $stopi\n"; #debugmode
}
#open (ITESTOUT,">xitest.out"); #debugmode
for ( $i=$stopi; $i<$#itimearr; $i+=500 ) {  # check every 200th data point
                                            # or it's really slow
  #print "IRU $i $#itimearr\n"; #debugggg
  my $stats = new Statistics::Descriptive::Discrete;
  while ($sec_itimearr[$i]-$sec_itimearr[$starti] > $itimespan) {
    $starti++;
    #print "s $starti\n";
  }
  $stats->add_data(@airu1g1iarr[$starti..$i]);
  $mode=$stats->mode();
  #print "$mode\n"; #debugmode
  #printf ITESTOUT "$i $sec_itimearr[$i] $itimearr[$i] $mode\n"; # debugmode
  if ( $mode > $airu1g1i_lim) {
    printf REPORT "AIRU1G1I  Violation at %19s Mode: %7.2f Limit: %7.2f mAmp\n", $itimearr[$i], $mode, $airu1g1i_lim;
    $i=$#itimearr+1; # found a violation, so stop
    #print "e $mode\n"; #debugmode
  } # if $stats->mode
} # for #itimearr

close REPORT;
#close ITESTOUT; #debugmode

# ******************************************************************
# ephin checks
open REPORT, "> $eoutfile";
open REPORTV, "> $evoutfile";
my $tephinviol = 0;
my $tephin102viol = 0;
my $eph27vviol = 0;
my $eboxviol = 0;
my $last27s=0;
#my $trectime = 120; #set rectime to 2 min for this one
my $trectime = 240; # 120 not enough to avoid bad data 
$jj=0;
for ( $i=0; $i<$#itimearr; $i+=2 ) {  # check every 200th data point
                                            # or it's really slow
  #print "EPH $i $#itimearr $mnframarr[$i] $eph27sarr[$i] $eph27varr[$i]\n"; # debuggggg
  # send another alert if temp exceeds 120 F
  if ( ($tephinarr[$i]) > 120.00 && $tephin102viol == 0) {
    $tephin102viol=1;
    close REPORT;  #start report over
    open REPORT, "> $eoutfile";
    if (! -s "./.dumps_mon_eph102_lock") {
      `cp .dumps_mon_eph_lock .dumps_mon_eph102_lock`;
      unlink ".dumps_mon_eph_lock"; # force rearming
    }
  }
    
  if ( ($tephinarr[$i]) > $tephin_max) {
    $tephin_max = $tephinarr[$i];
    $tephinmaxtime = $itimearr[$i];
    $tephinmaxpos = $tephinarr[$i];
  }
  if ( ($tephinarr[$i]) > $tephin_lim && $tephinviol == 0) {
    $tephinviol = 1;
    $tephintmptime = $itimearr[$i];
    $tephintmppos = $tephinarr[$i];
  } elsif ( ($tephinarr[$i]) < $tephin_lim && $tephinviol == 1) {
    $tephinviol = 0;
    if ( convert_time($itimearr[$i]) - convert_time($tephintmptime) > $trectime ) {
      printf REPORT " TEPHIN    Violation at %19s Value: %7.2f Limit: \< %7.2f deg C\n", $tephintmptime, $tephintmppos, $tephin_lim;
      printf REPORT " TEPHIN    Maximum Violation at %19s Value: %7.2f deg C\n", $tephinmaxtime, $tephinmaxpos;
      printf REPORT " TEPHIN    Recovery at %19s Value: %7.2f Limit: \< %7.2f deg C\n", $itimearr[$i], $tephinarr[$i], $tephin_lim;
    }
  } # if ( ($tephinarr[$i]) > $tephin_lim && $tephinviol == 0) {

  if ( ($eboxarr[$i]) > $ebox_lim && $eboxviol == 0) {
    $eboxviol = 1;
    $eboxtmptime = $itimearr[$i];
    $eboxtmppos = $eboxarr[$i];
  } elsif ( ($eboxarr[$i]) < $ebox_lim && $eboxviol == 1) {
    $eboxviol = 0;
    if ( convert_time($itimearr[$i]) - convert_time($eboxtmptime) > $trectime ) {
      printf REPORT " EPHIN EBOX (5EHSE300)   Violation at %19s Value: %7.2f Limit: \< %7.2f deg C\n", $eboxtmptime, $eboxtmppos, $ebox_lim;
      printf REPORT " EPHIN EBOX (5EHSE300)   Recovery at %19s Value: %7.2f Limit: \< %7.2f deg C\n", $itimearr[$i], $eboxarr[$i], $ebox_lim;
    }
  } # if ( ($eboxarr[$i]) > $ebox_lim && $eboxviol == 0) {

  if ( $mnframarr[$i] > 20 && $mnframarr[$i] < 108 && $eph27sarr[$i] == $last27s && ($eph27sarr[$i]+1) % 2 == 1) {  # only check if we know eph27v shows voltage
    #if ( ($mnframarr[$i]) > 4 && $eph27sarr[$i] != $last27s && ($eph27sarr[$i]+1) % 2 == 0 && $eph27varr[$i] < $eph27v_lim && $eph27vviol == 0) {
    if ( $eph27varr[$i] < $eph27v_lim && $eph27vviol == 0) {
      $eph27vviol = 1;
      $eph27vtmptime = $itimearr[$i];
      $eph27vtmppos = $eph27varr[$i];
    } elsif ( ($eph27varr[$i]) > $eph27v_lim && $eph27vviol == 1) {
      $eph27vviol = 0;
      if ( convert_time($itimearr[$i]) - convert_time($eph27vtmptime) > $trectime ) {
        printf REPORTV " EPHIN HKP27V  Violation at %19s Value: %7.2f Limit: \> %7.2f V\n", $eph27vtmptime, $eph27vtmppos, $eph27v_lim;
        printf REPORTV " EPHIN HKP27V  Recovery at %19s Value: %7.2f Limit: \> %7.2f V\n", $itimearr[$i], $eph27varr[$i], $eph27v_lim;
      }
    } # if ( $eph27varr[$i] < $eph27v_lim && $eph27vviol == 0) {
  } #if ( ($mnframarr[$i]) > 4 && $eph27sarr[$i] != $last27s && ($eph27sarr[$i]+1) % 2 == 0) {  # only check if we know eph27v shows voltage
  $last27s=$eph27sarr[$i];
  $jj+=2;  # scheme to look at a few frames in order then skip a bunch
  if ($jj == 16) { $i+=120; }
  if ($jj == 32) {
    $i+=1387;
    $jj=0;
   } # if ($jj == 32) {
} # for ( $i=0; $i<$#itimearr; $i++ ) {
if ( $tephinviol == 1 ) {
      printf REPORT " TEPHIN    Violation at %19s Value: %7.2f Limit: \< %7.2f deg C\n", $tephintmptime, $tephintmppos, $tephin_lim;
      printf REPORT " TEPHIN    Maximum Violation at %19s Value: %7.2f deg C\n", $tephinmaxtime, $tephinmaxpos;
}
if ( $eboxviol == 1 ) {
      printf REPORT " EPHIN EBOX (5EHSE300)    Violation at %19s Value: %7.2f Limit: \< %7.2f deg C\n", $eboxtmptime, $eboxtmppos, $ebox_lim;
}
if ( $eph27vviol == 1 ) {
      printf REPORTV " EPHIN HKP27V  Violation at %19s Value: %7.2f Limit: \> %7.2f V\n", $eph27vtmptime, $eph27vtmppos, $eph27v_lim;
}
close REPORT;
close REPORTV;

# ******************************************************************
# mups pline checks
open REPORT, "> $poutfile";
my $pline04viol=0;
my $trectime = 120; # 
$jj=0;
for ( $i=0; $i<$#mtimearr; $i+=2 ) {  # 
  if ( ($pline04arr[$i]) < $pline04_lim && $pline04viol == 0) {
    $pline04viol = 1;
    $pline04tmptime = $mtimearr[$i];
    $pline04tmppos = $pline04arr[$i];
  } elsif ( ($pline04arr[$i]) > $pline04_lim && $pline04viol == 1) {
    $pline04viol = 0;
    if ( convert_time($mtimearr[$i]) - convert_time($pline04tmptime) > $trectime ) {
      printf REPORT " PLINE04   Violation at %19s Value: %7.2f Limit: \> %7.2f deg C\n", $pline04tmptime, $pline04tmppos, $pline04_lim;
      printf REPORT " PLINE04   Recovery at %19s Value: %7.2f Limit: \> %7.2f deg C\n", $mtimearr[$i], $pline04arr[$i], $pline04_lim;
    }
  } # if ( ($pline04arr[$i]) < $pline04_lim && $pline04viol == 0) {

} # for ( $i=0; $i<$#mtimearr; $i++ ) {
if ( $pline04viol == 1 ) {
      printf REPORT " PLINE04   Violation at %19s Value: %7.2f Limit: \> %7.2f deg C\n", $pline04tmptime, $pline04tmppos, $pline04_lim;
}
close REPORT;

# ******************************************************************
# acis dea hk temp checks
my $deahk1viol = 0;
my $deahk2viol = 0;
my $deahk3viol = 0;
my $deahk4viol = 0;
my $deahk5viol = 0;
my $deahk6viol = 0;
my $deahk7viol = 0;
my $deahk8viol = 0;
my $deahk9viol = 0;
my $deahk10viol = 0;
my $deahk11viol = 0;
my $deahk12viol = 0;
# ****** acis dea temp limits degC
my $deat1min = 5.0;  # min limit
my $deat1_min = 5.0; # running min initial
my $deat1max = 35.0; # max limit
my $deat1_max = 35.0; # running max initial
my $deat2min = 5.0;
my $deat2_min = 5.0;
my $deat2max = 35.0;
my $deat2_max = 35.0;
my $deat3min = 0.0;
my $deat3_min = 0.0;
my $deat3max = 45.0;
my $deat3_max = 45.0;
my $deat4min = 0.0;
my $deat4_min = 0.0;
my $deat4max = 45.0;
my $deat4_max = 45.0;
my $deat5min = 0.0;
my $deat5_min = 0.0;
my $deat5max = 45.0;
my $deat5_max = 45.0;
my $deat6min = 0.0;
my $deat6_min = 0.0;
my $deat6max = 45.0;
my $deat6_max = 45.0;
my $deat7min = 0.0;
my $deat7_min = 0.0;
my $deat7max = 45.0;
my $deat7_max = 45.0;
my $deat8min = 0.0;
my $deat8_min = 0.0;
my $deat8max = 45.0;
my $deat8_max = 45.0;
my $deat9min = 0.0;
my $deat9_min = 0.0;
my $deat9max = 45.0;
my $deat9_max = 45.0;
my $deat10min = 0.0;
my $deat10_min = 0.0;
my $deat10max = 45.0;
my $deat10_max = 45.0;
my $deat11min = 0.0;
my $deat11_min = 0.0;
my $deat11max = 45.0;
my $deat11_max = 45.0;
my $deat12min = 0.0;
my $deat12_min = 0.0;
my $deat12max = 45.0;
my $deat12_max = 45.0;

$j = 0;
open REPORT, "> $doutfile";
for ( $i=0; $i<$#dttimearr; $i++ ) {
  #print "DEA $i $#dttimearr\n"; # debuggggg

  if ( ($deatemp1[$i]) > $deatemp1_max || ($deatemp1{$i}) < $deatemp1_min ) {
    $deatemp1_max = $deatemp1[$i];
    $deatemp1maxtime = $dttimearr[$i];
    $deatemp1maxpos = $deatemp1[$i];
  }

  if ( $deatemp1[$i] != 0 && ($deatemp1[$i] <= $deat1min || $deatemp1[$i] >= $deat1max) && $deahk1viol == 0) {
    $deahk1viol = 1;
    $deat1intmptime = $dttimearr[$i];
    $deat1intmppos = $deatemp1[$i];
  }
  if ( $deatemp1[$i] ne "" && $deatemp1[$i] > $deat1min && $deatemp1[$i] < $deat1max && $deahk1viol == 1) {
    $deahk1viol = 0;
    if ( $dttimearr[$i] - $deat1intmptime > $rectime ) {
      printf REPORT "DPAHK1 BEP PC Board Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat1intmptime u s u d`, $deat1intmppos, $deat1min, $deat1max;
      printf REPORT " DPAHK1    Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp1maxtime u s u d`, $deatemp1maxpos;
      printf REPORT "DPAHK1  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp1[$i], $deat1min, $deat1max;
    }
  }
  if ( ($deatemp2[$i]) > $deatemp2_max || ($deatemp2{$i}) < $deatemp2_min ) {
    $deatemp2_max = $deatemp2[$i];
    $deatemp2maxtime = $dttimearr[$i];
    $deatemp2maxpos = $deatemp2[$i];
  }

  if ( $deatemp2[$i] != 0 && ($deatemp2[$i] <= $deat2min || $deatemp2[$i] >= $deat2max) && $deahk2viol == 0) {
    $deahk2viol = 1;
    $deat2intmptime = $dttimearr[$i];
    $deat2intmppos = $deatemp2[$i];
  }
  if ( $deatemp2[$i] ne "" && $deatemp2[$i] > $deat2min && $deatemp2[$i] < $deat2max && $deahk2viol == 1) {
    $deahk2viol = 0;
    if ( $dttimearr[$i] - $deat2intmptime > $rectime ) {
      printf REPORT "DPAHK2 BEP Oscillator Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat2intmptime u s u d`, $deat2intmppos, $deat2min, $deat2max;
      printf REPORT " DPAHK2    Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp2maxtime u s u d`, $deatemp2maxpos;
      printf REPORT "DPAHK2  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp2[$i], $deat2min, $deat2max;
    }
  }
  if ( ($deatemp3[$i]) > $deatemp3_max || ($deatemp3{$i}) < $deatemp3_min ) {
    $deatemp3_max = $deatemp3[$i];
    $deatemp3maxtime = $dttimearr[$i];
    $deatemp3maxpos = $deatemp3[$i];
  }

  if ( $deatemp3[$i] != 0 && ($deatemp3[$i] <= $deat3min || $deatemp3[$i] >= $deat3max) && $deahk3viol == 0) {
    $deahk3viol = 1;
    $deat3intmptime = $dttimearr[$i];
    $deat3intmppos = $deatemp3[$i];
  }
  if ( $deatemp3[$i] ne "" && $deatemp3[$i] > $deat3min && $deatemp3[$i] < $deat3max && $deahk3viol == 1) {
    $deahk3viol = 0;
    if ( $dttimearr[$i] - $deat3intmptime > $rectime ) {
      printf REPORT "DPAHK3 FEP 0 Mongoose Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat3intmptime u s u d`, $deat3intmppos, $deat3min, $deat3max;
      printf REPORT " DPAHK3    Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp3maxtime u s u d`, $deatemp3maxpos;
      printf REPORT "DPAHK3  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp3[$i], $deat3min, $deat3max;
    }
  }
  if ( ($deatemp4[$i]) > $deatemp4_max || ($deatemp4{$i}) < $deatemp4_min ) {
    $deatemp4_max = $deatemp4[$i];
    $deatemp4maxtime = $dttimearr[$i];
    $deatemp4maxpos = $deatemp4[$i];
  }

  if ( $deatemp4[$i] != 0 && ($deatemp4[$i] <= $deat4min || $deatemp4[$i] >= $deat4max) && $deahk4viol == 0) {
    $deahk4viol = 1;
    $deat4intmptime = $dttimearr[$i];
    $deat4intmppos = $deatemp4[$i];
  }
  if ( $deatemp4[$i] ne "" && $deatemp4[$i] > $deat4min && $deatemp4[$i] < $deat4max && $deahk4viol == 1) {
    $deahk4viol = 0;
    if ( $dttimearr[$i] - $deat4intmptime > $rectime ) {
      printf REPORT "DPAHK4 FEP 0 PC Board Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat4intmptime u s u d`, $deat4intmppos, $deat4min, $deat4max;
      printf REPORT " DPAHK4    Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp4maxtime u s u d`, $deatemp4maxpos;
      printf REPORT "DPAHK4  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp4[$i], $deat4min, $deat4max;
    }
  }
  if ( ($deatemp5[$i]) > $deatemp5_max || ($deatemp5{$i}) < $deatemp5_min ) {
    $deatemp5_max = $deatemp5[$i];
    $deatemp5maxtime = $dttimearr[$i];
    $deatemp5maxpos = $deatemp5[$i];
  }

  if ( $deatemp5[$i] != 0 && ($deatemp5[$i] <= $deat5min || $deatemp5[$i] >= $deat5max) && $deahk5viol == 0) {
    $deahk5viol = 1;
    $deat5intmptime = $dttimearr[$i];
    $deat5intmppos = $deatemp5[$i];
  }
  if ( $deatemp5[$i] ne "" && $deatemp5[$i] > $deat5min && $deatemp5[$i] < $deat5max && $deahk5viol == 1) {
    $deahk5viol = 0;
    if ( $dttimearr[$i] - $deat5intmptime > $rectime ) {
      printf REPORT "DPAHK5 FEP 0 ACTEL Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat5intmptime u s u d`, $deat5intmppos, $deat5min, $deat5max;
      printf REPORT " DPAHK5    Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp5maxtime u s u d`, $deatemp5maxpos;
      printf REPORT "DPAHK5  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp5[$i], $deat5min, $deat5max;
    }
  }
  if ( ($deatemp6[$i]) > $deatemp6_max || ($deatemp6{$i}) < $deatemp6_min ) {
    $deatemp6_max = $deatemp6[$i];
    $deatemp6maxtime = $dttimearr[$i];
    $deatemp6maxpos = $deatemp6[$i];
  }

  if ( $deatemp6[$i] != 0 && ($deatemp6[$i] <= $deat6min || $deatemp6[$i] >= $deat6max) && $deahk6viol == 0) {
    $deahk6viol = 1;
    $deat6intmptime = $dttimearr[$i];
    $deat6intmppos = $deatemp6[$i];
  }
  if ( $deatemp6[$i] ne "" && $deatemp6[$i] > $deat6min && $deatemp6[$i] < $deat6max && $deahk6viol == 1) {
    $deahk6viol = 0;
    if ( $dttimearr[$i] - $deat6intmptime > $rectime ) {
      printf REPORT "DPAHK6 FEP 0 RAM Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat6intmptime u s u d`, $deat6intmppos, $deat6min, $deat6max;
      printf REPORT " DPAHK6    Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp6maxtime u s u d`, $deatemp6maxpos;
      printf REPORT "DPAHK6  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp6[$i], $deat6min, $deat6max;
    }
  }
  if ( ($deatemp7[$i]) > $deatemp7_max || ($deatemp7{$i}) < $deatemp7_min ) {
    $deatemp7_max = $deatemp7[$i];
    $deatemp7maxtime = $dttimearr[$i];
    $deatemp7maxpos = $deatemp7[$i];
  }

  if ( $deatemp7[$i] != 0 && ($deatemp7[$i] <= $deat7min || $deatemp7[$i] >= $deat7max) && $deahk7viol == 0) {
    $deahk7viol = 1;
    $deat7intmptime = $dttimearr[$i];
    $deat7intmppos = $deatemp7[$i];
  }
  if ( $deatemp7[$i] ne "" && $deatemp7[$i] > $deat7min && $deatemp7[$i] < $deat7max && $deahk7viol == 1) {
    $deahk7viol = 0;
    if ( $dttimearr[$i] - $deat7intmptime > $rectime ) {
      printf REPORT "DPAHK7 FEP 0 Frame Buf. Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat7intmptime u s u d`, $deat7intmppos, $deat7min, $deat7max;
      printf REPORT " DPAHK7    Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp7maxtime u s u d`, $deatemp7maxpos;
      printf REPORT "DPAHK7  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp7[$i], $deat7min, $deat7max;
    }
  }
  if ( ($deatemp8[$i]) > $deatemp8_max || ($deatemp8{$i}) < $deatemp8_min ) {
    $deatemp8_max = $deatemp8[$i];
    $deatemp8maxtime = $dttimearr[$i];
    $deatemp8maxpos = $deatemp8[$i];
  }

  if ( $deatemp8[$i] != 0 && ($deatemp8[$i] <= $deat8min || $deatemp8[$i] >= $deat8max) && $deahk8viol == 0) {
    $deahk8viol = 1;
    $deat8intmptime = $dttimearr[$i];
    $deat8intmppos = $deatemp8[$i];
  }
  if ( $deatemp8[$i] ne "" && $deatemp8[$i] > $deat8min && $deatemp8[$i] < $deat8max && $deahk8viol == 1) {
    $deahk8viol = 0;
    if ( $dttimearr[$i] - $deat8intmptime > $rectime ) {
      printf REPORT "DPAHK8 FEP 1 Mongoose Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat8intmptime u s u d`, $deat8intmppos, $deat8min, $deat8max;
      printf REPORT " DPAHK8    Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp8maxtime u s u d`, $deatemp8maxpos;
      printf REPORT "DPAHK8  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp8[$i], $deat8min, $deat8max;
    }
  }
  if ( ($deatemp9[$i]) > $deatemp9_max || ($deatemp9{$i}) < $deatemp9_min ) {
    $deatemp9_max = $deatemp9[$i];
    $deatemp9maxtime = $dttimearr[$i];
    $deatemp9maxpos = $deatemp9[$i];
  }

  if ( $deatemp9[$i] != 0 && ($deatemp9[$i] <= $deat9min || $deatemp9[$i] >= $deat9max) && $deahk9viol == 0) {
    $deahk9viol = 1;
    $deat9intmptime = $dttimearr[$i];
    $deat9intmppos = $deatemp9[$i];
  }
  if ( $deatemp9[$i] ne "" && $deatemp9[$i] > $deat9min && $deatemp9[$i] < $deat9max && $deahk9viol == 1) {
    $deahk9viol = 0;
    if ( $dttimearr[$i] - $deat9intmptime > $rectime ) {
      printf REPORT "DPAHK9 FEP 1 PC Board Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat9intmptime u s u d`, $deat9intmppos, $deat9min, $deat9max;
      printf REPORT " DPAHK9    Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp9maxtime u s u d`, $deatemp9maxpos;
      printf REPORT "DPAHK9  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp9[$i], $deat9min, $deat9max;
    }
  }
  if ( ($deatemp10[$i]) > $deatemp10_max || ($deatemp10{$i}) < $deatemp10_min ) {
    $deatemp10_max = $deatemp10[$i];
    $deatemp10maxtime = $dttimearr[$i];
    $deatemp10maxpos = $deatemp10[$i];
  }

  if ( $deatemp10[$i] != 0 && ($deatemp10[$i] <= $deat10min || $deatemp10[$i] >= $deat10max) && $deahk10viol == 0) {
    $deahk10viol = 1;
    $deat10intmptime = $dttimearr[$i];
    $deat10intmppos = $deatemp10[$i];
  }
  if ( $deatemp10[$i] ne "" && $deatemp10[$i] > $deat10min && $deatemp10[$i] < $deat10max && $deahk10viol == 1) {
    $deahk10viol = 0;
    if ( $dttimearr[$i] - $deat10intmptime > $rectime ) {
      printf REPORT "DPAHK10 FEP 1 ACTEL Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat10intmptime u s u d`, $deat10intmppos, $deat10min, $deat10max;
      printf REPORT " DPAHK10   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp10maxtime u s u d`, $deatemp10maxpos;
      printf REPORT "DPAHK10  Recovery at %19s Value: %7.2f\n", `axTime3 $dttimearr[$i] u s u d`, $deatemp10[$i], $deat10min, $deat10max;
    }
  }
  if ( ($deatemp11[$i]) > $deatemp11_max || ($deatemp11{$i}) < $deatemp11_min ) {
    $deatemp11_max = $deatemp11[$i];
    $deatemp11maxtime = $dttimearr[$i];
    $deatemp11maxpos = $deatemp11[$i];
  }

  if ( $deatemp11[$i] != 0 && ($deatemp11[$i] <= $deat11min || $deatemp11[$i] >= $deat11max) && $deahk11viol == 0) {
    $deahk11viol = 1;
    $deat11intmptime = $dttimearr[$i];
    $deat11intmppos = $deatemp11[$i];
  }
  if ( $deatemp11[$i] ne "" && $deatemp11[$i] > $deat11min && $deatemp11[$i] < $deat11max && $deahk11viol == 1) {
    $deahk11viol = 0;
    if ( $dttimearr[$i] - $deat11intmptime > $rectime ) {
      printf REPORT "DPAHK11 FEP 1 RAM Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat11intmptime u s u d`, $deat11intmppos, $deat11min, $deat11max;
      printf REPORT " DPAHK11   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp11maxtime u s u d`, $deatemp11maxpos;
      printf REPORT "DPAHK11  Recovery at %19s Value: %7.2f\n", `axTime3 $dttimearr[$i] u s u d`, $deatemp11[$i], $deat11min, $deat11max;
    }
  }
  if ( ($deatemp12[$i]) > $deatemp12_max || ($deatemp12{$i}) < $deatemp12_min ) {
    $deatemp12_max = $deatemp12[$i];
    $deatemp12maxtime = $dttimearr[$i];
    $deatemp12maxpos = $deatemp12[$i];
  }

  if ( $deatemp12[$i] != 0 && ($deatemp12[$i] <= $deat12min || $deatemp12[$i] >= $deat12max) && $deahk12viol == 0) {
    $deahk12viol = 1;
    $deat12intmptime = $dttimearr[$i];
    $deat12intmppos = $deatemp12[$i];
  }
  if ( $deatemp12[$i] ne "" && $deatemp12[$i] > $deat12min && $deatemp12[$i] < $deat12max && $deahk12viol == 1) {
    $deahk12viol = 0;
    if ( $dttimearr[$i] - $deat12intmptime > $rectime ) {
      printf REPORT "DPAHK12 FEP 1 Frame Buf. Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat12intmptime u s u d`, $deat12intmppos, $deat12min, $deat12max;
      printf REPORT " DPAHK12   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp12maxtime u s u d`, $deatemp12maxpos;
      printf REPORT "DPAHK12  Recovery at %19s Value: %7.2f\n", `axTime3 $dttimearr[$i] u s u d`, $deatemp12[$i], $deat12min, $deat12max;
    }
  }

} # for #dttimearr
# Report violations that do not exhibit recovery
if ( $deahk1viol == 1 ) {
      printf REPORT "DPAHK1 BEP PC Board Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat1intmptime u s u d`, $deat1intmppos, $deat1min, $deat1max;
      printf REPORT " DPAHK1   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp1maxtime u s u d`, $deatemp1maxpos;
}
if ( $deahk2viol == 2 ) {
      printf REPORT "DPAHK2 BEP Oscillator Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat2intmptime u s u d`, $deat2intmppos, $deat2min, $deat2max;
      printf REPORT " DPAHK2   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp2maxtime u s u d`, $deatemp2maxpos;
}
if ( $deahk3viol == 1 ) {
      printf REPORT "DPAHK3 FEP 0 Mongoose Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat3intmptime u s u d`, $deat3intmppos, $deat3min, $deat3max;
      printf REPORT " DPAHK3   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp3maxtime u s u d`, $deatemp3maxpos;
}
if ( $deahk4viol == 1 ) {
      printf REPORT "DPAHK4 FEP 0 PC Board Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat4intmptime u s u d`, $deat4intmppos, $deat4min, $deat4max;
      printf REPORT " DPAHK4   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp4maxtime u s u d`, $deatemp4maxpos;
}
if ( $deahk5viol == 1 ) {
      printf REPORT "DPAHK5 FEP 0 ACTEL Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat5intmptime u s u d`, $deat5intmppos, $deat5min, $deat5max;
      printf REPORT " DPAHK5   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp5maxtime u s u d`, $deatemp5maxpos;
}
if ( $deahk6viol == 1 ) {
      printf REPORT "DPAHK6 FEP 0 RAM Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat6intmptime u s u d`, $deat6intmppos, $deat6min, $deat6max;
      printf REPORT " DPAHK6   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp6maxtime u s u d`, $deatemp6maxpos;
}
if ( $deahk7viol == 1 ) {
      printf REPORT "DPAHK7 FEP 0 Frame Buf. Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat7intmptime u s u d`, $deat7intmppos, $deat7min, $deat7max;
      printf REPORT " DPAHK7   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp7maxtime u s u d`, $deatemp7maxpos;
}
if ( $deahk8viol == 1 ) {
      printf REPORT "DPAHK8 FEP 1 Mongoose Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat8intmptime u s u d`, $deat8intmppos, $deat8min, $deat8max;
      printf REPORT " DPAHK8   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp8maxtime u s u d`, $deatemp8maxpos;
}
if ( $deahk9viol == 1 ) {
      printf REPORT "DPAHK9 FEP 1 PC Board Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat9intmptime u s u d`, $deat9intmppos, $deat9min, $deat9max;
      printf REPORT " DPAHK9   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp9maxtime u s u d`, $deatemp9maxpos;
}
if ( $deahk10viol == 1 ) {
      printf REPORT "DPAHK10 FEP 1 ACTEL Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat10intmptime u s u d`, $deat10intmppos, $deat10min, $deat10max;
      printf REPORT " DPAHK10   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp10maxtime u s u d`, $deatemp10maxpos;
}
if ( $deahk11viol == 1 ) {
      printf REPORT "DPAHK11 FEP 1 RAM Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat11intmptime u s u d`, $deat11intmppos, $deat11min, $deat11max;
      printf REPORT " DPAHK11   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp11maxtime u s u d`, $deatemp11maxpos;
}
if ( $deahk12viol == 1 ) {
      printf REPORT "DPAHK12 FEP 1 Frame Buf. Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat12intmptime u s u d`, $deat12intmppos, $deat12min, $deat12max;
      printf REPORT " DPAHK12   Max/Min Violation at %19s Value: %7.2f deg C\n", `axTime3 $deatemp12maxtime u s u d`, $deatemp12maxpos;
}

close REPORT;

# *******************************************************************
#  E-mail violations, if any
# *******************************************************************
if ( -s "testfile.out" ) {
  open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
  print MAIL "config_mon_2.5 \n\n"; # current version
  if ( -s $dumpname ) {
    open DNAME, "<$dumpname";
    while (<DNAME>) {
      print MAIL $_;
    }
  }
  print MAIL "\n";
  open REPORT, "< testfile.out";
  
  while (<REPORT>) {
    print MAIL $_;
  }
  print MAIL "This message sent to brad swolk\n";
  close MAIL;
}

#  E-mail violations, if any
my $lockfile = "./.dumps_mon_lock";
my $safefile = "/home/mta/Snap/.scs107alert";  # lock created by snapshot
if ( -s $outfile ) {
  if ( -s $lockfile || -s $safefile ) {  # already sent, don't send again
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$outfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad swolk\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    ###test 12/06/11open MAIL, "|mailx -s config_mon sot_lead\@head.cfa.harvard.edu brad\@head.cfa.harvard.edu jnichols\@head.cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon sot_yellow_alert\@head.cfa.harvard.edu";
    #open MAIL, "|mail brad\@head.cfa.harvard.edu swolk\@head.cfa.harvard.edu";
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$outfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    print MAIL "This message sent to sot_lead brad jnichols\n";
    #print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to brad swolk1\n";
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
}
unlink $outfile;

# *******************************************************************
#  E-mail aca violations, if any
# *******************************************************************
#  E-mail violations, if any
$lockfile = "./.dumps_mon_aca_lock";
if ( -s $acafile ) {
  if ( -s $lockfile ) {  # already sent, don't send again
    #open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu acisdude\@head.cfa.harvard.edu";
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$acafile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    #open MAIL, "|mail brad\@head.cfa.harvard.edu swolk\@head.cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5\n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$acafile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
}
unlink $acafile;
# *******************************************************************
#  E-mail acis violations, if any
# *******************************************************************
#  E-mail violations, if any
$lockfile = "./.dumps_mon_acis_lock";
if ( -s $aoutfile ) {
  if ( -s $lockfile ) {  # already sent, don't send again
    #open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu plucinsk\@head.cfa.harvard.edu";
    open MAIL, "|mailx -s config_mon_2.5c swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$aoutfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad swolk acisdude\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    #open MAIL, "|mailx -s config_mon sot_yellow_alert\@head.cfa.harvard.edu";
    open MAIL, "|mailx -s config_mon_2.5a swolk acisdude brad\@head.cfa.harvard.edu";
    #open MAIL, "|mail brad\@head.cfa.harvard.edu swolk\@head.cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5\n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$aoutfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    #print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to brad swolk1\n";
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
}
unlink $aoutfile;

# *******************************************************************
#  E-mail extra acis violations, if any
# *******************************************************************
#  E-mail violations, if any
$lockfile = "./.dumps_mon_acis_temp_lock";
if ( -s $atoutfile ) {
  if ( -s $lockfile ) {  # already sent, don't send again
    #open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu plucinsk\@head.cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu 6172573986\@mobile.mycingular.com 6177216763\@vtext.com";
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$atoutfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad swolk acisdude\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    #open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu 6172573986\@mobile.mycingular.com 6177216763\@vtext.com";
    open MAIL, "|mailx -s config_mon_2.5b swolk acisdude brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5\n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$atoutfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    #print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to brad swolk1\n";
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
}
unlink $atoutfile;

# *******************************************************************
#  E-mail acis dea hk temp violations, if any
# *******************************************************************
#  E-mail violations, if any
$lockfile = "./.dumps_mon_deatemp_lock";
if ( -s $doutfile ) {
  if ( -s $lockfile ) {  # already sent, don't send again
    #open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu plucinsk\@head.cfa.harvard.edu";
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$doutfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad swolk\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    #open MAIL, "|mailx -s config_mon sot_yellow_alert\@head.cfa.harvard.edu";
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|mail brad\@head.cfa.harvard.edu swolk\@head.cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5\n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$doutfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    #print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to brad swolk1\n";
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
}
unlink $doutfile;

# *******************************************************************
#  E-mail iru violations, if any
# *******************************************************************
$lockfile = "./.dumps_mon_iru_lock";
if ( -s $ioutfile ) {
  if ( -s $lockfile ) {  # already sent, don't send again
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$ioutfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad swolk brad1\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon sot_red_alert\@head.cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon sot_yellow_alert\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5\n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$ioutfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    #print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    #print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to sot_red_alert\n";
    print MAIL "This message sent to brad swolk brad1\n";
    #print MAIL "TEST_MODE TEST_MODE TEST_MODE\n";
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
}
unlink $ioutfile;
# *******************************************************************
#  E-mail ephin violations, if any
# *******************************************************************
$lockfile = "./.dumps_mon_eph_lock";
if ( -s $eoutfile ) {
  if ( -s $lockfile ) {  # already sent, don't send again
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "xconfig_mon_2.5 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$eoutfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad swolk\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    #open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon sot_red_alert\@head.cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon sot_yellow_alert\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5\n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$eoutfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    #print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    #print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to sot_red_alert\n";
    #print MAIL "This message sent to brad swolk\n";  #turnbackon
    #print MAIL "This message sent to sot_lead\n";
    #print MAIL "TEST_MODE TEST_MODE TEST_MODE\n";  #turnbackon
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
  unlink "./.dumps_mon_eph102_lock";
}
unlink $eoutfile;
$lockfile = "./.dumps_mon_ephv_lock";
if ( -s $evoutfile ) {
  if ( -s $lockfile ) {  # already sent, don't send again
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$evoutfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad swolk\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    #open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu swolk\@head.cfa.harvard.edu";
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon sot_yellow_alert\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5\n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$evoutfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    #print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    #print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to brad swolk\n";
    #print MAIL "This message sent to brad swolk1\n";
    #print MAIL "This message sent to sot_lead fot emartin\n";
    #print MAIL "TEST_MODE TEST_MODE TEST_MODE\n";
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
}
unlink $evoutfile;

# *******************************************************************
#  E-mail pline violations, if any
# *******************************************************************
$lockfile = "./.dumps_mon_mups_lock";
if ( -s $poutfile ) {
  if ( -s $lockfile ) {  # already sent, don't send again
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    print MAIL "xconfig_mon_2.5 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$poutfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad swolk\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    open MAIL, "|mailx -s config_mon_test swolk brad\@head.cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon sot_yellow_alert\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.5\n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$poutfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    #print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    #print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to sot_red_alert\n";
    #print MAIL "This message sent to brad swolk\n";  #turnbackon
    print MAIL "This message sent to sot_lead\n";
    #print MAIL "TEST_MODE TEST_MODE TEST_MODE\n";  #turnbackon
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
}
unlink $poutfile;
# end **************************************************************

sub parse_args {
    my $cinfile_found = 0;
    my $pinfile_found = 0;
    my $ainfile_found = 0;
    my $ginfile_found = 0;
    my $dinfile_found = 0;
    my $minfile_found = 0;
    
    for ($ii = 0; $ii <= $#ARGV; $ii++) {
	if (!($ARGV[$ii] =~ /^-/)) {
	    next;
	}

	# -c <infile>
	if ($ARGV[$ii] =~ /^-c/) {
	    $cinfile_found = 1;
	    if ($ARGV[$ii] =~ /^-c$/) {
		$ii++;
		$cinfile = $ARGV[$ii];	    
	    }
	    else {
		$cinfile = substr($ARGV[$ii], 2);
	    }	    
	} # if ($ARGV[$ii] =~ /^-c/)

	# -p <infile>
	if ($ARGV[$ii] =~ /^-p/) {
	    $pinfile_found = 1;
	    if ($ARGV[$ii] =~ /^-p$/) {
		$ii++;
		$pinfile = $ARGV[$ii];	    
	    }
	    else {
		$pinfile = substr($ARGV[$ii], 2);
	    }
	} # if ($ARGV[$ii] =~ /^-p/)

	# -a <infile>
	if ($ARGV[$ii] =~ /^-a/) {
	    $ainfile_found = 1;
	    if ($ARGV[$ii] =~ /^-a$/) {
		$ii++;
		$ainfile = $ARGV[$ii];	    
	    }
	    else {
		$ainfile = substr($ARGV[$ii], 2);
	    }
	} # if ($ARGV[$ii] =~ /^-a/)

	# -g <infile>
	if ($ARGV[$ii] =~ /^-g/) {
	    $ginfile_found = 1;
	    if ($ARGV[$ii] =~ /^-g$/) {
		$ii++;
		$ginfile = $ARGV[$ii];	    
	    }
	    else {
		$ginfile = substr($ARGV[$ii], 2);
	    }
	} # if ($ARGV[$ii] =~ /^-g/)

	# -d <infile>
	if ($ARGV[$ii] =~ /^-d/) {
	    $dinfile_found = 1;
	    if ($ARGV[$ii] =~ /^-d$/) {
		$ii++;
		$dtinfile = $ARGV[$ii];	    
	    }
	    else {
		$dtinfile = substr($ARGV[$ii], 2);
	    }
	} # if ($ARGV[$ii] =~ /^-d/)

	# -m <infile>
	if ($ARGV[$ii] =~ /^-m/) {
	    $minfile_found = 1;
	    if ($ARGV[$ii] =~ /^-m$/) {
		$ii++;
		$mupsfile = $ARGV[$ii];	    
	    }
	    else {
		$mupsfile = substr($ARGV[$ii], 2);
	    }
	} # if ($ARGV[$ii] =~ /^-d/)

        # -v<verbose>
        if ($ARGV[$ii] =~ /^-v/) {
            #$verbose_found = 1;
            if ($ARGV[$ii] =~ /^-v$/) {
                $ii++;
                $verbose = $ARGV[$ii];
            }
            else {
                $verbose = substr($ARGV[$ii], 2);
            }

        } # if ($ARGV[$ii] =~ /^-v/)
        # -h
        if ($ARGV[$ii] =~ /^-h/) {
            goto USAGE;
        } # if ($ARGV[$ii] =~ /^-h/)
    } #  for ($ii = 0; $ii <= $#ARGV; $ii++)

    if (!$cinfile_found || !$pinfile_found) {
	goto USAGE;
    }

    return;

  USAGE:
    print "Usage:\n\t$0 -c<ccdm infile> -p<pcad infile> [-v<verbose>]\n";
    exit (0);
}

#sub abs {
  #if ( $_ >= 0 ) {
    #return $_;
  #}
  #else {
    #return ($_ * -1);
  #}
#}
    
sub quat_to_euler {
    use Math::Trig;
    my @quat = @_;
    $RAD_PER_DEGREE = pi / 180.0;
    
    my $q1 = $quat[0];
    my $q2 = $quat[1];
    my $q3 = $quat[2];
    my $q4 = $quat[3];
    
    my $q12 = 2.0 * $q1 * $q1;
    my $q22 = 2.0 * $q2 * $q2;
    my $q32 = 2.0 * $q3 * $q3;
    
    my @T = (
	     [ 1.0 - $q22 - $q32, 2.0 * ($q1 * $q2 + $q3 * $q4), 2.0 * ($q3 * $q1 - $q2 * $q4) ],
	     [ 2.0 * ($q1 * $q2 - $q3 * $q4), 1.0 - $q32 - $q12,  2 * ($q2 * $q3 + $q4 * $q1) ],
	     [ 2.0 * ($q3 * $q1 + $q2 * $q4), 2.0 * ($q2 * $q3 - $q1 * $q4), 1.0 - $q12 - $q22 ]
	     );


    my %eci;

    $eci{ra}   = atan2($T[0][1], $T[0][0]);
    $eci{dec}  = atan2($T[0][2], sqrt($T[0][0] * $T[0][0] + $T[0][1] * $T[0][1]));
    $eci{roll} = atan2($T[2][0] * sin($eci{ra}) - $T[2][1] * cos($eci{ra}), -$T[1][0] * sin($eci{ra}) + $T[1][1] * cos($eci{ra}));
    

    $eci{ra}   /= $RAD_PER_DEGREE;
    $eci{dec}  /= $RAD_PER_DEGREE;
    $eci{roll} /= $RAD_PER_DEGREE;

    if ($eci{ra}   < 0.0)  {
	$eci{ra} += 360.0;
    }
    if ($eci{roll} < -1e-13) {
	$eci{roll} += 360.0;
    }
    if ($eci{dec}  < -90.0 || $eci{dec} > 90.0) {
	print "Ugh dec $eci{dec}\n";
    }

    return (%eci);
}

sub convert_time {
    my @yrday = split(':', $_[0]);
    my $year = $yrday[0];
    my $day  = $yrday[1];
    my $hour = $yrday[2];
    my $min  = $yrday[3];
    my $sec  = $yrday[4];
    
    #my @hrminsec = split(':', ($yrday[2] . $yrday[3]));
    #my $hour = $hrminsec[0];
    #my $min  = $hrminsec[1];
    #my $sec  = $hrminsec[2];

    my $totsecs = 0;
    $totsecs = $sec;
    $totsecs += $min  * 60;
    $totsecs += $hour * 3600;

    my $totdays = $day;

    if ($year >= 98 && $year < 1900) {
	$year = 1998 + ($year - 98);
    }
    elsif ($year < 98) {
	$year = 2000 + $year;
    }

    # add days for past leap years
    if ($year > 2000)
    {
        # add one for y2k
	$totdays++;
        # Number of years since 2000. -1 for already counted current leap
	$years = $year - 2000 - 1;
	$leaps = int ($years / 4);
	$totdays += $leaps;
    }
    
    $totdays += ($year - 1998) * 365;


    $totsecs += $totdays * 86400;

    return $totsecs;
}

sub index_match {
# chex can return more than one expected state due to
#uncertainty in timing of spacecraft event
#This function returns which expectation most closely matches actual.
  my($val, $lim, @pred) = @_;
  my $i = 0;
  my $diff = $val - $pred[$i];
  while (abs($diff) > $lim && $i <= $#pred) {
    ++$i;
    $diff = $val - $pred[$i];
  }
  return $i;
}
