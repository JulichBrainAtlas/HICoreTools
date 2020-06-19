## hitperl::volmesh package
########################################################################################################

### >>>
package hitperl::volmesh;

### >>>
use hitperl;
use File::Path;
use POSIX qw/floor/;
use POSIX qw/ceil/;
use List::Util qw[min max];
use Exporter;

### local includes
use hitperl::meshtools;

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'saveVertexVolumeIndexFile' );
$VERSION = 0.1;

#### start modules

## see 'https://www.geeksforgeeks.org/bresenhams-algorithm-for-3-d-line-drawing/'
sub getBresenhamPoints {
 my ($x0,$y0,$x1,$y1) = @_;
 ## print "getBresenhamPoints(): p1=(".$x0.":".$y0."), p2=(".$x1.":".$y1.")\n";
 return ($x0,$y0,$x1,$y1);
 
 my @linepoints = ();
 my $steep = abs($y1-$y0)>abs($x1-$x0);
 if ( $steep ) {
  ($x0,$y0) = ($y0,$x0);
  ($x1,$y1) = ($y1,$x1);
 }
 if ( $x0>$x1 ) {
  ($x0,$x1) = ($x1,$x0);
  ($y0,$y1) = ($y1,$y0);
 }
 my $dx = $x1-$x0;
 my $dy = abs($y1-$y0);
 my $error = 0;
 my $derror = $dy/$dx;
 my $ystep = $y0<$y1?1:-1;
 my $y = $y0;
 ## for $x0 .. $x1 -> $x {
 for ( my $x=$x0 ; $x<=$x1 ; $x++ ) {
  if ( $steep ){
   push(@linepoints,$y);
   push(@linepoints,$x);
  } else {
   push(@linepoints,$x);
   push(@linepoints,$y);
  }
  $error += $derror;
  if ( $error>=0.5 ) {
   $y += $ystep;
   $error -= 1.0;
  }
 }
 # print " + got ".scalar(@linepoints)." bresenham points (".join(",",@linepoints).")\n";
 return @linepoints;
}

### origin: (-82.66,-61.66,-70.66)
sub getNewSpacePointOld {
 my ($point_ptr,$size_ptr,$origin_ptr,$aspect_ptr) = @_;
 my @point = @{$point_ptr};
 my @size = @{$size_ptr};
 my @origin = @{$origin_ptr};
 my @aspect = @{$aspect_ptr};
 my $x = max(0,min($size[0],floor((-$point[1]-$origin[0])/$aspect[0])));
 my $y = max(0,min($size[1],floor((-$point[2]-$origin[1])/$aspect[1])));
 my $z = max(0,min($size[2],floor($size[2]-($point[0]-$origin[2])/$aspect[2])));
 return ($x,$y,$z);
}

### origin: old=(-70.66,-72.87,-58.77), new=(-72.87,-58.77,-70.66)
# with floor round
sub getNewSpacePoint {
 my ($point_ptr,$size_ptr,$origin_ptr,$aspect_ptr) = @_;
 my @point = @{$point_ptr};
 my @size = @{$size_ptr};
 my @origin = (-72.87,-58.77,-70.66);
 my @aspect = @{$aspect_ptr};
 my $x = max(0,min($size[0],floor($size[0]-($point[1]-$origin[0])/$aspect[0])));
 my $y = max(0,min($size[1],floor($size[1]-($point[2]-$origin[1])/$aspect[1])));
 my $z = max(0,min($size[2],floor($size[2]-($point[0]-$origin[2])/$aspect[2])));
 return ($x,$y,$z);
}
# get bounding box indices of space point
sub getNewSpacePointIndices {
 my ($point_ptr,$size_ptr,$origin_ptr,$aspect_ptr) = @_;
 my @point = @{$point_ptr};
 my @size = @{$size_ptr};
 my $xysize = $size[0]*$size[1];
 my @origin = (-72.87,-58.77,-70.66);
 my @aspect = @{$aspect_ptr};
 my $x = $size[0]-($point[1]-$origin[0])/$aspect[0];
 my $y = $size[1]-($point[2]-$origin[1])/$aspect[1];
 my $z = $size[2]-($point[0]-$origin[2])/$aspect[2];
 my $l1x = floor($x);
 my $l1y = floor($y);
 my $l1z = floor($z);
 my $h1x = ceil($x);
 my $h1y = ceil($y);
 my $h1z = ceil($z);
 my @rindices = ();
 push(@rindices,$l1z*$xysize+$l1y*$size[0]+$l1x);
 push(@rindices,$l1z*$xysize+$l1y*$size[0]+$h1x);
 push(@rindices,$l1z*$xysize+$h1y*$size[0]+$l1x);
 push(@rindices,$l1z*$xysize+$h1y*$size[0]+$h1x);
 push(@rindices,$h1z*$xysize+$l1y*$size[0]+$l1x);
 push(@rindices,$h1z*$xysize+$l1y*$size[0]+$h1x);
 push(@rindices,$h1z*$xysize+$h1y*$size[0]+$l1x);
 push(@rindices,$h1z*$xysize+$h1y*$size[0]+$h1x);
 return @rindices;
}

sub getIntersectionPoint {
 my ($vertices_ptr,$size_ptr,$origin_ptr,$aspect_ptr,$xi,$v1,$v2) = @_;
 my @vertices = @{$vertices_ptr};
 my @size = @{$size_ptr};
 my @origin = @{$origin_ptr};
 my @aspect = @{$aspect_ptr};
 my @point1 = ($vertices[3*$v1+0],$vertices[3*$v1+1],$vertices[3*$v1+2]);
 my @xyz1 = getNewSpacePoint(\@point1,$size_ptr,$origin_ptr,$aspect_ptr);
 ## print(" p1[".$v1."]=(".join(":",@xyz1).")\n");
 my @point2 = ($vertices[3*$v2+0],$vertices[3*$v2+1],$vertices[3*$v2+2]);
 my @xyz2 = getNewSpacePoint(\@point2,$size_ptr,$origin_ptr,$aspect_ptr);
 ## print(" p2[".$v2."]=(".join(":",@xyz2).")\n");
 my $lambda = ($xi-$xyz1[0])/($xyz2[0]-$xyz1[0]);
 my $yi = $xyz1[1]+$lambda*($xyz2[1]-$xyz1[1]);
 my $zi = $xyz1[2]+$lambda*($xyz2[2]-$xyz1[2]);
 return ($xi,$yi,$zi);
}
sub getMeanPoint {
 my ($vertices_ptr,$v1,$v2) = @_;
 my @vertices = @{$vertices_ptr};
 my $vv1 = 3*$v1;
 my $vv2 = 3*$v2;
 my $x1 = $vertices[$vv1+0];
 my $y1 = $vertices[$vv1+1];
 my $z1 = $vertices[$vv1+2];
 my $x2 = $vertices[$vv2+0];
 my $y2 = $vertices[$vv2+1];
 my $z2 = $vertices[$vv2+2];
 return (0.5*($x1+$x2),0.5*($y1+$y2),0.5*($z1+$z2));
}
sub saveVertexVolumeIndexFile {
 my ($filename,$meshdata_ptr,$hint,$verbose,$debug) = @_;
 my %meshdata = %{$meshdata_ptr};
 my @vertices = @{$meshdata{"vertices"}};
 my $nvertices = $meshdata{"nvertices"};
 my @simplices = @{$meshdata{"simplices"}};
 my $nsimplices = scalar(@simplices);
 my @values = split(/x/,$hint);
 my @size = ($values[0],$values[1],$values[2]);
 my $extended = $values[3] if ( scalar(@values)>3 );
 my $oversampling = 1;
 $oversampling = 0 if ( $extended==1 );
 print "volmesh.saveVertexVolumeIndexFile(): extended=$extended, oversampling=$oversampling\n" if ( $verbose );
 my %volindices = ();
 ## -70.66 -72.87 -58.77
 my $xorigin = -82.66;  ## $values[3];   // front-back
 my $yorigin = -61.66;  ## $values[4];   // up-and-down
 my $zorigin = -70.66;  ## $values[5];   // left-right
 my @origin = ($xorigin,$yorigin,$zorigin);
 my @aspect = (0.3,0.3,0.3);
 my $xysize = $size[0]*$size[1];
 my $outvalue = 128;
 open(FPout,">$filename") || die "FATAL ERROR: Cannot save volume index file '".$filename."': $!";
  print FPout "IRF UBYTE ".$size[0]." ".$size[1]." ".$size[2]."\n";
  ## face run
  my $perFace = 0;
  if ( $perFace ) {
   my $ii = 0;
   for ( my $ik=0 ; $ik<$nsimplices ; $ik+=3 ) {
    my $v1 = $simplices[$ii+0];
    my $x1 = (-$vertices[3*$v1+1]-$origin[0])/$aspect[0];
    my $v2 = $simplices[$ii+1];
    my $x2 = (-$vertices[3*$v2+1]-$origin[0])/$aspect[0];
    my $v3 = $simplices[$ii+2];
    my $x3 = (-$vertices[3*$v3+1]-$origin[0])/$aspect[0];
    my @inters = ();
    ### check x1 and x2
     my $xmin1 = min($x1,$x2);
     my $xmax1 = max($x1,$x2);
     if ( $xmin1<floor($xmax1) ) {
      push(@inters,floor($xmax1));
      push(@inters,0);
      push(@inters,1);
     }
    ### check x1 and x3
     my $xmin2 = min($x1,$x3);
     my $xmax2 = max($x1,$x3);
     if ( $xmin2<floor($xmax2) ) {
      push(@inters,floor($xmax2));
      push(@inters,0);
      push(@inters,2);
     }
    ### check x2 and x3
     my $xmin3 = min($x2,$x3);
     my $xmax3 = max($x2,$x3);
     if ( $xmin3<floor($xmax3) ) {
      push(@inters,floor($xmax3));
      push(@inters,1);
      push(@inters,2);
     }
    ### >>>
    if ( scalar(@inters)==6 ) {
     # print " v1=(".$x1."), v2=(".$x2."), v3=(".$x3."), inters=(".join(",",@inters).")\n";
     my $xinter = $inters[0];
     ## get intersection points
      my @p1 = getIntersectionPoint(\@vertices,\@size,\@origin,\@aspect,$xinter,$inters[1],$inters[2]);
      my @p2 = getIntersectionPoint(\@vertices,\@size,\@origin,\@aspect,$xinter,$inters[4],$inters[5]);
      # print "***  p1=(".$p1[0].":".$p1[1].":".$p1[2]."), p2=(".$p2[0].":".$p2[1].":".$p2[2].")\n";
      my $x1 = floor($p1[1]);
      my $y1 = floor($p1[1]+.5);
      my $z1 = floor($p1[2]+.5);
      my $y2 = floor($p2[1]+.5);
      my $z2 = floor($p2[2]+.5);
      if ( $y1!=$y2 || $z1!=$z2 ) {
       # bresenham for in-between points
       my @points = getBresenhamPoints($y1,$z1,$y2,$z2);
       for ( my $k=0 ; $k<scalar(@points) ; $k+=2 ) {
        my $yb = $points[2*$k+0];
        my $zb = $points[2*$k+1];
        my $index = $zb*$size[0]*$size[1]+$yb*$size[0]+$x1;
        print FPout $index." ".$outvalue."\n";
       }
      } else {
       my $index = $z1*$size[0]*$size[1]+$y1*$size[0]+$x1;
       print FPout $index." ".$outvalue."\n";
      }
    }
    $ii += 3;
   }
  }
  my $perVertex = 1;
  if ( $perVertex ) {
   print " + computing per vertex points...\n" if ( $verbose );
   ## vertex points
   if ( $extended ) { ## >>> NEW CODE >>>
    my $vn = 0;
    for ( my $i=0 ; $i<(3*$nvertices) ; $i+=3 ) {
     my @point = ($vertices[$i+0],$vertices[$i+1],$vertices[$i+2]);
     my @bbindices = getNewSpacePointIndices(\@point,\@size,\@origin,\@aspect);
     for ( my $jj=0 ; $jj<8 ; $jj++ ) {
      my $bbindex = $bbindices[$jj];
      @{$volindices{$bbindex}} = () unless ( exists($volindices{$bbindex}) );
      push(@{$volindices{$bbindex}},$vn);
      ## print " >>> ".$bbindex." => (".join(":",@{$volindices{$bbindex}}).")\n";
     }
     $vn += 1;
    }
   } else { ### >>> OLD CODE >>>
    for ( my $i=0 ; $i<(3*$nvertices) ; $i+=3 ) {
     my @point = ($vertices[$i+0],$vertices[$i+1],$vertices[$i+2]);
     my @npoint = getNewSpacePoint(\@point,\@size,\@origin,\@aspect);
     my $nindex = $npoint[2]*$xysize+$npoint[1]*$size[0]+$npoint[0];
     print FPout $nindex." ".$outvalue."\n";
    }
   }
  }
  if ( $oversampling ) {
   if ( $verbose ) {
    print " + computing per face oversampling...\n";
    print "  + computing edges...\n";
   }
   my %edges = ();
   my $ii = 0;
   for ( my $ik=0 ; $ik<$nsimplices ; $ik+=3 ) {
    my $v1 = $simplices[$ii+0];
    my $v2 = $simplices[$ii+1];
    my $v3 = $simplices[$ii+2];
    # edges
    my $hash1 = min($v1,$v2).".".max($v1,$v2);
    @{$edges{$hash1}} = (3*$v1,3*$v2) unless ( exists($computed{$hash1}) );
    my $hash2 = min($v1,$v3).".".max($v1,$v3);
    @{$edges{$hash2}} = (3*$v1,3*$v3) unless ( exists($computed{$hash2}) );
    my $hash3 = min($v2,$v3).".".max($v2,$v3);
    @{$edges{$hash3}} = (3*$v2,3*$v3) unless ( exists($computed{$hash3}) );
    # centroid
    #my $x1 = $vertices[3*$v1+0];
    #my $y1 = $vertices[3*$v1+1];
    #my $z1 = $vertices[3*$v1+2];
    #my $x2 = $vertices[3*$v2+0];
    #my $y2 = $vertices[3*$v2+1];
    #my $z2 = $vertices[3*$v2+2];
    #my $x3 = $vertices[3*$v3+0];
    #my $y3 = $vertices[3*$v3+1];
    #my $z3 = $vertices[3*$v3+2];
    #my @mean = (($x1+$x2+$x3)/3.,($y1+$y2+$y3)/3.,($z1+$z2+$z3)/3.);
    #my @np = getNewSpacePoint(\@mean,\@size,\@origin,\@aspect);
    #print FPout (floor(0.5+$np[2])*$xysize+floor(0.5+$np[1])*$size[0]+floor(0.5+$np[0]))." ".$outvalue."\n";
    ###
    $ii += 3;
   }
   print "  + computing oversamples of ".scalar(keys(%edges))." edges...\n" if ( $verbose );
   while ( my ($key,$value) = each(%edges) ) {
    my @vid = @{$value};
    my $x1 = $vertices[$vid[0]+0];
    my $y1 = $vertices[$vid[0]+1];
    my $z1 = $vertices[$vid[0]+2];
    my $x2 = $vertices[$vid[1]+0];
    my $y2 = $vertices[$vid[1]+1];
    my $z2 = $vertices[$vid[1]+2];
    my @mean = (0.5*($x1+$x2),0.5*($y1+$y2),0.5*($z1+$z2));
    ## >>> BEGIN NEW CODE >>>
    #my @bbindices = getNewSpacePointIndices(\@mean,\@size,\@origin,\@aspect);
    #for ( my $jj=0 ; $jj<8 ; $jj++ ) {
    # my $bbindex = $bbindices[$jj];
    # @{$volindices{$bbindex}} = () unless ( exists($volindices{$bbindex}) );
    # push(@{$volindices{$bbindex}},$vn);
    #}
    ## >>> END NEW CODE >>>
    ### >>> OLD CODE >>>
    my @np = getNewSpacePoint(\@mean,\@size,\@origin,\@aspect);
    print FPout (floor(0.5+$np[2])*$xysize+floor(0.5+$np[1])*$size[0]+floor(0.5+$np[0]))." ".$outvalue."\n";
    ### >>> END OLD CODE >>>
   }
  }
  if ( $extended ) { ### >>> NEW CODE >>>
   while ( my ($key,$vertexids_ptr) = each(%volindices) ) {
    my @vertexIds = removeDoubleEntriesFromArray(@{$vertexids_ptr});
    print FPout $key." 128 ".join(" ",@vertexIds)."\n";
   }
  }
 close(FPout);
 return 1;
}

#### end of modules
sub _debug { warn "@_\n" if $DEBUG; }

### return value (required to evaluate to TRUE)
return 1;