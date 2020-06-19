## hitperl::vtkmsh package
########################################################################################################

### >>>
package hitperl::vtkmesh;

### >>>
use hitperl;
use File::Path;
use Exporter;

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'loadVTKPolyFile', 'saveVTKPolyFile', 'loadVTKMeshFile' );
$VERSION = 0.1;

### local small helper
sub _cleanString {
 my $string = shift;
 $string =~ s/^\s+//g;
 $string =~ s/\s+$//g;
 return $string;
}

### >>>
sub _parseVTKBinaryData {
 my ($datalines_ptr,$verbose,$debug) = @_;
 my %datalines = %{$datalines_ptr};
 my %meshdata = ();
 while ( my ($key,$dataline) = each(%datalines) ) {
  print " + processing '".$key."' data type field: [".length($dataline)."]=|".$dataline."|\n" if ( $verbose );
  if ( $key =~ m/^POINTS/ ) {
   my @values = split(/ /,$key);
   print "  + parsing ".$values[1]." POINTS data...\n" if ( $verbose );
   my $template = "f f f";
   for ( my $n=0 ; $n<$values[1] ; $n++ ) {
    ### printf "0x%04X\t0x%02X\n", $n, ord $dataline;
    my ($x,$y,$z) = unpack($template,$dataline);
    print "   + coords[".$n."]=(".$x.":".$y.":".$z.")\n" if ( $n<5 );
   }
  }
 }
 return %meshdata;
}
sub _parseVTKAsciiData {
 my ($filename,$verbose,$debug) = @_;
 print "_parseVTKAsciiData(): Loading VTK ascii file '".$filename."'...\n" if ( $verbose );
 my %meshdata = ();
 open(FPin,"<$filename") || die "FATAL ERROR: Cannot open vtk mesh file '".$filename."' for reading: $!";
  my $nvertices = 0;
  my $ntriangles = 0;
  my $xmin = 1000000000;
  my $ymin = $zmin = $xmin;
  my $xmax = $ymax = $zmax = -$xmin;
  while ( <FPin> ) {
   next if ( $_ =~ m/^#/ );
   my $topline = $_;
   my $datatype = <FPin>;
   my $dataset = <FPin>;
   # vertices
   my @vertices = ();
   my $pointsinfo = <FPin>; chomp($pointsinfo);
   my @values = split(/ /,$pointsinfo);
   $nvertices = $values[1];
   print " + parsing ".$nvertices." vertices...\n" if ( $verbose );
   for ( my $i=0 ; $i<$nvertices ; $i++ ) {
    my $dataline = <FPin>;
    chomp($dataline);
    $dataline =~ s/\s+/ /g;
    my @coords = split(/ /,$dataline);
    # print "  + coords[$i]=(".$coords[0].":".$coords[1].":".$coords[2].")\n";
    $xmin = $coords[0] if ( $coords[0]<$xmin );
    $xmax = $coords[0] if ( $coords[0]>$xmax );
    $ymin = $coords[1] if ( $coords[1]<$ymin );
    $ymax = $coords[1] if ( $coords[1]>$ymax );
    $zmin = $coords[2] if ( $coords[2]<$zmin );
    $zmax = $coords[2] if ( $coords[2]>$zmax );
    push(@vertices,$coords[0]);
    push(@vertices,$coords[1]);
    push(@vertices,$coords[2]);
   }
   @{$meshdata{"vertices"}} = @vertices;
   # triangles
   my @simplices = ();
   my $trisinfo = <FPin>; chomp($trisinfo);
   @values = split(/ /,$trisinfo);
   $ntriangles = $values[1];
   print " + parsing ".$ntriangles." triangles...\n" if ( $verbose );
   for ( my $k=0 ; $k<$ntriangles ; $k++ ) {
    my $dataline = <FPin>;
    chomp($dataline);
    $dataline =~ s/\s+/ /g;
    my @indices = split(/ /,$dataline);
    # print " tri[$k]=(".$indices[1].":".$indices[2].":".$indices[3].")\n";
    push(@simplices,$indices[1]);
    push(@simplices,$indices[2]);
    push(@simplices,$indices[3]);
   }
   @{$meshdata{"simplices"}} = @simplices;
  }
 close(FPin);
 $meshdata{"nvertices"} = $nvertices;
 $meshdata{"nfaces"} = $ntriangles;
 $meshdata{"magic"} = "vtk";
 @{$meshdata{"range"}} = ($xmin,$xmax,$ymin,$ymax,$zmin,$zmax);
 print "  + datarange: x[$xmin:$xmax], y[$ymin:$ymax], z[$zmin:$zmax]\n" if ( $verbose );
 return %meshdata;
}
sub loadVTKMeshFile {
 my ($filename,$verbose,$debug) = @_;
 my %meshdata = ();
 print "vtkmesh.loadVTKMeshFile(): Loading vtk mesh file '".$filename."'...\n" if ( $verbose );
 my $datatype = undef;
 my %datalines = ();
 open(FPin,"<$filename") || die "FATAL ERROR: Cannot open vtk mesh file '".$filename."' for reading: $!";
  binmode(FPin);
  while ( <FPin> ) {
   next if ( $_ =~ m/^#/ );
   my $topline = $_;
   $datatype = <FPin>;
   if ( $datatype =~ m/^ascii$/i ) {
    close(FPin);
    return _parseVTKAsciiData($filename,$verbose,$debug);
   }
   chomp($datatype);
   my $dataset = <FPin>;
   ### loading vertices // DOES NOT WORK CORRECTLY //
   my $defdata = <FPin>;
   chomp($defdata);
   print " + defdata=$defdata\n";
   my $buffer = "";
   $template = "f f f";
   $len = length pack($template,'',0,0);
   for ( my $i=0 ; $i<363 ; $i++ ) {
    read(FPin,$buffer,$len);
    my ($x,$y,$z) = unpack($template,$buffer);
    print "  + coords=(".$x.":".$y.":".$z.")\n" if ( $verbose && $i<10 );
   }
   ### loading polygons // DOES NOT WORK CORRECTLY //
   $defdata = <FPin>;
   chomp($defdata);
   print " + defdata=$defdata\n";
   $template = "l l l";
   $len = length pack($template,'',0,0);
   for ( my $i=0 ; $i<722 ; $i++ ) {
    read(FPin,$buffer,$len);
    my ($u,$v,$w) = unpack($template,$buffer);
    print "  + indices=(".$u.":".$v.":".$w.")\n" if ( $verbose && $i<10 );
   }
   ### loading ????
   $defdata = <FPin>;
   chomp($defdata);
   print " + defdata=$defdata\n";
   # read(FPin,$buffer,4356,0);
   # $datalines{$defdata} = $buffer;
   last;
  }
 close(FPin);
 print " + datatype=$datatype\n" if ( $verbose );
 if ( $datatype =~ m/^binary$/i ) {
  %meshdata = _parseVTKBinaryData(\%datalines,$verbose,$debug);
 } elsif ( $datatype =~ m/^ascii$/i ) {
  print "loading ascii dataset...\n";
 }
 
 return %meshdata;
}

### >>>
sub loadVTKPolyFile {
 my ($filename,$verbose,$debug) = @_;
 my %meshdata = ();
 print "vtkmesh.loadVTKPolyFile(): Loading vtk poly file '".$filename."'...\n" if ( $verbose );
 open(FPin,"<$filename") || die "FATAL ERROR: Cannot open vtk poly file '".$filename."' for reading: $!";
  $meshdata{"filename"} = $filename;
  $meshdata{"magic"} = "vtkpoly";
  my $dataline;
  while ( <FPin> ) {
   chomp($_);
   $dataline = $_;
   last unless ( $dataline =~ m/^#/ );
  }
  $magic = _cleanString($dataline);
  unless ( $magic =~ m/^vtk output/i ) {
   print "FATAL ERROR: Invalid magic keyword '".$magic."'. This is not a valid vtk poly file.\n";
   return %meshdata;
  }
  my $datatype = <FPin>;
  $datatype = _cleanString($datatype);
  unless ( $datatype =~ m/^ASCII$/i ) {
   print "FATAL ERROR: Unsupported data storage type $datatype. Can only process ASCII datasets.\n";
   return %meshdata;
  }
  my $dataset = <FPin>;
  my @datasetline = split(/\ /,_cleanString($dataset));
  if ( !($datasetline[0] =~ m/^DATASET$/i && $datasetline[1] =~ m/^POLYDATA$/i) ) {
   print "FATAL ERROR: Invalid dataset ".$datasetline.".\n";
   return %meshdata;
  }
  my $dpValue = 0;
  my $xmin = 1000000000;
  my $ymin = $zmin = $xmin;
  my $xmax = $ymax = $zmax = -$xmin;
  my $nnormals = 0;
  while ( <FPin> ) {
   $dataline = $_;
   if ( $dataline =~ m/^POINT_DATA/i ) {
    chomp($dataline);
    my @elements = split(/\ /,$dataline);
    $dpValue = $elements[1];
   } elsif ( $dataline =~ m/^POINTS/i ) {
    my @vertexcoords = ();
    my @elements = split(/\ /,$dataline);
    $nverts = $elements[1];
    print " + found ".$nverts." vertices...\n" if ( $verbose );
    $ncounts = 0;
    while ( <FPin> ) {
     my $vertexline = _cleanString($_);
     my @coords = split(/\ /,$vertexline);
     my $ncoords = scalar(@coords);
     ### print "vertexline [$ncounts] >>> $vertexline >>> $ncoords\n";
     if ( $ncoords%3==0 ) {
      for ( my $vv=0 ; $vv<$ncoords ; $vv+=3 ) {
       my $x = $coords[$vv+0]; $x =~ s/\,/\./;
       my $y = $coords[$vv+1]; $y =~ s/\,/\./;
       my $z = $coords[$vv+2]; $z =~ s/\,/\./;
       $xmin = $x if ( $x<$xmin );
       $xmax = $x if ( $x>$xmax );
       $ymin = $y if ( $y<$ymin );
       $ymax = $y if ( $y>$ymax );
       $zmin = $z if ( $z<$zmin );
       $zmax = $z if ( $z>$zmax );
       $ncounts += 1;
       push(@vertexcoords,$x);
       push(@vertexcoords,$y);
       push(@vertexcoords,$z);
      }
      ### push(@vertexcoords,@coords);
     } else {
      print "FATAL ERROR: Parsing failure for vertex line '".$vertexline."'.\n";
      return %meshdata;
     }
     last if ( $ncounts==$nverts );
    }
    $meshdata{"nvertices"} = $nverts;
    @{$meshdata{"vertices"}} = @vertexcoords;
   } elsif ( $dataline =~ m/^NORMALS/i ) {
    print " + found ".$dpValue." normals...\n" if ( $verbose );
    my @normalcoords = ();
    while ( <FPin> ) {
     my $normalline = _cleanString($_);
     my @normals = split(/\ /,$normalline);
     # print " > ".$normalline."\n";
     my $ncoords = scalar(@normals);
     if ( $ncoords%3==0 ) {
      for ( my $vv=0 ; $vv<$ncoords ; $vv+=3 ) {
       my $nx = $normals[$vv+0]; $nx =~ s/\,/\./;
       my $ny = $normals[$vv+1]; $ny =~ s/\,/\./;
       my $nz = $normals[$vv+2]; $nz =~ s/\,/\./;
       # print "nxyz=(".$nx.":".$ny.":".$nz.")\n";
       push(@normalcoords,$nx);
       push(@normalcoords,$ny);
       push(@normalcoords,$nz);
       $nnormals += 1;
      }
     }
     last if ( $nnormals==$nverts );
    }
    @{$meshdata{"normals"}} = @normalcoords;
   } elsif ( $dataline =~ m/^POLYGONS/i ) {
    chomp($dataline);
    my @simplices = ();
    my @elements = split(/\ /,$dataline);
    my $nfaces = $elements[1];
    print " + found ".$nfaces." polygons...\n" if ( $verbose );
    ### print "found polygon line: $dataline, #polygons: $nfaces\n";
    for ( my $tri=0 ; $tri<$nfaces ; $tri++ ) {
     my $facedataline = <FPin>;
     my @facecoords = split(/\ /,_cleanString($facedataline));
     if ( $facecoords[0]==3 && scalar(@facecoords)==4 ) {
      for ( my $n=1 ; $n<=3 ; $n++ ) {
       push(@simplices,$facecoords[$n]);
      }
     } else {
      print "FATAL ERROR: Parsing failure for polygon line '".$facedataline."'.\n";
      return %meshdata;
     }
    }
    $meshdata{"nfaces"} = $nfaces;
    @{$meshdata{"simplices"}} = @simplices;
   } elsif ( $dataline =~ m/^EDGES/i ) {
    chomp($dataline);
    my @edges = ();
    my @elements = split(/\ /,$dataline);
    my $nedges = $elements[1];
    for ( my $edge=0 ; $edge<$nedges ; $edge++ ) {
     my $edgedataline = <FPin>;
     my @edgeindices = split(/\ /,_cleanString($edgedataline));
     push(@edges,@edgeindices);
    }
    $meshdata{"nedges"} = $nedges;
    @{$meshdata{"edges"}} = @edges;
   }
  }
 close(FPin);
 @{$meshdata{"range"}} = ($xmin,$xmax,$ymin,$ymax,$zmin,$zmax);
 if ( $verbose ) {
  print "+ vtk poly file: ".$filename."\n";
  print " + number of vertices ".$meshdata{"nvertices"}.", normals ".$nnormals.", triangles ".$meshdata{"nfaces"}." and edges ".$meshdata{"nedges"}."\n";
  print " + range: x[$xmin:$xmax], y[$ymin:$ymax], z[$zmin:$zmax]\n";
 }
 return %meshdata;
}

### >>>
sub saveVTKPolyFile {
 my ($filename,$meshdata_ptr,$verbose,$debug) = @_;
 my %meshdata = %{$meshdata_ptr};
 open(FPout,">$filename") || die "FATAL ERROR: Cannot save vtk poly file '".$filename."' for writing: $!";
  print FPout "# vtk DataFile Version 3.0\n";
  print FPout "vtk output\n";
  print FPout "ASCII\n";
  print FPout "DATASET POLYDATA\n";
  ### write vertices
   my @vertices = @{$meshdata{"vertices"}};
   my $nvertices = $meshdata{"nvertices"};
   print FPout "POINTS ".$nvertices." float\n";
   my $nc = 1;
   for ( my $i=0 ; $i<(3*$nvertices) ; $i+=3 ) {
    if ( $nc%3==0 ) {
     print FPout $vertices[$i]." ".$vertices[$i+1]." ".$vertices[$i+2]."\n";
    } else {
     print FPout $vertices[$i]." ".$vertices[$i+1]." ".$vertices[$i+2]." ";
    }
    $nc += 1;
   }
   print FPout "\n" if ( $nc%3!=0 );
   print FPout "\n";
  ### write tris
   my @simplices = @{$meshdata{"simplices"}};
   my $nfaces = $meshdata{"nfaces"};
   print FPout "POLYGONS ".$nfaces." ".(4*$nfaces)."\n";
   for ( my $i=0 ; $i<(3*$nfaces) ; $i+=3 ) {
    print FPout "3 ".$simplices[$i]." ".$simplices[$i+1]." ".$simplices[$i+2]."\n";
   }
   print FPout "\n";
  ### write lines (that's in agreement with the official file specs)
   if ( exists($meshdata{"nedges"}) && exists($meshdata{"edges"}) ) {
    my @edges = @{$meshdata{"edges"}};
    my $nedges = $meshdata{"nedges"};
    print FPout "LINES ".$nedges." ".(3*$nedges)."\n";
    for ( my $i=0 ; $i<(2*$nedges) ; $i+=2 ) {
     print FPout "2 ".$edges[$i]." ".$edges[$i+1]."\n";
    }
   }
  ### close file
 close(FPout);
}

#### end of modules
sub _debug { warn "@_\n" if $DEBUG; }

### return value (required to evaluate to TRUE)
return 1;