## hitperl::git package

### >>>
package hitperl::git;

### >>>
use File::Path;
use Exporter;

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'isGITAvailable', 'getGITRepositoryVersion', 'isGITRepositoryUpToDate', 'checkGITRepositoryDependencies' );
$VERSION = 0.1;

#### start modules

### private modules
sub _getConsoleCommandResult {
 my ($prog,$command) = @_;
 my $tmpfile = "/tmp/".$prog.(sprintf "%06x",int(rand(100000))).".log";
 system($command." > $tmpfile 2> $tmpfile");
 my $result = "";
 open(FPtmpin,"<$tmpfile") || die "FATAL ERROR: Malfunction in hitperl.git.".$prog.": Cannot create tmp file: $!";
  while ( <FPtmpin> ) {
   $result .= $_;
  }
 close(FPtmpin);
 unlink($tmpfile);
 chomp($result);
 return $result;
}

### public modules
sub isGITAvailable {
 my $result = _getConsoleCommandResult("isGITAvailable","git --version");
 return ($result=~m/^git/i)?1:0;
}
sub getGITRepositoryVersion {
 return _getConsoleCommandResult("getGITRepositoryVersion","git rev-parse HEAD");
}
sub getGITRepostitoryRemoteVersion {
 my $repos = shift;
 my $result = _getConsoleCommandResult("getGITRepostitoryRemoteVersion","git ls-remote ".$repos);
 my @lines = split(/\n/,$result);
 my $commitId = (split(/\t/,$lines[0]))[0];
 return $commitId;
}
sub isGITRepositoryUpToDate {
 return _getConsoleCommandResult("isGITRepositoryUpToDate","git remote show origin");
 if ( !($result =~ m/^fatal/i) ) {
  my @lines = split(/\n/,$result);
  foreach my $line (@lines) {
   if ( $line =~ m/master pushes to master/ ) {
    my @elements = split(/\(/,$line);
    return ($elements[1] =~ m/out of date/)?0:1;
   }
  }
 }
 return 1;
}
sub checkGITRepositoryDependencies {
 my ($prog,$depfilename) = @_;
 my %results = ();
 if ( -e $depfilename ) {
  open(FPin,"<$depfilename") || die "FATAL ERROR: Cannot open dependencies file '".$depfilename."' for reading: $!";
   while ( <FPin> ) {
    next if ( $_ =~ m/^#/ );
    chomp($_);
    my @elements = split(/ /,$_);
    if ( scalar(@elements)>=2 ) {
     my $reposname = $elements[0];
     my $commitId = $elements[1];
     my $rcommitId = getGITRepostitoryRemoteVersion($reposname);
     my $isNotUpToDate = ( $commitId eq $rcommitId )?0:1;
     $results{$reposname} = $rcommitId if ( $isNotUpToDate );
    }
   }
  close(FPin);
 }
 return %results;
}


#### end of modules
sub _debug { warn "@_\n" if $DEBUG; }

### return value
1;
