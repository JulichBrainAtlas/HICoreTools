# Copyright 2020 Forschungszentrum Jülich
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/opt/local/bin/perl

### >>>
use strict;
use Getopt::Long;
use File::Basename;
use POSIX;

### local local modules
use lib $ENV{HITHOME}."/src/perl";
use hitperl;
use hitperl::atlas;
use hitperl::jubdmesh;
use hitperl::giftimesh;
use hitperl::colormap;
use hitperl::meshtools;
use hitperl::offmesh;
use hitperl::database;
use hitperl::repos;

### >>>
my $DATABASEPATH = $ENV{DATABASEPATH};
my $logfilepath = $ENV{HITHOME}."/logs";

### >>>
sub getLabelNameFromDatabase {
 my ($dbh,$ident) = @_;
 return fetchFromAtlasDatabase($dbh,"SELECT name FROM atlas.structures WHERE id='$ident'");
}
sub getSideFromFilename {
 my ($name,$verbose,$debug) = @_;
 return 'l' if ( $name =~ m/_l_/i || $name =~ m/_left_/i );
 return 'r';
}

### >>>
my $help = 0;
my $verbose = 0;
my $printversion = 0;
my $printinfo = 0;
my $debug = 0;
my $overwrite = 0;
my $history = 0;
my $tostdout = 0;
my $histogram = 0;
my $colormap = 0;
my $names = 0;
my $ispmap = 0;
my $actionstr = "keeponly";
my $ATLASPATH = undef;
my $maskfilename = undef;
my $infilenamestring = undef;
my $inoutfilename = undef;
my $convfilename = undef;
my $colorfilename = undef;
my $namesfilename = undef;
my $likefilename = undef;
my $setstring = undef;
my $name = undef;
my $hint = undef;
my $hostname = "localhost";
my $accessfile = "login.dat";
my @hints = ("perindex","pervertex","pvalue","ascii","binary","jubrain","freesurfer","meshpainter");
my @argvlist = ();

sub printusage {
 print "usage: ".basename($0)." [--help|?][(-v|--verbose)][(-d|--debug)][--overwrite][--history][(-o|--output) <filename>][--hint <type>][--info]\n";
 print "\t[(-m|--mask) <filename>][(-c|--conversion) <filename>][(-a|--action) <keyword=$actionstr>][(-l|--like) <filename>][--stdout][--names]\n";
 print "\t[--ispmap][--histogram][--name <name>][--set <names:<filename|database>|colors:<filename>|add|colors>] (-i|--input) <filename(s)>\n";
 print "parameters:\n";
 print " version.................... ".getScriptRepositoryVersion($0,$debug)."\n";
 print " time string................ ".getTimeString(1)."\n";
 print " hint type values........... (".join(",",@hints).")\n";
 print " last call.................. '".getLastProgramLogMessage($0,$logfilepath)."'\n";
 exit(1);
}
if ( @ARGV>0 ) {
 foreach my $argnum (0..$#ARGV) {
  push(@argvlist,$ARGV[$argnum]);
 }
 GetOptions(
  'help|?+' => \$help,
  'verbose|v+' => \$verbose,
  'debug|d+' => \$debug,
  'overwrite+' => \$overwrite,
  'version+' => \$printversion,
  'history+' => \$history,
  'hint=s' => \$hint,
  'stdout+' => \$tostdout,
  'ispmap+' => \$ispmap,
  'names+' => \$names,
  'histogram+' => \$histogram,
  'info+' => \$printinfo,
  'colormap+' => \$colormap,
  'action|a=s' => \$actionstr,
  'conversion|c=s' => \$convfilename,
  'color=s' => \$colorfilename,
  'set=s' => \$setstring,
  'name=s' => \$name,
  'mask|m=s' => \$maskfilename,
  'like|l=s' => \$likefilename,
  'output|o=s' => \$inoutfilename,
  'input|i=s' => \$infilenamestring) ||
 printusage();
}
printProgramLog($0,1,$logfilepath) if $history;
if ( $printversion ) { print getScriptRepositoryVersion($0,$debug)."\n"; exit(1); }
printusage() if $help;
printusage() unless ( defined($infilenamestring) );

### check input parameters
if ( defined($hint) ) {
 $hint = "jubrain" if ( $hint =~ m/^meshpainter$/i );
 printfatalerror "FATAL ERROR: Invalid hint keyword '".$hint."'. Use one of (@hints)." unless ( isInArray($hint,\@hints) );
}
### connect to database
my $accessfilename = $DATABASEPATH."/scripts/data/".$accessfile;
my @accessdata = getAtlasDatabaseAccessData($accessfilename);
printfatalerror "FATAL ERROR: Malfunction in 'getAtlasDatabaseAccessData($accessfilename)'." if ( @accessdata!=2 );
my $dbh = connectToDatabase($hostname,$accessdata[0],$accessdata[1],"jubrain");
printfatalerror("FATAL ERROR: Cannot connect to jubrain database.") unless ( defined($dbh) );
### >>>
my @infilenames = split(/\,/,$infilenamestring);
printfatalerror "FATAL ERROR: Output filename is invalid if number of input files is larger than 1!" if ( scalar(@infilenames)>1 && defined($inoutfilename) );

### create program log entry after basic testing
createProgramLog($0,\@argvlist,$debug,$logfilepath);

### >>>
my %likeFileProperties = ();

### >>>
my %setoptions = ();
if ( defined($setstring) ) {
 my @names = split(/:/,$setstring);
 if ( scalar(@names)==1 ) {
  if ( $names[0] =~ m/^colors$/i ) {
   if ( defined($likefilename) ) {
    $setoptions{"likecolors"} = $likefilename;
    $likefilename = undef;
   } else {
    printfatalerror "FATAL ERROR: Need valid file defintion. Use option '--like'.";
   }
  } elsif ( $names[0] =~ m/^add$/i ) {
   if ( defined($likefilename) ) {
    $setoptions{"likeadd"} = $likefilename;
    $likefilename = undef;
   } else {
    printfatalerror "FATAL ERROR: Need valid file defintion. Use option '--like'.";
   }
  } else {
   printfatalerror "FATAL ERROR: Invalid option '".$names[0]."'.";
  }
 } elsif ( scalar(@names)>1 ) {
  if ( $names[0] =~ m/^colors$/i ) {
   $colorfilename = $names[1];
  } elsif ( $names[0] =~ m/^colorlist$/ ) {
   $setoptions{"colorlist"} = $names[1];
  } elsif ( $names[0] =~ m/^names$/i ) {
   $namesfilename = $names[1];
  } else {
   printfatalerror "FATAL ERROR: Yet unsupported value '".$setstring."' for option set.";
  }
 } else {
  printfatalerror "FATAL ERROR: Yet unsupported value '".$setstring."' for option set.";
 }
}

### color file or like file
my %structureColorIds = ();
my %structureIdColors = ();
if ( defined($colorfilename) ) {
 if ( defined($hint) && $hint =~ m/pvalue/ ) {
  my @rgbcolormap = loadLutColormap($colorfilename,$verbose,$debug);
  my $maxindex = scalar(@rgbcolormap)/3-1;
  my $ii = 0;
  for ( my $i=0 ; $i<$maxindex ; $i++,$ii+=3 ) {
   my $red   = $rgbcolormap[$ii];
   my $green = $rgbcolormap[$ii+1];
   my $blue  = $rgbcolormap[$ii+2];
   my $hashvalue = $red+256*$green+65536*$blue;
   $structureColorIds{$hashvalue} = $i;
   @{$structureIdColors{$i}} = ($red,$green,$blue);
  }
 } else {
  open(FPin,"<$colorfilename") || printfatalerror "FATAL ERROR: Cannot open color file '".$colorfilename."' for reading: $!";
   while ( <FPin> ) {
    next if ( $_ =~ m/^#/ );
    chomp($_);
    my @elements = split(/\ /,$_);
    if ( scalar(@elements)==4 ) {
     my $hashvalue = $elements[1]+256*$elements[2]+65536*$elements[3];
     $structureColorIds{$hashvalue} = $elements[0];
     @{$structureIdColors{$elements[0]}} = ($elements[1],$elements[2],$elements[3]);
    }
   }
  close(FPin);
 }
} elsif ( defined($likefilename) ) {
 if ( $likefilename =~ m/^colin/i ) {
  $likeFileProperties{'l'} = { 'nvertices' => 171259, 'nfaces' => 342514 };
  $likeFileProperties{'r'} = { 'nvertices' => 170783, 'nfaces' => 341562 };
 } elsif ( $likefilename =~ m/^icbm/i ) {
  printfatalerror "FATAL ERROR: Values not yet set appropriately for ICBM152casym dataset.";
  $likeFileProperties{'l'} = { 'nvertices' => 0, 'nfaces' => 0 };
  $likeFileProperties{'r'} = { 'nvertices' => 0, 'nfaces' => 0 };
 } else {
  ### expecting a coff file with color index info in the header line
  ### accepted format is: '#  labelId=74 color=(0,255,0)'
  print "Loading like file '".$likefilename."'...\n" if ( $verbose );
  open(FPin,"<$likefilename") || printfatalerror "FATAL ERROR: Cannot open like file '".$likefilename."' for reading: $!";
   while ( <FPin> ) {
    if ( $_ =~ m/^#/ ) {
     if ( $_ =~ m/labelId/ && $_ =~ m/color/ ) {
      chomp($_);
      $_ =~ s/\ +/\ /g;
      my @elements = split(/ /,$_);
      my $labelindex = int(substr($elements[1],8));
      my @colors = split(/,/,substr($elements[2],7,-1));
      my $hashvalue = $colors[0]+256*$colors[1]+65536*$colors[2];
      $structureColorIds{$hashvalue} = $labelindex;
      @{$structureIdColors{$labelindex}} = ($colors[0],$colors[1],$colors[2]);
      ### print " >>> id=$labelindex - color=(@colors) => $hashvalue\n";
     }
    } else {
     last;
    }
   }
  }
 close(FPin);
}
if ( $verbose && scalar(keys(%structureColorIds))>0 ) {
 print "Color index data:\n";
 while ( my ($key,$id) = each(%structureColorIds) ) {
  print " colorhash=$key => $id\n";
 }
}

### replace colors
my %replacecolors = ();
if ( defined($convfilename) ) {
 open(FPin,"<$convfilename") || printfatalerror "FATAL ERROR: Cannot open '".$convfilename."' for reading: $!";
  while ( <FPin> ) {
   next if ( $_ =~ m/^#/ );
   my $dataline = $_;
   chomp($dataline);
   my @elements = split(/\ /,$dataline);
   my $nelements = scalar(@elements);
   if ( $nelements>=3 ) {
    my $colindex = $elements[0]+256*$elements[1]+65536*$elements[2];
    if ( $nelements<6 ) {
     @{$replacecolors{$colindex}} = ($elements[0],$elements[1],$elements[2]);
    } else {
     @{$replacecolors{$colindex}} = ($elements[3],$elements[4],$elements[5]);
    }
   }
  }
 close(FPin);
}
if ( $verbose && scalar(keys(%replacecolors))>0 ) {
 print "Color conversion data:\n";
 while ( my ($key,$value) = each(%replacecolors) ) {
  my @colors = @{$value};
  print " $key => (@colors)\n";
 }
}

### processing
foreach my $infilename (@infilenames) {
 if ( $infilename =~ m/\.asc$/ && (defined($hint) && $hint eq "freesurfer") ) {
  print "processing FreeSurfer ascii scalar label file '".$infilename."'...\n" if ( $verbose );
  my @labelvalues = ();
  my $minValue = 100000000.0;
  my $maxValue = -$minValue;
  open(FPin,"<$infilename") || printfatalerror "FATAL ERROR: Cannot open FreeSurfer ascii file '".$infilename."' for reading: $!";
   while ( <FPin> ) {
    chomp($_);
    my @values = split(/ /,$_);
    my $lvalue = $values[4];
    $minValue = $lvalue if ( $lvalue<$minValue );
    $maxValue = $lvalue if ( $lvalue>$maxValue );
    push(@labelvalues,$lvalue);
   }
  close(FPin);
  print " + got ".scalar(@labelvalues)." label values: [".$minValue.":".$maxValue."].\n" if ( $verbose );
  my $outhint = "JUBDfdf";
  my %labeldata = ();
  $labeldata{"nlabels"} = scalar(@labelvalues);
  @{$labeldata{"labels"}} = @labelvalues;
  if ( !saveJuBrainLabels2($inoutfilename,\%labeldata,$outhint,$verbose,$debug) ) {
   printfatalerror "FATAL ERROR: Malfunction in 'saveJuBrainLabels2()'."
  }
 } elsif ( $infilename =~ m/\.off$/ ) {
  print "processing off file '".$infilename."'...\n" if ( $verbose );
  open(FPin,"<$infilename") || printfatalerror "FATAL ERROR: Cannot open off file '".$infilename."' for reading: $!";
   while ( <FPin> ) {
    next if ( $_ =~ m/^#/ );
    chomp($_);
    my $magic = $_;
    if ( $magic =~ m/COFF/ || $magic =~ m/CNOFF/ ) {
     print " + parsing vertex colors of ".$magic." file...\n" if ( $verbose );
     my $headerline = <FPin>;
     chomp($headerline);
     my @elements = split(/\ /,$headerline);
     my $nvertices = $elements[0];
     print "  + loading ".$nvertices." vertex colors...\n" if ( $verbose );
     my $nontrivials = 0;
     my $notfounds = 0;
     my %vertexlabels = ();
     my $offset = 3;
     $offset += 3 if ( $magic =~ m/CNOFF/ );
     for ( my $i=0 ; $i<$nvertices ; $i++ ) {
      my $dataline = <FPin>;
      chomp($dataline);
      my @values = split(/ /,$dataline);
      my $red = $values[$offset];
      my $green = $values[$offset+1];
      my $blue = $values[$offset+2];
      if ( $red!=255 || $green!=255 || $blue!=255 ) {
       my $hashvalue = $red+256*$green+65536*$blue;
       if ( exists($structureColorIds{$hashvalue}) ) {
        $vertexlabels{$i} = $structureColorIds{$hashvalue};
       } else {
        $vertexlabels{$i} = 200;
        $notfounds += 1;
       }
       $nontrivials += 1;
      }
     }
     print "  + got ".$nontrivials." nontrivial vertex color values, number of errors: ".$notfounds.".\n" if ( $verbose );
     if ( defined($hint) && $hint =~ m/pvalue/ ) {
      ### saving JUBDidf vertex pvalue index file
      open(FPout,">$inoutfilename") || printfatalerror "FATAL ERROR: Cannot create JUBD label file '".$inoutfilename."': $!";
       binmode(FPout);
       print FPout "JUBDidf";
       my $nvalues = scalar(keys(%vertexlabels))-1;
       print FPout pack "l,l",$nvertices,$nvalues;
       while ( my ($index,$value) = each(%vertexlabels) ) {
        print FPout pack "l,f",$index,$value/255.0;
       }
      close(FPout);
      print "Saved JUBDidf index vertex color file '".$inoutfilename."'.\n" if ( $verbose );
     } else {
      ### saving JUBDilf vertex color index file
      open(FPout,">$inoutfilename") || printfatalerror "FATAL ERROR: Cannot create JUBD label file '".$inoutfilename."': $!";
       binmode(FPout);
       print FPout "JUBDilf";
       my $nLabelColors = scalar(keys(%structureIdColors));
       print "  + number of label colors: ".$nLabelColors."\n";
       print FPout pack "l,l",$nvertices,$nLabelColors;
       # save label colors
       my @validIndexValues = ();
       my $n = 0;
       foreach my $index (sort(keys %structureIdColors)) {
        push(@validIndexValues,$index);
        my @rgb = @{$structureIdColors{$index}};
        print FPout pack "l,f,f,f",$index,$rgb[0]/255.0,$rgb[1]/255.0,$rgb[2]/255.0;
        print "   + $n: index=$index, color=[@{$structureIdColors{$index}}](".($rgb[0]/255.0).":".($rgb[1]/255.0).":".($rgb[2]/255.0).")\n" if ( $debug );
        $n += 1;
       }
       print "  + saved ".scalar(@validIndexValues)." labels.\n";
       # save indices
       my $nvalues = scalar(keys(%vertexlabels))-1;
       print FPout pack "l",$nvalues;
       print " + number of vertex labels: ".$nvalues.", inHash=".scalar(keys(%vertexlabels))."\n" if ( $verbose );
       while ( my ($index,$value) = each(%vertexlabels) ) {
        if ( isInArray($value,\@validIndexValues) ) {
         print FPout pack "l,l",$index,$value;
        } else {
         print "WARNING: Cannot find index=".$index.", value=".$value."\n";
        }
       }
      close(FPout);
      print "Saved JUBDilf index vertex color file '".$inoutfilename."'.\n" if ( $verbose );
     }
     last;
    } else {
     printfatalerror "FATAL ERROR: Invalid off file. Need a valid COFF file. Got: $_.";
    }
   }
  close(FPin);
 } elsif ( $infilename =~ m/\.dat$/ && defined($hint) && $hint eq "ascii" ) {
  print "processing ascii file '".$infilename."'...\n" if ( $verbose );
  if ( $inoutfilename =~ m/.gii$/ ) {
   my %labeldata = ();
   @{$labeldata{"labeltable"}} = ();
   $labeldata{"nvertices"} = 0;
   my @vertexlabels = ();
   $labeldata{"name"} = $name if defined($name);
   open(FPin,"<$infilename") || printfatalerror "FATAL ERROR: Cannot open '".$infilename."' for reading: $!";
    my $nvertices = 0;
    while ( <FPin> ) {
     next if ( $_ =~ m/#/ );
     chomp($_);
     my @values = split(/ /,$_);
     if ( $values[0] eq "nvertices" ) {
      $labeldata{"nvertices"} = $values[1];
      for ( my $i=0 ; $i<$values[1] ; $i++ ) {
       push(@vertexlabels,0);
      }
     } elsif ( $values[0] eq "colors" ) {
      my $ncolors = $values[1];
      print " + parsing $ncolors colors...\n" if ( $verbose );
      for ( my $n=0 ; $n<$ncolors ; $n++ ) {
       my $dataline = <FPin>;
       chomp($dataline);
       my @colors = split(/ /,$dataline);
       print "  + [".$n."] index=$colors[0], rgb=(".$colors[1].":".$colors[2].":".$colors[3].")\n" if ( $verbose );
       push(@{$labeldata{"labeltable"}},$colors[0].":".$colors[1].":".$colors[2].":".$colors[3].":".getLabelNameFromDatabase($dbh,$colors[0]));
      }
     } elsif ( $values[0] eq "labels" ) {
      my $nlabels = $values[1];
      print " + parsing $nlabels labels...\n" if ( $verbose );
      for ( my $n=0 ; $n<$nlabels ; $n++ ) {
       my $dataline = <FPin>;
       chomp($dataline);
       my @values = split(/ /,$dataline);
       if ( $values[1]!=0 ) {
        print "  + label[$n][".$values[0]."]=".$values[1]."\n" if ( $debug );
        $vertexlabels[$values[0]] = $values[1];
       }
      }
     }
    }
   close(FPin);
   @{$labeldata{"vertexlabels"}} = @vertexlabels;
   saveGiftiLabelFile($inoutfilename,\%labeldata,$verbose,$debug);
   print "Saved gifti file '".$inoutfilename."'.\n" if ( $verbose );
  } else {
   open(FPout,">$inoutfilename") || printfatalerror "FATAL ERROR: Cannot create '".$inoutfilename."' for saving: $!";
    binmode(FPout);
    print FPout "JUBDilf";
    open(FPin,"<$infilename") || printfatalerror "FATAL ERROR: Cannot open '".$infilename."' for reading: $!";
     my $nvertices = 0;
     while ( <FPin> ) {
      next if ( $_ =~ m/#/ );
      chomp($_);
      my @values = split(/ /,$_);
      if ( $values[0] eq "nvertices" ) {
       $nvertices = $values[1];
      } elsif ( $values[0] eq "colors" ) {
       my $ncolors = $values[1];
       print " + parsing $ncolors colors...\n" if ( $verbose );
       print FPout pack "l,l",$nvertices,$ncolors;
       for ( my $n=0 ; $n<$ncolors ; $n++ ) {
        my $dataline = <FPin>;
        chomp($dataline);
        my @colors = split(/ /,$dataline);
        print "  + [".$n."] index=$colors[0], rgb=(".$colors[1].":".$colors[2].":".$colors[3].")\n" if ( $verbose );
        print FPout pack "l,f,f,f",$colors[0],$colors[1]/255.0,$colors[2]/255.0,$colors[3]/255.0;
       }
      } elsif ( $values[0] eq "labels" ) {
       my $nlabels = $values[1];
       print " + parsing $nlabels labels...\n" if ( $verbose );
       print FPout pack "l",$nlabels;
       for ( my $n=0 ; $n<$nlabels ; $n++ ) {
        my $dataline = <FPin>;
        chomp($dataline);
        my @values = split(/ /,$dataline);
        if ( $values[1]!=0 ) {
         print "  + label[$n][".$values[0]."]=".$values[1]."\n" if ( $verbose );
         print FPout pack "l,l",$values[0],$values[1];
        }
       }
      }
     }
    close(FPin);
   close(FPout);
  }
 } elsif ( $infilename =~ m/\.vcol$/ ) {
  print "processing vertex color file '".$infilename."'...\n" if ( $verbose );
  my %meshlabels = loadRGBVertexLabels($infilename,$verbose);
  my %labelcolors = %{$meshlabels{"colors"}};
  if ( $actionstr =~ m/^keeponly$/i ) {
   print " + keeping only conversion colors.\n" if ( $verbose );
   my $nreplacedcolors = 0;
   while ( my ($key,$colorptr) = each(%labelcolors) ) {
    my @colors = @{$colorptr};
    my $index = $colors[0]+256*$colors[1]+65536*$colors[2];
    # print "key=$key, index[$colors[0]:$colors[1]:$colors[2]]=$index\n";
    if ( !exists($replacecolors{$index}) ) {
     @{$labelcolors{$key}} = (255,255,255);
     $nreplacedcolors += 1;
    }
   }
   print "  + replaced ".$nreplacedcolors." colors.\n" if ( $verbose );
  } elsif ( $actionstr =~ m/^remove$/i ) {
   while ( my ($key,$colorptr) = each(%labelcolors) ) {
    my @colors = @{$colorptr};
    my $index = $colors[0]+256*$colors[1]+65536*$colors[2];
    if ( exists($replacecolors{$index}) ) {
     @{$labelcolors{$key}} = (255,255,255);
    }
   }
  } elsif ( $actionstr =~ m/^keepreplace$/i ) {
   while ( my ($key,$colorptr) = each(%labelcolors) ) {
    my @colors = @{$colorptr};
    my $index = $colors[0]+256*$colors[1]+65536*$colors[2];
    if ( exists($replacecolors{$index}) ) {
     @{$labelcolors{$key}} = @{$replacecolors{$index}};
    } else {
     @{$labelcolors{$key}} = (255,255,255);
    }
   }
  } elsif ( $actionstr =~ m/^mask$/i ) {
   printfatalerror "FATAL ERROR: No mask file available!" unless ( defined($maskfilename) );
   my %mesh = loadOffFile($maskfilename,$verbose,$debug);
   my $nmaskvertices = $mesh{"nvertices"};
   printfatalerror "FATAL ERROR: Number of vertices mismatch: $nmaskvertices!=".$meshlabels{"nvertices"}."" if ( $nmaskvertices!=$meshlabels{"nvertices"} );
   my @maskcolors = @{$mesh{"colors"}};
   my $nn = 0;
   for ( my $n=0 ; $n<$nmaskvertices ; $n++ ) {
    if ( exists($labelcolors{$n}) ) {
     if ( $maskcolors[$nn]==255 && $maskcolors[$nn]==$maskcolors[$nn+1] && $maskcolors[$nn+1]==$maskcolors[$nn+2] ) {
      @{$labelcolors{$n}} = (255,255,255);
     }
    }
    $nn += 3;
   }
  } else {
   printfatalerror "FATAL ERROR: Invalid action '".$actionstr."'. Use either 'keeponly', 'keepreplace' or 'remove'.";
  }
  %{$meshlabels{"colors"}} = %labelcolors;
  saveRGBVertexLabelsAs(\%meshlabels,$inoutfilename,0,$verbose);
 } else {
  print "processing '".$infilename."' by loading JulichBrain labels...\n";
  my %labelobject = loadJuBrainLabels($infilename,$verbose,$debug);
  my %labelnames = %{$labelobject{"labelnames"}};
  my $nlabels = $labelobject{"nlabels"};
  printfatalerror "FATAL ERROR: Invalid number of labels in '".$infilename."'." if ( $nlabels==0 );
  if ( $colormap ) {
   print " + colormap...\n";
   my %labelcolors = %{$labelobject{"labelcolors"}};
   while ( my ($index,$value) = each(%labelcolors) ) {
    my @colors = @{$value};
    my $red = floor(255.0*$colors[0]);
    my $green = floor(255.0*$colors[1]);
    my $blue = floor(255.0*$colors[2]);
    print $labelnames{$index}."[".$index."] ".$red." ".$green." ".$blue."\n";
   }
  } elsif ( $names ) {
   print " + label names...\n";
   while ( my ($index,$name) = each(%labelnames) ) {
    print "  $index: $name\n";
   }
  } elsif ( $histogram ) {
   print " + computing histogram...\n";
   my $nvertices = $labelobject{"nvertices"};
   if ( $nvertices!=0 ) {
    my %labels =%{$labelobject{"labels"}};
    my %histogram = ();
    my $nLabelsTotal = 0;
    my $nDiffLabels = 0;
    my $gapMapCounts = 0;
    if ( defined($likefilename) ) {
     my $refBrainLC = lc($likefilename);
     $ATLASPATH = getAtlasDataDrive()."/Projects/Atlas" unless ( defined($ATLASPATH) );
     $ATLASPATH = $ENV{ATLASPATH} unless ( -d $ATLASPATH );
     my $refBrainFileName = $ATLASPATH."/data/brains/human/reference/".$refBrainLC;
     $refBrainFileName = "./data" if ( -d "./data/surf/freesurfer" );
     my $sidec = (basename($infilename) =~ m/_l_/)?"rh":"lh";
     $refBrainFileName .= "/surf/freesurfer/".$sidec."_pial_affine.off";
     print "  + loading reference surf file '".$refBrainFileName."'...\n";
     printfatalerror "FATAL ERROR: Cannot find reference file '".$refBrainFileName."': $!" unless ( -e $refBrainFileName );
     my %refMeshData = loadMeshFile($refBrainFileName,$verbose,$debug);
     printfatalerror "FATAL ERROR: Mismatch between number of vertices ".$refMeshData{"nvertices"}." and number of labels ".$nvertices."." if ( $refMeshData{"nvertices"}!=$nvertices );
     print "  + computing per vertex dual areas...\n";
     my @refMeshDualVertexAreas = getVertexDualAreaValues(\%refMeshData,$verbose);
     my $surfMeshArea = getMeshSurface(\%refMeshData,$verbose);
     my %dualareas = ();
     my $totalDualArea = 0.0;
     while ( my ($index,$value) = each(%labels) ) {
      $histogram{$value} = 0 unless ( exists($histogram{$value}) );
      $histogram{$value} += 1;
      $dualareas{$value} = 0.0 unless ( exists($dualareas{$value}) );
      my $dualarea = $refMeshDualVertexAreas[$index];
      $dualareas{$value} += $dualarea;
      $totalDualArea += $dualarea;
     }
     print "  + cummulative surface coverage values...\n";
     for my $key ( sort {$a<=>$b} keys %histogram ) {
      my $provalue = 100.0*($histogram{$key}/$nvertices);
      my $area = $dualareas{$key};
      my $parea = sprintf("%.3f",100.0*($area/$totalDualArea));
      print "   + ".$labelnames{$key}."[".$key."]: ".$histogram{$key}." / ".sprintf("%.3f",$area)."sqmm - ".sprintf("%.3f",$provalue)."% / ".$parea."%\n";
      $gapMapCounts += $provalue if ( $key>=500 && $key<600 );
      $nLabelsTotal += $histogram{$key};
      $nDiffLabels += 1;
     }
     my $coverage = 100.0*$nLabelsTotal/$nvertices;
     print " + got ".$nDiffLabels." different labels in ".$nLabelsTotal." vertex labels of ".$nvertices." vertices, coverage=".sprintf("%.3f",$coverage)."%, gapmaps=".sprintf("%.3f",$gapMapCounts)."%\n";
     print " + total area of reference surface: dual=".sprintf("%.3f",$totalDualArea)."sqmm, surf=".sprintf("%.3f",$surfMeshArea)."sqmm\n";
    } else {
     while ( my ($index,$value) = each(%labels) ) {
      $histogram{$value} = 0 unless ( exists($histogram{$value}) );
      $histogram{$value} += 1;
     }
     for my $key ( sort {$a<=>$b} keys %histogram ) {
      my $provalue = 100.0*($histogram{$key}/$nvertices);
      print "  + ".$labelnames{$key}."[".$key."]: ".$histogram{$key}." - ".sprintf("%.3f",$provalue)."%\n";
      $gapMapCounts += $provalue if ( $key>=500 && $key<600 );
      $nLabelsTotal += $histogram{$key};
      $nDiffLabels += 1;
     }
     my $coverage = 100.0*$nLabelsTotal/$nvertices;
     print " + got ".$nDiffLabels." different labels in ".$nLabelsTotal." vertex labels of ".$nvertices." vertices, coverage=".sprintf("%.3f",$coverage)."%, gapmaps=".sprintf("%.3f",$gapMapCounts)."%\n";
    }
   } else {
    print " - ERROR: Cannot compute histogram. Invalid number of vertices.\n";
   }
  } elsif ( $tostdout ) {
   print " to stdout...\n";
   print "  + number of vertices=".$labelobject{"nvertices"}."\n";
   my %labelcolors = %{$labelobject{"labelcolors"}};
   print "  + found ".scalar(keys(%labelcolors))." label colors:\n";
   ## while ( my ($index,$value) = each(%labelcolors) ) {
   foreach my $index (sort keys(%labelcolors)) {
    my @colors = @{$labelcolors{$index}};
    my $red = floor(255.0*$colors[0]);
    my $green = floor(255.0*$colors[1]);
    my $blue = floor(255.0*$colors[2]);
    print "   + color[".$index."]=(".$red.":".$green.":".$blue.")\n";
   }
   my %labelnames = %{$labelobject{"labelnames"}};
   print "  + found ".scalar(keys(%labelnames))." names:\n";
   ## while ( my ($index,$value) = each(%labelnames) ) {
   my $n = 0;
   foreach my $index ( sort { $a <=> $b } keys %labelnames ) {
    my $colorstring = "";
    if ( exists($labelcolors{$index}) ) {
     my @colors = @{$labelcolors{$index}};
     my $red = floor(255.0*$colors[0]);
     my $green = floor(255.0*$colors[1]);
     my $blue = floor(255.0*$colors[2]);
     $colorstring = $red.":".$green.":".$blue;
    }
    print "   + $n + name[".$index."]=".$labelnames{$index}." - color=(".$colorstring.")\n";
    $n += 1;
   }
   print "  + number of labels=". $labelobject{"nlabels"}."\n";
  } else {
   ### processing set data operations
   if ( defined($namesfilename) ) {
    if ( $labelobject{"nlabels"}>0 ) {
     print "+ set names of ".$labelobject{"nlabels"}." labels from source '".$namesfilename."'...\n" if ( $verbose );
     my %histogram = ();
     while ( my ($index,$value) = each(%{$labelobject{"labels"}}) ) {
      $histogram{$value} = 0 unless ( exists($histogram{$value}) );
      $histogram{$value} += 1;
     }
     my %labelnames = ();
     %labelnames = %{$labelobject{"labelnames"}} if ( exists($labelobject{"labelnames"}) );
     if ( $namesfilename =~ m/^database$/i ) {
      while ( my ($index,$value) = each(%histogram) ) {
       my $labelname = getLabelNameFromDatabase($dbh,$index);
       $labelnames{$index} = $labelname;
       print " index=$index, name=".$labelname."\n" if ( $verbose );
      }
     } else {
      printfatalerror "FATAL ERROR: Labelnames source '".$namesfilename."' not yet supported.";
      open(FPin,"<$namesfilename") || printfatalerror "FATAL ERROR: Cannot open file '".$namesfilename."': $!";
       while ( <FPin> ) {
        next if ( $_ =~ m/^#/ );
        chomp($_);
        my @values = split(/ /,$_);
        $labelnames{$values[0]} = $values[1];
       }
      close(FPin);
     }
     %{$labelobject{"labelnames"}} = %labelnames;
    } else {
     printfatalerror "FATAL ERROR: No labels. Cannot set names.";
    }
   }
   if ( defined($colorfilename) ) {
    my %nlabelcolors = ();
    %nlabelcolors = %{$labelobject{"labelcolors"}} if ( exists($labelobject{"labelcolors"}) );
    while ( my ($index,$colors) = each(%structureIdColors) ) {
     @{$nlabelcolors{$index}} = @{$colors};
    }
    %{$labelobject{"labelcolors"}} = %nlabelcolors;
   }
   if ( exists($setoptions{"colorlist"}) ) {
    print "  + set color labels based on '".$setoptions{"colorlist"}."'...\n" if ( $verbose );
    my %nlabelcolors = ();
    %nlabelcolors = %{$labelobject{"labelcolors"}} if ( exists($labelobject{"labelcolors"}) );
    my @values = split(/,/,$setoptions{"colorlist"});
    my $nvalues = scalar(@values);
    for ( my $i=0 ; $i<$nvalues ; $i+=4 ) {
     my $red   = $values[$i+1]/255.0;
     my $green = $values[$i+2]/255.0;
     my $blue  = $values[$i+3]/255.0;
     $nlabelcolors{$values[$i]} = [$red,$green,$blue];
     print "   + label[".$values[$i]."]=(".$red.":".$green.":".$blue.")\n" if ( $verbose );
    }
    %{$labelobject{"labelcolors"}} = %nlabelcolors;
    # my %llabelcolors = %{$labelobject{"labelcolors"}};
    # foreach my $index (sort keys(%llabelcolors)) {
    #  my @col = @{$llabelcolors{$index}};
    #  print "index=$index, colors=(".$col[0].":".$col[1].":".$col[2].")\n";
    # }
   }
   if ( exists($setoptions{"likeadd"}) ) {
    print "  + add datas from label file '".$setoptions{"likeadd"}."'...\n" if ( $verbose );
    my %likeobject = loadJuBrainLabels($setoptions{"likeadd"},$verbose,$debug);
    my $nSrc1Vertices = $labelobject{"nvertices"};
    my $nSrc2Vertices = $likeobject{"nvertices"};
    my $nSrc1Labels = $labelobject{"nlabels"};
    my $nSrc2Labels = $likeobject{"nlabels"};
    my $nDstVertices = $nSrc1Vertices+$nSrc2Vertices;
    my $nDstLabels = $nSrc1Labels+$nSrc2Labels;
    print "   + nvertices: ".$nSrc1Vertices."+".$nSrc2Vertices."=".$nDstVertices.", nlabels: ".$nSrc1Labels."+".$nSrc2Labels."=".$nDstLabels."\n" if ( $verbose );
    my %dstLabels = %{$labelobject{"labels"}};
    my %srcLabels = %{$likeobject{"labels"}};
    while ( my ($index,$label) = each(%srcLabels) ) {
     my $nindex = $index+$nSrc1Vertices;
     $dstLabels{$nindex} = $label;
    }
    %{$labelobject{"labels"}} = %dstLabels;
    $labelobject{"nlabels"} += $likeobject{"nlabels"};
    $labelobject{"nvertices"} = $nDstVertices;
   }
   if ( exists($setoptions{"likecolors"}) ) {
    print "  + set color labels based on like file '".$setoptions{"likecolors"}."'...\n" if ( $verbose );
    my %likeobject = loadJuBrainLabels($setoptions{"likecolors"},$verbose,$debug);
    my %likecolors = %{$likeobject{"labelcolors"}};
    print "   + found ".scalar(keys(%likecolors))." label colors\n" if ( $verbose );
    my %nlabelcolors = ();
    %nlabelcolors = %{$labelobject{"labelcolors"}} if ( exists($labelobject{"labelcolors"}) );
    while ( my ($index,$value) = each(%likecolors) ) {
     my @colors = @{$value};
     $nlabelcolors{$index} = [$colors[0],$colors[1],$colors[2]];
    }
    %{$labelobject{"labelcolors"}} = %nlabelcolors;
   }
   ### >>>
   my $outfilename = "";
   if ( !defined($inoutfilename) ) {
    $outfilename = $infilename;
    $outfilename .= ".dat";
   } else {
    $outfilename = $inoutfilename;
   }
   ### >>>
   print "Saving data '".$outfilename."'...\n" if ( $verbose );
   if ( $outfilename =~ m/\.dat$/ ) {
    if ( defined($hint) && $hint eq "jubrain" ) {
     print " + saving JuBrain dat file (compatible to JuBrain.meshpainter)...\n" if ( $verbose );
     open(FPout,">$outfilename") || printfatalerror "FATAL ERROR: Cannot create dat file '".$outfilename."': $!";
      print FPout "# created by ".basename($0)." at ".getTimeString(1)."\n";
      print FPout "nvertices ".$labelobject{"nvertices"}."\n";
      ## save label names
      my %labelNames = %{$labelobject{"labelnames"}};
      if ( scalar(keys(%labelNames))>0 ) {
       print FPout "# >>>\n";
       print FPout "names ".scalar(keys(%labelNames))."\n";
       while ( my ($labelId,$labelName) = each(%labelNames) ) {
        print FPout $labelId." ".$labelName."\n";
       }
      } else {
       printwarning "WARNING: No name labels available. Filling up with database values...";
       my %labelcolors = %{$labelobject{"labelcolors"}};
       print FPout "# >>>\n";
       print FPout "names ".scalar(keys(%labelcolors))."\n";
       my $i = 0;
       for my $key ( sort {$a<=>$b} keys %labelcolors ) {
        print FPout $key." ".getLabelNameFromDatabase($dbh,$key)."\n";
        $i += 1;
       }
      }
      ## save label colors
      my %labelcolors = %{$labelobject{"labelcolors"}};
      print FPout "# >>>\n";
      print FPout "colors ".scalar(keys(%labelcolors))."\n";
      for my $key ( sort {$a<=>$b} keys %labelcolors ) {
       my @rgbColor = @{$labelcolors{$key}};
       my $red = floor(255.0*$rgbColor[0]);
       my $green = floor(255.0*$rgbColor[1]);
       my $blue = floor(255.0*$rgbColor[2]);
       print FPout $key." ".$red." ".$green." ".$blue."\n";
      }
      ## save vertex label idents
      print FPout "# >>>\n";
      my %labeldatas = %{$labelobject{"labels"}};
      print FPout "labels ".scalar(keys(%labeldatas))."\n";
      while ( my ($index,$value) = each(%labeldatas) ) {
       print FPout $index." ".$value."\n";
      }
     close(FPout);
    } else {
     my %labeldatas = %{$labelobject{"labels"}};
     my $ncounts = keys %labeldatas;
     open(FPout,">$outfilename") || printfatalerror "FATAL ERROR: Cannot create dat file '".$outfilename."': $!";
     print FPout "# created by ".basename($0)." at ".getTimeString(1)."\n";
     print FPout "# inputfile='".$infilename."'\n";
     my %labelcolors = %{$labelobject{"labelcolors"}};
     my %labelnames = exists($labelobject{"labelnames"})?%{$labelobject{"labelnames"}}:();
     for my $key ( sort {$a<=>$b} keys %labelcolors ) {
      my @rgbColor = @{$labelcolors{$key}};
      my $labelname = exists($labelnames{$key})?$labelnames{$key}:getLabelNameFromDatabase($dbh,$key);
      print "color[id=$key, name=".$labelname."] = (@rgbColor)\n";
      my $red = floor(255.0*$rgbColor[0]);
      $red = 255 if ( $red>255 );
      my $green = floor(255.0*$rgbColor[1]);
      $green = 255 if ( $green>255 );
      my $blue = floor(255.0*$rgbColor[2]);
      $blue = 255 if ( $blue>255 );
      print FPout "# $key ".$labelname." ".$red." ".$green." ".$blue."\n";
     }
     print FPout $ncounts."\n";
     if ( defined($hint) && $hint eq "pervertex" ) {
      for ( my $n=0 ; $n<$ncounts ; $n++ ) {
       if ( exists($labeldatas{$n}) ) {
        print FPout $labeldatas{$n}."\n";
       } else {
        print FPout "0.0\n";
       }
      }
     } else {
      while ( my ($index,$value) = each(%labeldatas) ) {
       print FPout $index." ".$value."\n";
      }
     }
     close(FPout);
    }
   } elsif ( $outfilename =~ m/\.vcol$/ ) {
    ### >>>
    my %labeldatas = %{$labelobject{"labels"}};
    my $ncounts = keys %labeldatas;
    open(FPout,">$outfilename") || printfatalerror "FATAL ERROR: Cannot create dat file '".$outfilename."': $!";
    print FPout "# created by ".basename($0)." at ".getTimeString(1)."\n";
    print FPout "# inputfile='".$infilename."'\n";
    my %rgbcolors = ();
    my %labelcolors = %{$labelobject{"labelcolors"}};
    my $nReplacedColors = 0;
    for my $key ( sort {$a<=>$b} keys %labelcolors ) {
     print "   + ident=$key...\n" if ( $debug );
     if ( exists $replacecolors{$key} ) {
      @{$rgbcolors{$key}} = @{$replacecolors{$key}};
      $nReplacedColors += 1;
     } else {
      my @labelcolors = @{$labelcolors{$key}};
      my $red = ceil(255.0*$labelcolors[0]);
      $red = 255 if ( $red>255 );
      my $green = ceil(255.0*$labelcolors[1]);
      $green = 255 if ( $green>255 );
      my $blue = ceil(255.0*$labelcolors[2]);
      $blue = 255 if ( $blue>255 );
      @{$rgbcolors{$key}} = ($red,$green,$blue);
     }
    }
    print FPout "$ncounts\n";
    while ( my ($index,$value) = each(%labeldatas) ) {
     if ( exists $rgbcolors{$value} ) {
      my @rgb = @{$rgbcolors{$value}};
      print FPout $index." $rgb[0] $rgb[1] $rgb[2]\n";
     } else {
      print "WARNING: Unknown label index $value\n";
      print FPout $index." 255 0 0\n";
     }
    }
    close(FPout);
    print " + replaced ".$nReplacedColors." color(s).\n" if ( $verbose );
   } else {
    if ( defined($hint) && $hint eq "binary" ) {
     print "Saving binary JuBrain ".($ispmap?"pmap":"label")." file '".$inoutfilename."'...\n" if ( $verbose );
     if ( defined($likefilename) ) {
      my $side = getSideFromFilename($inoutfilename,$verbose,$debug);
      $labelobject{'nvertices'} = $likeFileProperties{$side}{'nvertices'};
     }
     if ( $ispmap ) {
      saveJuBrainPMapData(\%labelobject,$inoutfilename,$verbose,$debug);
     } else {
      saveJuBrainLabelData(\%labelobject,$inoutfilename,$verbose,$debug);
     }
    } else {
     printfatalerror "FATAL ERROR: Output format '".$outfilename."' not yet supported.";
    }
   }
   print "Created output file '".$outfilename."'.\n" if ( $verbose );
  }
 }
}

### >>>
$dbh->disconnect();
