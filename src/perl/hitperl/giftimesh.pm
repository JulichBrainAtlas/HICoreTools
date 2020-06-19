## hitperl::giftimesh package
## crude support of GifTI data files
########################################################################################################

### >>>
package hitperl::giftimesh;

### >>>
use hitperl;
use File::Path;
use Exporter;

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'loadGiftiFile', 'saveGiftiFile', 'saveGiftiLabelFile' );
$VERSION = 0.1;

#### start public modules

### loading gifti file
# data are stored in a data hash
sub _cleanString {
 my $string = shift;
 $string =~ s/^\s+//g;
 $string =~ s/\s+$//g;
 return $string;
}

### >>>
sub loadGiftiFile {
 my ($filename,$verbose,$debug) = @_;
 my %meshdata = ();
 print "giftimesh.loadGiftiFile(): Loading gifti ASCII mesh file '".$filename."'...\n" if ( $verbose );
 open(FPin,"<$filename") || die "FATAL ERROR: Cannot open gifti file '".$filename."' for reading: $!";
  $meshdata{"filename"} = $filename;
  my $xmin = 1000000000;
  my $ymin = $zmin = $xmin;
  my $xmax = $ymax = $zmax = -$xmin;
  while ( <FPin> ) {
   next if ( $_ =~ m/^#/ );
   chomp($_);
   $_ =~ s/\s+/\ /g;
   my @values = split(/\ /,$_);
   my $nvertices = $values[0];
   my $nfaces = $values[1];
   $meshdata{"nvertices"} = $nvertices;
   $meshdata{"nfaces"} = $nfaces;
   print " + loading gifti file with $nvertices vertices and $nfaces faces...\n" if ( $verbose );
   ### loading vertices
   my @vertices = ();
   for ( my $i=0 ; $i<$nvertices ; $i++ ) {
    my $vertexline = <FPin>;
    $vertexline =~ s/\s+/\ /g;
    chomp($vertexline);
    my @thevertices = split(/\ /,$vertexline);
    $xmin = $thevertices[0] if ( $thevertices[0]<$xmin );
    $xmax = $thevertices[0] if ( $thevertices[0]>$xmax );
    push(@vertices,$thevertices[0]);
    $ymin = $thevertices[1] if ( $thevertices[1]<$ymin );
    $ymax = $thevertices[1] if ( $thevertices[1]>$ymax );
    push(@vertices,$thevertices[1]);
    $zmin = $thevertices[2] if ( $thevertices[2]<$zmin );
    $zmax = $thevertices[2] if ( $thevertices[2]>$zmax );
    push(@vertices,$thevertices[2]);
   }
   @{$meshdata{"vertices"}} = @vertices;
   ### loading faces ...
   my @faces = ();
   for ( my $i=0 ; $i<$nfaces ; $i++ ) {
    my $faceline = <FPin>;
    $faceline =~ s/\s+/\ /g;
    chomp($faceline);
    my @elements = split(/\ /,$faceline);
    for ( my $n=0 ; $n<3 ; $n++ ) {
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

### saving gifti mesh file
sub saveGiftiFile {
 my ($filename,$meshdata_ptr,$verbose,$debug) = @_;
 my %meshdata = %{$meshdata_ptr};
 my @vertices = @{$meshdata{"vertices"}};
 my @normals = @{$meshdata{"normals"}};
 my @simplices = @{$meshdata{"simplices"}};
 my $nvertices = $meshdata{"nvertices"};
 my $nfaces = $meshdata{"nfaces"};
 my $meshname = exists($meshdata{"name"})?$meshdata{"name"}:"Colin27CortexLeft";
 my $meshtype = exists($meshdata{"type"})?$meshdata{"type"}:"Pial";
 print "giftimesh.saveGiftiFile(): Saving ascii gifti file '".$filename."' (#verts=$nvertices, #faces=$nfaces)...\n" if ( $verbose );
 open(FPout,">$filename") || die "FATAL ERROR: Cannot save ascii gifti file '".$filename."': $!";
  print FPout "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  print FPout "<!DOCTYPE GIFTI SYSTEM \"http://gifti.projects.nitrc.org/gifti.dtd\">\n";
  print FPout "<GIFTI Version=\"1.0\" NumberOfDataArrays=\"2\">\n";
  print FPout " <MetaData>\n";
  print FPout "  <MD>\n";
  print FPout "   <Name><![CDATA[gifticlib-version]]></Name>\n";
  print FPout "   <Value><![CDATA[gifti library version 1.09, 28 June, 2010]]></Value>\n";
  print FPout "  </MD>\n";
  print FPout " </MetaData>\n";
  print FPout " <LabelTable/>\n";
  print FPout " <DataArray Intent=\"NIFTI_INTENT_POINTSET\"\n";
  print FPout "      DataType=\"NIFTI_TYPE_FLOAT32\"\n";
  print FPout "      ArrayIndexingOrder=\"RowMajorOrder\"\n";
  print FPout "      Dimensionality=\"2\"\n";
  print FPout "      Dim0=\"".$nvertices."\"\n";
  print FPout "      Dim1=\"3\"\n";
  print FPout "      Encoding=\"ASCII\"\n";
  print FPout "      Endian=\"LittleEndian\"\n";
  print FPout "      ExternalFileName=\"\"\n";
  print FPout "      ExternalFileOffset=\"\">\n";
  print FPout "    <MetaData>\n";
  print FPout "     <MD>\n";
  print FPout "      <Name><![CDATA[AnatomicalStructurePrimary]]></Name>\n";
  print FPout "      <Value><![CDATA[".$meshname."]]></Value>\n";
  print FPout "     </MD>\n";
  print FPout "     <MD>\n";
  print FPout "      <Name><![CDATA[GeometricType]]></Name>\n";
  print FPout "      <Value><![CDATA[".$meshtype."]]></Value>\n";
  print FPout "     </MD>\n";
  print FPout "     <MD>\n";
  print FPout "      <Name><![CDATA[TopologicalType]]></Name>\n";
  print FPout "      <Value><![CDATA[Closed]]></Value>\n";
  print FPout "     </MD>\n";
  print FPout "     <MD>\n";
  print FPout "      <Name><![CDATA[Name]]></Name>\n";
  print FPout "      <Value><![CDATA[".$filename."]]></Value>\n";
  print FPout "     </MD>\n";
  print FPout "     <MD>\n";
  print FPout "      <Name><![CDATA[UserName]]></Name>\n";
  print FPout "      <Value><![CDATA[hmohlberg]]></Value>\n";
  print FPout "     </MD>\n";
  print FPout "     <MD>\n";
  print FPout "      <Name><![CDATA[Date]]></Name>\n";
  print FPout "      <Value><![CDATA[".getTimeString(1)."]]></Value>\n";
  print FPout "     </MD>\n";
  print FPout "    </MetaData>\n";
  print FPout "  <CoordinateSystemTransformMatrix>\n";
  print FPout "   <DataSpace><![CDATA[NIFTI_XFORM_UNKNOWN]]></DataSpace>\n";
  print FPout "   <TransformedSpace><![CDATA[NIFTI_XFORM_TALAIRACH]]></TransformedSpace>\n";
  print FPout "   <MatrixData>\n";
  print FPout "     1.000000 0.000000 0.000000 0.000000\n";
  print FPout "     0.000000 1.000000 0.000000 0.000000\n";
  print FPout "     0.000000 0.000000 1.000000 0.000000\n";
  print FPout "     0.000000 0.000000 0.000000 1.000000\n";
  print FPout "   </MatrixData>\n";
  print FPout "  </CoordinateSystemTransformMatrix>\n";
  print FPout "  <Data>\n";
  for ( my $i=0 ; $i<(3*$nvertices) ; $i+=3 ) {
   printf FPout "  %.6f %.6f %.6f\n",$vertices[$i],$vertices[$i+1],$vertices[$i+2];
  }
  print FPout "  </Data>\n";
  print FPout " </DataArray>\n";
  print FPout " <DataArray Intent=\"NIFTI_INTENT_TRIANGLE\"\n";
  print FPout "   DataType=\"NIFTI_TYPE_INT32\"\n";
  print FPout "   ArrayIndexingOrder=\"RowMajorOrder\"\n";
  print FPout "   Dimensionality=\"2\"\n";
  print FPout "   Dim0=\"".$nfaces."\"\n";
  print FPout "   Dim1=\"3\"\n";
  print FPout "   Encoding=\"ASCII\"\n";
  print FPout "   Endian=\"LittleEndian\"\n";
  print FPout "   ExternalFileName=\"\"\n";
  print FPout "   ExternalFileOffset=\"\">\n";
  print FPout "  <MetaData\/>\n";
  print FPout "  <Data>\n";
  for ( my $i=0 ; $i<(3*$nfaces) ; $i+=3 ) {
   print FPout "   ".$simplices[$i]." ".$simplices[$i+1]." ".$simplices[$i+2]."\n";
  }
  print FPout "  </Data>\n";
  print FPout " </DataArray>\n";
  print FPout "</GIFTI>\n";
 close(FPout);
}

### >>>
sub saveGiftiLabelFile {
 my ($filename,$labeldata_ptr,$verbose,$debug) = @_;
 my %labeldata = %{$labeldata_ptr};
 my $labelname = exists($labeldata{"name"})?$labeldata{"name"}:"JuBrainMPMAtlas";
 print "giftimesh.saveGiftiLabelFile(): Saving ascii gifti label (name=".$labelname.") file '".$filename."'...\n" if ( $verbose );
 open(FPout,">$filename") || die "FATAL ERROR: Cannot save ascii gifti label file '".$filename."': $!";
  print FPout "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  print FPout "<!DOCTYPE GIFTI SYSTEM \"http://gifti.projects.nitrc.org/gifti.dtd\">\n";
  print FPout "<GIFTI Version=\"1.0\" NumberOfDataArrays=\"1\">\n";
  print FPout " <MetaData>\n";
  print FPout "  <MD>\n";
  print FPout "   <Name>![CDATA[date]]</Name>\n";
  print FPout "   <Value>![CDATA[".getTimeString(1)."]]</Value>\n";
  print FPout "  </MD>\n";
  print FPout " </MetaData>\n";
  if ( exists $labeldata{"labeltable"} ) {
   my @labeltable = @{$labeldata{"labeltable"}};
   print FPout " <LabelTable>\n";
   foreach my $tablerow (@labeltable) {
    my @elements = split(/\:/,$tablerow);
    printf FPout "  <Label Index=\"%d\" Red=\"%.3f\"",$elements[0],$elements[1];
    printf FPout " Green=\"%.3f\" Blue=\"%.3f\" Alpha=\"1.000\"><![CDATA[\"%s\"]]></Label>\n",$elements[2],$elements[3],$elements[4];
   }
   print FPout " </LabelTable>\n";
  }
  print FPout " <DataArray\n";
  print FPout "  Intent=\"NIFTI_INTENT_LABEL\"\n";
  print FPout "  DataType=\"NIFTI_TYPE_INT32\"\n";
  print FPout "  ArrayIndexingOrder=\"RowMajorOrder\"\n";
  print FPout "  Dimensionality=\"1\"\n";
  print FPout "  Dim0=\"".$labeldata{"nvertices"}."\"\n";
  print FPout "  Encoding=\"ASCII\"\n";
  print FPout "  Endian=\"LittleEndian\"\n";
  print FPout "  ExternalFileName=\"\"\n";
  print FPout "  ExternalFileOffet=\"\">\n";
  print FPout "  <MetaData>\n";
  print FPout "   <MD>\n";
  print FPout "    <Name><![CDATA[Description]]></Name>\n";
  print FPout "    <Value><![CDATA[\"".$labelname."\"]]></Value>\n";
  print FPout "   </MD>\n";
  print FPout "  </MetaData>\n";
  print FPout "  <Data>\n";
  ### saving labels >>>
   my @vertexlabels = @{$labeldata{"vertexlabels"}};
   foreach my $vertexlabel (@vertexlabels) {
    print FPout "    $vertexlabel\n";
   }
  ### >>>
  print FPout "  </Data>\n";
  print FPout " </DataArray>\n";
  print FPout "</GIFTI>\n";
 close(FPout);
}

#### end of modules
sub _debug { warn "@_\n" if $DEBUG; }

### return value (required to evaluate to TRUE)
1;
