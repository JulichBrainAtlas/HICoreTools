## hitperl::jubdmesh package
########################################################################################################

### >>>
package hitperl::jubdmesh;

### >>>
use hitperl;
use File::Path;
use Exporter;
use POSIX qw/floor/;

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'saveJuBrainMeshFile', 'saveJuBrainPolyFile', 'loadJuBrainLabels', 'saveJuBrainLabels',
               'loadJuBrainLabelColormap', 'saveJuBrainLabels2', 'saveJuBrainLabelData', 'saveJuBrainPMapData',
               'saveJuBrainLabelASCIIData', 'loadJuBrainMeshFile', 'printJuBrainLabelInfos' );
$VERSION = 0.1;

#### local variables
my $timestamp = sprintf "%06x",int(rand(100000));
my $tmp = "tmp".$timestamp;

#### start public modules

### loading JuBrain label colormap (Index Red Green Blue)
sub loadJuBrainLabelColormap {
 my ($filename,$verbose,$debug) = @_;
 my %labelcolors = ();
 open(FPin,"<$filename") || printfatalerror "FATAL ERROR: Cannot open colormap file '".$filename."' for reading: $!";
  print " + loading color file '".$filename."'...\n" if ( $verbose );
  while ( <FPin> ) {
   next if ( $_ =~ m/^#/ );
   chomp($_);
   my @elements = split(/\ /,$_);
   if ( scalar(@elements)>3 ) {
    if ( $elements[1]>=0 && $elements[2]>=0 && $elements[3]>=0 ) {
     @{$labelcolors{$elements[0]}} = ($elements[1],$elements[2],$elements[3]);
    }
   } else {
    warn "WARNING: Parsing failure for line '$_'.\n";
   }
  }
 close(FPin);
 print "  + found ".keys(%labelcolors)." color labels.\n" if ( $verbose );
 return %labelcolors;
}

### loading JuBrain mesh file
sub loadJuBrainMeshFile {
 my ($filename,$verbose,$debug) = @_;
 my %meshdata = ();
 print "loadJuBrainMeshFile(): Loading JulichBrain mesh file '".$filename."'...\n" if ( $verbose );
 open(FPin,"<$filename") || printfatalerror "FATAL ERROR: Cannot open JulichBrain triangle mesh file '".$filename."': $!";
  $meshdata{"filename"} = $filename;
  my $xmin = 1000000000;
  my $ymin = $zmin = $xmin;
  my $xmax = $ymax = $zmax = -$xmin;
  binmode(FPin);
  read(FPin,$magic,5,0);
  if ( $magic =~ m/^JUBbp$/ ) {
   print " + parsing binary JUBbp poly mesh file...\n" if ( $verbose );
   my $template = "l l l l";
   my $len = length pack($template,'',0,0);
   read(FPin,$buffer,$len);
   my ($nverts,$nnormals,$ntris,$nedges) = unpack($template,$buffer);
   $meshdata{"nvertices"} = $nverts;
   $meshdata{"nnormals"} = $nnormals;
   $meshdata{"nfaces"} = $ntris;
   $meshdata{"nedges"} = $nedges;
   print "  + nverts: $nverts, nnormals: $nnormals, ntris: $ntris, nedges: $nedges\n" if ( $verbose );
   ### loading vertices
   print "  + loading $nverts vertices...\n" if ( $verbose );
   $template = "f f f";
   $len = length pack($template,'',0,0);
   my @vertices = ();
   for ( my $v=0 ; $v<$nverts ; $v++ ) {
    read(FPin,$buffer,$len);
    my ($vx,$vy,$vz) = unpack($template,$buffer);
    print "   + v[$v]($vx:$vy:$vz)\n" if ( $v<5 && $verbose );
    $xmin = $vx if ( $vx<$xmin );
    $xmax = $vx if ( $vx>$xmax );
    $ymin = $vy if ( $vy<$ymin );
    $ymax = $vy if ( $vy>$ymax );
    $zmin = $vz if ( $vz<$zmin );
    $zmax = $vz if ( $vz>$zmax );
    push(@vertices,$vx);
    push(@vertices,$vy);
    push(@vertices,$vz);
   }
   @{$meshdata{"vertices"}} = @vertices;
   ### loading tris
   print "  + loading $ntris triangles...\n" if ( $verbose );
   $template = "l l l";
   $len = length pack($template,'',0,0);
   my @simplices = ();
   for ( my $v=0 ; $v<$ntris ; $v++ ) {
    read(FPin,$buffer,$len);
    my ($i0,$i1,$i2) = unpack($template,$buffer);
    print "   + tri[$v]($i0:$i1:$i2)\n" if ( $v<5 && $verbose );
    push(@simplices,$i0);
    push(@simplices,$i1);
    push(@simplices,$i2);
   }
   @{$meshdata{"simplices"}} = @simplices;
   ### loading edges
   print "  + loading $nedges edges...\n" if ( $verbose );
   $template = "l l";
   $len = length pack($template,'',0,0);
   for ( my $v=0 ; $v<$nedges ; $v++ ) {
    read(FPin,$buffer,$len);
    my ($e0,$e1) = unpack($template,$buffer);
    print "   + edge[$v]($e0:$e1)\n" if ( $v<5 && $verbose );
   }
  } elsif ( $magic =~ m/^JUBtm$/ ) {
   print " + parsing binary JUBtm poly mesh file...\n" if ( $verbose );
   my $template = "l l";
   my $len = length pack($template,'',0,0);
   read(FPin,$buffer,$len);
   my ($nverts,$ntris) = unpack($template,$buffer);
   print "  + nverts: $nverts, ntris: $ntris\n" if ( $verbose );
   $meshdata{"nvertices"} = $nverts;
   $meshdata{"nfaces"} = $ntris;
   ### loading vertices
   print "  + loading $nverts vertices...\n" if ( $verbose );
   $template = "f f f";
   $len = length pack($template,'',0,0);
   my @vertices = ();
   for ( my $v=0 ; $v<$nverts ; $v++ ) {
    read(FPin,$buffer,$len);
    my ($vx,$vy,$vz) = unpack($template,$buffer);
    print "   + v[$v]($vx:$vy:$vz)\n" if ( $v<5 && $verbose );
    $xmin = $vx if ( $vx<$xmin );
    $xmax = $vx if ( $vx>$xmax );
    $ymin = $vy if ( $vy<$ymin );
    $ymax = $vy if ( $vy>$ymax );
    $zmin = $vz if ( $vz<$zmin );
    $zmax = $vz if ( $vz>$zmax );
    push(@vertices,$vx);
    push(@vertices,$vy);
    push(@vertices,$vz);
   }
   @{$meshdata{"vertices"}} = @vertices;
   ### loading normals
   print "  + loading $nverts normals...\n" if ( $verbose );
   my @normals = ();
   for ( my $n=0 ; $n<$nverts ; $n++ ) {
    read(FPin,$buffer,$len);
    my ($nx,$ny,$nz) = unpack($template,$buffer);
    print "   + n[$n]($nx:$ny:$nz)\n" if ( $n<5 && $verbose );
    push(@normals,($nx,$ny,$nz));
   }
   $meshdata{"nnormals"} = scalar(@normals)/3;
   @{$meshdata{"normals"}} = @normals;
   ### loading triangles
   print "  + loading $ntris triangles...\n" if ( $verbose );
   $template = "l l l";
   $len = length pack($template,'',0,0);
   my @simplices = ();
   for ( my $v=0 ; $v<$ntris ; $v++ ) {
    read(FPin,$buffer,$len);
    my ($i0,$i1,$i2) = unpack($template,$buffer);
    print "   + tri[$v]($i0:$i1:$i2)\n" if ( $v<5 && $verbose );
    push(@simplices,$i0);
    push(@simplices,$i1);
    push(@simplices,$i2);
   }
   @{$meshdata{"simplices"}} = @simplices;
  } else {
   print "jubdmesh.loadJuBrainMeshFile(): Yet unsupported data type '".$magic."'.\n";
  }
 close(FPout);
 $meshdata{"magic"} = $magic;
 @{$meshdata{"range"}} = ($xmin,$xmax,$ymin,$ymax,$zmin,$zmax);
 print " + datarange: x[$xmin:$xmax], y[$ymin:$ymax], z[$zmin:$zmax]\n" if ( $verbose );
 return %meshdata;
}

### saving jubd mesh file (only triangle meshes are supported, version 2 supports normals and edges output)
sub __saveJuBrainPolyMeshFile {
 my ($filename,$meshdata_ptr,$version,$verbose) = @_;
 my %meshdata = %{$meshdata_ptr};
 open(FPout,">$filename") || printfatalerror "FATAL ERROR: Cannot create JulichBrain triangle mesh file '".$filename."': $!";
  print "Saving JulichBrain mesh file '".$filename."', version: $version ...\n" if ( $verbose );
  binmode(FPout);
  if ( $version==1 ) {
   print FPout "JUBtm";
   print FPout pack "ll",$meshdata{"nvertices"},$meshdata{"nfaces"};
  } else {
   print FPout "JUBbp";
   $nedges = 0;
   $nedges = $meshdata{"nedges"} if ( exists($meshdata{"nedges"}) );
   $nnormals = 0;
   $nnormals = $meshdata{"nvertices"} if ( exists($meshdata{"normals"}) );
   print FPout pack "llll",$meshdata{"nvertices"},$nnormals,$meshdata{"nfaces"},$nedges;
  }
  ### save vertices
  print " + saving ".$meshdata{"nvertices"}." vertices...\n" if ( $verbose );
  my @vertices = @{$meshdata{"vertices"}};
  my @scaling = @{$meshdata{"scaling"}};
  if ( @scaling ) {
   if ( scalar(@scaling)>=4 ) {
    if ( $scaling[0]!=1.0 || $scaling[1]!=0.0 || $scaling[2]!=0.0 || $scaling[3]!=0.0 ) {
     print "  + scaling vertex values by ($scaling[0],$scaling[1],$scaling[2],$scaling[3])...\n" if ( $verbose );
     my $allscale = $scaling[0];
     for ( my $v=0 ; $v<scalar(@vertices) ; $v+=3 ) {
      my $vx = $vertices[$v+0]/$allscale+$scaling[1];
      my $vy = $vertices[$v+1]/$allscale+$scaling[2];
      my $vz = $vertices[$v+2]/$allscale+$scaling[3];
      print FPout pack "fff",$vx,$vy,$vz;
     }
    } else {
     foreach my $vertex (@vertices) {
      print FPout pack "f",$vertex;
     }
    }
   } else {
    warn "WARNING: Invalid dimension for scale vector: dim(@scaling)=".scalar(@scaling).".\n";
    foreach my $vertex (@vertices) {
     print FPout pack "f",$vertex;
    }
   }
  } else {
   foreach my $vertex (@vertices) {
    print FPout pack "f",$vertex;
   }
  }
  ### save normals
  if ( exists($meshdata{"normals"}) ) {
   print " + saving ".$meshdata{"nvertices"}." normals...\n" if ( $verbose );
   my @normals = @{$meshdata{"normals"}};
   foreach my $normal (@normals) {
    print FPout pack "f",$normal;
   }
  }
  ### save tri indices
  print " + saving ".$meshdata{"nfaces"}." face indices...\n" if ( $verbose );
  my @indices = @{$meshdata{"simplices"}};
  foreach my $index (@indices) {
   print FPout pack "l",$index;
  }
  ### save edges indices
  if ( exists($meshdata{"nedges"}) && $meshdata{"nedges"}>0 && exists($meshdata{"edges"}) ) {
   print " + saving ".$meshdata{"nedges"}." edge indices...\n" if ( $verbose );
   my @edges = @{$meshdata{"edges"}};
   foreach my $index (@edges) {
    print FPout pack "l",$index;
   }
  }
 close(FPout);
 print " + saved JulichBrain mesh file.\n" if ( $verbose );
 return 1;
}

### public caller
sub saveJuBrainPolyFile {
 my ($filename,$meshdata_ptr,$version,$verbose) = @_;
 return __saveJuBrainPolyMeshFile($filename,$meshdata_ptr,2,$verbose);
}
sub saveJuBrainMeshFile {
 my ($filename,$meshdata_ptr,$verbose) = @_;
 return __saveJuBrainPolyMeshFile($filename,$meshdata_ptr,1,$verbose);
}

### print label info to stdout
sub printJuBrainLabelInfos {
 my ($data_ptr,$offset) = @_;
 my %labelinfos = %{$data_ptr};
 print ' ' x $offset if ( defined($offset) && $offset>0 );
 print "filename='".$labelinfos{"filename"}."', magic='".$labelinfos{"magic"}."'";
 print ", nvertices=".$labelinfos{"nvertices"}.", nlabels=".$labelinfos{"nlabels"}."\n";
}

### loading JuBrain labels
sub loadJuBrainLabels {
 my ($filename,$verbose,$debug) = @_;
 my $magic = "unknown";
 my $comments = "";
 my $nlabels = -1;
 my $nvalues = -1;
 my %labels = ();
 my %colors = ();
 my %labelcolors = ();
 my %labelnames = ();
 my %labeldefs = ();
 if ( $filename =~ m/\.dat$/ ) {
  print "loadJuBrainLabels(): Loading JulichBrain dat labelfile '".$filename."'...\n" if ( $verbose );
  $magic = "dat";
  open(FPin,"<$filename") || printfatalerror "FATAL ERROR: Cannot load label file '".$filename."': $!";
   while ( <FPin> ) {
    if ( $_ =~ m/#/ ) {
     $comments .= $_;
     chomp($_);
     $_ =~ s/^\s+//;
     my @values = split(/\ /,$_);
     if ( scalar(@values)==6 ) {
      @{$labeldefs{$values[1]}} = ($values[2],($values[3],$values[4],$values[5]));
     } else {
      print " - unprocessed data line '".$_."'.\n" if ( $verbose );
     }
    } else {
     chomp($_);
     $_ =~ s/^\s+//;
     my @values = split(/\ /,$_);
     if ( $values[0] eq "nvertices" ) {
      my $nVertices = $values[1];
      $nvalues = $nVertices;
     } elsif ( $values[0] eq "colors" ) {
      my $nColors = $values[1];
      print " + found data for ".$nColors." label colors...\n" if ( $verbose );
      for ( my $ii=0 ; $ii<$nColors ; $ii++ ) {
       my $colorline = <FPin>;
       chomp($colorline);
       my @values = split(/ /,$colorline);
       if ( scalar(@values)>=4 ) {
        ## @{$colors{$i}} = ($n,$red,$green,$blue);
        my $n = $values[0];
        my $red   = $values[1]/255.0;
        my $green = $values[2]/255.0;
        my $blue  = $values[3]/255.0;
        print "  + found for label $n color (".$red.":".$green.":".$blue.")\n" if ( $verbose );
        @{$colors{$ii}} = ($n,$red,$green,$blue);
        @{$labelcolors{$n}} = ($red,$green,$blue)
       }
      }
     } elsif ( $values[0] eq "names" ) {
      my $nLabelNames = $values[1];
      print " + found data for ".$nLabelNames." label names...\n" if ( $verbose );
      for ( my $ii=0 ; $ii<$nLabelNames ; $ii++ ) {
       my $dataline = <FPin>;
       chomp($dataline);
       my @values = split(/ /,$dataline);
       if ( scalar(@values)>=2 ) {
        my $n = $values[0];
        my $name = $values[1];
        for ( my $n=2 ; $n<scalar(@values) ; $n++ ) {
         $name .= " ".$values[$n];
        }
        print "  + found for label $n name '".$name."'.\n" if ( $verbose );
        $labelnames{$n} = $name;
       }
      }
     } elsif ( $values[0] eq "labels" ) {
      $nlabels = $values[1];
      print " + found data for ".$nlabels." labels...\n" if ( $verbose );
      my $nValidLabels = 0;
      for ( my $ii=0 ; $ii<$nlabels ; $ii++ ) {
       my $coordline = <FPin>;
       chomp($coordline);
       my @values = split(/ /,$coordline);
       if ( scalar(@values)==2 ) {
        $labels{$values[0]} = $values[1];
        $nValidLabels += 1;
       }
      }
      print "  + got ".$nValidLabels." valid labels.\n" if ( $verbose );
     } else {
      chomp($_);
      $nlabels = $_;
      if ( $verbose ) {
       print " + got ".scalar(keys(%labeldefs))." label definitions.\n";
       print " + loading ".$nlabels." labels...\n";
      }
      while ( <FPin> ) {
       chomp($_);
       my @values = split(/ /,$_);
       if ( scalar(@values)==2 ) {
        $labels{$values[0]} = $values[1];
       } else {
        printfatalerror "FATAL ERROR: Parsing failure for line '$_'.";
       }
      }
     }
    }
   }
  close(FPin);
 } else {
  print "loadJuBrainLabels(): Loading JUBD labelfile '".$filename."'...\n" if ( $verbose );
  my $buffer = "";
  open(FPin,"<$filename") || printfatalerror "FATAL ERROR: Cannot load label file '".$filename."': $!";
   binmode(FPin);
   read(FPin,$magic,7,0);
   if ( $magic eq "JUBDilf" ) { # this is for a mpm dataset
    print " + parsing JulichBrain JUBDilf datafile '".$filename."'...\n" if ( $verbose );
    my $template = "l l";
    my $len = length pack($template,'',0,0);
    read(FPin,$buffer,$len);
    my $ncolors = 0;
    ($nvalues,$ncolors) = unpack($template,$buffer);
    print "jubdmesh.loadJuBrainLabels().DEBUG: #vertices=$nvalues, #colors=$ncolors\n" if ( $debug );
    $template = "l f f f";
    $len = length pack($template,'',0,0,0,0);
    for ( my $i=0 ; $i<$ncolors ; $i++ ) {
     read(FPin,$buffer,$len);
     my ($n,$red,$green,$blue) = unpack($template,$buffer);
     print "jubdmesh.loadJuBrainLabels().DEBUG: color[$i][$n]=($red:$green:$blue)\n" if ( $debug );
     @{$colors{$i}} = ($n,$red,$green,$blue);
     @{$labelcolors{$n}} = ($red,$green,$blue) unless ( exists($labelcolors{$n}) );
    }
    ## vertex labels
    $template = "l";
    $len = length pack($template,'',0);
    read(FPin,$buffer,$len);
    my ($nindices) = unpack($template,$buffer); # $nindices = $nlabels
    print " + loading binary $magic file [#vertices=$nvalues, #indices=$nindices]...\n" if ( $verbose );
    $template = "l l";
    $len = length pack($template,'',0,0);
    my %llabels = ();
    for ( my $i=0 ; $i<$nindices ; $i++ ) {
     read(FPin,$buffer,$len);
     my ($index,$label) = unpack($template,$buffer);
     ## print "DEBUG >> ".$index." - ".$label."\n";
     $labels{$index} = $label;
     $llabels{$label} = 1;
    }
    $nlabels = scalar(keys(%llabels));
    ## additional label names
    $template = "l";
    $len = length pack($template,'',0);
    if ( read(FPin,$buffer,$len) ) {
     my ($nLabelNames) = unpack($template,$buffer);
     print "jubdmesh.loadJuBrainLabels().DEBUG: nLabelNames=$nLabelNames\n" if ( $debug );
     $template = "l l";
     $len = length pack($template,'',0,0);
     for ( my $i=0 ; $i<$nLabelNames ; $i++ ) {
      read(FPin,$buffer,$len);
      my ($index,$strlength) = unpack($template,$buffer);
      read(FPin,$buffer,$strlength);
      $labelnames{$index} = $buffer;
      print "jubdmesh.loadJuBrainLabels().DEBUG:  + index=$index, name[$strlength]=$buffer\n" if ( $debug );
     }
    }
   } elsif ( $magic eq "JUBDidf" ) {
    print " + parsing JUBDidf datafile '".$filename."'...\n" if ( $verbose );
    my $template = "l l";
    my $len = length pack($template,'',0,0);
    read(FPin,$buffer,$len);
    ($nvalues,$nlabels) = unpack($template,$buffer);
    print " jubdmesh.loadJuBrainLabels().DEBUG: nModelVertices=$nvalues, nLabels=$nlabels\n" if ( $debug );
    $template = "l f";
    $len = length pack($template,'',0,0);
    for ( my $i=0 ; $i<$nlabels ; $i++ ) {
     read(FPin,$buffer,$len);
     my ($n,$pValue) = unpack($template,$buffer);
     $labels{$n} = $pValue;
     print "jubdmesh.loadJuBrainLabels().DEBUG: index=$n, pValue=$pValue\n" if ( $debug );
    }
   } elsif ( $magic eq "JUBDfdf" ) {
    print " + parsing JulichBrain JUBDfdf datafile '".$filename."'...\n" if ( $verbose );
    my $template = "l";
    my $len = length pack($template,'',0);
    read(FPin,$buffer,$len);
    $nlabels = $nvalues = unpack($template,$buffer);
    $template = "f";
    $len = length pack($template,'',0);
    for ( my $i=0 ; $i<$nlabels ; $i++ ) {
     read(FPin,$buffer,$len);
     $labels{$i} = unpack($template,$buffer);
    }
   } else {
    printfatalerror "FATAL ERROR: Found unsupported magic ".$magic." keyword for datafile '".$filename."'.";
   }
  close(FPin);
 }
 print " + got $nlabels labels for $nvalues vertices.\n" if ( $verbose );
 my %labelinfo = ();
 $labelinfo{"filename"} = $filename;
 $labelinfo{"comments"} = $comments;
 $labelinfo{"magic"} = $magic;
 $labelinfo{"nvertices"} = $nvalues;
 $labelinfo{"nlabels"} = $nlabels;
 %{$labelinfo{"labels"}} = %labels;
 %{$labelinfo{"colors"}} = %colors;
 %{$labelinfo{"labelcolors"}} = %labelcolors;
 %{$labelinfo{"labelnames"}} = %labelnames;
 %{$labelinfo{"defs"}} = %labeldefs;
 return %labelinfo;
}

### saving JuBrain labels
sub saveJuBrainLabels {
 my ($labeldata_ptr,$labelinfo_ptr,$filename,$verbose,$debug) = @_;
 my %labeldata = %{$labeldata_ptr};
 my %labelinfo = %{$labelinfo_ptr};
 print "jubdmesh.saveJuBrainLabels().DEBUG: nvertices=".$labelinfo{"nvertices"}.", nlabels=".$labelinfo{"nlabels"}."\n" if ( $debug );
 open(FPout,">$filename") || printfatalerror "FATAL ERROR: Cannot create label file '".$filename."': $!";
  binmode(FPout);
  # save magic
  print FPout "JUBDilf";
  # save label colors
  my %colors = %{$labelinfo{"colors"}};
  my $ncolors = scalar(keys(%colors));
  if ( $ncolors!=$labelinfo{"nlabels"} ) {
   print "WARNING: Mismatch between number of color label entries (=".$ncolors.") and number of labels (n=".$labelinfo{"nlabels"}.") in function saveJuBrainLabels().\n";
   print FPout pack "l,l",$labelinfo{"nvertices"},$ncolors;
  } else {
   print FPout pack "l,l",$labelinfo{"nvertices"},$labelinfo{"nlabels"};
  }
  print "jubdmesh.saveJuBrainLabels().DEBUG: nlabels=".$labelinfo{"nlabels"}.", ncolors=".scalar(keys(%colors))."\n" if ( $debug );
  # save label colors
  my $k = 0;
  foreach my $index (sort(keys %colors)) {
   my @rgb = @{$colors{$index}};
   my $oindex = $rgb[0];
   print "jubdmesh.saveJuBrainLabels().DEBUG: v[$k||$index|$oindex]($rgb[1]:$rgb[2]:$rgb[3])\n" if ( $debug );
   print FPout pack "l,f,f,f",$oindex,$rgb[1],$rgb[2],$rgb[3];
   $k += 1;
  }
  # save indices
  my %outlabels = ();
  my $nvalues = scalar(keys(%labeldata));
  print "jubdmesh.saveJuBrainLabels().DEBUG: nvalues=$nvalues\n" if ( $debug );
  print FPout pack "l",$nvalues;
  while ( my ($index,$value) = each(%labeldata) ) {
   # print "DEBUG: index=$index, value=$value\n" if ( $debug );
   print FPout pack "l,l",$index,$value;
   if ( exists($outlabels{$value}) ) {
    $outlabels{$value} += 1;
   } else {
    $outlabels{$value} = 1;
   }
  }
 close(FPout);
 if ( $debug ) {
  #while ( my ($index,$value) = each(%outlabels) ) {
  # print " + id=$index: n=$value\n";
  #}
  print "+ created label file '".$filename."'.\n";
 }
 return 1;
}

### this is the new version
sub saveJuBrainLabels2 {
 my ($filename,$labeldata_ptr,$hint,$verbose,$debug) = @_;
 my %labeldata = %{$labeldata_ptr};
 if ( defined($hint) && $hint =~ m/^JUBDfdf$/i ) {
  ### that is for global curvature values for instance, every vertex of a mesh has a value
  print "saveJuBrainLabels2(): Saving JUBDfdf file '".$filename."'...\n" if ( $verbose );
  my $nvalues = $labeldata{"nlabels"};
  my @values = @{$labeldata{"labels"}};
  if ( scalar(@values)==$nvalues ) {
   open(FPout,">$filename") || printfatalerror "FATAL ERROR: Cannot save binary vertex data file '".$filename."': $!";
    binmode(FPout);
    print FPout "JUBDfdf";
    print FPout pack "l",$nvalues;
    foreach my $value (@values) {
     print FPout pack "f",$value;
    }
   close(FPout);
  } else {
   print "FATAL ERROR: Size mismatch between number of labels (=".$nvalues.") and label array size (=".scalar(@values).".\n";
   return 0;
  }
 } elsif ( defined($hint) && $hint =~ m/^JUBDidf$/i ) {
  ### that is for vertex index values (normally the number of indices is smaller than the number of vertices)
  ### *** IN THE LAST VERSION THE NUMBER OF MESH VERTICES WAS NOT SET CORRECTLY ***
  print "jubdmesh.saveJuBrainLabels2().DEBUG: Saving JUBDidf file '".$filename."'...\n" if ( $debug );
  my $nvertices = $labeldata{"nvertices"};
  my $nvalues = $labeldata{"nlabels"};
  my $nindices = $labeldata{"nindexvalues"};
  my @values = @{$labeldata{"labels"}};
  my @indices = @{$labeldata{"indices"}};
  if ( $nindices==scalar(@values) && $nindices==scalar(@indices) ) {
   print "saveJuBrainLabels2(): Saving file '".$filename."', #vertices=$nvertices, #labels=$nvalues\n" if ( $verbose );
   open(FPout,">$filename") || printfatalerror "FATAL ERROR: Cannot save binary vertex data file '".$filename."': $!";
    print FPout "JUBDidf";
    print FPout pack "ll",$nvertices,$nindices;
    for ( my $i=0 ; $i<$nindices ; $i++ ) {
     print FPout pack "lf",$indices[$i],$values[$i];
    }
   close(FPout);
  } else {
   print "FATAL ERROR: Size mismatch between number of indices (=".$nindices.") and label array (n=".scalar(@values).") and/or index array (n=".scalar(@indices).") size.\n";
   return 0;
  }
 } else {
  print "FATAL ERROR: Unsupported output datatype hint: ".$hint."\n";
  return 0;
 }
 return 1;
}

### >>>
sub saveJuBrainLabelASCIIData {
 my ($labeldata_ptr,$filename,$verbose,$debug) = @_;
 my %labeldata = %{$labeldata_ptr};
 open(FPout,">$filename") || printfatalerror "FATAL ERROR: Cannot create label file '".$filename."': $!";
  print "jubdmesh.saveJuBrainLabelData(): Saving JulichBrain label data file '".$filename."'...\n" if ( $verbose );
  print FPout "# created by jubdmesh.saveJuBrainLabelASCIIData() at XXXX\n";
  print FPout "nvertices ".$labeldata{"nvertices"}."\n";
  # if available save label names
  my %labelnames = %{$labeldata{"labelnames"}};
  my $nLabelNames = scalar(keys(%labelnames));
  if ( $nLabelNames>0 ) {
   print FPout "# >>>\n";
   print FPout "names ".$nLabelNames."\n";
   while ( my ($index,$labelname) = each(%labelnames) ) {
    print FPout $index." ".$labelname."\n";
   }
  }
  # save label colors
  my %colors = %{$labeldata{"colors"}};
  my $ncolors = scalar(keys(%colors));
  print FPout "# >>>\n";
  print FPout "colors ".$ncolors."\n";
  foreach my $index (sort(keys %colors)) {
   my @rgb = @{$colors{$index}};
   my $red   = floor(255.0*$rgb[1]);
   my $green = floor(255.0*$rgb[2]);
   my $blue  = floor(255.0*$rgb[3]);
   print FPout $rgb[0]." ".$red." ".$green." ".$blue."\n";
  }
  # save label indices
  my %labels = %{$labeldata{"labels"}};
  my $nlabels = keys(%labels);
  print FPout "# >>>\n";
  print FPout "labels ".$nlabels."\n";
  while ( my ($index,$label) = each(%labels) ) {
   print FPout $index." ".$label."\n";
  }
 close(FPout);
 return 1;
}

sub saveJuBrainPMapData {
 my ($labeldata_ptr,$filename,$verbose,$debug) = @_;
 my %labeldata = %{$labeldata_ptr};
 open(FPout,">$filename") || printfatalerror "FATAL ERROR: Cannot create label file '".$filename."': $!";
  print "jubdmesh.saveJuBrainLabelData(): Saving JulichBrain JUBDidf binary pmap data file '".$filename."'...\n" if ( $verbose );
  print "SERIOUS WARNING: Invalid number of vertices ".$labeldata{"nvertices"}.". Use suitable option to set value appropriately!\n" if ( $labeldata{"nvertices"}<=0 );
  binmode(FPout);
  print FPout "JUBDidf";
  print FPout pack "l,l",$labeldata{"nvertices"},$labeldata{"nlabels"};
  my %labels = %{$labeldata{"labels"}};
  while ( my ($index,$value) = each(%labels) ) {
   ## print "DEBUG: index=$index, value=$value.\n" if ( $verbose );
   print FPout pack "l,f",$index,$value;
  }
 close(FPout);
}

sub saveJuBrainLabelData {
 my ($labeldata_ptr,$filename,$verbose,$debug) = @_;
 my %labeldata = %{$labeldata_ptr};
 open(FPout,">$filename") || printfatalerror "FATAL ERROR: Cannot create label file '".$filename."': $!";
  print "jubdmesh.saveJuBrainLabelData(): Saving JulichBrain JUBDilf binary label data file '".$filename."'...\n" if ( $verbose );
  binmode(FPout);
  print FPout "JUBDilf";
  print "jubdmesh.saveJuBrainLabelData().DEBUG: nvertices=".$labeldata{"nvertices"}.", nlabels=".$labeldata{"nlabels"}.".\n" if ( $debug );
  # save label colors
  my %labelcolors = %{$labeldata{"labelcolors"}};
  my $nlabelcolors = scalar(keys(%labelcolors));
  print "jubdmesh.saveJuBrainLabelData().DEBUG: nlabelcolors=".$nlabelcolors.".\n" if ( $debug );
  # save label colors
  print FPout pack "l,l",$labeldata{"nvertices"},$nlabelcolors;
  foreach my $index (sort(keys %labelcolors)) {
   my @rgb = @{$labelcolors{$index}};
   print FPout pack "l,f,f,f",$index,$rgb[0],$rgb[1],$rgb[2];
  }
  # save indices
  print "jubdmesh.saveJuBrainLabelData().DEBUG: nlabels=".$labeldata{"nlabels"}."\n" if ( $debug );
  my %labels = %{$labeldata{"labels"}};
  my $nvalues = keys(%labels);
  print FPout pack "l",$nvalues;
  while ( my ($index,$value) = each(%labels) ) {
   # print "DEBUG: index=$index, value=$value.\n" if ( $verbose );
   print FPout pack "l,l",$index,$value;
  }
  # save names
  my %labelnames = %{$labeldata{"labelnames"}};
  my $nLabelNames = scalar(keys(%labelnames));
  if ( $nLabelNames>0 ) {
   print "jubdmesh.saveJuBrainLabelData().DEBUG: labelnames[n=$nLabelNames]=".$labeldata{"labelnames"}."\n" if ( $debug );
   print FPout pack "l",$nLabelNames;
   while ( my ($index,$labelname) = each(%labelnames) ) {
    print " index=$index, name[".length($labelname)."]=$labelname\n" if ( $debug );
    print FPout pack "l,l",$index,length($labelname);
    print FPout $labelname;
   }
  }
 close(FPout);
 return 1;
}

#### end of modules
sub _debug { warn "@_\n" if $DEBUG; }

### return value (required to evaluate to TRUE)
1;
