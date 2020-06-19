## hitperl::stlmesh package
########################################################################################################

### >>>
package hitperl::stlmesh;

### >>>
use hitperl;
use File::Path;
use File::Basename;
use Exporter;

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'saveSTLFile', 'saveSTLASCIIFile' );
$VERSION = 0.1;

#### local variables
my $timestamp = sprintf "%06x",int(rand(100000));
my $tmp = "tmp".$timestamp;

#### start public modules

### saving stl file
sub saveSTLFile {
 my ($filename,$meshdata_ptr,$verbose,$debug) = @_;
 my @elements = split(/\./,basename($filename));
 return saveSTLASCIIFile($filename,$meshdata_ptr,$elements[0],$verbose,$debug);
}

### saving stl ascii mesh file
sub saveSTLASCIIFile {
 my ($filename,$meshdata_ptr,$name,$verbose,$debug) = @_;
 my %meshdata = %{$meshdata_ptr};
 my @vertices = @{$meshdata{"vertices"}};
 my @normals = @{$meshdata{"normals"}};
 my $nnormals = scalar(@normals);
 my @simplices = @{$meshdata{"simplices"}};
 my $nvertices = $meshdata{"nvertices"};
 my $nfaces = $meshdata{"nfaces"};
 open(FPout,">$filename") || die "FATAL ERROR: Cannot save stl file '".$filename."': $!";
  print FPout "solid ".$name."\n";
  for ( my $i=0 ; $i<(3*$nfaces) ; $i+=3 ) {
   ### compute facet normal
   my $idx1 = 3*$simplices[$i];
   my $x1 = $vertices[$idx1];
   my $y1 = $vertices[$idx1+1];
   my $z1 = $vertices[$idx1+2];
   my $idx2 = 3*$simplices[$i+1];
   my $x2 = $vertices[$idx2];
   my $y2 = $vertices[$idx2+1];
   my $z2 = $vertices[$idx2+2];
   my $idx3 = 3*$simplices[$i+2];
   my $x3 = $vertices[$idx3];
   my $y3 = $vertices[$idx3+1];
   my $z3 = $vertices[$idx3+2];
   my $dx1 = $x2-$x1;
   my $dy1 = $y2-$y1;
   my $dz1 = $z2-$z1;
   my $dx2 = $x3-$x1;
   my $dy2 = $y3-$y1;
   my $dz2 = $z3-$z1;
   my $nx = $dy1*$dz2-$dz1*$dy2;
   my $ny = $dz1*$dx2-$dx1*$dz2;
   my $nz = $dx1*$dy2-$dy1*$dx2;
   my $length = sqrt($nx*$nx+$ny*$ny+$nz*$nz);
   if ( $length!=0.0 ) {
    $nx /= $length;
    $ny /= $length;
    $nz /= $length;
   }
   print FPout "facet normal ".$nx." ".$ny." ".$nz."\n";
   ### save facet vertices
   print FPout " outer loop\n";
   for ( my $k=0 ; $k<3 ; $k++ ) {
    my $index = 3*$simplices[$i+$k];
    print FPout "  vertex ".$vertices[$index]." ".$vertices[$index+1]." ".$vertices[$index+2]."\n";
   }
   print FPout " endloop\n";
   print FPout "endfacet\n";
  }
  print FPout "endsolid ".$name."\n";
 close(FPout);
}

#### end of modules
sub _debug { warn "@_\n" if $DEBUG; }

### return value (required to evaluate to TRUE)
1;
