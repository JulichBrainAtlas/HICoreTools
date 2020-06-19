## hitperl::meshtools package
########################################################################################################

### >>>
package hitperl::meshtools;

### >>>
use hitperl;
use File::Path;
use Exporter;
use POSIX;
use List::Util qw[min max];

### local includes
use hitperl::brainvisa;
use hitperl::offmesh;
use hitperl::objmesh;
use hitperl::mnimesh;
use hitperl::plymesh;
use hitperl::jubdmesh;
use hitperl::giftimesh;
use hitperl::asciimesh;
use hitperl::vtkmesh;
use hitperl::stlmesh;
use hitperl::volmesh;

@ISA = ('Exporter');
@EXPORT = ( 'loadRGBVertexLabels', 'loadVertexLabels', 'getVertexTopology', 'meanFilterMeshRGBLabels', 'getVertexDualAreaValues',
             'medianFilterMeshRGBLabels', 'saveRGBVertexLabelsAs', 'saveVertexLabelsAs', 'renderRGBVertexLabelMesh',
             'getPValuesFromRGBLabels', 'savePValues', 'getColorHash', 'isValidMeshOfType', 'normalize2unitcube',
             'clipmesh', 'loadMeshFile', 'saveMeshFile', 'transformmesh', 'flipfaceorientation', 'computemeannormals',
             'medianFilterMeshLabels', 'meanFilterMeshLabels', 'minFilterMeshLabels', 'maxFilterMeshLabels',
             'getSurfacePatchArea', 'heatKernelSmoothingMeshLabels', 'getSimplexTopology', 'computeTriangleArea',
             'laplaceFilterMeshLabels', 'thresholdFilterMeshLabels', 'clusterFilterMeshLabels', 'getMeshLabelDataRange',
             'rescaleMeshLabels', 'saveIndexedVertexLabelsAs', 'saveVertexLabelInfoFile', 'getTriangleArea', 'getMeshSurface',
             'fillHolesFilterMeshLabels', 'edgeFilterMeshLabels', 'getLabelPatchDistanceValues' );
$VERSION = 0.6;

#### start public modules

### local helper functions
sub _roundToUInt8 {
 my $value = shift;
 my $icolor = ceil($value);
 $icolor = 255 if ( $icolor>255 );
 return $icolor;
}

### ---
sub renderRGBVertexLabelMesh {
 my ($labelfile,$meshfile,$createtab,$verbose) = @_;
 my $picfile = $labelfile;
 $picfile =~ s/\.vcol$//;
 my $opts = "--width 400 --height 400";
 $opts .= " --overlay rgba:$labelfile --mirror";
 my $sidestring = "top,left,front,bottom,right,back";
 $opts .= " --view ".$sidestring;
 system("hitRenderToImage $opts -i $meshfile -o $picfile");
 if ( $createtab ) {
  my @picoutfiles = ();
  my @sides = split(/\,/,$sidestring);
  foreach my $side (@sides) {
   push(@picoutfiles,"${picfile}_${side}.png");
  }
  my $tabout = "${picfile}_tab.png";
  $opts = "-tile 3x2";
  system("montage @picoutfiles $opts -geometry +0+0 $tabout");
 }
}

### saving vertex labels
sub saveVertexLabelsAs {
 my ($meshlabels_ptr,$filename,$verbose,$debug) = @_;
 my @meshlabels = @{$meshlabels_ptr};
 open(FPout,">$filename") || printfatalerror "FATAL ERROR: Cannot create vertex label file '".$filename."': $!";
  print FPout scalar(@meshlabels)."\n";
  for ( my $i=0 ; $i<scalar(@meshlabels) ; $i++ ) {
   print FPout $meshlabels[$i]."\n";
  }
 close(FPout);
 return 1;
}
sub saveIndexedVertexLabelsAs {
 my ($meshlabels_ptr,$filename,$header,$verbose,$debug) = @_;
 my @meshlabels = @{$meshlabels_ptr};
 my $dataline = "";
 my $nlabels = 0;
 for ( my $i=0 ; $i<scalar(@meshlabels) ; $i++ ) {
  if ( $meshlabels[$i]>0.0 ) {
   $dataline .= $i." ".$meshlabels[$i]."\n";
   $nlabels += 1;
  }
 }
 open(FPout,">$filename") || printfatalerror "FATAL ERROR: Cannot create indexed vertex label file '".$filename."': $!";
  print FPout $header if ( defined($header) );
  if ( $nlabels!=scalar(@meshlabels) ) {
   print FPout "# extended topline: nlabels nvertices\n";
   print FPout $nlabels." ".scalar(@meshlabels)."\n";
  } else {
   print FPout $nlabels."\n";
  }
  print FPout $dataline;
 close(FPout);
 return 1;
}

### new version: support of the new data label array format
sub saveRGBVertexLabelsAs {
 my ($meshlabels_ptr,$filename,$nvertices,$verbose) = @_;
 print "meshtools.saveRGBVertexLabelsAs(): Saving vertex rgb color label file '".$filename."'...\n" if ( $verbose );
 my %meshlabels = %{$meshlabels_ptr};
 open(FPout,">$filename") || printfatalerror "FATAL ERROR: Cannot create rgb vertex label file '".$filename."': $!";
  if ( exists($meshlabels{"version"}) && $meshlabels{"version"}==1.0 ) {
   print " > filename='".$meshlabels{"filename"}."', nvertices=".$meshlabels{"nvertices"}."\n" if ( $verbose );
   print FPout $meshlabels{"comment"}."\n";
   my $nvertices = $meshlabels{"nvertices"};
   print FPout $nvertices."\n";
   my %labelcolors = %{$meshlabels{"colors"}};
   for ( my $i=0 ; $i<$nvertices ; $i++ ) {
    if ( my @colors=@{$labelcolors{$i}} ) {
     print FPout $i." ".$colors[0]." ".$colors[1]." ".$colors[2]."\n";
    } else {
     print FPout $i." 255 255 255\n";
    }
   }
  } else {
   print FPout "# vertex rgb cluster file\n";
   print FPout "RGB\n";
   print FPout $nvertices."\n";
   for ( my $i=0 ; $i<$nvertices ; $i++ ) {
    if ( my @colors=@{$meshlabels{$i}} ) {
     my $red = sprintf("%.6f",$colors[0]/255.0);
     my $green = sprintf("%.6f",$colors[1]/255.0);
     my $blue = sprintf("%.6f",$colors[2]/255.0);
     print FPout $red." ".$green." ".$blue."\n";
    } else {
     print FPout "1.000000 1.000000 1.000000\n";
    }
   }
  }
 close(FPout);
 return 1;
}

### loading simple vertex label file
sub loadVertexLabels {
 my ($filename,$verbose,$debug) = @_;
 print "meshtools.loadVertexLabels(): Loading vertex label file '".$filename."'...\n" if ( $verbose );
 my @labels = ();
 open(FPin,"<$filename") || printfatalerror "FATAL ERROR: Cannot open vertex label file '".$filename."' for reading: $!";
  my $nvertices = <FPin>;
  while ( <FPin> ) {
   chomp($_);
   push(@labels,$_);
  }
 close(FPin);
 print "  + got ".scalar(@labels)." vertex labels.\n" if ( $verbose );
 return @labels;
}

### loading vertex RGB color label file and returns a indexed rgb uint8 rgb color file
### new version: support of .vcol files. data are stored in a new data label array.
sub loadRGBVertexLabels {
 my ($filename,$verbose) = @_;
 print "meshtools.loadRGBVertexLabels(): Loading rgb vertex label file '".$filename."'...\n" if ( $verbose );
 my %labels = ();
 my $ncounts = 0;
 open(FPin,"<$filename") || printfatalerror "FATAL ERROR: Cannot open vertex RGB label file '".$filename."' for reading: $!";
  if ( $filename =~ m/\.vcol/ ) {
   my $comstring = "";
   my %colors = ();
   my $nvertices = 0;
   while ( <FPin> ) {
    if ( $_ =~ m/^#/ ) {
     $comstring .= $_;
     next;
    }
    chomp($_);
    $nvertices = $_;
    for ( my $i=0 ; $i<$nvertices ; $i++ ) {
     my $dataline = <FPin>;
     chomp($dataline);
     my @elements = split(/\ /,$dataline);
     if ( scalar(@elements)>3 ) {
      @{$colors{$elements[0]}} = ($elements[1],$elements[2],$elements[3]);
      $ncounts += 1;
     }
    }
    last;
   }
   $labels{"version"} = 1.0;
   $labels{"filename"} = $filename;
   chomp($comstring);
   $labels{"comment"} = $comstring;
   $labels{"nvertices"} = $nvertices;
   %{$labels{"colors"}} = %colors;
  } else {
   while ( <FPin> ) {
    if ( $_ =~ m/^RGB/ ) {
     my $nvertices = <FPin>;
     for ( my $i=0 ; $i<$nvertices ; $i++ ) {
      my $colorline = <FPin>;
      chomp($colorline);
      my @rgbcolors = split(/\ /,$colorline);
      if ( @rgbcolors==3 ) {
       my $red = _roundToUInt8($rgbcolors[0]*255.0);
       my $green = _roundToUInt8($rgbcolors[1]*255.0);
       my $blue = _roundToUInt8($rgbcolors[2]*255.0);
       if ( $red!=255 || $green!=255 || $blue!=255 ) {
        @{$labels{$i}} = ($red,$green,$blue);
        $ncounts += 1;
       }
      }
     }
    }
   }
  }
 close(FPin);
 print "  > got ".$ncounts." non-trivial label colors.\n" if ( $verbose );
 return %labels;
}

### ---
sub getColorHash {
 my ($red,$green,$blue) = @_;
 return $red+256*$green+65536*$blue;
}
sub getBestColorMatchIndex {
 my ($colormap_ptr,$colorhash) = @_;
 my %colormap = %{$colormap_ptr};
 my $mindistvalue = 1000000;
 my $mindistposition = -1;
 while ( my ($key,$value)=each(%colormap) ) {
  my $lDistance = abs($key-$colorhash);
  return $value if ( $lDistance==0 );
  if ( $lDistance<$mindistvalue ) {
   $mindistvalue = $lDistance;
   $mindistposition = $value;
  }
 }
 return $mindistposition;
}
sub getPValuesFromRGBLabels {
 my ($rgblabels_ptr,$colormap_ptr,$verbose,$debug) = @_;
 my %rgblabels = %{$rgblabels_ptr};
 my @colormap = @{$colormap_ptr};
 my %colormaphash = ();
 my $n = 0;
 for ( my $i=0 ; $i<768 ; $i+=3 ) {
  my $hashvalue = getColorHash($colormap[$i],$colormap[$i+1],$colormap[$i+2]);
  $colormaphash{$hashvalue} = $n;
  $n += 1;
 }
 my %pvalues = ();
 while ( my ($key,$value)=each(%rgblabels) ) {
  my @colors = @{$value};
  my $hashvalue = getColorHash($colors[0],$colors[1],$colors[2]);
  $pvalues{$key} = getBestColorMatchIndex(\%colormaphash,$hashvalue)/255.0;
  print "id[$key]=@colors, hash=$hashvalue, pValue=$pvalues{$key}\n" if ( $debug );
 }
 return %pvalues;
}

### save pValues
sub savePValues {
 my ($pvalues_ptr,$filename,$nvertices,$verbose,$debug) = @_;
 my %pvalues = %{$pvalues_ptr};
 open(FPout,">$filename") || printfatalerror "FATAL ERROR: Cannot create pValue file '".$filename."': $!";
  print FPout $nvertices."\n";
  for ( my $i=0 ; $i<$nvertices ; $i++ ) {
   if ( my $pvalue=$pvalues{$i} ) {
    my $formated = sprintf("%.6f",$pvalue);
    print FPout $formated."\n";
   } else {
    print FPout "0.000000\n";
   }
  }
 close(FPout);
}

### compute vertex topology: creates for every vertex the L1 vertex neighbor list
sub getVertexTopology {
 my ($meshdata_ptr,$verbose,$debug) = @_;
 print "meshtools.getVertexTopology(): Computing vertex mesh topology...\n" if ( $verbose );
 my %meshdata = %{$meshdata_ptr};
 my @simplices = @{$meshdata{"simplices"}};
 my $nsimplices = @simplices;
 $nsimplices /= 3;
 my %meshtopology = ();
 my $ii = 0;
 for ( my $i=0 ; $i<$nsimplices ; $i++ ) {
  for ( my $j=0 ; $j<3 ; $j++ ) {
   my $ivertex = $simplices[$ii+$j];
   for ( my $jj=0 ; $jj<3 ; $jj++ ) {
    next if ( $jj==$j );
    $meshtopology{$ivertex} .= $simplices[$ii+$jj].",";
   }
  }
  $ii += 3;
 }
 my %meshtopodata = ();
 while ( my ($key,$value)=each(%meshtopology) ) {
  chop($value);
  @{$meshtopodata{$key}} = removeDoubleEntriesFromArray(split(/\,/,$value));
  ## print " vertex[$key]=(@{$meshtopodata{$key}})\n";
 }
 return %meshtopodata;
}

### compute face topology: creates for every vertex a list of the L1 triangles
sub getSimplexTopology {
 my ($meshdata_ptr,$verbose,$debug) = @_;
 my %meshdata = %{$meshdata_ptr};
 my $nvertices = $meshdata{"nvertices"};
 my @vertices = @{$meshdata{"vertices"}};
 my @simplices = @{$meshdata{"simplices"}};
 my $nsimplices = $meshdata{"nfaces"};
 if ( $verbose ) {
  print "meshtools.getSimplexTopology(): Computing simplex mesh topology of ".$nsimplices." simplices...\n";
  print " + nvertices=".$nvertices.", nsimplices=".$nsimplices."|".scalar(@simplices)."\n";
 }
 my %meshtopology = ();
 my $ii = 0;
 for ( my $i=0 ; $i<$nsimplices ; $i++ ) {
  for ( my $j=0 ; $j<3 ; $j++ ) {
   ## print " simplex[".($ii+$j)."]=".$simplices[$ii+$j]."\n";
   $meshtopology{$simplices[$ii+$j]} .= $i.",";
  }
  $ii += 3;
 }
 my %meshtopodata = ();
 while ( my ($key,$value)=each(%meshtopology) ) {
  chop($value);
  @{$meshtopodata{$key}} = removeDoubleEntriesFromArray(split(/\,/,$value));
 }
 return %meshtopodata;
}

### compute triangle area: values={(x1,y1,z1):(x2,y2,z2):(x3,y3,z3)}
sub getTriangleArea {
 my ($values_ptr,$verbose) = @_;
 my @values = @{$values_ptr};
 my $x1 = $values[3]-$values[0];
 my $y1 = $values[4]-$values[1];
 my $z1 = $values[5]-$values[2];
 my $x2 = $values[6]-$values[0];
 my $y2 = $values[7]-$values[1];
 my $z2 = $values[8]-$values[2];
 my $x = $y1*$z2-$z1*$y2;
 my $y = $z1*$x2-$x1*$z2;
 my $z = $x1*$y2-$y1*$x2;
 return 0.5*sqrt($x*$x+$y*$y+$z*$z);
}
### compute surface area sum
sub _getSum {
 my $vector_ptr = shift;
 my @vector = @{$vector_ptr};
 my $sum = 0.0;
 foreach my $value (@vector) {
  $sum += $value;
 }
 return $sum;
}

### computes the dual vertex areas
sub getVertexDualAreaValues {
 my ($meshdata_ptr,$verbose) = @_;
 my %meshdata = %{$meshdata_ptr};
 print "meshtools::getVertexDualAreaValues(): Processing '".$meshdata{"filename"}."'...\n" if ( $verbose );
 my @simplices = @{$meshdata{"simplices"}};
 my $nsimplices = $meshdata{"nfaces"};
 my @vertices = @{$meshdata{"vertices"}};
 my $nvertices = $meshdata{"nvertices"};
 ## compute list of neighbor triangles for each vertex
 print " + computing vertex/triangle topology: nverts=$nvertices, nfaces=$nsimplices...\n" if ( $verbose );
 my $ii = 0;
 my %meshvtopology = ();
 my @triangleareas = ();
 for ( my $i=0 ; $i<$nsimplices ; $i++ ) {
  my @tricoords = ();
  for ( my $j=0 ; $j<3 ; $j++ ) {
   my $ivertex = $simplices[$ii+$j];
   my $vp = 3*$ivertex;
   $meshvtopology{$ivertex} .= $i.",";
   push(@tricoords,($vertices[$vp],$vertices[$vp+1],$vertices[$vp+2]));
  }
  push(@triangleareas,getTriangleArea(\@tricoords,$verbose));
  $ii += 3;
 }
 my $surfarea1 = _getSum(\@triangleareas);
 ## compute dual vertex areas
 print " + computing dual vertex areas...\n" if ( $verbose );
 my @dualareas = ();
 for ( my $i=0 ; $i<$nvertices ; $i++ ) {
  my @triangles = split("\,",$meshvtopology{$i});
  my $area = 0.0;
  foreach my $triangle (@triangles) {
   $area += $triangleareas[$triangle];
  }
  $area = 1.0/3.0*$area;
  push(@dualareas,$area);
 }
 my $surfarea2 = _getSum(\@dualareas);
 print " + surface areas: origmesh=$surfarea1, dualmesh=$surfarea2\n" if ( $verbose );
 return @dualareas;
}

### >>>
sub getMeshSurface {
 my ($meshdata_ptr,$verbose) = @_;
 my %meshdata = %{$meshdata_ptr};
 print "meshtools::getMeshSurface(): Processing '".$meshdata{"filename"}."'...\n" if ( $verbose );
 my $totalSurfArea = 0.0;
 my @simplices = @{$meshdata{"simplices"}};
 my $nsimplices = $meshdata{"nfaces"};
 my @vertices = @{$meshdata{"vertices"}};
 my $nvertices = $meshdata{"nvertices"};
 print " + computing total surface area: nverts=$nvertices, nfaces=$nsimplices...\n" if ( $verbose );
 my $ii = 0;
 for ( my $i=0 ; $i<$nsimplices ; $i++ ) {
  my @tricoords = ();
  for ( my $j=0 ; $j<3 ; $j++ ) {
   my $ivertex = $simplices[$ii+$j];
   my $vp = 3*$ivertex;
   push(@tricoords,($vertices[$vp],$vertices[$vp+1],$vertices[$vp+2]));
  }
  $ii += 3;
  $totalSurfArea += getTriangleArea(\@tricoords,$verbose);
 }
 print " + surface area: $totalSurfArea\n" if ( $verbose );
 return $totalSurfArea;
}

### computes the area of a given surface patch
### returns an area with the total area and the individual tri areas
sub getSurfacePatchArea {
 my ($meshdata_ptr,$patchtriangles_ptr,$verbose,$debug) = @_;
 my %meshdata = %{$meshdata_ptr};
 print "meshtools::getSurfacePatchArea(): Processing '".$meshdata{"filename"}."'...\n" if ( $verbose );
 my @simplices = @{$meshdata{"simplices"}};
 my $nsimplices = $meshdata{"nfaces"};
 my @vertices = @{$meshdata{"vertices"}};
 my $nvertices = $meshdata{"nvertices"};
 my @patchtriangles = @{$patchtriangles_ptr};
 my $area = 0.0;
 my @areas = ();
 foreach my $triangle (@patchtriangles) {
  my $n3t = 3*$triangle;
  my @tricoords = ();
  for ( my $i=0 ; $i<3 ; $i++ ) {
   my $vidx = 3*$simplices[$n3t+$i];
   push(@tricoords,($vertices[$vidx],$vertices[$vidx+1],$vertices[$vidx+2]));
  }
  my $triarea = getTriangleArea(\@tricoords,$verbose);
  push(@areas,$triarea);
  $area += $triarea;
 }
 unshift(@areas,$area);
 return @areas;
}

### >>>
sub getMeshLabelDataRange {
 my ($labeldata_ptr,$verbose,$debug) = @_;
 my @labels = @{$labeldata_ptr};
 my $fmin = 1000000;
 my $fmax = -$fmin;
 foreach my $label (@labels) {
  $fmin = $label if ( $label<$fmin );
  $fmax = $label if ( $label>$fmax );
 }
 return ($fmin,$fmax);
}

### (unweighted) filter vertex labels
sub rescaleMeshLabels {
 my ($labeldata_ptr,$low,$high,$verbose,$debug) = @_;
 print "meshtools::rescaleMeshLabels(): Rescaling label data at range ($low:$high)...\n" if ( $verbose );
 my @labels = @{$labeldata_ptr};
 my @rlabels = ();
 my $delta = $high-$low;
 foreach my $label (@labels) {
  if ( $label>=$high ) {
   push(@rlabels,255.0);
  } elsif ( $label>=$low ) {
   push(@rlabels,255.0*($label-$low)/$delta);
  } else {
   push(@rlabels,0.0);
  }
 }
 return @rlabels;
}
sub clusterFilterMeshLabels {
 my ($labeldata_ptr,$meshtopology_ptr,$verbose,$debug) = @_;
 print "meshtools::clusterFilterMeshLabels(): Clustering label data...\n" if ( $verbose );
 my @labels = @{$labeldata_ptr};
 my %meshtopology = %{$meshtopology_ptr};
 my @clabels = ();
 my @visited = ();
 for ( my $n=0 ; $n<scalar(@labels) ; $n++ ) {
  push(@clabels,0);
  push(@visited,0);
 }
 my $ll = 0;
 my $n = 0;
 my $clsid = 1;
 foreach my $label (@labels) {
  if ( $label>0.0 && $visited[$n]==0 ) {
   print "DEBUG: Found new cluster $clsid starting at index $n...\n" if ( $debug );
   my @nlist = ($n);
   do {
    my @newlist = ();
    foreach my $nn (@nlist) {
     $visited[$nn] = 1;
     $clabels[$nn] = $clsid;
     my @neighborIdents = @{$meshtopology{$nn}};
     print " topo[n=$nn]=(@neighborIdents)\n" if ( $debug );
     foreach my $neighborIdent (@neighborIdents) {
      if ( $labels[$neighborIdent]>0.0 && $visited[$neighborIdent]==0 ) {
       print "  + add label $neighborIdent to newlist...\n" if ( $debug );
       $clabels[$neighborIdent] = $clsid;
       $visited[$neighborIdent] = 1;
       push(@newlist,$neighborIdent);
      }
     }
    }
    print " - $ll - newlist=(@newlist)\n" if ( $debug );
    @nlist = @newlist;
    $ll += 1;
   } while ( scalar(@nlist)!=0 );
   $clsid += 1;
  }
  $n += 1;
 }
 $clsid -= 1;
 print "  + found $clsid cluster(s).\n" if ( $verbose );
 return @clabels;
}
sub thresholdFilterMeshLabels {
 my ($labeldata_ptr,$low,$high,$verbose,$debug) = @_;
 print "meshtools::thresholdFilterMeshLabels(): Thresholding label data at low=$low and high=$high...\n" if ( $verbose );
 my @labels = @{$labeldata_ptr};
 my @flabels = ();
 foreach my $label (@labels) {
  if ( $label>=$low && $label<=$high ) {
   push(@flabels,$label);
  } else {
   push(@flabels,0.0);
  }
 }
 return @flabels;
}
sub edgeFilterMeshLabels {
 my ($labeldata_ptr,$meshdata_ptr,$meshtopology_ptr,$verbose,$debug) = @_;
 print "meshtools::edgeFilterMeshLabels(): Edge filtering label data...\n" if ( $verbose );
 my $nEdgePoints = 0;
 my @labels = @{$labeldata_ptr};
 my %meshdata = %{$meshdata_ptr};
 my @vertices = @{$meshdata{"vertices"}};
 my %meshtopology = %{$meshtopology_ptr};
 my %edgelist = ();
 for ( my $i=0 ; $i<scalar(@labels) ; $i++ ) {
  my $label = $labels[$i];
  ## print "label[$i]=$label\n";
  my $foundedge = 0;
  my @neighborIdents = @{$meshtopology{$i}};
  my $nneighbors = scalar(@neighborIdents);
  if ( $nneighbors>0 ) {
   foreach my $neighborIdent (@neighborIdents) {
    my $nlabel = $labels[$neighborIdent];
    if ( $nlabel!=$label ) {
     my $pairident = min($i,$neighborIdent)."-".max($i,$neighborIdent);
     if ( !exists($edgelist{$pairident}) ) {
      my $np1 = 3*$i;
      my $x1 = $vertices[$np1+0];
      my $y1 = $vertices[$np1+1];
      my $z1 = $vertices[$np1+2];
      my $np2 = 3*$neighborIdent;
      my $x2 = $vertices[$np2+0];
      my $y2 = $vertices[$np2+1];
      my $z2 = $vertices[$np2+2];
      my $x12 = 0.5*($x1+$x2);
      my $y12 = 0.5*($y1+$y2);
      my $z12 = 0.5*($z1+$z2);
      print "  + found new edge: label[$i](".$x1.":".$y1.":".$z1.")=$label <-> nlabel[$neighborIdent](".$x2.":".$y2.":".$z2.")=$nlabel -> point(".$x12.":".$y12.":".$z12.")\n";
      $nEdgePoints += 1;
      @{$edgelist{$pairident}} = ($x12,$y12,$z12);
     }
    }
   }
  }
 }
 print " + found ".$nEdgePoints ." edge points.\n" if ( $verbose );
 return %edgelist;
}
sub meanFilterMeshLabels {
 my ($labeldata_ptr,$meshtopology_ptr,$verbose,$debug) = @_;
 print "meshtools::meanFilterMeshLabels(): Mean filtering label data...\n" if ( $verbose );
 my @labels = @{$labeldata_ptr};
 my %meshtopology = %{$meshtopology_ptr};
 my @flabels = ();
 for ( my $i=0 ; $i<scalar(@labels) ; $i++ ) {
  my @neighborIdents = @{$meshtopology{$i}};
  push(@neighborIdents,$i);
  my $sum = 0;
  my $nneighbors = scalar(@neighborIdents);
  if ( $nneighbors>0 ) {
   foreach my $neighborIdent (@neighborIdents) {
    $sum += $labels[$neighborIdent];
   }
   push(@flabels,$sum/$nneighbors); ## _roundToUInt8($sum/$nneighbors));
  } else {
   push(@flabels,0.0);
  }
 }
 return @flabels;
}
## fill smaller holes by computing for each label the summed distance and use for the hole
## the label with the shortest mean distance
sub fillHolesFilterMeshLabels {
 my ($labelId,$labeldata_ptr,$flabeldata_ptr,$meshdata_ptr,$meshtopology_ptr,$verbose,$debug) = @_;
 print "meshtools::fillHolesFilterMeshLabels(): Filling holes of label ".$labelId." data...\n" if ( $verbose );
 my %meshdata = %{$meshdata_ptr};
 my @labels = @{$labeldata_ptr};
 my @flabels = @{$flabeldata_ptr};
 my @vertices = @{$meshdata{"vertices"}};
 my %meshtopology = %{$meshtopology_ptr};
 for ( my $i=0 ; $i<scalar(@labels) ; $i++ ) {
  if ( $labels[$i]==$labelId ) {
   my $outstring = "";
   my @neighborIdents = @{$meshtopology{$i}};
   my %labellist = ();
   foreach my $neighborIdent (@neighborIdents) {
    my $nLabelIdent = $labels[$neighborIdent];
    $outstring .= $neighborIdent."//".$nLabelIdent.",";
    $labellist{$nLabelIdent} = [] unless ( exists($labellist{$nLabelIdent}) );
    push(@{$labellist{$nLabelIdent}},$neighborIdent);
   }
   chop($outstring);
   my $np = 3*$i;
   my $x = $vertices[$np+0];
   my $y = $vertices[$np+1];
   my $z = $vertices[$np+2];
   print "  + vertex[".$i."|(".$x.":".$y.":".$z.")]=".$outstring."\n" if ( $verbose );
   my $minDistanceValue = 1000000;
   my $minDistanceLabelId = -1;
   while ( my ($key,$value) = each(%labellist) ) {
    my @values = @{$value};
    my $nvalues = scalar(@values);
    my $distance = 0.0;
    for ( my $k=0 ; $k<$nvalues ; $k++ ) {
     $np = 3*$values[$k];
     my $dx = $x-$vertices[$np+0];
     my $dy = $y-$vertices[$np+1];
     my $dz = $z-$vertices[$np+2];
     my $ndistance = sqrt($dx*$dx+$dy*$dy+$dz*$dz);
     print "   + distance between label ".$i." and label ".$values[$k]."=".$ndistance."\n" if ( $verbose );
     $distance += $ndistance;
    }
    $distance = $distance/$nvalues;
    if ( $distance<$minDistanceValue && $key!=$labelId ) {
     $minDistanceValue = $distance;
     $minDistanceLabelId = $key;
    }
    print "    + label=$key -> ".join(",",@values)." > distance[".$nvalues."]=".$distance."\n" if ( $verbose );
   }
   if ( $minDistanceLabelId>=0 ) {
    print "  + found for vertex ".$i." bestValue for minDistance=".$minDistanceValue.", labelId=".$minDistanceLabelId.".\n" if ( $verbose );
    $flabels[$i] = $minDistanceLabelId;
   } else {
    printwarning "WARNING: Cannot find any valid label for hole at vertex $i.\n";
   }
  }
 }
 return @flabels;
}
sub medianFilterMeshLabels {
 my ($labeldata_ptr,$meshtopology_ptr,$verbose,$debug) = @_;
 print "meshtools::medianFilterMeshLabels(): Median filtering label data...\n" if ( $verbose );
 my @labels = @{$labeldata_ptr};
 my %meshtopology = %{$meshtopology_ptr};
 my @flabels = ();
 for ( my $i=0 ; $i<scalar(@labels) ; $i++ ) {
  my @neighborIdents = @{$meshtopology{$i}};
  push(@neighborIdents,$i);
  my @values = ();
  my $nneighbors = scalar(@neighborIdents);
  if ( $nneighbors>0 ) {
   foreach my $neighborIdent (@neighborIdents) {
    push(@values,$labels[$neighborIdent]);
   }
   my @nvalues = sort {$a <=> $b} @values;
   push(@flabels,$nvalues[$nneighbors/2]);
  } else {
   push(@flabels,0.0);
  }
 }
 return @flabels;
}
sub getLabelPatchDistanceValues {
 my ($labeldata_ptr,$meshtopology_ptr,$verbose,$debug) = @_;
 print "meshtools::getLabelPatchDistanceValues(): Processing...\n" if ( $verbose );
 my %distances = ();
 my @indices = @{$labeldata_ptr};
 for ( my $i=0 ; $i<scalar(@indices) ; $i++ ) {
  $distances{$indices[$i]} = -1;
 }
 my %meshtopology = %{$meshtopology_ptr};
 my $maxNIterations = 50;
 my $k = 1;
 for ( ; $k<=$maxNIterations ; $k++ ) {
  print "  + iteration $k...\n" if ( $verbose );
  for ( my $i=0 ; $i<scalar(@indices) ; $i++ ) {
   if ( $distances{$indices[$i]}==-1 ) {
    my @neighborIdents = @{$meshtopology{$indices[$i]}};
    push(@neighborIdents,$indices[$i]);
    my $mindist = 10000;
    my $ncounts = 0;
    my $nneighbors = scalar(@neighborIdents);
    ### print "****processing: index=".$indices[$i].", neighs[".$nneighbors."]=(".join(",",@neighborIdents).")\n";
    foreach my $neighborIdent (@neighborIdents) {
     if ( !exists($distances{$neighborIdent}) ) {
      $distances{$indices[$i]} = 1;
      last;
     } else {
      if ( $distances{$neighborIdent}!=-1 ) {
       $mindist = min($mindist,int($distances{$neighborIdent}));
      } else {
       $ncounts += 1;
      }
     }
    }
    if ( $ncounts!=scalar(@neighborIdents) ) {
     $distances{$indices[$i]} = $k
    }
   }
  }
  my $needNewIteration = 0;
  while ( my ($index,$distance)=each(%distances) ) {
   if ( $distance==-1 ) {
    $needNewIteration = 1;
    last;
   }
  }
  last if ( $needNewIteration==0 );
 }
 print " + stopped after $k iterations.\n" if ( $verbose );
 return %distances;
}
sub minFilterMeshLabels {
 my ($labeldata_ptr,$meshtopology_ptr,$verbose,$debug) = @_;
 print "meshtools::minFilterMeshLabels(): Min filtering label data...\n" if ( $verbose );
 my @labels = @{$labeldata_ptr};
 my %meshtopology = %{$meshtopology_ptr};
 my @flabels = ();
 for ( my $i=0 ; $i<scalar(@labels) ; $i++ ) {
  my @neighborIdents = @{$meshtopology{$i}};
  push(@neighborIdents,$i);
  my @values = ();
  my $nneighbors = scalar(@neighborIdents);
  if ( $nneighbors>0 ) {
   foreach my $neighborIdent (@neighborIdents) {
    push(@values,$labels[$neighborIdent]);
   }
   my @nvalues = sort {$a <=> $b} @values;
   push(@flabels,$nvalues[0]);
  } else {
   push(@flabels,0.0);
  }
 }
 return @flabels;
}
sub maxFilterMeshLabels {
 my ($labeldata_ptr,$meshtopology_ptr,$verbose,$debug) = @_;
 print "meshtools::maxFilterMeshLabels(): Max filtering label data...\n" if ( $verbose );
 my @labels = @{$labeldata_ptr};
 my %meshtopology = %{$meshtopology_ptr};
 my @flabels = ();
 for ( my $i=0 ; $i<scalar(@labels) ; $i++ ) {
  my @neighborIdents = @{$meshtopology{$i}};
  push(@neighborIdents,$i);
  my @values = ();
  my $nneighbors = scalar(@neighborIdents);
  if ( $nneighbors>0 ) {
   foreach my $neighborIdent (@neighborIdents) {
    push(@values,$labels[$neighborIdent]);
   }
   my @nvalues = sort {$a <=> $b} @values;
   push(@flabels,$nvalues[$nneighbors-1]);
  } else {
   push(@flabels,0.0);
  }
 }
 return @flabels;
}
# see: "Heat Kernel Smoothing using Laplace-Beltrami Eigenfunctions", Moo K. Chung et al.
sub laplaceFilterMeshLabels {
 my ($labeldata_ptr,$meshdata_ptr,$meshtopology_ptr,$alpha,$niter,$verbose,$debug) = @_;
 print "meshtools.laplaceFilterMeshLabels(): Laplace diffusion filtering label data with alpha=$alpha and $niter iterations...\n" if ( $verbose );
 my $rescale = 1;
 my @labels = @{$labeldata_ptr};
 my %meshtopology = %{$meshtopology_ptr};
 my %meshdata = %{$meshdata_ptr};
 my @vertices = @{$meshdata{"vertices"}};
 # computing weight list for L1 neighbors
 my %neighborweights = ();
 my $ii = 0;
 for ( my $i=0 ; $i<scalar(@labels) ; $i++ ) {
  my @weights = ();
  my $sumweights = 0.0;
  my $x = $vertices[$ii+0];
  my $y = $vertices[$ii+1];
  my $z = $vertices[$ii+2];
  my @neighborIdents = @{$meshtopology{$i}};
  foreach my $neighborIdent (@neighborIdents) {
   my $ik = 3*$neighborIdent;
   my $dx = $x-$vertices[$ik+0];
   my $dy = $y-$vertices[$ik+1];
   my $dz = $z-$vertices[$ik+2];
   my $w = sqrt($dx*$dx+$dy*$dy+$dz*$dz);
   $sumweights += $w;
   push(@weights,$w);
  }
  push(@weights,$sumweights);
  @{$neighborweights{$i}} = @weights;
  $ii += 3;
 }
 # start iterations
 my @flabels = ();
 for ( my $n=0 ; $n<$niter ; $n++ ) {
  print "  + computing iteration $n of $niter iterations...\n" if ( $verbose );
  my $maxnv = 0.0;
  my $tmove = 0.0;
  if ( $n!=0 ) {
   @labels = ();
   @labels = @flabels;
   @flabels = ();
  }
  for ( my $i=0 ; $i<scalar(@labels) ; $i++ ) {
   my @neighborIdents = @{$meshtopology{$i}};
   my @neighborweights = @{$neighborweights{$i}};
   my $nneighbors = scalar(@neighborIdents);
   my $tweight = $neighborweights[-1];
   if ( $nneighbors>0 && $tweight!=0.0 ) {
    my $wsum = 0.0;
    for ( my $k=0 ; $k<$nneighbors ; $k++ ) {
     my $nValue  = $labels[$neighborIdents[$k]];
     my $nWeight = $neighborweights[$k];
     $wsum += $nValue*$nValue*$nWeight/$tweight;
    }
    my $dmove = $alpha*(sqrt($wsum)-$labels[$i]);
    my $nv = $labels[$i]+$dmove;
    $maxnv = $nv if ( $nv>$maxnv );
    if ( $labels[$i]>0.0 ) {
     $tmove += $dmove;
     $nv = 0.0 if ( $nv<0.0 );
     #if ( $nv>1.0 ) {
     # $nv = 1.0;
     #} elsif ( $nv<0.0 ) {
     # $nv = 0.0;
     #}
     push(@flabels,$nv);
    } else {
     push(@flabels,0.0);
    }
   } else {
    push(@flabels,0.0);
   }
  }
  print "   + maxnv: ".$maxnv.", total move: ".$tmove."\n" if ( $verbose );
  if ( $rescale && $maxnv<255.0 ) {
   my $sf = 255.0/$maxnv;
   my @tlabels = ();
   foreach my $flabel (@flabels) {
    push(@tlabels,$sf*$flabel)
   }
   @flabels = @tlabels;
  }
 }
 return @flabels;
}

sub getNumberOfNonZeroValues {
 my ($labeldata_ptr,$cutOff) = @_;
 my @labels = @{$labeldata_ptr};
 my $nzlabels = 0;
 for ( my $i=0 ; $i<scalar(@labels) ; $i++ ) {
  $nzlabels += 1 if ( $labels[$i]>$cutOff );
 }
 return $nzlabels;
}
## KNOWN BUG: still a little bit asymmetric
sub heatKernelSmoothingMeshLabels {
 my ($labeldata_ptr,$meshdata_ptr,$meshtopology_ptr,$sigma,$niter,$normalize,$maxLikeValue,$verbose,$debug) = @_;
 print "meshtools.heatKernelSmoothingMeshLabels(): Heat kernel ".($normalize?"":"un-")."normalized smoothing label data with sigma=$sigma, $niter iterations and like=$maxLikeValue...\n" if ( $verbose );
 my @labels = @{$labeldata_ptr};
 my $nlabels = scalar(@labels);
 my %meshtopology = %{$meshtopology_ptr};
 my %meshdata = %{$meshdata_ptr};
 my @vertices = @{$meshdata{"vertices"}};
 my @flabels = ();
 ### compute weights
 my %neighborweights = ();
 my $ii = 0;
 my $cutOff = 0.01;
 my $maxValue = -1000000.0;
 my $minValue = +1000000.0;
 my $nVertexLabels = 0;
 for ( my $i=0 ; $i<$nlabels ; $i++ ) {
  my $labelvalue = $labels[$i];
  $maxValue = $labelvalue if ( $labelvalue>$maxValue );
  $minValue = $labelvalue if ( $labelvalue<$minValue );
  $nVertexLabels += 1 if ( $labelvalue>$cutOff );
  my @weights = ();
  my $sumweights = 0.0;
  my $x = $vertices[$ii+0];
  my $y = $vertices[$ii+1];
  my $z = $vertices[$ii+2];
  my @neighborIdents = @{$meshtopology{$i}};
  foreach my $neighborIdent (@neighborIdents) {
   my $ik = 3*$neighborIdent;
   my $dx = $x-$vertices[$ik+0];
   my $dy = $y-$vertices[$ik+1];
   my $dz = $z-$vertices[$ik+2];
   print " dxyz[".$neighborIdent."]=(".$dx.":".$dy.":".$dz.")\n" if ( $debug );
   my $w = exp(-($dx*$dx+$dy*$dy+$dz*$dz)/(2*$sigma));
   $sumweights += $w;
   push(@weights,$w);
  }
  push(@weights,$sumweights);
  @{$neighborweights{$i}} = @weights;
  $ii += 3;
  print "xyz=(".$x.":".$y.":".$z."), weights=@weights\n" if ( $debug );
 }
 ### iterate
 print "  + number of non-zero labels ".getNumberOfNonZeroValues(\@labels,$cutOff).", range=[$minValue:$maxValue]\n" if ( $verbose );
 for ( my $n=0 ; $n<$niter ; $n++ ) {
  print "  + computing iteration ".($n+1)." of ".$niter." iterations...\n" if ( $verbose );
  if ( $n!=0 ) {
   @labels = @flabels;
   @flabels = ();
  }
  for ( my $i=0 ; $i<$nlabels ; $i++ ) {
   my $dconv = 0.0;
   my @neighborweights = @{$neighborweights{$i}};
   my $tweight = $neighborweights[-1];
   if ( $tweight!=0.0 ) {
    my @neighborIdents = @{$meshtopology{$i}};
    my $nneighbors = scalar(@neighborIdents);
    print "    + tweight=".$tweight.", nneighs=".$nneighbors."\n" if ( $debug );
    for ( my $k=0 ; $k<$nneighbors ; $k++ ) {
     $dconv += $labels[$neighborIdents[$k]]*$neighborweights[$k]/$tweight;
    }
   }
   push(@flabels,$dconv);
  }
 }
 if ( $normalize ) {
  ### normalizing data according max value (easy) and number of vertices (complex)
  my $mmaxValue = ($maxLikeValue>$maxValue)?$maxLikeValue:$maxValue;
  print "   + normalizing labels to [".$minValue.":".$mmaxValue."]...\n" if ( $verbose );
  my $maxfValue = 0.0;
  my $minfValue = 1000000.0;
  my $granularity = 0.01;
  my $maxLookup = 0.3;
  my @nRangeLabelValues = ();
  my $nRangeLabelValues = int($maxLookup/$granularity);
  print " >>>> nRangeLabelValues=$nRangeLabelValues\n" if ( $debug );
  for ( my $i=0 ; $i<=$nRangeLabelValues ; $i++ ) {
   push(@nRangeLabelValues,0);
  }
  my $nVertexfLabels = 0;
  for ( my $i=0 ; $i<$nlabels ; $i++ ) {
   my $labelvalue = $flabels[$i];
   $maxfValue = $labelvalue if ( $labelvalue>$maxfValue );
   $minfValue = $labelvalue if ( $labelvalue<$minfValue );
   $nVertexfLabels += 1 if ( $labelvalue>$cutOff );
   ## get number of vertices between data ranges for areal normalization
    if ( $labelvalue>$cutOff && $labelvalue<$maxLookup ) {
     my $idx = int($labelvalue/$granularity);
     $nRangeLabelValues[$idx] += 1;
    }
   ##
  }
  my $minCutOff = $cutOff;
  my $deltaNVertexLabels = $nVertexfLabels-$nVertexLabels;
  if ( $deltaNVertexLabels>0 ) {
   print "   + number of vertex labels: before=$nVertexLabels, after=$nVertexfLabels, delta=$deltaNVertexLabels\n" if ( $verbose );
   my $sum = 0;
   my $n = 1;
   while ( $sum<$deltaNVertexLabels && $n<$nRangeLabelValues ) {
    $sum += $nRangeLabelValues[$n];
    print "    ++ sum[$n]=$sum\n" if ( $debug );
    $n += 1;
   }
   $minCutOff = $n>1?($n-1)*$granularity:0.0;
   print "   + rangevalues[".$nRangeLabelValues."]=(".join(",",@nRangeLabelValues)."), min-cutoff=".$minCutOff."\n" if ( $verbose );
  }
  if ( $maxfValue!=0.0 ) {
   my $normfactor = $mmaxValue/($maxfValue-$minCutOff);
   for ( my $i=0 ; $i<$nlabels ; $i++ ) {
    if ( $flabels[$i]>$minCutOff ) {
     $flabels[$i] = ($flabels[$i]-$minCutOff)*$normfactor;
    } else {
     $flabels[$i] = 0.0;
    }
   }
  } else {
   print "   - WARNING: Maximum label value is 0.0!\n";
  }
 }
 print "   + number of non-zero labels ".getNumberOfNonZeroValues(\@flabels,$cutOff)."\n" if ( $verbose );
 return @flabels;
}

### filter rgb labels
sub meanFilterMeshRGBLabels {
 my ($labeldata_ptr,$meshtopology_ptr,$verbose) = @_;
 print "meshtools.meanFilterMeshRGBLabels(): Mean filtering label RGB data...\n" if ( $verbose );
 my %meshlabels = %{$labeldata_ptr};
 my %meshtopology = %{$meshtopology_ptr};
 my %flabels = ();
 while ( my ($key,$value)=each(%meshlabels) ) {
  my @neighborIdents = @{$meshtopology{$key}};
  push(@neighborIdents,$key);
  my $ncolors = 0;
  my $nred = 0;
  my $ngreen = 0;
  my $nblue = 0;
  foreach my $neighborIdent (@neighborIdents) {
   my @rgbcolor = @{$meshlabels{$neighborIdent}};
   if ( @rgbcolor==3 ) {
    $nred += $rgbcolor[0];
    $ngreen += $rgbcolor[1];
    $nblue += $rgbcolor[2];
    $ncolors += 1;
   }
  }
  $nred = _roundToUInt8($nred/$ncolors);
  $ngreen = _roundToUInt8($ngreen/$ncolors);
  $nblue = _roundToUInt8($nblue/$ncolors);
  @{$flabels{$key}} = ($nred,$ngreen,$nblue);
 }
 return %flabels;
}
sub medianFilterMeshRGBLabels {
 my ($labeldata_ptr,$meshtopology_ptr,$verbose) = @_;
 print "meshtools.medianFilterMeshRGBLabels(): Median filtering label data...\n" if ( $verbose );
 my %meshlabels = %{$labeldata_ptr};
 my %meshtopology = %{$meshtopology_ptr};
 my %flabels = ();
 while ( my ($key,$value)=each(%meshlabels) ) {
  my @neighborIdents = @{$meshtopology{$key}};
  push(@neighborIdents,$key);
  my @reds = ();
  my @greens = ();
  my @blues = ();
  foreach my $neighborIdent (@neighborIdents) {
   my @rgbcolor = @{$meshlabels{$neighborIdent}};
   if ( @rgbcolor==3 ) {
    push(@reds,$rgbcolor[0]);
    push(@greens,$rgbcolor[1]);
    push(@blues,$rgbcolor[2]);
   }
  }
  my @nreds = sort {$a <=> $b} @reds;
  my @ngreens = sort {$a <=> $b} @greens;
  my @nblues = sort {$a <=> $b} @blues;
  my $midpos = @nreds/2;
  @{$flabels{$key}} = ($nreds[$midpos],$ngreens[$midpos],$nblues[$midpos]);
 }
 return %flabels;
}

### >>>
sub flipfaceorientation {
 my ($meshdata_ptr,$verbose,$debug) = @_;
 my %meshdata = %{$meshdata_ptr};
 ### >>>
 my $nfaces = $meshdata{"nfaces"};
 my @simplices = @{$meshdata{"simplices"}};
 my @nsimplices = ();
 for ( my $i=0 ; $i<(3*$nfaces) ; $i+=3 ) {
  my $n1 = $simplices[$i];
  my $n2 = $simplices[$i+1];
  my $n3 = $simplices[$i+2];
  push(@nsimplices,($n3,$n2,$n1));
 }
 @{$meshdata{"simplices"}} = @nsimplices;
 ### >>>
 return %meshdata;
}

### >>>
sub computemeannormals {
 my ($meshdata_ptr,$flip,$verbose,$debug) = @_;
 print "meshtools.computemeannormals(): Computing mean normals...\n" if ( $verbose );
 my %meshdata = %{$meshdata_ptr};
 ### >>>
  # computing face normals
  my %vertexfaces = ();
  my @vertices = @{$meshdata{"vertices"}};
  my $nfaces = $meshdata{"nfaces"};
  my $nvertices = $meshdata{"nvertices"};
  my @simplices = @{$meshdata{"simplices"}};
  print " + nvertices=".$nvertices.", nfaces=".$nfaces."/".scalar(@simplices)."\n" if ( $verbose );
  my @nfacenormals = ();
  my $ii = 0;
  for ( my $i=0 ; $i<(3*$nfaces) ; $i+=3 ) {
   my @values = ();
   ### >>>
    my $n1 = $simplices[$i+0];
    push(@{$vertexfaces{$n1}},$ii);
    my $nn1 = 3*$n1;
    my $nx1 = $vertices[$nn1+0];
    my $ny1 = $vertices[$nn1+1];
    my $nz1 = $vertices[$nn1+2];
    push(@values,($nx1,$ny1,$nz1));
    ### >>>
    my $n2 = $simplices[$i+1];
    push(@{$vertexfaces{$n2}},$ii);
    my $nn2 = 3*$n2;
    my $nx2 = $vertices[$nn2+0];
    my $ny2 = $vertices[$nn2+1];
    my $nz2 = $vertices[$nn2+2];
    push(@values,($nx2,$ny2,$nz2));
    ### >>>
    my $n3 = $simplices[$i+2];
    push(@{$vertexfaces{$n3}},$ii);
    my $nn3 = 3*$n3;
    my $nx3 = $vertices[$nn3+0];
    my $ny3 = $vertices[$nn3+1];
    my $nz3 = $vertices[$nn3+2];
    push(@values,($nx3,$ny3,$nz3));
    ### >>>
    # print " n=(".$n1.":".$n2.":".$n3.")\n";
    if ( $debug ) {
     if ( $i<3 ) {
      print " face[$i](v[".$n1."]=(".$nx1.":".$ny1.":".$nz1."), v[".$n2."]=(".$nx2.":".$ny2.":".$nz2."), v[".$n3."]=(".$nx3.":".$ny3.":".$nz3."))\n";
     }
    }
    ### compute normal vector
    my $x1 = $values[3]-$values[0];
    my $y1 = $values[4]-$values[1];
    my $z1 = $values[5]-$values[2];
    my $x2 = $values[6]-$values[0];
    my $y2 = $values[7]-$values[1];
    my $z2 = $values[8]-$values[2];
    my $nx = $y1*$z2-$z1*$y2;
    my $ny = $z1*$x2-$x1*$z2;
    my $nz = $x1*$y2-$y1*$x2;
    my $norm = sqrt($nx*$nx+$ny*$ny+$nz*$nz);
    $norm = 1.0 if ( $norm==0.0 );
   ### >>>
   push(@nfacenormals,($nx/$norm,$ny/$norm,$nz/$norm));
   $ii += 1;
  }
  # >>>
  my $scale = 1.0;
  $scale *= -1.0 if ( $flip );
  my @normals = ();
  my $nvertices = $meshdata{"nvertices"};
  for ( my $i=0 ; $i<$nvertices ; $i++ ) {
   my ($nx,$ny,$nz) = (0.0,0.0,0.0);
   my @faces = @{$vertexfaces{$i}};
   foreach my $face (@faces) {
    my $face3 = 3*$face;
    $nx += $nfacenormals[$face3];
    $ny += $nfacenormals[$face3+1];
    $nz += $nfacenormals[$face3+2];
    print " + n[$face]($nx:$ny:$nz)\n" if ( $i==0 && $debug );
   }
   my $norm = sqrt($nx*$nx+$ny*$ny+$nz*$nz);
   $norm = 1.0 if ( $norm==0.0 );
   $norm *= $scale;
   push(@normals,(-$nx/$norm,-$ny/$norm,-$nz/$norm));
  }
  @{$meshdata{"normals"}} = @normals;
  # >>>
 ### >>>
 return %meshdata;
}

### >>>
sub transformmesh {
 my ($meshdata_ptr,$translations_ptr,$scales_ptr,$verbose,$debug) = @_;
 my %meshdata = %{$meshdata_ptr};
 my @translations = @{$translations_ptr};
 my @scales = @{$scales_ptr};
 if ( $verbose ) {
  print "transformmesh(): processing mesh '".$meshdata{"filename"}."': scales=(".$scales[0].":".$scales[1].":".$scales[2].")";
  print ", translations[n=".scalar(@translations)."](".$translations[0].":".$translations[1].":".$translations[2].")...\n";
 }
 my $xmin = 1000000000;
 my $ymin = $zmin = $xmin;
 my $xmax = $ymax = $zmax = -$xmin;
 my @procvertices = ();
 my @vertices = @{$meshdata{"vertices"}};
 my $nvertices = $meshdata{"nvertices"};
 if ( scalar(@translations)==6 ) {
  for ( my $i=0 ; $i<(3*$nvertices) ; $i+=3 ) {
   my $nx = ($vertices[$i+0]+$translations[0])*$scales[0];
   $nx += $translations[3];
   my $ny = ($vertices[$i+1]+$translations[1])*$scales[1];
   $ny += $translations[4];
   my $nz = ($vertices[$i+2]+$translations[2])*$scales[2];
   $nz += $translations[5];
   push(@procvertices,($nx,$ny,$nz));
   $xmin = $nx if ( $nx<$xmin );
   $xmax = $nx if ( $nx>$xmax );
   $ymin = $ny if ( $ny<$ymin );
   $ymax = $ny if ( $ny>$ymax );
   $zmin = $nz if ( $nz<$zmin );
   $zmax = $nz if ( $nz>$zmax );
  }
 } else {
  for ( my $i=0 ; $i<(3*$nvertices) ; $i+=3 ) {
   my $nx = ($vertices[$i+0]+$translations[0])*$scales[0];
   my $ny = ($vertices[$i+1]+$translations[1])*$scales[1];
   my $nz = ($vertices[$i+2]+$translations[2])*$scales[2];
   push(@procvertices,($nx,$ny,$nz));
   $xmin = $nx if ( $nx<$xmin );
   $xmax = $nx if ( $nx>$xmax );
   $ymin = $ny if ( $ny<$ymin );
   $ymax = $ny if ( $ny>$ymax );
   $zmin = $nz if ( $nz<$zmin );
   $zmax = $nz if ( $nz>$zmax );
  }
 }
 @{$meshdata{"vertices"}} = @procvertices;
 @{$meshdata{"range"}} = ($xmin,$xmax,$ymin,$ymax,$zmin,$zmax);
 return %meshdata;
}

### >>>
sub normalize2unitcube {
 my ($meshdata_ptr,$verbose,$debug) = @_;
 my %meshdata = %{$meshdata_ptr};
 print "meshtools.normalize2unitcube(): Normalizing mesh '".$meshdata{"filename"}."' to unit cube...\n" if ( $verbose );
 my @normedvertices = ();
 my @vertices = @{$meshdata{"vertices"}};
 my $nvertices = $meshdata{"nvertices"};
 my @xyzranges = @{$meshdata{"range"}};
 my $xrange = $xyzranges[1]-$xyzranges[0];
 my $maxrange = $xrange;
 my $yrange = $xyzranges[3]-$xyzranges[2];
 $maxrange = $yrange if ( $yrange>$maxrange );
 my $zrange = $xyzranges[5]-$xyzranges[4];
 $maxrange = $zrange if ( $zrange>$maxrange );
 my $hxrange = $xrange/2;
 my $hyrange = $yrange/2;
 my $hzrange = $zrange/2;
 my $xmin = 1000000000;
 my $ymin = $zmin = $xmin;
 my $xmax = $ymax = $zmax = -$xmin;
 print "  + range: ($xrange:$yrange:$zrange), max: $maxrange.\n" if ( $verbose );
 $maxrange = $maxrange/2;
 for ( my $i=0 ; $i<(3*$nvertices) ; $i+=3 ) {
  my $nx = ($vertices[$i+0]-($xyzranges[0]+$hxrange))/$maxrange;
  my $ny = ($vertices[$i+1]-($xyzranges[2]+$hyrange))/$maxrange;
  my $nz = ($vertices[$i+2]-($xyzranges[4]+$hzrange))/$maxrange;
  push(@normedvertices,($nx,$ny,$nz));
  $xmin = $nx if ( $nx<$xmin );
  $xmax = $nx if ( $nx>$xmax );
  $ymin = $ny if ( $ny<$ymin );
  $ymax = $ny if ( $ny>$ymax );
  $zmin = $nz if ( $nz<$zmin );
  $zmax = $nz if ( $nz>$zmax );
 }
 print "  + new datarange: x=($xmin:$xmax), y=($ymin:$ymax), z=($zmin:$zmax).\n" if ( $verbose );
 @{$meshdata{"vertices"}} = @normedvertices;
 return %meshdata;
}

### >>>
sub clipmesh {
 my ($meshdata_ptr,$clipbox_ptr,$verbose,$debug) = @_;
 my %meshdata = %{$meshdata_ptr};
 my @clipbox = @{$clipbox_ptr};
 print "meshtools.clipmesh(): Clipping mesh '".$meshdata{"filename"}."' with (@clipbox)...\n" if ( $verbose );
 my @normedvertices = ();
 my @vertices = @{$meshdata{"vertices"}};
 my $nvertices = $meshdata{"nvertices"};
 my @clippedfaces = ();
 my $nclippedfaces = 0;
 my @faces = @{$meshdata{"simplices"}};
 my $nfaces = $meshdata{"nfaces"};
 my $nIsInBox = 0;
 for ( my $i=0 ; $i<(3*$nfaces) ; $i+=3 ) {
  my $i1 = $faces[$i+0];
  my $i2 = $faces[$i+1];
  my $i3 = $faces[$i+2];
  my $n1 = 3*$i1;
  my $n2 = 3*$i2;
  my $n3 = 3*$i3;
  my ($x1,$y1,$z1) = ($vertices[$n1],$vertices[$n1+1],$vertices[$n1+2]);
  # print "DEBUG: face indices: v1[$i1]($x1:$y1:$z1): ($clipbox[0]:$clipbox[1] ++ $clipbox[2]:$clipbox[3] ++ $clipbox[2]:$clipbox[3])\n";
  if ( $x1>$clipbox[0] && $x1<$clipbox[1] && $y1>$clipbox[2] && $y1<$clipbox[3] && $z1>$clipbox[4] && $z1<$clipbox[5] ) {
   my ($x2,$y2,$z2) = ($vertices[$n2],$vertices[$n2+1],$vertices[$n2+2]);
   # print "DEBUG: face indices: v2[$i2]($x2:$y2:$z2)\n";
   if ( $x2>$clipbox[0] && $x2<$clipbox[1] && $y2>$clipbox[2] && $y2<$clipbox[3] && $z2>$clipbox[4] && $z2<$clipbox[5] ) {
    my ($x3,$y3,$z3) = ($vertices[$n3],$vertices[$n3+1],$vertices[$n3+2]);
    if ( $x3>$clipbox[0] && $x3<$clipbox[1] && $y3>$clipbox[2] && $y3<$clipbox[3] && $z3>$clipbox[4] && $z3<$clipbox[5] ) {
     $nIsInBox += 1;
    } else {
     push(@clippedfaces,($i1,$i2,$i3));
     $nclippedfaces += 1;
    }
   } else {
    push(@clippedfaces,($i1,$i2,$i3));
    $nclippedfaces += 1;
   }
  } else {
   push(@clippedfaces,($i1,$i2,$i3));
   $nclippedfaces += 1;
  }
 }
 @{$meshdata{"simplices"}} = @clippedfaces;
 $meshdata{"nfaces"} = $nclippedfaces;
 print "  + removed $nIsInBox (=".100.0*($nIsInBox/$nfaces)."\%) faces from mesh.\n" if ( $verbose );
 return %meshdata;
}

### >>>
sub isValidMeshOfType {
 my ($meshtype,$allowed,$debug) = @_;
 print "mshtools.isValidMeshOfType().DEBUG: meshtype='$meshtype', allowed=($allowed)\n" if ( $debug );
 my @allowedmeshes = split(/\,/,$allowed);
 foreach my $allowedmesh (@allowedmeshes) {
  return 1 if ( $allowedmesh =~ m/^$meshtype$/i );
 }
 return 0;
}

### >>>
sub loadMeshFile {
 my ($filename,$verbose,$debug,$hint) = @_;
 print "meshtools.loadMeshFile(): filename='".$filename."', hint=".$hint."\n" if ( $verbose );
 my %meshdata = ();
 if ( $filename =~ m/\.off$/i ) {
  %meshdata = loadOffFile($filename,$verbose,$debug);
 } elsif ( $filename =~ m/\.ply$/i ) {
  %meshdata = loadPLYFile($filename,$verbose,$debug);
 } elsif ( $filename =~ m/\.obj$/i ) {
  if ( defined($hint) && $hint=~m/^obj$/ ) {
   %meshdata = loadObjFile($filename,$verbose,$debug);
  } else {
   %meshdata = loadMNIObjFile($filename,$verbose,$debug);
  }
 } elsif ( $filename =~ m/\.jubd$/i || ( defined($hint) && $hint=~m/^jubd$/ ) ) {
  %meshdata = loadJuBrainMeshFile($filename,$verbose,$debug);
 } elsif ( $filename =~ m/\.poly$/i || ( defined($hint) && $hint=~m/^poly$/ ) ) {
  %meshdata = loadVTKPolyFile($filename,$verbose,$debug);
 } elsif ( $filename =~ m/\.vtk$/i ) {
  %meshdata = loadVTKMeshFile($filename,$verbose,$debug);
 } elsif ( $filename =~ m/\.asc$/ ) {
  %meshdata = loadGiftiFile($filename,$verbose,$debug);
 } elsif ( $filename =~ m/\.mesh$/ ) {
  %meshdata = loadBrainVisaMeshFile($filename,$verbose,$debug);
 } else {
  printfatalerror "meshtools.loadMeshFile(): FATAL ERROR: Unsupported input mesh type '".$filename."'.";
 }
 return %meshdata;
}

### >>>
sub saveMeshFile {
 my ($meshdata_ptr,$filename,$verbose,$debug,$hint) = @_;
 if ( $filename =~ m/\.poly$/ ) {
  if ( !saveVTKPolyFile($filename,$meshdata_ptr,$verbose,$debug) ) {
   printfatalerror "FATAL ERROR: Malfunction in 'saveVTKPolyFile(".$filename.")'.";
  }
 } elsif ( $filename =~ m/\.asc$/ ) {
  if ( !saveASCIIFile($filename,$meshdata_ptr,$verbose,$debug) ) {
   printfatalerror "FATAL ERROR: Malfunction in 'saveASCIIFile(".$filename.")'.";
  }
 } elsif ( $filename =~ m/\.gii$/ || $outfilename =~ m/\.gifti$/ ) {
  if ( !saveGiftiFile($filename,$meshdata_ptr,$verbose,$debug) ) {
   printfatalerror "FATAL ERROR: Malfunction in 'saveGiftiFile(".$filename.")'.";
  }
 } elsif ( $filename =~ m/\.itxt/ ) {
  if ( defined($hint) ) {
   if ( !saveVertexVolumeIndexFile($filename,$meshdata_ptr,$hint,$verbose,$debug) ) {
    printfatalerror "FATAL ERROR: Malfunction in 'saveVertexVolumeIndexFile(".$filename.")'.";
   }
  } else {
   printfatalerror "FATAL ERROR: Need data size hint.";
  }
 } elsif ( $filename =~ m/\.obj$/ ) {
  if ( defined($hint) && $hint =~ m/^mni$/i ) {
   if ( !saveMNIObjFile($filename,$meshdata_ptr,$verbose,$debug) ) {
    printfatalerror "FATAL ERROR: Malfunction in 'saveMNIObjFile(".$filename.")'.";
   }
  }
 } elsif ( $filename =~ m/\.off$/ ) {
  if ( !saveOffFile($filename,$meshdata_ptr,$verbose,$debug) ) {
   printfatalerror "FATAL ERROR: Malfunction in 'saveOffFile(".$filename.")'.";
  }
 } elsif ( $filename =~ m/\.ply$/ ) {
  if ( !savePLYFile($filename,$meshdata_ptr,$verbose,$debug) ) {
   printfatalerror "FATAL ERROR: Malfunction in 'savePLYFile(".$filename.")'.";
  }
 } elsif ( $filename =~ m/\.stl$/ ) {
  if ( !saveSTLFile($filename,$meshdata_ptr,$verbose,$debug) ) {
   printfatalerror "FATAL ERROR: Malfunction in 'saveSTLFile(".$filename.")'.";
  }
 } elsif ( $filename =~ m/\.jubd$/ ) {
  if ( defined($hint) && $hint =~ m/^poly$/i ) {
   if ( !saveJuBrainPolyFile($filename,$meshdata_ptr,$verbose,$debug) ) {
    printfatalerror "FATAL ERROR: Malfunction in 'saveJuBrainPolyFile(".$filename.")'.";
   }
  } else {
   if ( !saveJuBrainMeshFile($filename,$meshdata_ptr,$verbose,$debug) ) {
    printfatalerror "FATAL ERROR: Malfunction in 'saveJuBrainMeshFile(".$filename.")'.";
   }
  }
 } elsif ( defined($hint) && $hint =~ m/^jubd$/i ) {
  if ( !saveJuBrainMeshFile($filename,$meshdata_ptr,$verbose,$debug) ) {
   printfatalerror "FATAL ERROR: Malfunction in 'saveJuBrainMeshFile(".$filename.")'.";
  }
 } else {
  printfatalerror "FATAL ERROR: Unsupported output mesh type '".$filename."'.";
 }
 return 1;
}

#### end of modules
sub _debug { warn "@_\n" if $DEBUG; }

### return value (required to evaluate to TRUE)
1;
