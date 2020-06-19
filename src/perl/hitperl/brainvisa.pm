## hitperl::brainvisa package
########################################################################################################

### >>>
package hitperl::brainvisa;

### >>>
use hitperl;
use File::Path;
use Exporter;

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'loadBrainVisaMeshFile', 'saveBrainVisaMeshFile' );
$VERSION = 0.1;

### small private helper
sub _cleanString {
 my $string = shift;
 $string =~ s/^\s+//g;
 $string =~ s/\s+$//g;
 return $string;
}

#### start public modules

sub loadBrainVisaMeshFile {
 my ($filename,$verbose,$debug) = @_;
 my %meshdata = ();
 $meshdata{"nvertices"} = 0;
 $meshdata{"nfaces"} = 0;
 print "brainvisa.loadBrainVisaMeshFile(): Loading BrainVisa mesh file '".$filename."'...\n" if ( $verbose );
 open(FPin,"<$filename") || die "FATAL ERROR: Cannot open BrainVisa mesh file '".$filename."' for reading: $!";
  $meshdata{"filename"} = $filename;
  my $xmin = 1000000000;
  my $ymin = $zmin = $xmin;
  my $xmax = $ymax = $zmax = -$xmin;
  my $magic = undef;
  while ( <FPin> ) {
   chomp($_);
   next if ( $_ =~ m/^#/ );
   my $datatype = _cleanString($_);
   $_ = <FPin>;
   my $magic    = _cleanString($_);
   my $nblocks  = <FPin>;
   chomp($nblocks);
   my $nelems   = <FPin>;
   chomp($nelems);
   my $ndims    = <FPin>;
   chomp($ndims);
   print " + datatype=$datatype, magic=$magic, nelements=($nblocks,$nelems,$ndims)\n" if ( $verbose );
   ### >>>
   my $dataline = <FPin>;
   chomp($dataline);
   my @elements = split(/ /,$dataline);
   my $nvertices = $elements[0];
   my @vertices = ();
   for ( my $k=1 ; $k<scalar(@elements) ; $k++ ) {
    my $vertexline = substr($elements[$k],1,-1);
    my @thevertices = split(/\,/,$vertexline);
    print "  + v[$k]($thevertices[0]:$thevertices[1]:$thevertices[2])\n" if ( $debug );
    $xmin = $thevertices[0] if ( $thevertices[0]<$xmin );
    $xmax = $thevertices[0] if ( $thevertices[0]>$xmax );
    $ymin = $thevertices[1] if ( $thevertices[1]<$ymin );
    $ymax = $thevertices[1] if ( $thevertices[1]>$ymax );
    $zmin = $thevertices[2] if ( $thevertices[2]<$zmin );
    $zmax = $thevertices[2] if ( $thevertices[2]>$zmax );
    push(@vertices,@thevertices);
   }
   print "  + got $nvertices vertices\n" if ( $verbose );
   @{$meshdata{"vertices"}} = @vertices;
   ### >>>
   $dataline = <FPin>;
   $dataline = <FPin>;
   chomp($dataline);
   @elements = split(/ /,$dataline);
   my $nnormals = $elements[0];
   my @normals = ();
   for ( my $k=1 ; $k<scalar(@elements) ; $k++ ) {
    my $normalline = substr($elements[$k],1,-1);
    my @thenormals = split(/\,/,$normalline);
    print "  + nm[$k]($thenormals[0]:$thenormals[1]:$thenormals[2])\n" if ( $debug );
    push(@normals,@thenormals);
   }
   print "  + got $nnormals normals\n" if ( $verbose );
   ### >>>
   $dataline = <FPin>;
   $dataline = <FPin>;
   $dataline = <FPin>;
   $dataline = <FPin>;
   chomp($dataline);
   @elements = split(/ /,$dataline);
   my $nfaces = $elements[0];
   for ( my $k=1 ; $k<scalar(@elements) ; $k++ ) {
    my $indexline = substr($elements[$k],1,-1);
    my @theindices = split(/\,/,$indexline);
    print "  + face[$k]($theindices[0]:$theindices[1]:$theindices[2])\n" if ( $verbose );
   }
  }
 close(FPin);
 @{$meshdata{"range"}} = ($xmin,$xmax,$ymin,$ymax,$zmin,$zmax); 
 print "  + datarange: x[$xmin:$xmax], y[$ymin:$ymax], z[$zmin:$zmax]\n" if ( $verbose );
 return %meshdata;
}

### saving BrainVisa mesh file
sub saveBrainVisaMeshFile {
 my ($filename,$meshdata_ptr,$verbose,$debug) = @_;
  die "brainvisa.saveBrainVisaMeshFile(): Save of brainvisa mesh files not yet supported.";
 return -1;
 #my %meshdata = %{$meshdata_ptr};
 #my @vertices = @{$meshdata{"vertices"}};
 #my @normals = @{$meshdata{"normals"}};
 #my @simplices = @{$meshdata{"simplices"}};
 #my $nvertices = $meshdata{"nvertices"};
 #my $nfaces = $meshdata{"nfaces"};
 #open(FPout,">$filename") || die "FATAL ERROR: Cannot save brainvisa file '".$filename."': $!";
 #close(FPout);
}

#### end of modules
sub _debug { warn "@_\n" if $DEBUG; }

### return value (required to evaluate to TRUE)
return 1;
