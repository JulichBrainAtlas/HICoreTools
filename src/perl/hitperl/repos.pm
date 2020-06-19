########################################################################################################

### >>>
package hitperl::repos;

########################################################################################################
# requires the following external cpan modules:
#  Date::Parse
########################################################################################################

### >>>
use File::Basename;
use File::Copy;
use File::Find;
use File::Path;
use Date::Parse;
use File::stat;
use Time::localtime;
use Exporter;
use Cwd 'abs_path';

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'moveFilesToRepository', 'getYoungestRepositoryVersionFromFile', 'getNextMinorRepositoryVersion',
             'getMajorRepositoryVersion', 'getNextMajorRepositoryVersion', 'addNewRevisionTextToRepository',
             'getMinorRepositoryVersion', 'getRepositoryVersion', 'getScriptRepositoryVersion',
             'getFileRepositoryInfoField' );
$VERSION = 0.1;

#### start modules

### move files to named repository
sub moveFilesToRepository {
 my ($srcdata,$dstpath,$compress,$verbose,$debug) = @_;
 ### >>>
 my @outfiles = ();
 if ( -d $srcdata ) {
  print "repos.moveFilesToRepository(): inpath='".$srcdata."', repospath='".$dstpath."', compress=$compress\n" if ( $verbose );
  my @pathelements = split(/\//,$srcdata);
  my @dirs = ($srcdata);
  my @files;
  find({ wanted => sub { push(@files,$_) } , no_chdir => 1 }, @dirs);
  my @movepaths = ();
  foreach my $file (@files) {
   my $ffile = $file;
   $ffile =~ s/$srcdata//;
   my $outdst = $dstpath."/".$pathelements[-1].$ffile;
   if ( $debug ) {
    my $type = "file";
    $type = "dir" if ( -d $file );
    print "repos.moveFilesToRepository().DEBUG: $type=$ffile -> $outdst\n";
   }
   if ( -d $file ) {
    if ( ! -d $outdst ) {
     mkpath($outdst) || die "FATAL ERROR: Cannot create output path '".$path."': $!";
    }
    push(@movepaths,$file);
   } elsif ( -f $file ) {
    move($file,$outdst) || die "FATAL ERROR: Cannot move file: $!";
    push(@outfiles,$outdst) if ( $compress );
   } else {
    warn "WARNING: Found invalid file '".$file."'. Cannot move!\n";
   }
  }
  @movepaths = reverse(@movepaths);
  print "repos.moveFilesToRepository().DEBUG: Removing ".scalar(@movepaths)." paths...\n" if ( $debug );
  foreach my $movepath (@movepaths) {
   print " repos.moveFilesToRepository().DEBUG: Removing path '".$movepath."'...\n" if ( $debug );
   rmdir($movepath) || die "FATAL ERROR: Cannot remove directory '".$movepath."': $!";
  }
 } elsif ( -f $srcdata ) {
  print "moveFilesToRepository(): infile='".$srcdata."', repospath='".$dstpath."', compress=$compress\n" if ( $verbose );
  move($srcdata,$dstpath) || die "FATAL ERROR: Cannot move source file '".$srcdata."' into '".$dstpath."': $!";
  push(@outfiles,$dstpath."/".basename($srcdata)) if ( $compress );
 }
 ### compress files
 if ( $compress && scalar(@outfiles)>0 ) {
  foreach my $outfile (@outfiles) {
   unless ( $outfile =~ m/\.gz$/ ) {
    print " + compressing file '".$outfile."'...\n" if ( $verbose );
    system("gzip -f $outfile") if ( -e $outfile && $debug!=1 );
   }
  }
 }
 ### >>>
}

### >>>
sub getTimeString {
 my $formated = shift;
 my ($sec,$min,$hour,$mday,$mon,$year) = CORE::localtime();
 $year += 1900;
 $mon += 1;
 $hour = "0$hour" if ( length($hour)==1 );
 $min = "0$min" if ( length($min)==1 );
 $sec = "0$sec" if ( length($sec)==1 );
 $mon = "0$mon" if ( length($mon)==1 );
 return "${mday}.${mon}.${year} - ${hour}:${min}:${sec}" if ( defined($formated) );
 return "${hour}${min}${mday}${mon}${year}"
}
sub addNewRevisionTextToRepository {
 my ($repospath,$revision,$comment,$verbose,$debug) = @_;
 if ( -d $repospath ) {
  print "repos.addNewRevisionTextToRepository(): repospath='".$repospath."', revision=$revision, comment='$comment'.\n" if ( $verbose );
  my $versionfile = $repospath;
  $versionfile .= "/version";
  open(FPout,">>$versionfile") || die "FATAL ERROR: Cannot create .repos version file '".$versionfile."': $!";
   if ( defined($comment) && length($comment)>0 ) {
    print FPout "$revision [".getTimeString(1)."] $comment\n";
   } else {
    print FPout "$revision [".getTimeString(1)."]\n";
   } 
  close(FPout);
  return 1;
 }
 warn "WARNING: invalid repository path '$repospath': $!";
 return 0;
}

### returns youngest (this is svn nomenclature) repository version
sub getYoungestRepositoryVersionFromFile {
 my ($repospath,$verbose,$debug) = @_;
 my $versionfile = $repospath."/version";
 if ( -e $versionfile ) {
  open(FPin,"<$versionfile") || die "FATAL ERROR: Cannot open .repos version file '".$versionfile."': $!";
   my @elements = ();
   while ( <FPin> ) {
    my $dataline = $_;
    @elements = split(/\ /,$dataline);
   }
  close(FPin);
  return $elements[0];
 } else {
  warn "WARNING: Cannot find versionfile '$versionfile'.\n";
 }
 return -1;
}

### returns (next) minor/major repository version name
# .repos is going to be added at the end to the repository path name
sub getMinorRepositoryVersion {
 my ($repospath,$verbose,$debug) = @_;
 $repospath .= "/.repos" unless ( $repospath =~ m/repos$/ );
 my $youngestversion = getYoungestRepositoryVersionFromFile($repospath,$verbose,$debug);
 return -1 if ( $youngestversion<=0 );
 my $minorversion = 0;
 @elements = split(/\./,$youngestversion);
 return $elements[1] if ( scalar(@elements)==2 );
 return $minorversion;
}
sub getNextMinorRepositoryVersion {
 my ($repospath,$verbose,$debug) = @_;
 $repospath .= "/.repos" unless ( $repospath =~ m/repos$/ );
 my $youngestversion = getYoungestRepositoryVersionFromFile($repospath,$verbose,$debug);
 return -1 if ( $youngestversion<=0 );
 my $minorversion = 1;
 @elements = split(/\./,$youngestversion);
 if ( scalar(@elements)==2 ) {
  $minorversion = 1+$elements[1];
 }
 return $minorversion;
}
sub getMajorRepositoryVersion {
 my ($repospath,$verbose,$debug) = @_;
 $repospath .= "/.repos" unless ( $repospath =~ m/repos$/ );
 print "DEBUG: repospath='$repospath'\n" if ( $debug );
 my $youngestversion = getYoungestRepositoryVersionFromFile($repospath,$verbose,$debug);
 return -1 if ( $youngestversion<=0 );
 @elements = split(/\./,$youngestversion);
 return $elements[0];
}
sub getNextMajorRepositoryVersion {
 my ($repospath,$verbose,$debug) = @_;
 $repospath .= "/.repos" unless ( $repospath =~ m/repos$/ );
 my $majorversion = getMajorRepositoryVersion($repospath,$verbose,$debug);
 return $majorversion+1;
}
sub getRepositoryVersion {
 my ($projectpath,$verbose,$debug) = @_;
 my $repospath = $projectpath."/.repos";
 return "unknown" unless ( -d $repospath );
 my $major = getMajorRepositoryVersion($repospath,$verbose,$debug);
 my $minor = getMinorRepositoryVersion($repospath,$verbose,$debug);
 return $major.".".$minor;
}

### >>>
# here we need a check whether the prog has been changed after last checkout
# mtime is the number of seconds after epoch time 01.01.1970
sub getMTimeFromDateString {
 my ($datestring,$debug) = @_;
 my @elements = split(/ /,$datestring);
 my $datecstring = $elements[0]."T".$elements[1];
 my $mtimestring = str2time($datecstring); ### this requires 'Date::Parse'
 print "DEBUG: date='$datestring' -> str2time($datecstring) => mtime=$mtimestring\n" if ( $debug );
 return $mtimestring;
}
# PROBLEM: Follow symbolic links
sub getScriptRepositoryVersion {
 my ($iprogname,$debug) = @_;
 my $progname = abs_path($iprogname);
 my $progmtime = stat($progname)->mtime;
 print "DEBUG: progname='$progname', mtime=$progmtime\n" if ( $debug );
 my $resultstring = `svn info $progname`;
 my @datalines = split(/\n/,$resultstring);
 my $revision = "unrevisoned version";
 my $cdatestring = "";
 my $reposmtime = 0;
 foreach my $dataline (@datalines) {
  if ( $dataline =~ m/^Revision:/ ) {
   my @elements = split(/ /,$dataline);
   $revision = $elements[1]; 
  } elsif ( $dataline =~ m/^Last Changed Date/ ) {
   $cdatestring = substr($dataline,19);
   $reposmtime = getMTimeFromDateString($cdatestring,$debug);
  }
 }
 if ( $progmtime>$reposmtime ) {
  return "WARNING: Repository version $revision is NOT up-to-date!";
 }
 return $revision.", last changed date: ".$cdatestring;
}
sub getFileRepositoryInfoField {
 my ($filename,$field,$verbose,$debug) = @_;
 my $resultstring = `svn info $filename`;
 my @datalines = split(/\n/,$resultstring);
 foreach my $dataline (@datalines) {
  if ( $dataline =~ m/^$field/ ) {
   my @elements = split(/\:/,$dataline,2);
   $elements[1] =~ s/^\s+//g;
   $elements[1] =~ s/\s+$//g;
   return $elements[1];
  }
 }
 return "unknown";
}

#### end of modules
sub _debug { warn "@_\n" if $DEBUG; }

### return value
1;
