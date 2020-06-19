## hitperl::offmesh package
########################################################################################################

### >>>
package hitperl::offmesh;

### >>>
use hitperl;
use File::Path;
use Exporter;

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'loadOffFile', 'saveOffFile', 'getZPlanePositionListFromOffMeshFile' );
$VERSION = 0.2;

#### local variables
my $timestamp = sprintf "%06x",int(rand(100000));
my $tmp = "tmp${timestamp}";

#### start public modules

### loading simple off mesh file and retrun z-plane positions
sub getZPlanePositionListFromOffMeshFile {
 my ($filename,$verbose) = @_;
 my @xvalues = ();
 my @yvalues = ();
 my @zvalues = ();
 my %zplanes = ();
 print "offmesh.getZPlanePositionListFromOffMeshFile(): Loading mesh file '".$filename."'...\n" if ( $verbose );
 open(FPin,"<$filename") || die "FATAL ERROR: Cannot open input file '".$filename."' for reading: $!";
  while ( <FPin> ) {
   if ( $_ =~ m/^OFF/ ) {
    my $headerline = <FPin>;
    chop($headerline);
    my @values = split(/\ /,$headerline);
    my $nvertices = $values[0];
    my $ntriangles = $values[1];
    print " + loading ".$nvertices." vertices...\n" if ( $verbose );
    for ( my $n=0 ; $n<$nvertices ; $n++ ) {
     my $vertexline = <FPin>;
     chop($vertexline);
     my @coords = split(/\ /,$vertexline);
     push(@xvalues,$coords[0]);
     push(@yvalues,$coords[1]);
     push(@zvalues,$coords[2]);
     @{$zplanes{$coords[2]}} = ();
    }
    print "  + got ".scalar(keys(%zplanes))." z-planes: (".join(",",sort(keys(%zplanes))).")\n" if ( $verbose );
   }
  }
 close(FPin);
 return %zplanes;
}

### loading off file (only tri meshes are supported)
# data are stored in a data hash
sub _cleanString {
 my $string = shift;
 $string =~ s/^\s+//g;
 $string =~ s/\s+$//g;
 return $string;
}

sub loadOffFile {
 my ($filename,$verbose,$debug) = @_;
 my %meshdata = ();
 print "offmesh.loadOffFile(): Loading geomview off file '".$filename."'...\n" if ( $verbose );
 open(FPin,"<$filename") || die "FATAL ERROR: Cannot open geomview off file '".$filename."' for reading: $!";
  $meshdata{"filename"} = $filename;
  my $xmin = 1000000000;
  my $ymin = $zmin = $xmin;
  my $xmax = $ymax = $zmax = -$xmin;
  my $magic = undef;
  while ( <FPin> ) {
   chomp($_);
   next if ( $_ =~ m/^#/ );
   $magic = _cleanString($_) unless ( defined($magic) );
   my $infoline = <FPin>;
   my @values = split(/\ /,$infoline);
   my $nvertex = $values[0];
   my $nfaces = $values[1];
   $meshdata{"nvertices"} = $nvertex;
   $meshdata{"nfaces"} = $nfaces;
   $meshdata{"magic"} = $magic;
   print " + loading $magic file with $nvertex vertices and $nfaces faces...\n" if ( $verbose );
   # loading vertices
   my @vertices = ();
   if ( $magic =~ m/^OFF/ ) {
    for ( my $i=0 ; $i<$nvertex ; $i++ ) {
     my $vertexline = <FPin>;
     $vertexline =~ s/\r[\n]*/\n/gm;
     chomp($vertexline);
     my @thevertices = split(/\ /,$vertexline);
     print "   + v[$i]($thevertices[0]:$thevertices[1]:$thevertices[2])\n" if ( $i<5 && $verbose );
     $xmin = $thevertices[0] if ( $thevertices[0]<$xmin );
     $xmax = $thevertices[0] if ( $thevertices[0]>$xmax );
     $ymin = $thevertices[1] if ( $thevertices[1]<$ymin );
     $ymax = $thevertices[1] if ( $thevertices[1]>$ymax );
     $zmin = $thevertices[2] if ( $thevertices[2]<$zmin );
     $zmax = $thevertices[2] if ( $thevertices[2]>$zmax );
     push(@vertices,@thevertices);
    }
   } elsif ( $magic =~ m/^NOFF/ ) {
    my @normals = ();
    for ( my $i=0 ; $i<$nvertex ; $i++ ) {
     my $vertexnormalline = <FPin>;
     $vertexline =~ s/\r[\n]*/\n/gm;
     chomp($vertexnormalline);
     # print " vertexnormalline = $vertexnormalline\n";
     $vertexnormalline = _cleanString($vertexnormalline);
     my @elements = split(/\ /,$vertexnormalline);
     my @thevertices = @elements[0..2];
     $xmin = $thevertices[0] if ( $thevertices[0]<$xmin );
     $xmax = $thevertices[0] if ( $thevertices[0]>$xmax );
     $ymin = $thevertices[1] if ( $thevertices[1]<$ymin );
     $ymax = $thevertices[1] if ( $thevertices[1]>$ymax );
     $zmin = $thevertices[2] if ( $thevertices[2]<$zmin );
     $zmax = $thevertices[2] if ( $thevertices[2]>$zmax );
     push(@vertices,@thevertices);
     push(@normals,@elements[3..5]);
    }
    @{$meshdata{"normals"}} = @normals;
    $meshdata{"nnormals"} = scalar(@normals)/3;
   } elsif ( $magic =~ m/^COFF/ ) {
    my @colors = ();
    for ( my $i=0 ; $i<$nvertex ; $i++ ) {
     my $vertexcolorline = <FPin>;
     chomp($vertexcolorline);
     $vertexcolorline = _cleanString($vertexcolorline);
     my @elements = split(/\ /,$vertexcolorline);
     my @thevertices = @elements[0..2];
     $xmin = $thevertices[0] if ( $thevertices[0]<$xmin );
     $xmax = $thevertices[0] if ( $thevertices[0]>$xmax );
     $ymin = $thevertices[1] if ( $thevertices[1]<$ymin );
     $ymax = $thevertices[1] if ( $thevertices[1]>$ymax );
     $zmin = $thevertices[2] if ( $thevertices[2]<$zmin );
     $zmax = $thevertices[2] if ( $thevertices[2]>$zmax );
     push(@vertices,@thevertices);
     push(@colors,@elements[3..5]);
    }
    @{$meshdata{"colors"}} = @colors;
   } elsif ( $magic =~ m/^CNOFF/ ) {
    my @normals = ();
    my @colors = ();
    for ( my $i=0 ; $i<$nvertex ; $i++ ) {
     my $vertexnormalcolorline = <FPin>;
     chomp($vertexnormalcolorline);
     $vertexnormalcolorline = _cleanString($vertexnormalcolorline);
     my @elements = split(/\ /,$vertexnormalcolorline);
     my @thevertices = @elements[0..2];
     $xmin = $thevertices[0] if ( $thevertices[0]<$xmin );
     $xmax = $thevertices[0] if ( $thevertices[0]>$xmax );
     $ymin = $thevertices[1] if ( $thevertices[1]<$ymin );
     $ymax = $thevertices[1] if ( $thevertices[1]>$ymax );
     $zmin = $thevertices[2] if ( $thevertices[2]<$zmin );
     $zmax = $thevertices[2] if ( $thevertices[2]>$zmax );
     push(@vertices,@thevertices);
     push(@normals,@elements[3..5]);
     push(@colors,@elements[6..8]);
    }
    @{$meshdata{"normals"}} = @normals;
    @{$meshdata{"colors"}} = @colors;
   } else {
    print "FATAL ERROR: Unsupported off mesh type '$magic'.\n";
    return %meshdata;
   }
   @{$meshdata{"vertices"}} = @vertices;
   # loading face elements
   my @simplices = ();
   for ( my $i=0 ; $i<$nfaces ; $i++ ) {
    my $faceline = <FPin>;
    $faceline =~ s/\t/ /g;
    $faceline =~ s/\R//g;
    # print ">> faceline = >$faceline<\n";
    my @elements = split(/\ /,$faceline);
    for ( my $n=1 ; $n<=$elements[0] ; $n++ ) {
     # print "   >> add simplex >$elements[$n]<\n";
     push(@simplices,$elements[$n]);
    }
   }
   @{$meshdata{"simplices"}} = @simplices;
  }
 close(FPin);
 @{$meshdata{"range"}} = ($xmin,$xmax,$ymin,$ymax,$zmin,$zmax);
 print "  + datarange: x[$xmin:$xmax], y[$ymin:$ymax], z[$zmin:$zmax]\n" if ( $verbose );
 return %meshdata;
}

### saving (c)off mesh file
sub saveOffFile {
 my ($filename,$meshdata_ptr,$verbose,$debug) = @_;
 my %meshdata = %{$meshdata_ptr};
 my @vertices = @{$meshdata{"vertices"}};
 my @normals = @{$meshdata{"normals"}};
 my @simplices = @{$meshdata{"simplices"}};
 my $nvertices = $meshdata{"nvertices"};
 my $nfaces = $meshdata{"nfaces"};
 open(FPout,">$filename") || die "FATAL ERROR: Cannot save geomview off file '".$filename."': $!";
 if ( exists($meshdata{"colors"}) ) {
  print "offmesh.saveOffFile(): Saving geomview coff file '".$filename."' (#verts=$nvertices, #faces=$nfaces)...\n" if ( $verbose );
  if ( @normals ) {
   print FPout "CNOFF\n";
  } else {
   print FPout "COFF\n";
  }
  print FPout "$nvertices $nfaces 0\n";
  my @colors = @{$meshdata{"colors"}};
  if ( @normals ) {
   for ( my $i=0 ; $i<(3*$nvertices) ; $i+=3 ) {
    print FPout $vertices[$i]." ".$vertices[$i+1]." ".$vertices[$i+2]." ".$normals[$i]." ".$normals[$i+1]." ".$normals[$i+2]." ";
    print FPout $colors[$i]." ".$colors[$i+1]." ".$colors[$i+2]." 255\n";
   }
  } else {
   for ( my $i=0 ; $i<(3*$nvertices) ; $i+=3 ) {
    print FPout $vertices[$i]." ".$vertices[$i+1]." ".$vertices[$i+2]." ".$colors[$i]." ".$colors[$i+1]." ".$colors[$i+2]." 255\n";
   }
  }
 } else {
  print "offmesh.saveOffFile(): Saving geomview ".(@normals?"n":"")."off file '".$filename."' (#verts=$nvertices, #faces=$nfaces)...\n" if ( $verbose );
  if ( @normals ) {
   print FPout "NOFF\n";
  } else {
   print FPout "OFF\n";
  }
  print FPout "$nvertices $nfaces 1\n";
  if ( @normals ) {
   for ( my $i=0 ; $i<(3*$nvertices) ; $i+=3 ) {
    print FPout $vertices[$i]." ".$vertices[$i+1]." ".$vertices[$i+2]." ".$normals[$i]." ".$normals[$i+1]." ".$normals[$i+2]."\n";
   }
  } else {
   for ( my $i=0 ; $i<(3*$nvertices) ; $i+=3 ) {
    print FPout $vertices[$i]." ".$vertices[$i+1]." ".$vertices[$i+2]."\n";
   }
  }
 }
 for ( my $i=0 ; $i<(3*$nfaces) ; $i+=3 ) {
  print FPout "3 ".$simplices[$i]." ".$simplices[$i+1]." ".$simplices[$i+2]."\n";
 }
 close(FPout);
}

#### end of modules
sub _debug { warn "@_\n" if $DEBUG; }

### return value (required to evaluate to TRUE)
1;
