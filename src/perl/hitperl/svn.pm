## hitperl::svn package
#
# available perl extensions:
#  use SVN::Core;
#  use SVN::Repos;
#  use SVN::Simple::Edit;
#  use SVN::Fs;
#
########################################################################################################

### >>>
package hitperl::svn;

### >>>
use File::Path;
use Exporter;

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'fileIsInRepository', 'getLatestRevision', 'getProjectRepositoryPath', 'getRevisionFromProjectFile',
             'getLatestFileRevision' );
$VERSION = 0.1;

#### start modules

### >>>
sub getRevisionFromProjectFile {
 my ($project,$path,$verbose,$debug) = @_;
 my $projectinfofile = $path."/".$project.".xml";
 if ( -e $projectinfofile ) {
  open(FPin,"<$projectinfofile") || die "FATAL ERROR: Cannot open local project xml file '".$projectinfofile."' for reading: $!";
   while ( <FPin> ) {
    if ( $_ =~ m/\<Revision/i ) {
     my @values1 = split(/\>/,$_);
     my @values2 = split(/\</,$values1[1]);
     close(FPin);
     return $values2[0];
    }
   }
  close(FPin);
 }
 return "unknown";
}

### checks whether a file is already in the repository
sub fileIsInRepository {
 my ($updatefile,$reposfiles_ref_ptr) = @_;
 my @reposfiles = @{$reposfiles_ref_ptr};
 return 1 if ( grep(/\b$updatefile\b/,@reposfiles) );
 return 0;
}

### returns latest revision number
# to get version of a single file in the repository use:
#  'svn info file:///<REPOSITORYPATH>/<PROJECT>/../../<FILENAME>'
sub getLatestRevision {
 my $repospath = shift;
 if ( -d $repospath ) {
  my $revision = `svnlook youngest $repospath`;
  chomp($revision);
  return $revision;
 }
 warn "WARNING: Invalid repository url '".$repospath."'.\n";
 return 0;
}

### >>>
# short version will only return the latest revision number
sub getLatestFileRevision {
 my ($subpath,$file,$shortversion) = @_;
 my $REPOSPATH = $ENV{REPOSITORIESPATH};
 $REPOSPATH .= "/subversion/".$subpath;
 return "unknown" unless ( -d $REPOSPATH );
 my $filepath = $REPOSPATH."/".$file; 
 my $result = `svn info file://$filepath`;
 my $revision = "";
 my $lastdate = "";
 my @lines = split(/\n/,$result);
 foreach my $line (@lines) {
  if ( $line =~ m/Revision/ ) {
   my @elements = split(/\:/,$line);
   $revision = $elements[1];
   $revision =~ s/^\s+//;
   return $revision if ( defined($shortversion) );
  } elsif ( $line =~ m/Last Changed Date/ ) {
   my @elements = split(/\:/,$line,2);
   $lastdate = $elements[1];
   $lastdate =~ s/^\s+//;
  }
 }
 return $revision."; ".$lastdate;
}

### returns project repository path
sub getProjectRepositoryPath {
 my $project = shift;
 my $REPOSPATH = $ENV{REPOSITORIESPATH};
 return $REPOSPATH."/subversion/Atlasprojects/".$project;
}

#### end of modules
sub _debug { warn "@_\n" if $DEBUG; }

### return value
return 1;
