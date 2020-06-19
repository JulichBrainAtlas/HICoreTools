## hitperl::ontology package
########################################################################################################

### >>>
package hitperl::ontology;

### >>>
use File::Path;
use File::Basename;
use Spreadsheet::Read;
use Exporter;
use hitperl;
use hitperl::xml;

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'getAreasFromOntologyFile', 'getProjectAreasFromOntologyFile', 'getProjectsFromOntology', 'getOntologyPath',
            'getOfficialAreaNamesFromOntologyFile', 'getToolboxDisplayNamesFromOntologyFile', 'getDateFromOntologyFilename',
            'printOntology', 'loadCSVFile', 'addPathToOntologyTree', 'printTreeNode', 'printJSONTreeNode', 'printOntologyFields',
            'getNamedFieldsFromOntologyFile', 'getOfficialHBPAreaNameFromOntologyFile', 'getDOIsFromOntologyFile',
            'getOfficialHBPAreaNamesFromOntologyFile' );
$VERSION = 0.3;

### private modules

sub _getCleanTableElement_ {
 my ($workbook,$position) = @_;
 my $element = $workbook->[1]{$position};
 $element =~ s/^\s+|\s+$//g;
 return $element;
}

### start public modules

### >>>
sub printJSONTreeNode {
 my ($node,$level,$depth,$maxdepth) = @_;
 my $ostr = " " x (2*$level);
 my $oostr = " " x (2*($level+1));
 if ( $node->{type} eq "leaf" ) {
  ### print "*** $level - $depth - $maxdepth\n";
  print $ostr." },{\n" if ( $level==$maxdepth+1 && $depth==1 );
  print $ostr."    \"name\": \"".$node->{name}."\",\n";
  print $ostr."    \"toolbox\": \"".$node->{toolbox}."\",\n";
  print $ostr."    \"brodmann\": \"".$node->{brodmann}."\",\n";
  print $ostr."    \"status\": \"".$node->{status}."\",\n";
  print $ostr."    \"owner\": \"".$node->{owner}."\",\n";
  print $ostr."    \"version\": \"".$node->{version}."\",\n";
  print $ostr."    \"size\": ".$node->{size}."\n";
  if ( $depth<$maxdepth-1 ) { ### && $level!=($maxdepth-1) ) {
   print $ostr." },{\n";
  }
 } else {
  if ( $level==0 ) {
   print $ostr."{\n";
  } else {
   print $ostr."},{\n" if ( $depth>0 );
  }
  print $ostr." \"name\": \"".$node->{name}."\",\n";
  print $ostr." \"children\": [{\n";
 }
 if ( defined($node->{children}) ) {
  ##print $ostr."{\n";
  my $idx = 0;
  my @childnodes = @{$node->{children}};
  my $nchildnodes = scalar(@childnodes);
  for my $child (@childnodes) {
   printJSONTreeNode($child,$level+1,$idx,$nchildnodes);
   $idx += 1;
  }
  print $oostr."}]\n";
 }
 print $ostr."}\n" if ( $level==0 );
}
sub printTreeNode {
 my ($node,$level) = @_;
 print "." x ($level*6)
        , $node->{name}, " " x 4
        , $node->{size},"\n";
 if ( defined($node->{children}) ) {
  for my $child (@{$node->{children} }) {
   printTreeNode($child,$level+1);
  }
 }
}
sub addPathToOntologyTree {
 my ($tree_ptr,$info_ptr,$pathstring,$verbose,$debug) = @_;
 my %tree = %{$tree_ptr};
 my %info = %{$info_ptr};
 ## printTreeNode(\%tree,1) if ( $debug );
 my $parent = undef;
 print " path=$pathstring\n" if ( $verbose );
 my @elements = split(/\//,$pathstring);
 $elements[-2] .= ", ".$elements[-1];
 my $nelements = scalar(@elements)-1;
 for ( my $level=0 ; $level<$nelements ; $level++ ) {
  my $element = $elements[$level];
  if ( $level<($nelements-1) ) {
   print "  adding branch '$element' at level $level to tree...\n" if ( $verbose );
   if ( $level==0 ) {
    if ( !defined($tree{name}) ) { ### || !($tree{name} eq $element) ) {
     print " creating master level: ".$element."\n";
     %tree = (
      name => $element,
      type => "branch",
      size => $level
     );
    }
    $parent = \%tree;
   } else {
    my $ni = 0;
    my $ndim = 0;
    my $hasElement = 0;
    if ( defined($parent->{children}) ) {
     my @tarray = @{$parent->{children}};
     $ndim = scalar(@tarray);
     for ( my $k=0 ; $k<$ndim ; $k++ ) {
      my %tanode = %{$tarray[$k]};
      if ( $tanode{name} eq $element ) {
       $hasElement = 1;
       $ni = $k;
       last;
      }
     }
     ##my %tanode = %{$tarray[$ni]};
     ##$hasElement = 1 if ( $tanode{name} eq $element );
     ##$ni = 1 if ( scalar(@tarray)==1 && $hasElement==0 );
     ##print "   + dim=".scalar(@tarray)." found branch level: ".$tanode{name}.", hasElement=".$hasElement."\n";
    }
    if ( !$hasElement ) {
     my %node = (
      name => $element,
      type => "branch",
      size => $level
     );
     $ni = $ndim;
     $$parent{children}[$ni] = \%node;
    }
    $parent = $$parent{children}[$ni];
   }
  } else {
   print "  adding leaf '$element' at level $level to tree...\n";
   my %node = (
     name => $element,
     status => $info{"Status"},
     toolbox => $info{"Toolbox display name"},
     brodmann => $info{"Brodmann area"},
     owner => $info{"Investigator"},
     version => "0.1",
     type => "leaf",
     size => $level
   );
   my $ni = scalar(@{$$parent{children}});
   ##print " >>> dim=".scalar(@{$$parent{children}}).", name[0]='".$$parent{children}[0]{name}."'.\n";
   $$parent{children}[$ni] = \%node;
   ##print "  >>> name[$ni]='$$parent{children}[$ni]{name}'.\n";
  }
 }
 printTreeNode(\%tree,1) if ( $debug );
 return %tree;
}

### simple CSV loader
# + support for windows and dos formatted csv files
# + can handle single newline separated datalines in csv file
sub loadCSVFile {
 my ($filename,$verbose,$debug) = @_;
 ### check for format
 my $nlines = 0;
 open(FPin,"<$filename") || die "FATAL ERROR: Cannot open csv file '".$filename."' for reading: $!";
  while ( <FPin> ) {
   $nlines += 1;
  }
 close(FPin);
 my @headerlines = ();
 my @datalines = ();
 if ( $nlines>1 ) {
  open(FPin,"<$filename");
   my $headerline1 = <FPin>;
   $headerline1 =~ s/\r|\n//g;
   push(@headerlines,$headerline1);
   my $headerline2 = <FPin>;
   $headerline2 =~ s/\r|\n//g;
   push(@headerlines,$headerline2);
   while ( <FPin> ) {
    $_ =~ s/\r\n$//g;
    push(@datalines,$_);
   }
  close(FPin);
 } else {
  open(FPin,"<$filename");
   my $datas = $_;
  close(FPin);
  my @tdatalines = split(/\012\015?|\015\012?/,$datas);
  for ( my $k=0 ; $k<scalar(@tdatalines) ; $k++ ) {
   my $dataline = $tdatalines[$k];
   if ( length($dataline)>0 ) {
    push(@datalines,$dataline);
   } else {
    # print " *** combining '$datalines[$k-1]' and '$tdatalines[$k+1]' ...\n";
    $datalines[-1] .= $tdatalines[$k+1];
    # print "   >>> got => '".$datalines[-1]."'\n";
    $k += 1;
   }
  }
 }
 if ( $debug ) {
  print "DEBUG::loadCSV(): Got ".scalar(@headerlines)." headerlines...\n";
  my $m = 0;
  foreach my $headerline (@headerlines) {
   print " + headerline[".$m."]='".$headerline."'\n";
   $m += 1;
  }
  print "DEBUG::loadCSV(): Got ".scalar(@datalines)." datalines...\n";
  my $n = 0;
  foreach my $dataline (@datalines) {
   print " + dataline[".$n."]='".$dataline."'\n";
   $n += 1;
  }
 }
 my %csvdata = ();
 @{$csvdata{"header"}} = @headerlines;
 @{$csvdata{"data"}} = @datalines;
 return %csvdata;
}

###
sub getNamedFieldsFromOntologyFile {
 my ($tablefilename,$verbose,$debug) = @_;
 my %ontologyinfos = ();
 if ( -e $tablefilename ) {
  print "ontology.getNamedFieldsFromOntologyFile(): Processing ontology file '".$tablefilename."'...\n" if ( $verbose );
  if ( $tablefilename =~ m/\.xlsx$/ ) {
   warn "ontology.getNamedFieldsFromOntologyFile(): Excel file format not supported anymore. Use csv format instead.\n";
  } elsif ( $tablefilename =~ m/\.csv$/ ) {
   ### loading and analyzing csv file
   my %csvdata = loadCSVFile($tablefilename,$verbose,$debug);
   my @datalines = @{$csvdata{"data"}};
   my $ndatalines = scalar(@datalines);
   my @headerlines = @{$csvdata{"header"}};
   my @fieldnames = split(/\;/,$headerlines[1],-1);
   my $nfieldnames = scalar(@fieldnames);
   print "DEBUG: fieldnames[".$nfieldnames."]=(".join(",",@fieldnames).")\n" if ( $debug );
   for ( my $n=0 ; $n<$ndatalines ; $n++ ) {
    my @elements = split(/\;/,$datalines[$n],-1);
    my $nelements = scalar(@elements);
    my %listelements = ();
    my $nNamePosition = 0;
    if ( 1==1 || $nelements==$nfieldnames ) {
     if ( $nelements!=$nfieldnames ) {
      print " - WARNING: Number of header (=".$nelements.") and field elements (=".$nfieldnames.") mismatch.\n";
     }
     for ( my $k=0 ; $k<$nfieldnames ; $k++ ) {
      if ( length($fieldnames[$k])>0 ) {
       my $elementname = $elements[$k];
       $elementname =~ s/^\s+|\s+$//g;
       if ( length($elementname)>0 ) {
        $listelements{$fieldnames[$k]} = $elementname;
        print "DEBUG: adding /".$fieldnames[$k]."/ = ".$elementname."\n" if ( $debug );
        $nNamePosition = $k if ( $fieldnames[$k] =~ m/Filename area for Toolbox/ )
       } else {
        $listelements{$fieldnames[$k]} = "unknown";
       }
      }
     }
    } else {
     die "FATAL ERROR: Number of header (=".$nelements.") and field elements (=".$nfieldnames.") mismatch.";
    }
    my $structurename = $elements[$nNamePosition]; ## -4
    my @selements = split(/\_/,$structurename);
    my $nstructurename = $selements[0]."_".$elements[9];
    $structurename =~ s/^\s+|\s+$//g;
    print "DEBUG: structurename[".$nstructurename."] = $structurename\n" if ( 1==1 || $debug );
    if ( length($nstructurename)>0 && $nstructurename =~ m/\_/ ) {
     print " structurename[".$nNamePosition."]=".$nstructurename." owner=".$listelements{"Investigator"}."\n" if ( 1==1 || $debug );
     %{$ontologyinfos{$nstructurename}} = %listelements;
    } else {
     ## print " - no add of structure $structurename: (".join(",",@elements).")\n";
    }
   }
  } else {
   print "ontology.getNamedFieldsFromOntologyFile(): Unsupported format for ontology file.\n";
  }
 } else {
  warn "ontology.getNamedFieldsFromOntologyFile(): Cannot find ontology file '".$tablefilename."'.\n";
 }
 return %ontologyinfos;
}
sub printOntologyFields {
 my ($ontology_ptr,$verbose,$debug) = @_;
 my %ontology = %{$ontology_ptr};
 while ( my ($key,$value) = each(%ontology) ) {
  my $fielddatastr = "";
  my %fielddatas = %{$value};
  while ( my ($name,$ivalue) = each(%fielddatas) ) {
   $fielddatastr .= $name."=[".$ivalue."], ";
  }
  chop($fielddatastr);
  chop($fielddatastr);
  print $key." => {".$fielddatastr."}\n";
 }
}

### get HBP name from anatomy toolbox name
sub getOfficialHBPAreaNameFromOntologyFile {
 my ($tablefilename,$name,$verbose) = @_;
 return $name;
}

### get relation between internal/official name to toolbox display name
sub getToolboxDisplayNamesFromOntologyFile {
 my ($tablefilename,$statusptr,$internal,$verbose) = @_;
 my @status = @{$statusptr};
 my %ontologies = ();
 if ( -e $tablefilename ) {
  print "ontology.getToolboxDisplayNamesFromOntologyFile(): Processing ontology file '".$tablefilename."', status=(@status)...\n" if ( $verbose );
  my $workbook = ReadData($tablefilename);
  my $nareas = $workbook->[1]{maxrow}-$workbook->[1]{minrow};
  print " + analyzing ".$nareas." table rows of sheet 1...\n" if ( $verbose );
  if ( $internal==1 ) {
   for ( my $n=2 ; $n<=$nareas ; $n++ ) {
    my $status = $workbook->[1]{"O".$n};
    if ( isInArray($status,$statusptr) ) {
     my $structurename = _getCleanTableElement_($workbook,"P".$n);
     $ontologies{$structurename} = _getCleanTableElement_($workbook,"R".$n);
    }
   }
  } else {
   for ( my $n=2 ; $n<=$nareas ; $n++ ) {
    my $status = $workbook->[1]{"O".$n};
    if ( isInArray($status,$statusptr) ) {
     my $structurename = _getCleanTableElement_($workbook,"Q".$n);
     $ontologies{$structurename} = _getCleanTableElement_($workbook,"R".$n);
    }
   }
  }
 } else {
  warn "ontology.getOntologyPath(): Cannot find ontology file '$tablefilename'.\n";
 }
 return %ontologies;
}

### table rows from 1(=header) to size
### last element of folder array does contain the status
sub getOntologyPath {
 my ($tablefilename,$statusptr,$verbose) = @_;
 my %ontologypaths = ();
 if ( -e $tablefilename ) {
  print "ontology.getOntologyPath(): Processing ontology file '".$tablefilename."', status=(".join(",",@{$statusptr}).")...\n" if ( $verbose );
  if ( $tablefilename =~ m/\.xlsx$/ ) {
   my $workbook = ReadData($tablefilename);
   my $nareas = $workbook->[1]{maxrow}-$workbook->[1]{minrow};
   print " + analyzing ".$nareas." table rows of sheet 1...\n" if ( $verbose );
   my @keys = ("A","B","C","D","F","G");
   for ( my $n=2 ; $n<=$nareas ; $n++ ) {
    my $status = $workbook->[1]{"O".$n};
    if ( isInArray($status,$statusptr) ) {
     my $structurename = $workbook->[1]{"Q".$n};
     $structurename =~ s/^\s+|\s+$//g;
     if ( length($structurename) ) {
      my @branches = ();
      foreach my $key (@keys) {
       my $element = $workbook->[1]{$key.$n};
       $element =~ s/^\s+|\s+$//g;
       if ( length($element) ) {
        if ( scalar(@branches)==0 || !($branches[-1] =~ m/^$element$/) ) {
         push(@branches,$element);
        }
       }
      }
      push(@branches,$status);
      @{$ontologypaths{$structurename}} = @branches;
     }
    }
   }
  } elsif ( $tablefilename =~ m/\.csv$/ ) {
   ### loading and analyzing csv file
   my %csvdata = loadCSVFile($tablefilename,$verbose,$debug);
   my @datalines = @{$csvdata{"data"}};
   my $nareas = scalar(@datalines);
   print " + analyzing ".$nareas." table rows...\n" if ( $verbose );
   for ( my $i=0 ; $i<scalar(@datalines) ; $i++ ) {
    my @elements = split(/;/,$datalines[$i],-1);
    my $status = $elements[15]; ### -5
    $status =~ s/^\s+|\s+$//g;
    ### print "status=$status\n";
    if ( isInArray($status,$statusptr) ) {
     my $structurename = $elements[17]; ## -3
     $structurename =~ s/^\s+|\s+$//g;
     if ( length($structurename)==0 ) {
      $structurename = $elements[-4];
      $structurename =~ s/^\s+|\s+$//g;
     }
     if ( length($structurename) ) {
      my @branches = ();
      for ( my $k=0 ; $k<=5 ; $k++ ) {
       my $element = $elements[$k];
       $element =~ s/^\s+|\s+$//g;
       if ( length($element) ) {
        if ( scalar(@branches)==0 || !($branches[-1] =~ m/^$element$/) ) {
         push(@branches,$element);
        }
       }
      }
      push(@branches,$status);
      ### >>>>
      my $hbpname = $elements[19];
      ### print "name=$hbpname\n";
      push(@branches,$hbpname);
      ### >>>
      my $esname = $structurename."//".$elements[16];
      $esname =~ s/\s+$//;
      @{$ontologypaths{$esname}} = @branches;
      ## print " > processing structure '$structurename': ".join("//",@branches)."\n";
     } else {
      print "WARNING: Missing official name of structure '".$structurename."'.\n";
     }
    }
   }
  } else {
   print "ontology.getOntologyPath(): Unsupported format for ontology file.\n";
  }
 } else {
  warn "ontology.getOntologyPath(): Cannot find ontology file '".$tablefilename."'.\n";
 }
 return %ontologypaths;
}

### get areas of status from ontology table file
### WARNING: It can not be guaranteed that the name of an area is always the name that is also internally used!!!
### Column positions:
###  > Status:        O
###  > Internal name: P
###  > External name: Q
sub getAreasFromOntologyFile {
 my ($tablefilename,$status,$verbose,$debug) = @_;
 my @areas = ();
 my @skippedareas = ();
 if ( -e $tablefilename ) {
  print "ontology.getAreasFromOntologyFile(): Processing ontology file '".$tablefilename."'...\n" if ( $verbose );
  if ( $tablefilename =~ m/\.xlsx$/ ) {
   my $workbook = ReadData($tablefilename);
   my $nareas = $workbook->[1]{maxrow}-$workbook->[1]{minrow}-1;
   print " + analyzing ".$nareas." table rows of sheet 1...\n" if ( $verbose );
   for ( my $n=1 ; $n<=$nareas ; $n++ ) {
    if ( $workbook->[1]{"O".$n} =~ m/$status/i ) {
     my $internalname = $workbook->[1]{"P".$n};
     $internalname =~ s/^\s+|\s+$//g;
     if ( length($internalname)==0 ) {
      push(@skippedareas,$workbook->[1]{"Q".$n});
      print "  + SERIOUS WARNING: Invalid internal name for area: ".$workbook->[1]{"P".$n}." in row $n. Skipping!\n";
      # push(@areas,"unknown_".$workbook->[1]{"G".$n});
     } else {
      push(@areas,$internalname);
     }
    }
   }
  } elsif ( $tablefilename =~ m/\.csv$/ ) { # offsets are critical: previous -5 and -4
   print " + parsing new (including DOI field) csv file, status=".$status."...\n";
   my %csvdata = loadCSVFile($tablefilename,$verbose,$debug);
   my @datalines = @{$csvdata{"data"}};
   my $nline = 0;
   foreach my $dataline (@datalines) {
    my @elements = split(/;/,$dataline,-1);
    print " > elements[".$nline."]=(".join(":",@elements).")\n" if ( $debug );
    my $statusname = $elements[15]; ### -7];
    $statusname =~ s/^\s+|\s+$//g;
    print " > status=$statusname\n" if ( $debug );
    if ( $statusname =~ m/$status/i ) {
     my $areaname = $elements[16]; ### -6];
     $areaname =~ s/^\s+|\s+$//g;
     push(@areas,$areaname) if ( length($areaname)>0 );
    }
    $nline += 1;
   }
  } else {
   print "ontology.getAreasFromOntologyFile(): Unsupported format for ontology file.\n";
  }
  if ( $verbose ) {
   print "Found ".scalar(@areas)." ".$status." areas: (".join(",",@areas).") and skipped ".scalar(@skippedareas);
   print " unspecified areas: (".join(",",@skippedareas).").\n";
  }
 } else {
  print "ontology.getAreasFromOntologyFile(): Cannot find ontology file '".$tablefilename."'.\n";
 }
 return @areas;
}

sub getProjectAreasFromOntologyFile {
 my ($tablefilename,$status,$verbose,$debug) = @_;
 my @areas = getAreasFromOntologyFile($tablefilename,$status,$verbose,$debug);
 my %projectareas = ();
 foreach my $area (@areas) {
  my @elements = split(/\_/,$area);
  if ( scalar(@elements)==2 ) {
   @{$projectareas{$elements[0]}} = () unless ( exists($projectareas{$elements[0]}) );
   push(@{$projectareas{$elements[0]}},$elements[1]) unless ( isInArray($elements[1],\@{$projectareas{$elements[0]}}) );
  }
 }
 return %projectareas;
}

sub getProjectsFromOntology {
 my $ontology_ptr = shift;
 my @projects = ();
 while ( my ($project,$value) = each(%{$ontology_ptr}) ) {
  push(@projects,$project);
 }
 return @projects;
}

sub getOfficialHBPAreaNamesFromOntologyFile {
 my ($tablefilename,$verbose) = @_;
 my %hbpnames = ();
 if ( -e $tablefilename ) {
  print "Processing ontology file '".$tablefilename."'...\n" if ( $verbose );
  if ( $tablefilename =~ m/\.csv$/ ) {
   my %csvdata = loadCSVFile($tablefilename,$verbose,$debug);
   my @datalines = @{$csvdata{"data"}};
   foreach my $dataline (@datalines) {
    my @elements = split(/;/,$dataline,-1);
    my $iname = $elements[16]; ### -6];
    $iname =~ s/^\s+|\s+$//g;
    my $oname = $elements[19]; ### -5];
    $oname =~ s/^\s+|\s+$//g;
    if ( length($iname)>0 && length($oname)>0 ) {
     print "DEBUG[ontology.getOfficialHBPAreaNamesFromOntologyFile]: iname='".$iname."' oname='".$oname."'\n" if ( $debug );
     $hbpnames{lc($iname)} = $oname;
    }
   }
  }
 } else {
  print "Error: Cannot find ontology file '".$tablefilename."'.\n";
 }
 return %hbpnames;
}

sub getOfficialAreaNamesFromOntologyFile {
 my ($tablefilename,$verbose,$debug) = @_;
 my %outnames = ();
 if ( -e $tablefilename ) {
  print "ontology.getOfficialAreaNamesFromOntologyFile(): Processing ontology file '".$tablefilename."'...\n" if ( $verbose );
  if ( $tablefilename =~ m/\.xlsx$/ ) {
   my $workbook = ReadData($tablefilename);
   my $nareas = $workbook->[1]{maxrow}-$workbook->[1]{minrow}-1;
   for ( my $n=1 ; $n<=$nareas ; $n++ ) {
    my $iname = $workbook->[1]{"P".$n};
    $iname =~ s/^\s+|\s+$//g;
    my $oname = $workbook->[1]{"Q".$n};
    $oname =~ s/^\s+|\s+$//g;
    if ( length($iname)>0 && length($oname)>0 ) {
     print "DEBUG[ontology.getOfficialAreaNamesFromOntologyFile]: iname='".$iname."' oname='".$oname."'\n" if ( $debug );
     $outnames{$iname} = $oname;
    }
   }
  } elsif ( $tablefilename =~ m/\.csv$/ ) {
   my %csvdata = loadCSVFile($tablefilename,$verbose,$debug);
   my @datalines = @{$csvdata{"data"}};
   foreach my $dataline (@datalines) {
    my @elements = split(/;/,$dataline,-1);
    my $iname = $elements[16]; ### -6];
    $iname =~ s/^\s+|\s+$//g;
    my $oname = $elements[17]; ### -5];
    $oname =~ s/^\s+|\s+$//g;
    if ( length($iname)>0 && length($oname)>0 ) {
     print "DEBUG[ontology.getOfficialAreaNamesFromOntologyFile]: iname='".$iname."' oname='".$oname."'\n" if ( $debug );
     $outnames{lc($iname)} = $oname;
    }
   }
  }
 } else {
  print "ontology.getOfficialAreaNamesFromOntologyFile(): Error: Cannot find ontology file '".$tablefilename."'.\n";
 }
 return %outnames;
}

sub getDOIsFromOntologyFile {
 my ($tablefilename,$verbose,$debug) = @_;
 my %outdois = ();
 if ( -e $tablefilename ) {
  print "ontology.getDOIsFromOntologyFile(): Processing ontology file '".$tablefilename."'...\n" if ( $verbose );
  if ( $tablefilename =~ m/\.csv$/ ) {
   my %csvdata = loadCSVFile($tablefilename,$verbose,$debug);
   my @datalines = @{$csvdata{"data"}};
   foreach my $dataline (@datalines) {
    my @elements = split(/;/,$dataline,-1);
    my $iname = $elements[16]; ### -6];
    $iname =~ s/^\s+|\s+$//g;
    my $doi = $elements[14]; ### -5];
    $doi =~ s/^\s+|\s+$//g;
    if ( length($iname)>0 && length($doi)>0 ) {
     print "DEBUG[ontology.getDOIsFromOntologyFile]: iname='".$iname."' doi='".$doi."'\n" if ( $debug );
     $outdois{lc($iname)} = $doi;
    }
   }
  }
 } else {
  print "Error: Cannot find ontology file '".$tablefilename."'.\n";
 }
 return %outdois;
}

sub getDateFromOntologyFilename {
 my $filename = basename(shift);
 $filename =~ s{\.[^.]+$}{};
 return (split(/_/,$filename))[2];
}

sub printOntology {
 my ($ontology_ptr,$name) = @_;
 print $name." ontology:\n";
 while ( my ($project,$value) = each(%{$ontology_ptr}) ) {
  my @areas = @{$value};
  print " project=$project: areas(n=".scalar(@areas).")=(".join(",",@areas).")\n";
 }
}

### end modules

sub _debug { warn "@_\n" if $DEBUG; }

### return value
1;
