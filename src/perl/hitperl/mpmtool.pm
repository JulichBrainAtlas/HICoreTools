## hitperl::mpmtool package
########################################################################################################

### >>>
package hitperl::mpmtool;

### >>>
use hitperl;
use POSIX;
use Exporter;
use File::Basename;
use Digest::MD5;

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'saveMPMDataTable', 'loadMPMDataTable', 'dropIndexValueFromMPMDataTable',
     'getIndexValuesFromMPMDataTable', 'getListOfStructuresInMPMDataTable','saveFSLAtlasSpecFileAs',
     'getNormalizedIndexValuesFromMPMDataTable', 'savePValuesAs', 'getProjectMPMFromMPMDataTable',
     'getMaximumOverlapExceeds', 'saveMPMDataTableInfo', 'getMPMDataTableInfo', 'getShiftedIndexValues',
     'addStructureValuesFromIndexFileToMPMDataTable', 'getMaximumKeyTable', 'printMPMDataTableToString',
     'getMaximumStructureIdentsFromMPMDataTable', 'dropProjectFromMPMDataTable', 'loadIndexFile',
     'dropIndexValuesFromMPMDataTable', 'getProjectListFromMPMDataTable', 'saveIValuesAs',
     'getINormalizedIndexValuesFromMPMDataTable', 'addStructureValuesToMPMDataTable', 'saveXMLLabelInfoFile',
     'getStructureIdentsFromMPMDataTable', 'saveINormalizedValuesAs' );
$VERSION = 0.1;

### --
sub getShiftedIndexValues {
 my ($indexvalues_ptr,$shifting_ptr,$verbose,$debug) = @_;
 my %indices = %{$indexvalues_ptr};
 my %shiftings = %{$shifting_ptr};
 my %newindices = ();
 while ( my ($key,$value)=each(%indices) ) {
  if ( exists($shiftings{$value}) ) {
   $newindices{$key} = $shiftings{$value};
  } else {
   die "FATAL ERROR: No new value found in conversion table for $value.";
  }
 }
 return %newindices;
}

### --
sub _getSubElement_ {
 my ($string,$index) = @_;
 my @elements = split(/\_/,$string);
 return $elements[$index];
}
sub saveFSLAtlasSpecFileAs {
 my ($datatable_ptr,$ontology_ptr,$atlasfilename,$dataversion,$verbose) = @_;
 my %datatable = %{$datatable_ptr};
 my %ontology = %{$ontology_ptr};
 my %sidenames = ( 'l' => "left", 'r' => "right" );
 my $specfilename = $atlasfilename;
 unless ( $specfilename =~ m/\.xml$/ ) {
  $specfilename =~ s/\.gz$//;
  $specfilename =~ s/\.nii$//;
  $specfilename =~ s/\.vff$//;
  $specfilename .= ".xml";
 }
 open(FPout,">$specfilename") || die "FATAL ERROR: Cannot create FSL Atlas specification file '".$specfilename."': $!";
  print FPout "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n";
  print FPout "<atlas version=\"1.0\">\n";
  print FPout " <header>\n";
  print FPout "  <name>JuBrain Cytoarchitectonic Probability Atlas</name>\n";
  print FPout "  <type>Label</type>\n";
  print FPout "  <images>\n";
  print FPout "   <imagefile>".basename($atlasfilename)."</imagefile>\n";
  print FPout "  </images>\n";
  print FPout " </header>\n";
  my @fileinfos = @{$datatable{"files"}};
  print FPout " <data>\n";
  if ( $dataversion==1 ) {
   ### that's for fgpmaps
   foreach my $fileinfo (@fileinfos) {
    my @elements = split(/\;/,$fileinfo);
    if ( scalar(@elements)==3 ) {
     my @names = split(/\_\_/,$elements[1]);
     my $structurename = _getSubElement_($names[1],1);
     $structurename .= "_"._getSubElement_($names[2],1);
     $structurename = $ontology{$structurename} if ( exists($ontology{$structurename}) );
     $sidename = $sidenames{_getSubElement_($names[2],2)};
     print FPout "  <label index=\"".($elements[0]-1)."\">".$sidename." ".$structurename."</label>\n";
    }
   }
  } elsif ( $dataversion==2 ) {
   ### that's for mpmatlas data
   foreach my $fileinfo (@fileinfos) {
    my @elements = split(/\;/,$fileinfo);
    if ( scalar(@elements)==3 ) {
     my @names = split(/\_/,$elements[1]);
     my $structurename = $names[0]."_".$names[1];
     $structurename = $ontology{$structurename} if ( exists($ontology{$structurename}) );
     $sidename = $sidenames{$names[2]};
     print FPout "  <label index=\"".($elements[0]-1)."\">".$sidename." ".$structurename."</label>\n";
    }
   }
  }
  print FPout " </data>\n";
  print FPout "</atlas>\n";
 close(FPout);
 print "mpmtool.saveFSLAtlasSpecFileAs(): Created FSL Atlas specification file '".$specfilename."'.\n" if ( $verbose );
 return $specfilename;
}

### --
sub loadIndexFile {
 my ($filename,$verbose,$debug) = @_;
 my %indices = ();
 open(FPin,"<$filename") || die "FATAL ERROR: Cannot open index file '".$filename."': $!";
  while ( <FPin> ) {
   next if ( $_ =~ m/^#/ );
   chomp($_);
   my @values = split(/ /,$_);
   $indices{$values[0]} = $values[1] if ( scalar(@values)==2 );
  }
 close(FPin);
 return %indices;
}

### --
sub saveIValuesAs {
 my ($indexvalues_ptr,$filename,$verbose,$debug) = @_;
 print " + saving ivalue index file '".$filename."'...\n" if ( $verbose );
 my %indexvalues = %{$indexvalues_ptr};
 open(FPout,">$filename") || die "FATAL ERROR: Cannot create '".$filename."': $!";
  while ( my ($key,$value)=each(%indexvalues) ) {
   print FPout $key." ".ceil($value)."\n";
  }
 close(FPout);
 return $filename;
}
sub saveXMLLabelInfoFile {
 my ($indexvalues_ptr,$labelnames_ptr,$filename,$verbose,$debug) = @_;
 my $xmlfilename = $filename;
 $xmlfilename =~ s/\.itxt/\.xml/;
 print " + saving label index file '".$xmlfilename."'...\n" if ( $verbose );
 my $outstr = "";
 my %labelnames = %{$labelnames_ptr};
 my %indexvalues = %{$indexvalues_ptr};
 my $idx = 1;
 my $n = 0;
 my %nvalues = {};
 while ( my ($key,$value)=each(%indexvalues) ) {
  my $cvalue = ceil($value);
  if ( !exists($nvalues{$cvalue}) ) {
   $nvalues{$cvalue} = $idx;
   my $labelname = exists($labelnames{$cvalue})?$labelnames{$cvalue}:"Unknown";
   my $red   = int(rand(255));
   my $green = int(rand(255));
   my $blue  = int(rand(255));
   $outstr .= "  <Structure num=\"".$n."\" id=\"".$cvalue."\" grayvalue=\"".$idx."\" color=\"rgb(".$red.",".$green.",".$blue.")\">".$labelname."</Structure>\n";
   $idx += 1;
   $n += 1;
  }
 }
 open(FPout,">$xmlfilename") || die "FATAL ERROR: Cannot create label index file '".$xmlfilename."': $!";
  print FPout "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\n";
  print FPout "<JulichBrain-Atlas version=\"1.0\">\n";
  print FPout " <Structures numStructures=\"".$n."\">\n";
  print FPout $outstr;
  print FPout " </Structures>\n";
  print FPout "<JulichBrain-Atlas>\n";
 close(FPout);
 return $xmlfilename;
}
sub saveINormalizedValuesAs {
 my ($indexvalues_ptr,$filename,$verbose,$debug) = @_;
 print " + saving ivalue normalized index file '".$filename."'...\n" if ( $verbose );
 my %indexvalues = %{$indexvalues_ptr};
 my %nvalues = {};
 my $idx = 1;
 my $convstr = "";
 while ( my ($key,$value)=each(%indexvalues) ) {
  my $cvalue = ceil($value);
  if ( !exists($nvalues{$cvalue}) ) {
   $nvalues{$cvalue} = $idx;
   $convstr .= "# ".$cvalue." ".$idx."\n";
   $idx += 1;
  }
 }
 if ( $idx>255 ) {
  print "SERIOUS WARNING: Index overflow error. Max index is $idx.\n";
 }
 open(FPout,">$filename") || die "FATAL ERROR: Cannot create '".$filename."': $!";
  print FPout "# created by mpmtool.saveINormalizedValuesAs()\n";
  print FPout $convstr;
  ## print FPout "IRF UBYTE 256 256 256\n";
  while ( my ($key,$value)=each(%indexvalues) ) {
   print FPout $key." ".$nvalues{ceil($value)}."\n";
  }
 close(FPout);
 return $filename;
}
sub savePValuesAs {
 my ($indexvalues_ptr,$filename,$verbose,$debug) = @_;
 print " + saving pvalue index file '".$filename."'...\n" if ( $verbose );
 my %indexvalues = %{$indexvalues_ptr};
 open(FPout,">$filename") || die "FATAL ERROR: Cannot create '".$filename."': $!";
  while ( my ($key,$value)=each(%indexvalues) ) {
   print FPout $key." ".sprintf("%.6f",$value)."\n";
  }
 close(FPout);
 return $filename;
}

### --
sub saveMPMDataTableInfo {
 my ($tablefilename,$project,$structures_ptr,$revision,$verbose,$debug) = @_;
 my $infofilename = $tablefilename;
 $infofilename =~ s/\.dat$/\.txt/;
 @structures = @{$structures_ptr};
 my %projectstructures = ();
 ### open info filename
  if ( -e $infofilename ) {
   open(FPin,"<$infofilename") || die "FATAL ERROR: Cannot open info file '".$infofilename."' for reading: $!";
    while ( <FPin> ) {
     next if ( $_ =~ m/^\#/ );
     if ( $_ =~ m/^[a-zA-Z]/ ) {
      my @elements = split(/\ /,$_,2);
      chomp($elements[1]);
      $projectstructures{$elements[0]} = $elements[1];
     }
    }
   close(FPin);
  }
  my $projectinfo = "[revision=$revision, structures[".scalar(@structures)."]=(@structures)]";
  $projectstructures{$project} = $projectinfo;
  ### save info file
  open(FPout,">$infofilename");
   while ( my ($key,$value) = each(%projectstructures) ) {
    print FPout $key." ".$value."\n";
   }
  close(FPout);
 ### >>>
 return $infofilename;
}

### >>>
sub printMPMDataTableToString {
 my ($datatables_ptr,$verbose,$debug) = @_;
 my %datatables = %{$datatables_ptr};
 ### create string
  my $outstring = "";
  $outstring .= "n ".$datatables{"name"}."\n" if ( exists $datatables{"name"} );
  my @fileinfos = @{$datatables{"files"}};
  foreach my $fileinfo (@fileinfos) {
   $outstring .= "f ".$fileinfo."\n";
  }
  my %datatable = %{$datatables{"data"}};
  while ( my ($key,$value)=each(%datatable) ) {
   my @pvalues = @{$value};
   $outstring .= "d ".$key." @pvalues\n";
  }
 ### >>>
 return $outstring;
}

### updated to new version
sub saveMPMDataTable {
 my ($datatables_ptr,$filename,$verbose,$debug) = @_;
 print "saveMPMDataTable(): Saving mpm datatable '".$filename."'...\n" if ( $verbose );
 my %datatables = %{$datatables_ptr};
 ### >>>
  open(FPout,">$filename") || die "FATAL ERROR: Cannot create mpm datafile '".$filename."': $!";
   ### saving name of the datatable
   print FPout "n ".$datatables{"name"}."\n" if ( exists $datatables{"name"} );
   ### saving fileinfo
   my @fileinfos = @{$datatables{"files"}};
   foreach my $fileinfo (@fileinfos) {
    print FPout "f ".$fileinfo."\n";
   }
   ### saving data values
   my %datatable = %{$datatables{"data"}};
   while ( my ($key,$value)=each(%datatable) ) {
    my @pvalues = @{$value};
    print FPout "d ".$key." @pvalues\n";
   }
  close(FPout);
 ### >>>
 return $filename;
}

### updated to new version
sub loadMPMDataTable {
 my ($filename,$verbose,$debug) = @_;
 my %datatables = ();
 if ( -e $filename ) {
  print "loadMPMDataTable(): Loading '".$filename."'...\n" if ( $verbose );
  my $nvalues = 0;
  my $nfiles = 0;
  my $tablename = "unknown";
  my @tablefiles = ();
  my %datatable = ();
  open(FPin,"<$filename") || die "FATAL ERROR: Cannot open mpm index datafile '".$filename."': $!";
   while ( <FPin> ) {
    chomp($_);
    if ( $_ =~ m/^d/i ) {
     ### for the index values
     my @elements = split(/\ /,$_);
     my $datatype = shift(@elements);
     my $index = shift(@elements);
     @{$datatable{$index}} = @elements;
     $nvalues += 1;
    } elsif ( $_ =~ m/^f/i ) {
     ### for the indexfile infos
     push(@tablefiles,substr($_,2));
     $nfiles += 1;
    } elsif ( $_ =~ m/^n/i ) {
     ### for the name of the datatable
     $tablename = substr($_,2);
    }
   }
  close(FPin);
  $datatables{"name"} = $tablename;
  @{$datatables{"files"}} = @tablefiles;
  %{$datatables{"data"}} = %datatable;
  print " + got $nfiles files and $nvalues non-zero data entries.\n" if ( $verbose );
 } else {
  print "loadMPMDataTable(): Could not find mpm datatable file '".$filename."'.\n" if ( $verbose );
 }
 return %datatables;
}

### small local helper
sub _hasStructureId {
 my ($id,$values_ptr) = @_;
 my @values = @{$values_ptr};
 for ( my $i=0 ; $i<scalar(@values) ; $i+=2 ) {
  return 1 if ( $values[$i]==$id );
 }
 return 0;
}
sub _hasStructureIds {
 my ($ids_ptr,$values_ptr) = @_;
 my @values = @{$values_ptr};
 my @ids = @{$ids_ptr};
 for ( my $i=0 ; $i<scalar(@values) ; $i+=2 ) {
  return 1 if ( isInArray($values[$i],\@ids) );
 }
 return 0;
}

### >>>
sub getMaximumKeyTable {
 my ($datatables_ptr,$threshold,$verbose,$debug) = @_;
 my %datatables = %{$datatables_ptr};
 my %datatable = %{$datatables{"data"}};
 my %ndatatable = ();
 while ( my ($key,$value)=each(%datatable) ) {
  my @values = @{$value};
  my $maxvalue = 0.0;
  my $maxid = 0;
  for ( my $n=0 ; $n<scalar(@values) ; $n +=2 ) {
   if ( $values[$n+1]>$maxvalue ) {
    $maxvalue = $values[$n+1];
    $maxid = $values[$n];
   }
  }
  $ndatatable{$key} = $maxid if ( $maxvalue>$threshold );
 }
 %{$datatables{"maxindexdata"}} = %ndatatable;
 return %datatables;
}

### updated to new version
sub dropIndexValueFromMPMDataTable {
 my ($datatables_ptr,$strucDBIdent,$verbose,$debug) = @_;
 print "mpmtool.dropIndexValueFromMPMDataTable().DEBUG: Dropping structure $strucDBIdent from datatable...\n" if ( $debug );
 my %datatables = %{$datatables_ptr};
 ### >>>
  ### drop index from fileinfos
  my @nfileinfos = ();
  my @fileinfos = @{$datatables{"files"}};
  foreach my $fileinfo (@fileinfos) {
   my @elements = split(/\;/,$fileinfo);
   if ( $elements[0]!=$strucDBIdent ) {
    push(@nfileinfos,$fileinfo);
   }
  }
  if ( scalar(@nfileinfos)==scalar(@fileinfos) ) {
   warn "WARNING: Could not find any structure with id '$strucDBIdent'.\n";
   return %datatables;
  }
  @{$datatables{"files"}} = @nfileinfos;
  ### drop data from table
  my %datatable = %{$datatables{"data"}};
  while ( my ($key,$value)=each(%datatable) ) {
   my @datavalues = @{$value};
   if ( _hasStructureId($strucDBIdent,\@datavalues) ) {
    print "mpmtool.dropIndexValueFromMPMDataTable().DEBUG: Found structure: $key - @datavalues\n" if ( $debug );
    my @newvalues = ();
    my @values = @{$value};
    my $nvalues = @values;
    for ( my $i=0 ; $i<$nvalues ; $i+=2 ) {
     push(@newvalues,($values[$i],$values[$i+1])) if ( $values[$i]!=$strucDBIdent );
    }
    if ( scalar(@newvalues)>0 ) {
     @{$datatable{$key}} = @newvalues;
    } else {
     delete $datatable{$key};
    }
   }
  }
  %{$datatables{"data"}} = %datatable;
 ### >>>
 return %datatables;
}

### >>>
sub dropIndexValuesFromMPMDataTable {
 my ($datatables_ptr,$structureIds_ptr,$verbose,$debug) = @_;
 my %datatables = %{$datatables_ptr};
 my @structureIds = @{$structureIds_ptr};
 print "   + removing ".scalar(@structureIds)." structures @structureIds from datatable '".$datatables{"name"}."'...\n" if ( $verbose );
 ### >>>
  ### updating fileinfo list
  my @nfileinfos = ();
  my @fileinfos = @{$datatables{"files"}};
  my $nfilelines = scalar(@fileinfos);
  foreach my $fileinfo (@fileinfos) {
   my @elements = split(/\;/,$fileinfo);
   unless ( isInArray($elements[0],\@structureIds) ) {
    push(@nfileinfos,$fileinfo);
    $nfilelines -= 1;
   }
  }
  @{$datatables{"files"}} = @nfileinfos;
  ### dropping structure data from datatable
  my %datatable = %{$datatables{"data"}};
  my $ndatalines = 0;
  while ( my ($key,$value)=each(%datatable) ) {
   my @datavalues = @{$value};
   if ( _hasStructureIds(\@structureIds,\@datavalues) ) {
    ### print "DEBUG: found structure(s): $key - @datavalues...\n" if ( $debug );
    my @newvalues = ();
    my @values = @{$value};
    my $nvalues = @values;
    for ( my $i=0 ; $i<$nvalues ; $i+=2 ) {
     push(@newvalues,($values[$i],$values[$i+1])) unless ( isInArray($values[$i],\@structureIds) );
    }
    if ( scalar(@newvalues)>0 ) {
     @{$datatable{$key}} = @newvalues;
    } else {
     delete $datatable{$key};
     $ndatalines += 1;
    }
   }
  }
  %{$datatables{"data"}} = %datatable;
  #### >>>
  print "    + removed $nfilelines files and $ndatalines data lines.\n" if ( $verbose );
 ### >>>
 return %datatables;
}

### search for project name in datafile and removes all of them, project will be totally rmoved
sub dropProjectFromMPMDataTable {
 my ($datatables_ptr,$projectname,$verbose,$debug) = @_;
 my %datatables = %{$datatables_ptr};
 print "  + dropping project ".$projectname." from datatable '".$datatables{"name"}."'...\n" if ( $verbose );
 # get structure id's of the project from filelist
 my @structureIds = ();
 my @fileinfos = @{$datatables{"files"}};
 foreach my $fileinfo (@fileinfos) {
  my @elements1 = split(/\_\_/,$fileinfo);
  my @elements2 = split(/\_/,$elements1[1]);
  if ( $elements2[1] =~ m/^$projectname$/ ) {
   my @elements = split(/\;/,$fileinfo);
   my $structureId = $elements[0];
   push(@structureIds,$structureId);
   print "DEBUG: fileinfo: '".$fileinfo."': project=$elements2[1], structureId=$structureId\n" if ( $debug );
  }
 }
 return %datatables if ( scalar(@structureIds)==0 );
 return dropIndexValuesFromMPMDataTable(\%datatables,\@structureIds,$verbose,$debug);
}

### >>>
sub getProjectListFromMPMDataTable {
 my ($datatables_ptr,$verbose,$debug) = @_;
 my %datatables = %{$datatables_ptr};
 my @projects = ();
 my @fileinfos = @{$datatables{"files"}};
 foreach my $fileinfo (@fileinfos) {
  my @elements1 = split(/\_\_/,$fileinfo);
  my @elements2 = split(/\_/,$elements1[1]);
  push(@projects,$elements2[1]);
 }
 return removeDoubleEntriesFromArray(@projects);
}

### updated to new version
# the index file starts with the md5 hashsum (of the datablock) of the original volume file
# structureDBIdent;<filename>;<md5sum>
sub isValidStructureDBIdent {
 my $ident = shift;
 return 0 unless ( defined($ident) );
 return 1 if ( $ident =~ /^\d+$/ );
 return 0;
}
sub addStructureValuesToMPMDataTable {
 my ($datatables_ptr,$indexdata_ptr,$strucDBIdent,$verbose,$debug) = @_;
 ### >>>
  my %datatables = %{$datatables_ptr};
  my %datatable = %{$datatables{"data"}};
  my %indexdata = %{$indexdata_ptr};
  my $nvalues = 0;
  while ( my ($key,$value)=each(%indexdata) ) {
   push(@{$datatable{$key}},($strucDBIdent,$value));
   $nvalues += 1;
  }
  %{$datatables{"data"}} = %datatable;
  if ( $verbose ) {
   print " + added $nvalues index values of structure $strucDBIdent to datatable '".$datatables{"name"}."'.\n";
  }
 ###
 return %datatables;
}
sub addStructureValuesFromIndexFileToMPMDataTable {
 my ($datatables_ptr,$indexfile,$strucDBIdent,$verbose,$debug) = @_;
 die "FATAL ERROR: Invalid database structure ident 'strucDBIdent'." if ( !isValidStructureDBIdent($strucDBIdent) );
 my %datatables = %{$datatables_ptr};
 if ( $verbose ) {
  print "addStructureValuesFromIndexFileToMPMDataTable(): Adding structure values with ident $strucDBIdent from indexfile '".$indexfile."' to '".$datatables{"name"}."'...\n";
 }
 ### >>>
  ### computing md5 checksum of the indexfile
  my $md5 = Digest::MD5->new;
  open(CHECK,$indexfile) or die "FATAL ERROR: Cannot open '".$indexfile."': $!";
   binmode(CHECK);
   $md5->addfile(*CHECK);
  close(CHECK);
  my $md5sum = $md5->hexdigest;
  print "addStructureValuesFromIndexFileToMPMDataTable(): md5sum($indexfile)=$md5sum.\n" if ( $verbose );
  ### loading indexfile
  open(FPin,"<$indexfile") || die "FATAL ERROR: Cannot open index file '".$indexfile."' for reading: $!";
   ### update file info data
   my @nfileinfos = ();
   my @fileinfos = @{$datatables{"files"}};
   foreach my $fileinfo (@fileinfos) {
    my @elements = split(/\;/,$fileinfo);
    if ( $elements[0]==$strucDBIdent ) {
     die "FATAL ERROR: Cannot update existing structure of '".$fileinfo."'. Drop them first.";
    } else {
     push(@nfileinfos,$fileinfo);
    }
   }
   my $bindexfile = basename($indexfile);
   $bindexfile =~ s/\.gz$// if ( $bindexfile =~ m/\.gz$/ );
   $bindexfile =~ s{\.[^.]+$}{};
   push(@nfileinfos,"$strucDBIdent;$bindexfile;$md5sum");
   @{$datatables{"files"}} = @nfileinfos;
   ### update mpm data (expecting float numbers in the range of (0.0<x<=1.0)
   my %datatable = %{$datatables{"data"}};
   my $nvalues = 0;
   ### loading header
   my $datatype = "DEFAULT";
   my $headerline = <FPin>;
   if ( $headerline =~ m/IRF/ && $headerline =~ m/UBYTE/ ) {
    print " + parsing UBYTE index file...\n" if ( $verbose );
    $datatype = "UBYTE";
    while ( <FPin> ) {
     chomp($_);
     my @values = split(/\ /,$_);
     if ( @values==2 && $values[1]>0 ) {
      push(@{$datatable{$values[0]}},($strucDBIdent,$values[1]/255.0));
      $nvalues += 1;
     }
    }
   } else {
    print " + parsing FLOAT index file...\n" if ( $verbose );
    seek(FPin,0,0);
    while ( <FPin> ) {
     chomp($_);
     my @values = split(/\ /,$_);
     if ( @values==2 && $values[1]>0.0 ) {
      if (  $debug && $nvalues<10 ) {
       print "mpmtool.addStructureValuesFromIndexFileToMPMDataTable().DEBUG: [$nvalues] ==>>> $values[0] >>> $values[1]\n";
      }
      push(@{$datatable{$values[0]}},($strucDBIdent,$values[1]));
      $nvalues += 1;
     }
    }
   }
   %{$datatables{"data"}} = %datatable;
  close(FPin);
  print " + added $nvalues $datatype index values of structure $strucDBIdent to datatable '".$datatables{"name"}."'.\n" if ( $verbose );
 ### >>>
 return %datatables;
}

### updated to new version
sub getMPMDataTableInfo {
 my ($datatables_ptr,$verbose,$debug) = @_;
 my %datatables = %{$datatables_ptr};
 ### >>>
  print "mpmtool.getMPMDataTableInfo(): Analyzing datatable '".$datatables{"name"}."'...\n";
  ### analyzing fileinfo lines
  my @fileinfos = @{$datatables{"files"}};
  print " + number of file lines: ".scalar(@fileinfos)."\n";
  foreach my $fileinfo (@fileinfos) {
   print "  + fileline: '".$fileinfo."'\n";
  }
  ### analyzing data lines
  my %datatable = %{$datatables{"data"}};
  my $nlines = 0;
  my $min = 100000000;
  my $max = 0;
  while ( my ($key,$value)=each(%datatable) ) {
   $min = $key if ( $key<$min );
   $max = $key if ( $key>$max );
   $nlines += 1;
  }
  print " + number of datalines: $nlines, range=$min:$max.\n";
 ### >>>
}

### get list of structure idents
sub getStructureIdentsFromMPMDataTable {
 my ($datatables_ptr,$verbose,$debug) = @_;
 my %datatables = %{$datatables_ptr};
 my %indices = ();
 my %datatable = %{$datatables{"data"}};
 while ( my ($key,$value)=each(%datatable) ) {
  my @datavalues = @{$value};
  #print "key=$key, datavalues=@datavalues\n";
  for ( my $i=0 ; $i<scalar(@datavalues) ; $i+=2 ) {
   $indices{$datavalues[$i]} = 1;
  }
 }
 return keys(%indices)
}

### updated to new version
sub getIndexValuesFromMPMDataTable {
 my ($datatables_ptr,$strucDBIdent,$verbose,$debug) = @_;
 unless ( isValidStructureDBIdent($strucDBIdent) ) {
  die "mpmtool.getIndexValuesFromMPMDataTable(): FATAL ERROR: Invalid structure database ident '$strucDBIdent'.";
 }
 print "mpmtool.getIndexValuesFromMPMDataTable(): Get index values of structure $strucDBIdent from datatable...\n" if ( $verbose );
 my %datatables = %{$datatables_ptr};
 ### >>>
  my %datatable = %{$datatables{"data"}};
  my %indexvalues = ();
  while ( my ($key,$value)=each(%datatable) ) {
   my @datavalues = @{$value};
   for ( my $i=0 ; $i<scalar(@datavalues) ; $i+=2 ) {
    if ( $datavalues[$i]==$strucDBIdent ) {
     $indexvalues{$key} = $datavalues[$i+1];
     last;
    }
   }
  }
 ### >>>
 return %indexvalues;
}

### >>>
sub getMaximumStructureIdentsFromMPMDataTable {
 my ($datatables_ptr,$threshold,$verbose,$debug) = @_;
 print "getMaximumStructureIdentsFromMPMDataTable(): threshold=$threshold\n" if ( $verbose );
 my %datatables = %{$datatables_ptr};
 my %datatable = %{$datatables{"data"}};
 my %indexvalues = ();
 while ( my ($key,$value)=each(%datatable) ) {
  my @datavalues = @{$value};
  if ( scalar(@datavalues)>2 ) {
   my $maxvalue = 0.0;
   my $maxindex = -1;
   my $i = 0;
   for ( my $ii=1 ; $ii<scalar(@datavalues) ; $ii+=2 ) {
    if ( $datavalues[$ii]>$threshold && $datavalues[$ii]>$maxvalue ) {
     $maxvalue = $datavalues[$ii];
     $maxindex = $datavalues[$i];
    }
    $i += 2;
   }
   if ( $maxindex!=-1 ) {
    $indexvalues{$key} = $maxindex;
   }
  } else {
   if ( $datavalues[1]>=$threshold ) {
    $indexvalues{$key} = $datavalues[0];
   }
  }
 }
 return %indexvalues;
}

### >>>
sub getProjectMPMFromMPMDataTable {
 my ($datatables_ptr,$structureIdents_ptr,$threshold,$verbose,$debug) = @_;
 my %datatables = %{$datatables_ptr};
 my %datatable = %{$datatables{"data"}};
 my @structures = @{$structureIdents_ptr};
 my %indexvalues = ();
 while ( my ($key,$value)=each(%datatable) ) {
  my @datavalues = @{$value};
  for ( my $i=0 ; $i<scalar(@datavalues) ; $i+=2 ) {
   if ( isInArray($datavalues[$i],\@structures) ) {
    # check whether the maximum value is in structures
    my $max = 0.0;
    my $maxId = -1;
    for ( my $ii=0 ; $ii<scalar(@datavalues) ; $ii+=2 ) {
     if ( $datavalues[$ii+1]>$max ) {
      $max = $datavalues[$ii+1];
      $maxId = $datavalues[$ii];
     }
    }
    if ( $maxId>0 && isInArray($maxId,\@structures) && $max>=$threshold ) {
     $indexvalues{$key} = $maxId;
    }
   }
  }
 }
 return %indexvalues;
}

### updated to new version
### returns normalized pValues of structure with database ident $strucDBIdent
# must be a number ((un)signed integer, float) or a string
sub getNormalizedIndexValuesFromMPMDataTable {
 my ($datatables_ptr,$strucDBIdent,$maxvalue,$verbose,$debug) = @_;
 unless ( isValidStructureDBIdent($strucDBIdent) ) {
  die "mpmtool.getNormalizedIndexValuesFromMPMDataTable(): FATAL ERROR: Invalid structure database ident '$strucDBIdent'.";
 }
 my %datatables = %{$datatables_ptr};
 ### >>>
  my %datatable = %{$datatables{"data"}};
  my %indexvalues = ();
  if ( $strucDBIdent =~ /^[+-]?\d+$/ ) {
   print " + got normalized index values of structure with ident $strucDBIdent from datatable...\n" if ( $verbose );
   while ( my ($key,$value)=each(%datatable) ) {
    my @datavalues = @{$value};
    for ( my $i=0 ; $i<scalar(@datavalues) ; $i+=2 ) {
     if ( $datavalues[$i]==$strucDBIdent ) {
      print "mpmtool.getNormalizedIndexValuesFromMPMDataTable().DEBUG: Processing $datavalues[$i]...\n" if ( $debug );
      my $sum = 0.0;
      for ( my $ii=1 ; $ii<scalar(@datavalues) ; $ii+=2 ) {
       $sum += $datavalues[$ii];
      }
      if ( $sum>$maxvalue ) {
       $indexvalues{$key} = $maxvalue*$datavalues[$i+1]/$sum;
      } else {
       $indexvalues{$key} = $datavalues[$i+1];
      }
      print "mpmtool.getNormalizedIndexValuesFromMPMDataTable().DEBUG: sum=$sum, value=$indexvalues{$key}\n" if ( $debug );
      last;
     }
    }
   }
  } else {
   print "get normalized index values of structure $strucDBIdent from datatable...\n" if ( $verbose );
   while ( my ($key,$value)=each(%datatable) ) {
    my @datavalues = @{$value};
    for ( my $i=0 ; $i<scalar(@datavalues) ; $i+=2 ) {
     if ( $datavalues[$i] =~ m/^$strucDBIdent$/ ) {
      # print ">>> processing $datavalues[$i]...\n";
      my $sum = 0.0;
      for ( my $ii=1 ; $ii<scalar(@datavalues) ; $ii+=2 ) {
       $sum += $datavalues[$ii];
      }
      if ( $sum>$maxvalue ) {
       $indexvalues{$key} = $maxvalue*$datavalues[$i+1]/$sum;
      } else {
       $indexvalues{$key} = $datavalues[$i+1];
      }
      last;
     }
    }
   }
  }
 ### >>>
 return %indexvalues;
}

sub getINormalizedIndexValuesFromMPMDataTable {
 my ($datatables_ptr,$strucDBIdent,$ignoreareas_ptr,$maxvalue,$verbose,$debug) = @_;
 unless ( isValidStructureDBIdent($strucDBIdent) ) {
  die "mpmtool.getINormalizedIndexValuesFromMPMDataTable(): FATAL ERROR: Invalid structure database ident '$strucDBIdent'.";
 }
 my %datatables = %{$datatables_ptr};
 my @ignoreareas = @{$ignoreareas_ptr};
 ### >>>
  print "mpmtool.getINormalizedIndexValuesFromMPMDataTable(): maxValue=$maxvalue, ignoreareas=(".join(",",@ignoreareas).")\n" if ( $verbose );
  my %datatable = %{$datatables{"data"}};
  my %indexvalues = ();
  if ( $strucDBIdent =~ /^[+-]?\d+$/ ) {
   print " + got normalized index values of structure with ident $strucDBIdent from datatable...\n" if ( $verbose );
   while ( my ($key,$value)=each(%datatable) ) {
    my @datavalues = @{$value};
    for ( my $i=0 ; $i<scalar(@datavalues) ; $i+=2 ) {
     if ( $datavalues[$i]==$strucDBIdent ) {
      print "mpmtool.getINormalizedIndexValuesFromMPMDataTable().DEBUG: pos=$key, strucDBIdent=$datavalues[$i]: " if ( $debug );
      my $sum = 0.0;
      my $nsum = 0;
      my $nasum = 0;
      for ( my $ii=1 ; $ii<scalar(@datavalues) ; $ii+=2 ) {
       $nasum += 1;
       if ( !isInArray($datavalues[$ii-1],\@ignoreareas) ) {
        $sum += $datavalues[$ii];
        $nsum += 1;
       }
      }
      if ( $sum>$maxvalue ) {
       $indexvalues{$key} = $maxvalue*$datavalues[$i+1]/$sum;
      } else {
       $indexvalues{$key} = $datavalues[$i+1];
      }
      print "sum[$nsum|$nasum]=$sum, value=$indexvalues{$key}\n" if ( $debug );
      last;
     }
    }
   }
  } else {
   print " + get normalized index values of structure $strucDBIdent from datatable...\n" if ( $verbose );
   while ( my ($key,$value)=each(%datatable) ) {
    my @datavalues = @{$value};
    for ( my $i=0 ; $i<scalar(@datavalues) ; $i+=2 ) {
     if ( $datavalues[$i] =~ m/^$strucDBIdent$/ ) {
      # print ">>> processing $datavalues[$i]...\n";
      my $sum = 0.0;
      for ( my $ii=1 ; $ii<scalar(@datavalues) ; $ii+=2 ) {
       if ( !isInArray($datavalues[$ii-1],\@ignoreareas) ) {
        $sum += $datavalues[$ii];
       }
      }
      if ( $sum>$maxvalue ) {
       $indexvalues{$key} = $maxvalue*$datavalues[$i+1]/$sum;
      } else {
       $indexvalues{$key} = $datavalues[$i+1];
      }
      last;
     }
    }
   }
  }
 ### >>>
 return %indexvalues;
}

### updated to new version
sub getListOfStructuresInMPMDataTable {
 my ($datatables_ptr,$verbose,$debug) = @_;
 print "mpmtool.getListOfStructuresInMPMDataTable(): Get list of structures in datatable...\n" if ( $verbose );
 my %datatables = %{$datatables_ptr};
 ### >>>
  my %datatable = %{$datatables{"data"}};
  my @structures = ();
  while ( my ($key,$value)=each(%datatable) ) {
   my @datavalues = @{$value};
   for ( my $i=0 ; $i<scalar(@datavalues) ; $i+=2 ) {
    push(@structures,$datavalues[$i]);
   }
  }
 ### >>>
 return removeDoubleEntriesFromArray(@structures);
}

### updated to new version
sub getMaximumOverlapExceeds {
 my ($datatables_ptr,$maxvalue,$verbose,$debug) = @_;
 my %datatables = %{$datatables_ptr};
 ### >>>
  my %datatable = %{$datatables{"data"}};
  my @structures = ();
  while ( my ($key,$value)=each(%datatable) ) {
   my @datavalues = @{$value};
   my $summe = 0;
   for ( my $i=1 ; $i<scalar(@datavalues) ; $i+=2 ) {
    $summe += $datavalues[$i];
   }
   if ( $summe>$maxvalue ) {
    for ( my $i=0; $i<scalar(@datavalues) ; $i+=2 ) {
     push(@structures,$datavalues[$i]);
    }
   }
  }
 ### >>>
 return removeDoubleEntriesFromArray(@structures);
}

sub _debug { warn "@_\n" if $DEBUG; }

### return value
1;
