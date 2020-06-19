## hitperl::asciimesh package
########################################################################################################

### >>>
package hitperl::asciimesh;

### >>>
use hitperl;
use File::Path;
use Exporter;

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'loadASCIIFile', 'saveASCIIFile' );
$VERSION = 0.1;

### load asc tools can be found in 'fsurfmesh.pm'
sub loadASCIIFile {
 my ($filename,$verbose,$debug) = @_;
 my %meshdata = ();
 print "asciimesh.loadASCIIFile(): Loading ASCII mesh file '".$filename."'...\n" if ( $verbose );
  ### NOT YET ###
 return %meshdata;
}

### >>>
sub saveASCIIFile {
 my ($filename,$meshdata_ptr,$verbose,$debug) = @_;
 my %meshdata = %{$meshdata_ptr};
 my @vertices = @{$meshdata{"vertices"}};
 my @normals = @{$meshdata{"normals"}};
 my @simplices = @{$meshdata{"simplices"}};
 my $nvertices = $meshdata{"nvertices"};
 my $nfaces = $meshdata{"nfaces"};
 print "asciimesh.saveASCIIFile(): Saving ascii file '".$filename."' (#verts=$nvertices, #faces=$nfaces)...\n" if ( $verbose );
 open(FPout,">$filename") || die "FATAL ERROR: Cannot save ascii file '".$filename."': $!";
  print FPout "#!ascii version of $filename\n";
  print FPout $nvertices." ".$nfaces."\n";
  for ( my $n=0 ; $n<(3*$nvertices) ; $n+=3 ) {
   printf FPout "%.6f  %.6f  %.6f  0\n",$vertices[$n],$vertices[$n+1],$vertices[$n+2];
  }
  for ( my $i=0 ; $i<(3*$nfaces) ; $i+=3 ) {
   print FPout $simplices[$i]." ".$simplices[$i+1]." ".$simplices[$i+2]." 0\n";
  }
 close(FPout);
}

### return value (required to evaluate to TRUE)
return 1;