## hitperl::atlas package
########################################################################################################

### >>>
package hitperl::atlas;

### >>>
use File::Path;
use Sys::Hostname;
use Exporter;
use hitperl;
use hitperl::xml;

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'getHistoSectionInfoFromIncFile', 'isValidTrafoType', 'isValidTrafoTypes', 'getProjectBrains',
  'getHistoImageFileList', 'getAtlasProjects', 'getNumberOfProjectBrains', 'getAtlasProjectsDataDrive',
  'getAtlasDataDrive', 'getAtlasContourDataDrive', 'getAtlasBrains', 'getContourProjectStructures',
  'getContourProjectCombinationStructures', 'getContourProjectCombinations', 'getCheckedStructureName',
  'isValidStructureName', 'getContourProjectColors', 'getNearestHistoSectionFileWithId', 'getAtlasStatusProjects',
  'getAtlasProjectsListFileName', 'getBrainIdentsFromName' );
$VERSION = 0.4;

#### start modules

### >>>
sub getAtlasContourDataDrive {
 my ($version,$debug) = @_;
 $version = 2 unless ( defined($version) );
 print "atlas.getAtlasDataDrive(): hostname=".hostname.", version=".$version."\n" if ( defined($debug) );
 my $datadrive = "/Volumes/AtlasDaten".$version;
 die "FATAL ERROR: Invalid atlas contour data drive '".$datadrive."' for host '".hostname."': $!" unless ( -d $datadrive );
 return $datadrive;
}
sub getAtlasDataDrive {
 return getAtlasContourDataDrive($version,$debug);
}

sub getAtlasProjectsDataDrive {
 return $ENV{ATLASPATH}."/projects";
}

### checks whether we have a valid trafo type
sub isValidTrafoType {
 my $trafotype = shift;
 return 1 if ( $trafotype eq "orig" || $trafotype eq "lin" || $trafotype eq "nlin" );
 return 0;
}
sub isValidTrafoTypes {
 my $trafotypes_ptr = shift;
 my @trafos = @{$trafotypes_ptr};
 foreach my $trafo (@trafos) {
  return 0 unless ( isValidTrafoType($trafo) );
 }
 return 1;
}

### >>>
sub getProjectBrains {
 my ($project,$path,$verbose,$debug) = @_;
 my $xmlfile = $path."/".$project.".xml";
 print "atlas.getProjectBrains(): Analyzing local project info file '".$xmlfile."'...\n" if ( defined($debug) && $debug );
 my @brains = ();
 my $oldVersion = 0;
 if ( -e $xmlfile ) {
  open(FPin,"<$xmlfile") || die "FATAL ERROR: Cannot open local project xml file '".$xmlfile."' for reading: $!";
   while ( <FPin> ) {
    if ( $_ =~ m/<ContourProject/ ) {
     my $version = getXMLAttribute($_,"version");
     $oldVersion = 1 if ( $version==2.0 );
    } elsif ( $_ =~ m/<Brain/ && $_ =~ m/num\=/ ) {
     if ( $oldVersion ) {
      chomp($_);
      print " + parsing brain line '$_'...\n" if ( $debug );
      my @elements1 = split(/\>/,$_);
      my @elements2 = split(/\</,$elements1[1]);
      push(@brains,$elements2[0]);
     } else {
      push(@brains,getXMLAttribute($_,"name","unknown"));
     }
    }
   }
  close(FPin);
 } else {
  warn "WARNING: Cannot find local project xml file '".$xmlfile."'.\n" if ( $verbose );
 }
 print " + found ".scalar(@brains)." brains: (@brains)\n" if ( $debug );
 return @brains;
}

sub getNumberOfProjectBrains {
 my ($project,$path,$verbose,$debug) = @_;
 my $xmlfile = $path."/".$project.".xml";
 print "atlas.getNumberOfProjectBrains(): Loading local project file '".$xmlfile."'...\n" if ( $verbose );
 if ( -e $xmlfile ) {
  open(FPin,"<$xmlfile") || die "FATAL ERROR: Cannot open local project xml file '".$xmlfile."' for reading: $!";
   while ( <FPin> ) {
    if ( $_ =~ m/<Brains/ ) {
     my @elements = split(/\ /,$_);
     foreach my $element (@elements) {
      if ( $element =~ m/^numBrains\=/ ) {
       my @nelements = split(/\"/,$element);
       return $nelements[1];
      }
     }
    }
   }
  close(FPin);
 }
 return 10;
}

### get keyvalue of histo sections from config file
sub getHistoSectionInfoFromIncFile {
 my ($pmbrain,$key,$atlaspath) = @_;
 my $filename = $atlaspath."/data/brains/human/postmortem/".$pmbrain."/histo";
 if ( ! -d $filename ) {
  print "WARNING: Invalid brain data path '".$filename."': $!";
  return "0";
 }
 $filename .= "/".$pmbrain."_info.inc";
 if ( ! -e $filename ) {
  print "WARNING: Cannot find local project include file '".$filename."': $!";
  return "0";
 }
 open(FPin,"<$filename") || die "FATAL ERROR: Cannot open '".$filename."' for reading: $!";
  while ( <FPin> ) {
   if ( $_ =~ m/^$key/i ) {
    chomp($_);
    my @values = split(/\=/,$_);
    close(FPin);
    return $values[1];
   }
  }
 close(FPin);
 print "WARNING: Cannot find any field $key in '".$filename."'.\n";
 return "0";
}

### >>>
sub getHistoImageFileList {
 my ($path,$suffix) = @_;
 $suffix = "png" unless ( defined($suffix) );
 my %histofilelist = ();
 if ( -d $path ) {
  my @histofiles = getDirent($path);
  foreach my $histofile (@histofiles) {
   next unless ( $histofile =~ m/\.${suffix}$/i );
   my $ident = getStructureIdentFromFileName($histofile);
   $histofilelist{$ident} = $histofile;
  }
 }
 return %histofilelist;
}

sub getNearestHistoSectionFileWithId {
 my ($sectionlist_ref,$ident) = @_;
 my %sectionlist = %{$sectionlist_ref};
 my $rfilename = "";
 my $lastmin = 100000;
 while ( my ($id,$filename)=each(%sectionlist) ) {
  if ( abs($id-$ident)<$lastmin ) {
   $rfilename = $filename;
   $lastmin = abs($id-$ident);
  }
 }
 return $rfilename;
}

### *** BEGIN OF RESTRICTED CODE ***
sub getBrainIdentsFromName {
 return (
    "pm13995" => 11,
    "pm14686" => 7,
    "pm1494"  => 12,
    "pm1696"  => 6,
    "pm18992" => 2,
    "pm20784" => 4,
    "pm2431"  => 13,
    "pm28193" => 3,
    "pm295"   => 10,
    "pm3297"  => 17,
    "pm34083" => 19,
    "pm38281" => 5,
    "pm3903"  => 20,
    "pm50381" => 18,
    "pm54491" => 1,
    "pm5694"  => 8,
    "pm6794"  => 22,
    "pm6895"  => 9,
    "pm7186"  => 14,
    "pm8099"  => 23,
    "pm9892"  => 24,
    "pmG699"  => 15,
    "pmG999"  => 16,
    "pm49692" => 21,
    "pm64679" => 26
 );
}
### *** END OF RESTRICTED CODE ***

### returns list of atlas brains
sub getAtlasBrains {
 my $brainnames = shift;
 my @atlasbrains = ();
 if ( $brainnames =~ m/^atlas$/i || $brainnames =~ m/^all$/i ) {
  my $atlaspath = $ENV{ATLASPATH};
  $brainnames = $atlaspath."/projects/contourrecon/scripts/data/misc/brains_atlas.txt";
 }
 if ( -e $brainnames ) {
  open(FPin,"<$brainnames") || die "FATAL ERROR: Cannot open '".$brainnames."' for reading: $!";
  while ( <FPin> ) {
   next if ( $_ =~ m/^#/ );
   @elements = split(/\ /,wchomp($_));
   push(@atlasbrains,$elements[0]);
  }
 close(FPin);
 } else {
  @atlasbrains = split(/\,/,$brainnames);
 }
 return @atlasbrains;
}

### returns list of atlas contourrecon projects
sub getAtlasProjectsListFileName {
 my ($projectlist,$verbose) = @_;
 my $atlaspath = $ENV{ATLASPATH};
 my $filename = "";
 if ( $projectlist =~ m/^atlasall$/i ) {
  $filename = $atlaspath."/projects/contourrecon/scripts/data/misc/projects_atlasall.txt";
 } elsif ( $projectlist =~ m/^publicatlas$/i ) {
  $filename = $atlaspath."/projects/contourrecon/scripts/data/misc/projects_atlaspublic.txt";
 } elsif ( $projectlist =~ m/^atlas$/i ) {
  $filename = $atlaspath."/projects/contourrecon/scripts/data/misc/projects_atlas.txt";
 } elsif ( $projectlist =~ m/^cortexcerebri$/i ) {
  $filename = $atlaspath."/projects/contourrecon/scripts/data/misc/projects_cortexcerebri.txt";
 }
 return $filename;
}
sub getAtlasStatusProjects {
 my ($projectlist,$verbose) = @_;
 my %projects = ();
 my $projectlistname = getAtlasProjectsListFileName($projectlist,$verbose);
 $projectlistname =~ s/.txt/2.txt/;
 ### >>>
  print "atlas.getAtlasStatusProjects(): Loading project list file '".$projectlistname."'...\n" if ( $verbose );
  open(FPin,"<$projectlistname") || die "FATAL ERROR: Cannot open '".$projectlistname."' for reading: $!";
   while ( <FPin> ) {
    next if ( $_ =~ m/^#/ );
    my @elements = split('#',wchomp($_));
    $elements[0] =~ s/^\s+|\s+$//g;
    print $elements[0]."\n";
    my @infos = split(/ /,$elements[0]);
    $projects{$infos[0]} = $infos[1];
   }
  close(FPin);
 ### >>>
 return %projects;
}
sub getAtlasProjects {
 my ($projectlist,$verbose) = @_;
 my @projects = ();
 my $projectlistname = getAtlasProjectsListFileName($projectlist,$verbose);
 if ( length($projectlistname)>1 && -e $projectlistname ) {
  print "atlas.getAtlasProjects(): Loading project list file '".$projectlistname."'...\n" if ( $verbose );
  open(FPin,"<$projectlistname") || die "FATAL ERROR: Cannot open '".$projectlistname."' for reading: $!";
  while ( <FPin> ) {
   next if ( $_ =~ m/^#/ );
   my @elements = split('#',wchomp($_));
   $elements[0] =~ s/^\s+|\s+$//g;
   push(@projects,$elements[0]);
  }
 close(FPin);
 } else {
  @projects = split(/\,/,$projectlist);
 }
 return @projects;
}

## check whether the structure name is correct
sub isValidStructureName {
 my $structurename = shift;
 my @elements = split(/\_/,$structurename);
 my $nelements = scalar(@elements);
 if ( $nelements==2 || $nelements==3 ) {
  my $lastelement = lc($elements[-1]);
  if ( $lastelement eq "l" || $lastelement eq "r" || $lastelement eq "b" ) {
   return 1;
  } elsif ( $lastelement eq "onlyinner" || $lastelement eq "onlyouter" || $lastelement eq "inner" || $lastelement eq "outer" ) {
   my $side = lc($elements[-2]);
   if ( $side eq "l" || $side eq "r" || $side eq "b" ) {
    return 1;
   }
  }  
 }
 return 0;
}

## ensures that the structure name (for a structure like 'AbcD_l') ends with a small letter
sub getCheckedStructureName {
 my $structurename = shift;
 my @elements = split(/\_/,$structurename);
 my $lastelement = lc($elements[-1]);
 my $newstructurename = "";
 if ( $lastelement eq "l" || $lastelement eq "r" || $lastelement eq "b" ) {
  for ( my $n=0 ; $n<scalar(@elements)-1 ; $n++ ) {
   $newstructurename .= $elements[$n]."_";
  }
  $newstructurename .= $lastelement;
 } elsif ( $lastelement eq "onlyinner" || $lastelement eq "onlyouter" || $lastelement eq "inner" || $lastelement eq "outer" ) {
  my $side = lc($elements[-2]);
  if ( $side eq "l" || $side eq "r" || $side eq "b" ) {
   for ( my $n=0 ; $n<scalar(@elements)-2 ; $n++ ) {
    $newstructurename .= $elements[$n]."_";
   }
   $newstructurename .= $side."_".$lastelement;
  } else {
   ## invalid format
   warn "atlas.getCheckedStructureName(): Invalid structure name '".$structurename."'. Expecting '_l|r|b' before '_inner|outer|onlyinner|onlyouter'!\n";
   return $structurename;
  }
 } else {
   ## invalid format
   warn "atlas.getCheckedStructureName(): Invalid structure name '".$structurename."'. Expecting '_l|r|b|inner|outer|onylinner|onlyouter' at the end!\n";
   return $structurename;
 }
 return $newstructurename;
}

##
sub getContourProjectColors {
 my ($projectpath,$verbose,$debug) = @_;
 my $colorfilename = $projectpath."/colors.inc";
 my %colors = ();
 return %colors unless ( -e $colorfilename );
 open(FPin,"<$colorfilename") || die "FATAL ERROR: Cannot open color file '".$colorfilename."' for reading: $!";
  print " Loading colormap file '".$colorfilename."'...\n" if ( $verbose );
  while ( <FPin> ) {
   next if ( $_ =~ m/^#/ );
   chomp($_);
   my @elements = split(/\ /,$_);
   if ( scalar(@elements)>=4 ) {
    @{$colors{$elements[0]}} = ($elements[1],$elements[2],$elements[3]);
   } else {
    print "Parsing failure for line $_.\n";
   }
  }
 close(FPin);
 return %colors;
}

## contourreccon project specific functions
sub getContourProjectStructures {
 my ($projectpath,$all,$verbose,$debug) = @_;
 my $strucfile = $projectpath."/structures.inc";
 my @structures = ();
 open(FPstrucin,"<$strucfile") || die "FATAL ERROR: Cannot open structure file '".$strucfile."': $!";
  while ( <FPstrucin> ) {
   if ( ( defined($all) && $all==1 && ($_ =~ m/structure/i || $_ =~ m/unfinished/i) ) || $_ =~ m/structure/i ) {
    my @values = split(/\=/,wchomp($_));
    my $strucs = cleanString($values[1]);
    my @structurenames = split(/\ /,$strucs);
    foreach my $structurename (@structurenames) {
     push(@structures,getCheckedStructureName($structurename));
    }
   }
  }
 close(FPstrucin);
 die "FATAL ERROR: Invalid number of structures '".$strucfile."'." if ( scalar(@structures)==0 );
 return sort(@structures);
}
sub getContourProjectCombinations {
 my ($infile,$verbose,$debug) = @_;
 $infile .= "/combinations.inc";
 my %combinations = ();
 return %combinations unless ( -e $infile );
 open(FPdatain,"<$infile") || die "FATAL ERROR: Cannot open combinations file '".$infile."': $!";
  while ( <FPdatain> ) {
   next if ( $_ =~ m/^#/ );
   my @values = split(/\=/,wchomp($_));
   if ( @values>=2 ) {
    $values[0] = getCheckedStructureName(cleanString($values[0]));
    $values[1] = getCheckedStructureName(cleanString($values[1]));
    $combinations{$values[0]} = $values[1];
   }
  }
 close(FPdatain);
 return %combinations;
}
sub removeElementFromArray {
 my ($array_ref_ptr,$structure) = @_;
 my @array = @{$array_ref_ptr};
 my @outarray = ();
 foreach my $element (@array) {
  next if ( $element =~ m/^$structure$/ );
  push(@outarray,$element);
 }
 return @outarray;
}
sub getContourProjectCombinationStructures {
 my ($infile,$unique,$verbose,$debug) = @_;
 my @structures = ();
 my %combinations = getContourProjectCombinations($infile);
 if ( defined($unique) && $unique==1 ) {
  @structures = getContourProjectStructures($infile);
  while ( my ($key,$value) = each(%combinations) ) {
   my @skipstructures = split(/\ /,$value);
   foreach my $skipstructure (@skipstructures) {
    @structures = removeElementFromArray(\@structures,$skipstructure);
   }
   push(@structures,$key);
  }
 } else {
  while ( my ($key,$value) = each(%combinations) ) {
   push(@structures,$key);
  }
 }
 return @structures;
}

#### end of modules
sub _debug { warn "@_\n" if $DEBUG; }

### return value
1;
