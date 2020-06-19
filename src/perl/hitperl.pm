## hitperl package
########################################################################################################

### >>>
package hitperl;

### core system includes
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use File::stat;
use Time::localtime;
use Digest::MD5;
use Digest::MD5 qw(md5_base64);
use Term::ANSIColor;
use Exporter;

### Do not use strict here otherwise it will not work
@ISA = ('Exporter');
@EXPORT = ( 'ssystem', 'getDirent', 'getDateString', 'getTimeString', 'createProjectLogFile', 'getARGVOptionString',
  'createOutputPath', 'getXMLValue', 'getXMLValues', 'cleanString', 'getProgramOptions', 'getScriptOptions', 'getNamedOption',
  'getNewestFileTimeFromFileList', 'getStructureIdentFromFileName', 'getStatusIdentFromFileName', 'replaceLastSuffix',
  'removeDoubleEntriesFromArray', 'removeFromArray', 'cleanStructureName', 'isInArray', 'getProgramLogOptionsString',
  'fileIsNewer', 'baseFileIsNewer', 'getMatchFileName', 'rsystem', 'getFileList', 'checkIfFileExist', 'getMD5FileCheckSum',
  'printMessage', 'printDebug', 'printWarning', 'printHash', 'printTimeLog', 'replaceSuffix', 'getTimeStamp', 'saveDataArrayAs',
  'getFiles', 'isInRange', 'getSideString', 'clip', 'wchomp', 'printHashArray', 'isLeftSideFile', 'getIntegerFromString',
  'whomp', 'getBooleanString', 'checkFileExists', 'scopy', 'cleanDirectory', 'createProgramLog', 'getMatchElementFromArray',
  'printProgramLog', 'getLastProgramLogMessage', 'getOrientationString', 'ssysteml', 'getFileTime', 'getFileSuffix',
  'createProgramLogOptions', 'getPathForTempFiles', 'getCleanStructureList', 'getScriptVersion', 'getHashString', 'checkExecutables',
  'redoProgramLogCall', 'getNewFileName', 'onTerminalCommand', 'runR', 'getSectionIdent', 'areInArray', 'removeElementFromArray',
  'printfatalerror', 'printerror', 'printdebug', 'printwarning', 'printinfo' );
$VERSION = 0.9;

### >>>
sub printerror {
 my $text = shift;
 chomp($text);
 print color('red');
 print $text."\n";
 print color('reset');
}
sub printfatalerror {
 my $text = shift;
 printerror($text);
 exit(0);
}
sub printdebug {
 my $text = shift;
 print "DEBUG: ".$text."\n";
}
sub printwarning {
 my $text = shift;
 chomp($text);
 print color('yellow');
 print $text."\n";
 print color('reset');
}
sub printinfo {
 my $text = shift;
 print color('blue');
 print $text."\n";
 print color('reset');
}

### >>>
sub getARGVOptionString {
 my ($options_ptr,$debuglevel) = @_;
 my @options = @{$options_ptr};
 my $optstring = "";
 if ( @options>1 ) {
  foreach my $argnum (1..$#options) {
   $optstring .= $options[$argnum]." ";
  }
 }
 chop($optstring);
 return $optstring;
}

### >>>
sub saveDataArrayAs {
 my ($datas_ptr,$filename,$comment,$verbose,$debug) = @_;
 my @datas = @{$datas_ptr};
 open(FPout,">$filename") || die "FATAL ERROR: Cannot write data array as '".$filename."'. $!";
  print FPout "# ".$comment."\n";
  print FPout scalar(@datas)."\n";
  foreach $data (@datas) {
   print FPout $data."\n";
  }
 close(FPout);
 return 1;
}

### >>>
sub getMD5FileCheckSum {
 my $filename = shift;
 my $md5 = Digest::MD5->new;
 open(CHECK,$filename) or die "FATAL ERROR: Cannot open file '".$filename."': $!";
  binmode(CHECK);
  $md5->addfile(*CHECK);
 close(CHECK);
 return $md5->hexdigest;
}

### >>>
sub onTerminalCommand {
 my ($com,$debug) = @_;
 my $result = `$com`;
 chomp($result);
 return $result;
}
sub runR {
 my ($com,$debug) = @_;
 print "DEBUG: ".$com."\n" if ( defined($debug) && $debug>=1 );
 my @elements = split(/\ /,onTerminalCommand($com),2);
 chomp($elements[1]);
 return($elements[1]);
}

### >>>
sub getScriptVersion {
 my $scriptfilename = shift;
 my $filepath = dirname($scriptfilename);
 my $versionfile = dirname($scriptfilename)."/data/version.txt";
 if ( -e $versionfile ) {
  open(FPin,"<$versionfile");
   my $version = <FPin>;
  close(FPin);
  chomp($version);
  return $version;
 }
 return "unknown";
}

### >>>
sub getPathForTempFiles {
 my $tmppath = $ENV{TMPDIR};
 if ( defined($tmppath) ) {
  chop($tmppath) if ( $tmppath =~ m/\/$/ );
  return $tmppath;
 }
 return "/tmp";
}

### >>>
sub getScriptOptions {
 my ($ARGV_ptr,$masterscript) = @_;
 my @ARGV = @{$ARGV_ptr};
 if ( @ARGV>1 ) {
  my $options = "";
  foreach my $argnum (1..$#ARGV) {
   $options .= $ARGV[$argnum]." ";
  }
  chop($options);
  return $options;
 }
 ssystem("perl ".$masterscript,0);
 exit(1);
}
sub getProgramOptions {
 my $options_ref_ptr = shift;
 my %options = %{$options_ref_ptr};
 my $optionstring = "";
 while ( my ($key,$value) = each(%options) ) {
  if ( $key =~ m/\:f$/ ) {
   $optionstring .= "--".substr($key,0,-2)." " if ( $value==1 );
  } else {
   $optionstring .= "--".$key." ".$value." " if ( defined($value) );
  }
 }
 chop($optionstring);
 return $optionstring;
}
sub getNamedOption {
 my ($options_ref_ptr,$optionname) = @_;
 my %options = %{$options_ref_ptr};
 while ( my ($key,$value) = each(%options) ) {
  if ( $key =~ m/\:f$/ ) {
   my $option = substr($key,0,-2);
   if ( $option =~ m/^$optionname$/i ) {
    if ( $value==1 ) {
     return "--".substr($key,0,-2)." ";
    }
   }
  } else {
   if ( $key eq $optionname && defined($value) ) {
    return "--".$key." ".$value." ";
   }
  }
 }
 return "";
}

### program log functions
# get log file path:
#  + if logfilepath is defined (for global log file storage set $logfilepath=$HOME):
#     1st preference: '$logfilepath/.log/scripts/<progrname>.log'
#     2nd preference: '$logfilepath/<progname>.log'
#   otherwise:
#    '<progpath>/.log/scripts/<progname>.log'
sub getProgramLogFileName {
 my ($progname,$logfilepath) = @_;
 my ($filename,$directory,$suffix) = fileparse($progname,qr/\.[^.]*/);
 ## print "progname=".$progname.", logfilepath='".$logfilepath."', directory='".$directory."'\n";
 if ( defined($logfilepath) ) {
  my $logfilepath2 = $logfilepath."/.log/scripts";
  return $logfilepath2."/".$filename.".log" if ( -d $logfilepath2 );
  return $logfilepath."/".$filename.".log";
 }
 my $outdir = $directory."log";
 $outdir = $directory.".log" unless ( -d $outdir );
 $outdir .= "/scripts/".$filename.".log";
 return $outdir
}
# at the moment there is no check whether the script has changed after the last checkout!!!
sub getProgramRevision {
 my ($progname,$debug) = @_;
 my $resultstring = `svn info $progname`;
 my @datalines = split(/\n/,$resultstring);
 print "DEBUG: progname='".$progname."', svn-datalines: @datalines\n" if ( $debug );
 my $revnumber = "-1";
 print "DEBUG: mtime=".stat($progname)->mtime.", epochtime=(".scalar(gmtime(0)).")\n" if ( $debug );
 foreach my $dataline (@datalines) {
  if ( $dataline =~ m/^Revision:/i ) {
   my @elements = split(/ /,$dataline);
   $revnumber = $elements[1];
  } elsif ( $dataline =~ m/^Last Changed Date:/ ) {
   print "DEBUG: dataline=$dataline\n" if ( $debug );
   ## $lastcdate = substr($dataline,19);
  }
 }
 return $revnumber;
}
# program log functions (abs_path to follow symlinks, e.g. for perl executables in the $HITOOLS/progs/perl folder)
use Cwd 'abs_path';
sub createProgramLog {
 my ($progname,$argv_ref,$debug,$logfilepath) = @_;
 my @argvv = @{$argv_ref};
 my $logfile = getProgramLogFileName($progname,$logfilepath);
 my $revision = getProgramRevision(abs_path($progname),$debug);
 print "DEBUG: progname=$progname, logfile='".$logfile."', revision='$revision'.\n" if ( $debug );
 open(FPout,">>$logfile") || die "FATAL ERROR: Cannot create program log file entry '".$logfile."': $!";
  print FPout "[".getTimeString(1)." - version=\"".$revision."\"] ".$progname." @argvv\n";
 close(FPout);
 return $logfile;
}
sub getProgramLogOptionsString {
 my ($argv_ref,$debug) = @_;
 my %options = %{$argv_ref};
 my $optionstring = "";
 while ( my($name,$option) = each(%options) ) {
  print "DEBUG: name=$name, option=$option\n" if ( $debug );
  if ( $name =~ m/\:f/ ) {
   $optionstring .= " --".substr($name,0,length($name)-2) if ( $option==1 );
  } else {
   $optionstring .= " --".$name." \"".$option."\"" if ( defined($option) );
  }
 }
 return $optionstring;
}
sub createProgramLogOptions {
 my ($progname,$argv_ref,$debug) = @_;
 my $optionstring = getProgramLogOptionsString($argv_ref,$debug);
 my $revision = getProgramRevision($progname,$debug);
 my $logfile = getProgramLogFileName($progname);
 open(FPout,">>$logfile") || die "FATAL ERROR: Cannot create program log file entry '".$logfile."': $!";
  print FPout "[".getTimeString(1)." - version=\"".$revision."\"] ".$progname.$optionstring."\n";
 close(FPout);
 return $logfile;
}
sub getLastProgramLogMessage {
 my ($progname,$logfilepath) = @_;
 my $logfile = getProgramLogFileName($progname,$logfilepath);
 return "not available" unless ( -e $logfile );
 open(FPin,"<$logfile") || die "FATAL ERROR: Cannot open '".$logfile."' for reading: $!";
  while ( <FPin> ) {
   $lastline = $_;
  }
 close(FPin);
 chomp($lastline);
 return $lastline;
}
sub printProgramLog {
 my ($progname,$doExit,$logfilepath) = @_;
 my $logFileName = getProgramLogFileName($progname,$logfilepath);
 if ( ! -e $logFileName ) {
  warn "Fatal Error: Cannot find program log file '".$logFileName."'.\n";
 } else {
  open(FPin,"<$logFileName") || die "Error: Cannot open program log file '".$logFileName."': $!";
   while ( <FPin> ) {
    print $_;
   }
  close(FPin);
 }
 exit(1) if ( defined($doExit) && $doExit==1 );
}
sub redoProgramLogCall {
 my ($progname,$ident,$debug) = @_;
 my $logFileName = getProgramLogFileName($progname);
 my @programcalls = ();
 open(FPin,"<$logFileName") || die "Error: Cannot open program log file '".$logFileName."': $!";
  while ( <FPin> ) {
   chomp($_);
   push(@programcalls,$_);
  }
 close(FPin);
 die "FATAL ERROR: Invalid call number $ident." if ( scalar(@programcalls)<abs($ident) );
 my @thecalls = split(/\] /,$programcalls[$ident],2);
 print "DEBUG: programcall: '$thecalls[1]'\n" if ( $debug );
 ssystem("perl $thecalls[1]",$debug);
 exit(1);
}

### printout subs
sub printMessage {
 my ($text,$verbose,$FPlogout) = @_;
 print $text if ( $verbose );
 print $FPlogout " > $text" if ( defined($FPlogout) );
}

sub printDebug {
 my ($text,$debug,$FPlogout) = @_;
 print "DEBUG: $text\n" if ( $debug );
 print $FPlogout " [DEBUG] $text\n" if ( defined($FPlogout) );
}

sub printWarning {
 my ($text,$silent,$FPlogout) = @_;
 warn "WARNING: $text\n" unless ( $silent );
 print $FPlogout " ! WARNING: $text !\n" if ( defined($FPlogout) );
}

sub printTimeLog {
 my ($text,$FPlogout) = @_;
 my ($sec,$min,$hour,$mday,$mon,$year) = CORE::localtime();
 print "[$hour:$min.$sec] $text";
}

### >>>
sub printHash {
 my $ref_to_hash = shift;
 my %hash = %{$ref_to_hash};
 if ( scalar(keys(%hash))==0 ) {
  print "printHash(): Hash is empty.\n";
 } else {
  while ( my ($key,$value) = each(%hash) ) {
   print "value[$key]: '$value'\n";
  }
 }
}

sub printHashArray {
 my ($ref_to_hash,$FP,$comment) = @_;
 my %hash = %{$ref_to_hash};
 while ( my ($key,$array_ptr) = each(%hash) ) {
  @array = @{$array_ptr};
  print $FP $comment." value[$key]: (@array)\n";
 }
}

sub getHashString {
 my $ref_to_hash = shift;
 my %hash = %{$ref_to_hash};
 my $hashstring = "";
 while ( my ($key,$value) = each(%hash) ) {
  $hashstring .= $key.":".$value.",";
 }
 chop($hashstring);
 return $hashstring;
}

### more system supporting subs
sub scopy {
 my ($src,$dst,$debug) = @_;
 if ( $debug ) {
  print " DEBUG: 'copy '$src' to '$dst'.\n";
  return unless ( $debug==2 );
 }
 copy($src,$dst) || die "FATAL ERROR: Could not copy '".$src."': $!";
}

sub ssystem {
 my ($call,$debuglevel,$FPlogout) = @_;
 if ( $debuglevel ) {
  print " DEBUG.ssystem(): '$call'.\n";
  return unless ( $debuglevel==2 );
 }
 if ( defined($FPlogout) ) {
  print $FPlogout " <SystemCall>\n";
  print $FPlogout "  <Command>\n";
  print $FPlogout "   <Call>".$call."</Call>\n";
  print $FPlogout "   <StartAt>".getTimeString(1)."</StartAt>\n";
 }
 my $rValue = system($call);
 if ( defined($FPlogout) ) {
  print $FPlogout "   <EndAt>".getTimeString(1)."</EndAt>\n";
  print $FPlogout "   <RValue>".$rValue."</RValue>\n";
  print $FPlogout "  </Command>\n";
  print $FPlogout " </SystemCall>\n";
 }
 return $rValue;
}

sub rsystem {
 my ($call,$debuglevel,$FPlogout) = @_;
 if ( $debug ) {
  print " DEBUG.rsystem(): '$call'.\n";
  return if ( $debuglevel==1 );
 }
 if ( defined($FPlogout) ) {
  print $FPlogout " <SystemCall>\n";
  print $FPlogout "  <Command>\n";
  print $FPlogout "   <Call>".$call."</Call>\n";
  print $FPlogout "   <StartAt>".getTimeString(1)."</StartAt>\n";
 }
 my $rValue = system($call);
 if ( $rValue!=0 ) {
  if ( $? == -1 ) {
   print "FATAL ERROR: Failed to execute: $!\n";
  } elsif ( $? & 127 ) {
   printf "FATAL ERROR: Child died with signal %d, %s coredump.\n",($? & 127),  ($? & 128) ? 'with' : 'without';
  } else {
   printf "FATAL ERROR: Child exited with value %d.\n", $? >> 8;
  }
 }
 if ( defined($FPlogout) ) {
  print $FPlogout "   <EndAt>".getTimeString(1)."</EndAt>\n";
  print $FPlogout "   <RValue>".$rValue."</RValue>\n";
  print $FPlogout "  </Command>\n";
  print $FPlogout  " </SystemCall>\n";
 }
 return $rValue;
}

### system call with automatic log file creation
sub ssysteml {
 my ($call,$debug) = @_;
 unless ( $debug==1 ) {
  my @elements = split(/\ /,$call);
  for ( my $n=0 ; $n<scalar(@elements) ; $n++ ) {
   if ( $elements[$n] eq "-out" || $elements[$n] eq "-o" ) {
    my $outfile = $elements[$n+1];
    my $outfilename = basename($outfile);
    my @parts = split(/\./,$outfilename);
    $outfilename = basename($elements[0])."__".$parts[0]."__".$parts[1].".xml";
    my $outfilepath = dirname($outfile);
    $outfilepath .= "/.log";
    $outfilename = createOutputPath($outfilepath)."/".$outfilename;
    open(FPlogout,">$outfilename") || die "FATAL ERROR: Cannot create log file '".$outfilename."': $!";
     ssystem($call,$debug,FPlogout);
    close(FPlogout);
    return;
   }
  }
 }
 ssystem($call,$debug);
}

### folder entries starting with a point will be ignorred
sub getDirent {
 my ($lPath,$suffix,$fullpath) = @_;
 opendir(DIR,"${lPath}/.") || die "FATAL ERROR: Cannot open directory '".$lPath."/.': $!";
  my @a = readdir(DIR);
 closedir(DIR);
 my @filelist = ();
 if ( defined($suffix) && defined($fullpath) && $fullpath==1 ) {
  foreach my $file (@a) {
   next unless ( $file =~ m/${suffix}$/i );
   next if ( $file =~ m/^\_/ );
   push(@filelist,$lPath."/".$file);
  }
 } elsif ( defined($suffix) ) {
  foreach my $file (@a) {
   next unless ( $file =~ m/${suffix}$/i );
   next if ( $file =~ m/^\_/ );
   push(@filelist,$file);
  }
 } elsif ( defined($fullpath) && $fullpath==1 ) {
  foreach my $file (@a) {
   next if ( $file =~ m/^\./ || $file =~ m/^\_/ );
   push(@filelist,$lPath."/".$file);
  }
 } else {
  foreach my $file (@a) {
   next if ( $file =~ m/^\./ || $file =~ m/^\_/ );
   push(@filelist,$file);
  }
 }
 return sort(@filelist);
}

### only tmp directories can be deleted (be very restrictive because this call is very dangerous!!!)
### directory must start or end with 'tmp' or '.tmp'
sub cleanDirectory {
 my ($path,$debug) = @_;
 if ( -d $path ) {
  if ( $debug ) {
   print " DEBUG: rmtree(".$path.").\n";
   return unless ( $debug==2 );
  }
  if ( $path =~ m/^tmp/ || $path =~ m/^\.\/tmp/ ) {
   rmtree($path) || die "FATAL ERROR: Cannot remove directory '".$path."': $!";
  } else {
   my $subpathtoclean = $path;
   my @subpaths = split(/\//,$path);
   if ( scalar(@subpaths)>1 ) {
    $subpathtoclean = $subpaths[-1];
   }
   if ( $subpathtoclean =~ m/^tmp/ ) {
    rmtree($path) || die "FATAL ERROR: Cannot remove directory '".$path."': $!";
   } else {
    warn "WARNING: Cannot delete directory '".$path."'. Only tmp directories can be deleted!\n";
   }
  }
 } else {
  warn "WARNING: Input path '".$path."' is not a valid path.\n";
 }
}

### get time informations
# Time::localtime overwrites the localtime() function
# therefore we use CORE:: to get access to the original version
sub getDateString {
 my $formated = shift;
 my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = CORE::localtime(time);
 $mday = sprintf("%02d",$mday);
 $mon = sprintf("%02d",$mon+1);
 $year += 1900;
 return "${mday}.${mon}.${year}" if ( defined($formated) );
 return "$mday$mon$year";
}
sub getTimeString {
 my $formated = shift;
 my ($sec,$min,$hour,$mday,$mon,$year) = CORE::localtime();
 $year += 1900;
 $mon += 1;
 $hour = "0$hour" if ( length($hour)==1 );
 $min  = "0$min" if ( length($min)==1 );
 $sec  = "0$sec" if ( length($sec)==1 );
 $mday = "0$mday" if ( length($mday)==1 );
 $mon  = "0$mon" if ( length($mon)==1 );
 return "${mday}.${mon}.${year} - ${hour}:${min}:${sec}" if ( defined($formated) );
 return "${hour}${min}${mday}${mon}${year}"
}
sub getTimeStamp {
 my $filename = shift;
 my $mtime = stat($filename)->mtime;
 my ($sec,$min,$hour,$day,$month,$year) = CORE::localtime($mtime);
 $day = "0$day" if ( $day<10 );
 $month += 1;
 $month = "0$month" if ( $month<10 );
 $year = 1900+$year;
 $sec = "0$sec" if ( $sec<10 );
 $min = "0$min" if ( $min<10 );
 $hour = "0$hour" if ( $hour<10 );
 return "$hour$min$sec$day$month$year";
}

## remove spaces at the beginning and end of a string
sub cleanString {
 my $string = shift;
 $string =~ s/^\s+//g;
 $string =~ s/\s+$//g;
 return $string;
}
sub wchomp {
 my $string = shift;
 chomp($string);
 $string =~ s/\r//g;
 return $string;
}
sub whomp {
 my $string = shift;
 $string =~ s/\r//g;
 return $string;
}

## creates a directory
sub createOutputPath {
 my ($path,$debug) = @_;
 if ( defined($debug) ) {
  if ( $debug ) {
   print " DEBUG: Creating directory '".$path."'.\n";
   return $path unless ( $debug==2 );
  }
 }
 unless ( -d $path ) {
  mkpath($path) || die "FATAL ERROR: Cannot create output path '".$path."': $!";
 }
 return $path;
}

# returns 1 if $infile is newer than $outfile
sub fileIsNewer {
 my ($infile,$outfile,$debug) = @_;
 return 0 if ( ! -e $infile || ! -e $outfile );
 print "DEBUG:fileIsNewer(): stat($infile)=".stat($infile)->mtime." > stat($outfile)=".stat($outfile)->mtime."\n" if ( $debug );
 return 1 if ( stat($infile)->mtime>stat($outfile)->mtime );
 return 0;
}

sub baseFileIsNewer {
 my ($infile,$outfile) = @_;
 return 0 unless ( -e $infile );
 my $basename = basename($outfile);
 $basename =~ s/\.png$//i;
 my $path = dirname($outfile);
 my @files = getDirent($path);
 foreach my $file (@files) {
  next unless ( $file =~ m/\.png$/i );
  if ( $file=~ m/^$basename/ ) {
   my $pathfile = $path."/".$file;
   if ( stat($infile)->mtime>stat($pathfile)->mtime ) {
    return 1;
   } else {
    return 0;
   }
  }
 }
 return 0;
}

# find recursively all files (maximal number of recursions limited?)
# + ignoring everything which starts with a dot
sub getFiles {
 my ($pathname,$suffix) = @_;
 opendir(DIR,$pathname) || die "FATAL ERROR: Cannot open directory '".$pathname."': $!";
  my @files = grep { !/^\.{1,2}/ } readdir(DIR);
 closedir(DIR);
 my @filelist = ();
 foreach my $file (@files) {
  my $filename = $pathname."/".$file;
  push(@filelist,$filename) if ( -e $filename && $file =~ m/${suffix}$/ );
  push(@filelist,getFiles($filename,$suffix)) if ( -d $filename );
 }
 return @filelist;
}

# return a <ident>-<filename> list
# 16.05.2013:
#  added maxlength parameter to get a correct ident number even if more digits appears AFTER
#  the ident number
sub getFileList {
 my ($pathname,$suffix,$maxlength,$skipsuffix) = @_;
 my %filelist = ();
 return %fileslist unless ( -d $pathname );
 my @files = getDirent($pathname);
 if ( defined($skipsuffix) ) {
  foreach my $file (@files) {
   next if ( $file =~ m/${skipsuffix}$/ );
   next unless ( $file =~ m/${suffix}$/i );
   my $ident = getStructureIdentFromFileName($file);
   $ident = substr($ident,0,$maxlength) if ( defined($maxlength) );
   $filelist{$ident} = $pathname."/".$file;
  }
 } else {
  foreach my $file (@files) {
   next unless ( $file =~ m/${suffix}$/i );
   my $ident = getStructureIdentFromFileName($file);
   $ident = substr($ident,0,$maxlength) if ( defined($maxlength) );
   $filelist{$ident} = $pathname."/".$file;
  }
 }
 return %filelist;
}

sub getMatchFileName {
 my ($pathname,$basename) = @_;
 return "" unless ( -d $pathname );
 my @files = getDirent($pathname);
 foreach my $file (@files) {
  next unless ( $file =~ m/\.png$/i );
  return $pathname."/".$file if ( $file=~ m/^$basename/i )
 }
 return "";
}

sub checkExecutables {
 my ($verbose,@executables) = @_;
 my $nfails = 0;
 print "hitperl.checkExecutables(): Checking ".scalar(@executables)." executables...\n" if ( $verbose );
 foreach my $executable (@executables) {
  my $whichResult = `which $executable`;
  my $chkResult = ($whichResult =~ m/$executable/ )?"passed":"failed";
  $nfails += 1 if ( $chkResult =~ m/failed/ );
  print " + checking '".$executable."'... ".$chkResult."\n" if ( $verbose );
 }
 return $nfails;
}

sub checkIfFileExist {
 my ($filename,$pedantic,$silent,$FPlogout) = @_;
 return 1 if ( -e $filename );
 printWarning("File '".$filename."' does not exist.",$silent,$FPlogout);
 exit(1) if ( $pedantic );
 return 0;
}

sub getFileTime {
 my ($infile,$debug) = @_;
 return 0 unless ( -e $infile );
 return stat($infile)->mtime;
}

sub getFileSuffix {
 my ($filename,$debug) = @_;
 my @elements = split(/\./,$filename);
 return $elements[-1];
}

sub getNewestFileTimeFromFileList {
 my ($infilelist_ref,$debug) = @_;
 my @infiles = @{$infilelist_ref};
 my $newest_time = 0;
 foreach my $infile (@infiles) {
  die "hitperl::getNewestFileTimeFromFileList(): FATAL ERROR: Invalid file '".$infile."': $!" unless ( -e $infile );
  my $infile_time = stat($infile)->mtime;
  $newest_time = $infile_time if ( $infile_time>$newest_time );
  print "DEBUG: Time from '".$infile."': $infile_time\n" if ( $debug );
 }
 return $newest_time;
}

sub createProjectLogFile {
 my ($project,$progname,$arglist,$verbose) = @_;
 my $logfile = "./log";
 if ( ! -d $logfile ) {
  mkpath($logfile) || die "FATAL ERROR: Cannot create log file outpath '".$logfile."': $!";
 }
 if ( $project ) {
  $logfile .= "/${project}_".basename($progname);
 } else {
  $logfile .= "/".basename($progname);
 }
 my $datestring = getDateString();
 $logfile =~ s/.pl/_${datestring}.log/;
 local *FPlogout;
 open(FPlogout,">>$logfile") || die "FATAL ERROR: Cannot create log file '".$logfile."': $!";
 print FPlogout "[".CORE::localtime()."] call: '$progname$arglist'\n";
 print "creating log file '".$logfile."'...\n" if ( $verbose );
 return *FPlogout;
}

sub getContourProjectNeighbors {
 my $strucfile = shift;
 $strucfile .= "/structures.inc";
 my @neighbors = ();
 open(FPstrucin,"<$strucfile") || die "FATAL ERROR: Could not open structure file '".$strucfile."': $!";
  while ( <FPstrucin> ) {
   if ( $_ =~ m/neighbors/i ) {
    chomp($_);
    my @values = split(/\=/,$_);
    my $strucs = cleanString($values[1]);
    push(@neighbors,split(/\ /,$strucs));
   }
  }
 close(FPstrucin);
 return @neighbors;
}

### >>>
sub getIntegerFromString {
 my $value = shift;
 $value =~ tr/0-9//cd;
 return $value;
}

### returns structure ident number string WITH leading 0's (e.g. 0049)
sub getStructureIdentFromFileName {
 my ($filename,$position) = @_;
 my $ident = undef;
 if ( defined($position) ) {
  my @elements = split('\_',basename($filename));
  if ( $position<scalar(@elements) ) {
   $ident = $elements[$position];
  } else {
   $ident = $elements[0];
  }
  $ident = basename($filename) unless ( $ident =~ /\d/ );
 } else {
  $ident = basename($filename);
 }
 $ident =~ tr/0-9/./c;
 $ident =~ s/\.//g;
 return $ident;
}

sub getSectionIdent {
 my ($aString,$aPosition) = @_;
 return getStructureIdentFromFileName($aString,$aPosition);
}

sub getStatusIdentFromFileName {
 my $filename = shift;
 my $number = getStructureIdentFromFileName($filename);
 my @celements = split(/\./,$filename);
 my @elements = split(/\_/,$celements[0]);
 foreach my $element (@elements) {
  if ( $element =~ m/$number/ ) {
   return substr($element,length($element)-1,1);
  }
 }
 print "hitperl.getStatusIdentFromFileName(): FATAL ERROR: Cannot get status ident from file '".$filename."'.\n";
 exit(1);
 return "u";
}

sub cleanStructureName {
 my ($strucname,$level) = @_;
 my @elements = split(/\_/,$strucname);
 if ( defined($level) ) {
  ### onlyinner or onlyouter are removed
  if ( $strucname =~ m/\_onlyinner$/i || $strucname =~ m/\_onlyouter$/i ) {
   return $elements[-2] if ( $level==-1 );
   return $level==1?"$elements[-3]_$elements[-2]":$elements[-3];
  }
  return $elements[-1] if ( $level==-1 );
  return $level==1?"$elements[-2]_$elements[-1]":$elements[-2];
 }
 if ( $strucname =~ m/\_onlyinner$/i || $strucname =~ m/\_onlyouter$/i ) {
  return $elements[-3]."_".$elements[-2]."_".$elements[-1];
 }
 return $elements[-2]."_".$elements[-1];
}

## this removes any _l|_r side spec at the end and will return a unique list
# WARNING: liste muss als @liste und nicht als referenz übergeben werden
sub getCleanStructureList {
 my @list = @_;
 my @cleanlist = ();
 foreach my $element (@list) {
  $element =~ s/\_l$//i if ( $element =~ m/\_l$/i );
  $element =~ s/\_r$//i if ( $element =~ m/\_r$/i );
  push(@cleanlist,$element);
 }
 return removeDoubleEntriesFromArray(@cleanlist);
}

## xml stuff
# used in: xmlintersect, createcnt
sub getXMLValue {
 my $line = shift;
 my @values1 = split(/\>/,$line);
 my @values2 = split(/\</,$values1[1]);
 return $values2[0];
}

# used in: gettopology, createthickness, creatempm
sub getXMLValues {
 my $line = shift;
 my @values1 = split(/\>/,$line);
 my @values2 = split(/\</,$values1[1]);
 return split(/\ /,$values2[0]);
}

### >>>
sub getNewFileName {
 my ($filename,$oldsuffix,$newsuffix) = @_;
 die "FATAL ERROR: Cannot find suffix '".$oldsuffix."' in filename '".$filename."'." unless ( $filename =~ m/$oldsuffix$/ );
 my $newfilename = $filename;
 $newfilename =~ s/$oldsuffix$/$newsuffix/;
 return $newfilename;
}

### this will look for the first point
# changed 07.12.2012 + replaced substitute
sub replaceSuffix {
 my ($filename,$newsuffix) = @_;
 my ($base,$path,$oldsuffix) = fileparse($filename,'\..*');
 ## print "base=$base, path=$path, suffix=$oldsuffix\n";
 return $base.$newsuffix if ( $path =~ m/^\.\/$/ );
 return $path.$base.$newsuffix;
}
sub replaceLastSuffix {
 my ($filename,$newsuffix) = @_;
 my @elements = split(/\./,$filename);
 if ( scalar(@elements)>1 ) {
  my $newfilename = "";
  for ( my $n=0 ; $n<scalar(@elements)-1 ; $n++ ) {
   $newfilename .= $elements[$n].".";
  }
  chop($newfilename) if ( $newsuffix =~ m/$\./ );
  $newfilename .= $newsuffix;
  return $newfilename;
 }
 return replaceSuffix($filename,$newsuffix);
}

### check whether file exists
sub checkFileExists {
 my $filename = shift;
 die "FATAL ERROR: Cannot find file '".$filename."': $!" unless ( -e $filename );
 return $filename;
}

### check whether a value is within the data range
sub isInRange {
 my ($value,$ref_to_rangearray) = @_;
 my @ranges = @{$ref_to_rangearray};
 return 1 if ( $ranges[0] eq "min" && $ranges[1] eq "max" );
 return 1 if ( $ranges[0] eq "min" && $value<=$ranges[1] );
 return 1 if ( $value>=$ranges[0] && $ranges[1] eq "max" );
 return 1 if ( $value>=$ranges[0] && $value<=$ranges[1] );
 return 0;
}

### checks whether a substring _l_ exists in the filename. in this case it resturns true >>>
sub isLeftSideFile {
 my $filename = shift;
 return 1 if ( basename($filename) =~ m/\_l\_/i );
 return 0;
}

### >>>
sub getBooleanString {
 my $flag = shift;
 return "true" if ( $flag==1 );
 return "false";
}
sub getOrientationString {
 my $orientchar = shift;
 return "sagittal" if ( $orientchar eq "x" );
 return "horizontal" if ( $orientchar eq "z" );
 return "coronal" if ( $orientchar eq "y" );
 return "unknown";
}
sub getSideString {
 my $sidechar = shift;
 return "left" if ( $sidechar eq "l" );
 return "right" if ( $sidechar eq "r" );
 return "both" if ( $sidechar eq "b" );
 return "unknown";
}

### >>>
sub clip {
 my ($minvalue,$maxvalue,$value) = @_;
 return $minvalue if ( $value<=$minvalue );
 return $maxvalue if ( $value>=$maxvalue );
 return $value;
}

# remove double entries from an array
sub removeDoubleEntriesFromArray {
 my %array;
 grep { $array{$_}=0 } @_;
 return (keys %array);
}

sub removeElementFromArray {
 my ($ref_to_array,$element) = @_;
 my @arr = @{$ref_to_array};
 my $narr = scalar(@arr);
 my $index = 0;
 while ( $index<$narr && $arr[$index]!=$element ) {
  $index++;
 }
 splice(@arr,$index,1) if ( $index<$narr );
 return @arr;
}

sub removeFromArray {
 my ($ref_to_srcarray,$ref_to_subarray,$verbose,$debug) = @_;
 my @srcarray = @{$ref_to_srcarray};
 my @subarray = @{$ref_to_subarray};
 print "DEBUG: RemoveFromArray(): source array: (@srcarray), subarray=(@subarray)\n" if ( $debug );
 my %subhash = ();
 foreach my $subelement (@subarray) {
  $subhash{$subelement} = 1;
 }
 my @narray = ();
 foreach my $srcelement (@srcarray) {
  push(@narray,$srcelement) unless ( exists($subhash{$srcelement}) );
 }
 return @narray;
}

# check whether a element is in arrray
# update: returns 1 if the only element is ++ALL++
# problems with grep: not all strings are accepted (he does not like + for instance)
sub isInArray {
 my ($element,$ref_to_array) = @_;
 my @array = @{$ref_to_array};
 ### print "array=@array, element=$element\n";
 return 1 if ( @array==1 && $array[0] eq "++ALL++" );
 ### return 1 if grep(/\b$element\b/,@array);
 foreach my $a (@array) { return 1 if ( $a eq $element ); }
 return 0;
}

sub areInArray {
 my ($ref_to_elements,$ref_to_array) = @_;
 my @elements = @{$ref_to_elements};
 foreach my $element (@elements) {
  return 1 if ( isInArray($element,$ref_to_array) );
 }
 return 0;
}

sub getMatchElementFromArray {
 my ($element,$ref_to_array,$suffix) = @_;
 my @array = @{$ref_to_array};
 if ( defined($suffix) ) {
  foreach my $a (@array) { return $a if ( $a =~ m/^$element/ && $a =~ m/$suffix$/ ); }
 } else {
  foreach my $a (@array) { return $a if ( $a =~ m/^$element/ ); }
 }
 return None;
}

sub _debug { warn "@_\n" if $DEBUG; }

### return value
1;
