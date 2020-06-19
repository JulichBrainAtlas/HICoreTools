## hitperl::mnimesh package
########################################################################################################

### >>>
package hitperl::mnimesh;

### >>>
use hitperl;
use File::Path;
use Exporter;

@ISA = ('Exporter');
@EXPORT = ( 'loadFile', 'loadMNIObjFile', 'loadVertexInfoTextFile', 'saveMNIObjFile', );
$VERSION = 0.1;

#### local variables
my $timestamp = sprintf "%06x",int(rand(100000));
my $tmp = "tmp".$timestamp;

#### start public modules

### load mni obj file
# data are stored in a data hash
sub _cleanString {
 my $string = shift;
 $string =~ s/^\s+//g;
 $string =~ s/\s+$//g;
 return $string;
}

### >>>
sub loadFile {
 my ($filename,$verbose,$debug) = @_;
 print " *** WARNING: 'mnimesh::loadFile()' Code has changed ***\n";
 my %data = ();
 print "mnimesh.loadFile(): Loading mni obj file '".$filename."'...\n" if ( $verbose );
 open(FPin,"<$filename") || die "FATAL ERROR: Cannot open mni obj file '".$filename."' for reading: $!";
  my $xmin = 1000000000;
  my $ymin = $zmin = $xmin;
  my $xmax = $ymax = $zmax = -$xmin;
  my $tmpline = "";
  my $headerline = <FPin>;
  die "mnimesh.loadFile(): FATAL ERROR: line=$headerline - invalid syntax in file '".$infile."': $!" unless ( $headerline =~ m/^P/ );
  chomp($headerline);
  my @headervalues = split(/ /,$headerline);
  $nvertices = $headervalues[-1];
  print " + loading ".$nvertices." vertices...\n" if ( $verbose );
  my @vertices = ();
  for ( my $nv=0 ; $nv<$nvertices ; $nv++ ) {
   my $vertexline = <FPin>;
   chomp($vertexline);
   $vertexline = _cleanString($vertexline);
   my @thevertices = split(/\ /,$vertexline);
   $xmin = $thevertices[0] if ( $thevertices[0]<$xmin );
   $xmax = $thevertices[0] if ( $thevertices[0]>$xmax );
   $ymin = $thevertices[1] if ( $thevertices[1]<$ymin );
   $ymax = $thevertices[1] if ( $thevertices[1]>$ymax );
   $zmin = $thevertices[2] if ( $thevertices[2]<$zmin );
   $zmax = $thevertices[2] if ( $thevertices[2]>$zmax );
   push(@vertices,@thevertices);
   # print "DEBUG: vertex = $vertexline\n";
  }
  $data{"nvertices"} = $nvertices;
  @{$data{"vertices"}} = @vertices;
  $tmpline = <FPin>;
  print " + loading ".$nvertices." normals...\n" if ( $verbose );
  my @normals = ();
  for ( my $nv=0 ; $nv<$nvertices ; $nv++ ) {
   my $normalline = <FPin>;
   chomp($normalline);
   $normalline = _cleanString($normalline);
   push(@normals,split(/\ /,$normalline));
   # print "DEBUG: normals = $normalline\n";
  }
  @{$data{"normals"}} = @normals;
  $tmpline = <FPin>;
  my $simplexdim = <FPin>;
  chomp($simplexdim);
  $simplexdim = _cleanString($simplexdim);
  $data{"nfaces"} = $simplexdim;
  $tmpline = <FPin>;
  $tmpline = <FPin>;
  my @simplices = ();
  if ( $verbose ) {
   print " + loading ".$simplexdim." simplices...\n";
   print "  + parsing simplex dimension info lines...\n";
  }
  while ( <FPin> ) {
   my $datastring = _cleanString($_);
   last if ( length($datastring)==0 );
  }
  print "  + parsing simplex info...\n" if ( $verbose );
  while ( <FPin> ) {
   push(@simplices,split(/\ /,_cleanString($_)));
  }
  @{$data{"simplices"}} = @simplices;
 close(FPin);
 print " got ".(scalar(@{$data{"simplices"}})/3)." simplices.\n" if ( $verbose );
 @{$data{"range"}} = ($xmin,$xmax,$ymin,$ymax,$zmin,$zmax);
 return %data;
}
sub loadMNIObjFile {
 my ($filename,$verbose,$debug) = @_;
 return loadFile($filename,$verbose,$debug);
}

###
sub loadVertexInfoTextFile {
 my ($filename,$verbose) = @_;
 my @values = ();
 print "mnimesh.loadVertexInfoTextFile(): Loading vertex info file '".$filename."'...\n" if ( $verbose );
 open(FPin,"<$filename") || die "FATAL ERROR: Cannot open vertex info file '".$filename."' for reading: $!";
  while ( <FPin> ) {
   chomp($_);
   push(@values,$_);
  }
 close(FPin);
 print " > got values for ".@values." vertices!\n" if ( $verbose );
 return @values;
}

###
sub saveFile {
 my ($filename,$meshdata_ptr,$verbose,$debug) = @_;
 my %meshdata = %{$meshdata_ptr};
 my @vertices = @{$meshdata{"vertices"}};
 my @normals = @{$meshdata{"normals"}};
 my @simplices = @{$meshdata{"simplices"}};
 my $nvertices = $meshdata{"nvertices"};
 my $nfaces = $meshdata{"nfaces"};
 open(FPout,">$filename") || die "FATAL ERROR: Cannot save mni obj file '".$filename."': $!";
  print FPout "P 0.3 0.3 0.4 10 1 ".$nvertices."\n"; ### aspect ???????
  for ( my $i=0 ; $i<(3*$nvertices) ; $i+=3 ) {
   print FPout " ".$vertices[$i]." ".$vertices[$i+1]." ".$vertices[$i+2]."\n";
  }
  print FPout "\n";
  for ( my $i=0 ; $i<(3*$nvertices) ; $i+=3 ) {
   print FPout " ".$normals[$i]." ".$normals[$i+1]." ".$normals[$i+2]."\n";
  }
  print FPout "\n";
  print FPout $nfaces."\n";
  print FPout "0 1 1 1 1\n";
  print FPout "\n";
  my $nelements = 8;
  # save simplex topo info
  my $kk = 3;
  my $n3faces = 3*$nfaces;
  for ( my $i=0 ; $i<$nfaces ; $i+=$nelements ) {
   my $dataline = "";
   for ( my $k=0 ; ($k<$nelements && $kk<=$n3faces); $k++ ) {
    $dataline .= " ".$kk;
    $kk += 3;
   }
   print FPout $dataline."\n";
  }
  print FPout "\n";
  # save simplex info
  for ( my $i=0 ; $i<(3*$nfaces) ; $i+=$nelements ) {
   my $dataline = "";
   for ( my $k=0 ; $k<$nelements ; $k++ ) {
    $dataline .= " ".$simplices[$i+$k];
   }
   print FPout $dataline."\n"; ##  if ( $k<$nelements-1 );
  }
 close(FPout);
 return 1;
}
sub saveMNIObjFile {
 my ($filename,$meshdata_ptr,$verbose,$debug) = @_; 
 return saveFile($filename,$meshdata_ptr,$verbose,$debug);
}

#### end of modules
sub _debug { warn "@_\n" if $DEBUG; }

### return value (required to evaluate to TRUE)
1;
