#!/opt/local/bin/perl

### script to convert a JulichBrain surface label dataset to a volume dataset

### >>>
use strict;
use File::Basename;
use Getopt::Long;
use POSIX;
use List::Util qw[min max];

### >>>
use lib $ENV{HITHOME}."/src/perl";
use hitperl;
use hitperl::atlas;
use hitperl::meshtools;
use hitperl::jubdmesh;
use hitperl::offmesh;
use hitperl::repos;
use hitperl::svn;
use hitperl::rtlog;

### >>>
sub getPointInBetween {
 my ($x1,$y1,$z1,$x2,$y2,$z2) = @_;
 my @midvertex = ();
 push(@midvertex,0.5*($x1+$x2)); ## $x1+0.5*($x2-$x1));
 push(@midvertex,0.5*($y1+$y2)); ##$y1+0.5*($y2-$y1));
 push(@midvertex,0.5*($z1+$z2)); ##$z1+0.5*($z2-$z1));
 return @midvertex
}
sub getCenterPoint {
 my ($x1,$y1,$z1,$x2,$y2,$z2,$x3,$y3,$z3) = @_;
 my @centerp = ();
 push(@centerp,1.0/3.0*($x1+$x2+$x3));
 push(@centerp,1.0/3.0*($y1+$y2+$y3));
 push(@centerp,1.0/3.0*($z1+$z2+$z3));
 return @centerp;
}
sub getPointToPointDistance {
 my ($x1,$y1,$z1,$x2,$y2,$z2) = @_;
 my $dx = $x1-$x2;
 my $dy = $y1-$y2;
 my $dz = $z1-$z2;
 return $dx*$dx+$dy*$dy+$dz*$dz;
}
sub getMinIndex3 {
 my ($n1,$n2,$n3) = @_;
 return $n1 if ( $n1<$n2 && $n1<$n3 );
 return $n2 if ( $n2<$n1 && $n2<$n3 );
 return $n3;
}

### >>>
my $logfilepath = $ENV{HITHOME}."/logs";

### >>>
my $help = 0;
my $verbose = 0;
my $debug = 0;
my $history = 0;
my $overwrite = 0;
my $binary = 0;
my $pedantic = 0;
my $fill = 0;
my $printversion = 0;
my $oversampling = 0;
my $refinemesh = 0;
my $dynamic = 0;
my $aspmap = -1;
my $getInnerSurface = 0;
my $surfmodel =  "freesurfer";
my $surftype = "m";
my $refBrain = "Colin27";
my $modality = "inflated";
my $side = undef;
my $outtype = undef;
my $typehint = "jubrain";
my $distfilename = undef;
my $infilename = undef;
my $outfilename = undef;
my $ATLASPATH = undef;
my @argvlist = ();

### >>>
### >>>
sub printusage {
 my $infotext = shift;
 print "Error: ".$infotext."!\n" if ( defined($infotext) );
 print "Usage: ".basename($0)." [--help|?][--pedantic][(-v|--verbose)][(-d|--debug)][--overwrite][--history][--version][--binary][--inner][--refine]\n";
 print "\t[--atlaspath <path>][(-r|--reference) <name=$refBrain>][--model <name=$surfmodel>][--oversampling <value=$oversampling>][--surftype <name>]\n";
 print "\t[--fill][--dynamic][--distancemap <filename>][--pmap <labelId>][(-o|--out) <filename>][--outtype <name>] --side <l|r> (-i|--in) <filename(s)>\n";
 print "Parameters:\n";
 print " version.................... ".getScriptRepositoryVersion($0,$debug)."\n";
 print " atlas data path............ ".getAtlasDataDrive()."\n";
 print " last call.................. '".getLastProgramLogMessage($0,$logfilepath)."'\n";
 exit(1);
}
if ( @ARGV>0 ) {
 foreach my $argnum (0..$#ARGV) {
  push(@argvlist,$ARGV[$argnum]);
 }
 GetOptions(
  'help|?+' => \$help,
  'verbose|v+' => \$verbose,
  'version+' => \$printversion,
  'debug|d+' => \$debug,
  'history+' => \$history,
  'pedantic+' => \$pedantic,
  'binary+' => \$binary,
  'fill+' => \$fill,
  'dynamic+' => \$dynamic,
  'overwrite+' => \$overwrite,
  'inner+' => \$getInnerSurface,
  'refine+' => \$refinemesh,
  'oversampling=i' => \$oversampling,
  'pmap=i' => \$aspmap,
  'model=s' => \$surfmodel,
  'side=s' => \$side,
  'distancemap=s' => \$distfilename,
  'out=s' => \$outfilename,
  'surftype=s' => \$surftype,
  'outtype=s' => \$outtype,
  'type|t=s' => \$typehint,
  'hint=s' => \$typehint,
  'atlaspath=s' => \$ATLASPATH,
  'in|i=s' => \$infilename) ||
 printusage();
}
printProgramLog($0,1,$logfilepath) if $history;
printusage() if $help;
if ( $printversion ) { print getScriptRepositoryVersion($0,$debug)."\n"; exit(1); }
printusage("Missing parameter for input filename") if ( !defined($infilename) );
printusage("Missing parameter for input side") if ( !defined($side) );

### >>>
createProgramLog($0,\@argvlist,$debug,$logfilepath);

### setup mesh data
my %refBrainFiles = ();
my $refBrainLC = lc($refBrain);
$ATLASPATH = getAtlasDataDrive()."/Projects/Atlas" unless ( defined($ATLASPATH) );
$ATLASPATH = $ENV{ATLASPATH} unless ( -d $ATLASPATH );
my $refBrainPath = $ATLASPATH."/data/brains/human/reference/".$refBrainLC;
$refBrainPath = "./data" if ( -d "./data/surf/freesurfer" );
$refBrainFiles{"rn"} = $refBrainPath."/surf/freesurfer/lh_pial_affine.off";
$refBrainFiles{"ln"} = $refBrainPath."/surf/freesurfer/rh_pial_affine.off";
$refBrainFiles{"rm"} = $refBrainPath."/surf/freesurfer/lh_smoothwm_affine_midcortex.off";
$refBrainFiles{"lm"} = $refBrainPath."/surf/freesurfer/rh_smoothwm_affine_midcortex.off";
$refBrainFiles{"ri"} = $refBrainPath."/surf/freesurfer/lh_inflated.off";
$refBrainFiles{"li"} = $refBrainPath."/surf/freesurfer/rh_inflated.off";

### loading data (need full sized label vector)
print "Loading input files...\n" if ( $verbose );

## loading mesh
my $meshmodalityflag = $side.$surftype;
my %meshdata = ();
my @distances = ();
my @pialvertices = ();
### as an additional option: compute inner surface as smoothwm-n(smoothwm-pial)*distance(pial,smoothwm)
if ( $getInnerSurface || defined($distfilename) || $fill ) {
 print " + computing inner mesh surface...\n" if ( $verbose );
 my $meshmodalityflag = $side."n";
 my %pialmeshdata = loadMeshFile($refBrainFiles{$meshmodalityflag},$verbose,$debug);
 @pialvertices = @{$pialmeshdata{"vertices"}};
 my $npialvertices = $pialmeshdata{"nvertices"};
 $meshmodalityflag = $side."m";
 my %smoothwmmeshdata = loadMeshFile($refBrainFiles{$meshmodalityflag},$verbose,$debug);
 my @smoothwmvertices = @{$smoothwmmeshdata{"vertices"}};
 my $nsmoothwmvertices = $pialmeshdata{"nvertices"};
 printfatalerror "FATAL ERROR: Number of vertices mismatch between pial and smoothwm surface." if ( $npialvertices!=$nsmoothwmvertices );
 my $np = 0;
 my $minDistance = +1000000.0;
 my $maxDistance = -1000000.0;
 my $meanDistance = 0.0;
 my $sdDistance = 0.0;
 my @innervertices = ();
 for ( my $i=0 ; $i<$npialvertices ; $i++ ) {
  my $xp = $pialvertices[$np+0];
  my $yp = $pialvertices[$np+1];
  my $zp = $pialvertices[$np+2];
  my $xs = $smoothwmvertices[$np+0];
  my $ys = $smoothwmvertices[$np+1];
  my $zs = $smoothwmvertices[$np+2];
  my $xi = $xp+2.0*($xs-$xp);
  my $yi = $yp+2.0*($ys-$yp);
  my $zi = $zp+2.0*($zs-$zp);
  #if ( $i<10 ) {
  # print " pial=(".$xp.":".$yp.":".$zp."), smoothwm=(".$xs.":".$ys.":".$zs."), inner=(".$xi.":".$yi.":".$zi.")\n";
  #}
  push(@innervertices,$xi);
  push(@innervertices,$yi);
  push(@innervertices,$zi);
  my $distance = sqrt(getPointToPointDistance($xp,$yp,$zp,$xi,$yi,$zi));
  $meanDistance += $distance;
  $sdDistance += $distance*$distance;
  $minDistance = $distance if ( $distance<$minDistance );
  $maxDistance = $distance if ( $distance>$maxDistance );
  push(@distances,$distance);
  $np += 3;
 }
 @{$meshdata{"vertices"}} = @innervertices;
 $meshdata{"nvertices"} = $pialmeshdata{"nvertices"};
 @{$meshdata{"simplices"}} = @{$pialmeshdata{"simplices"}};
 $meshdata{"nfaces"} = $pialmeshdata{"nfaces"};
 if ( defined($distfilename) ) {
  my $ndistances = scalar(@distances);
  $meanDistance = $meanDistance/$ndistances;
  $sdDistance = sqrt($sdDistance/$ndistances-$meanDistance*$meanDistance);
  open(FPout,">$distfilename") || printfatalerror "FATAL ERROR: Cannot save distance file '".$distfilename."': $!";
   print FPout "# automatically created by $0\n";
   print FPout "# data range: min=$minDistance, max=$maxDistance\n";
   print FPout "# mean range: $meanDistance +/- $sdDistance\n";
   print FPout $ndistances."\n";
   for ( my $n=0 ; $n<$ndistances ; $n++ ) {
    print FPout $distances[$n]."\n";
   }
  close(FPout);
  print " + saved distance file '".$distfilename."'.\n" if ( $verbose );
 }
} else {
 my $meshmodalityflag = $side.$surftype;
 print " + loading mesh with modality '".$meshmodalityflag."'...\n" if ( $verbose );
 %meshdata = loadMeshFile($refBrainFiles{$meshmodalityflag},$verbose,$debug);
}
exit(0) if ( defined($distfilename) );

## loading labels
my %inlabeldata = ();
my $magic = undef;
my @labels = ();
my $nvertices = $meshdata{"nvertices"};
if ( !defined($typehint) || $typehint =~ m/^auto$/i ) {
 print "loading vertex label file '".$infilename."'...\n" if ( $verbose );
 @labels = loadVertexLabels($infilename,$verbose,$debug);
} else {
 print "loading JulichBrain label file '".$infilename."'...\n" if ( $verbose );
 %inlabeldata = loadJuBrainLabels($infilename,0,$debug);
 $magic = $inlabeldata{"magic"};
 printJuBrainLabelInfos(\%inlabeldata) if ( $verbose );
 print " + magic=$magic, nvertices=".$inlabeldata{"nvertices"}."\n" if ( $verbose );
 if ( $inlabeldata{"nvertices"}==-1 || $magic =~ m/^JUBDilf$/i || $magic =~ m/^JUBDidf$/i || $magic =~ m/^dat$/i ) {
  print "  + expanding indexed label data of size ".$inlabeldata{"nlabels"}.
                  " to full sized label data vector of size ".$nvertices."...\n" if ( $verbose );
  for ( my $i=0 ; $i<$nvertices ; $i++ ) {
   push(@labels,0.0);
  }
  my %jlabels = %{$inlabeldata{"labels"}};
  while ( my ($index,$value)=each(%jlabels) ) {
   if ( $index<$nvertices ) {
    print " ++ index=$index, value=$value\n" if ( $debug );
    $labels[$index] = $value;
   } else {
    printfatalerror "FATAL ERROR: Label vertex index overflow error: index=".$index." > nvertices=".$nvertices.".";
   }
  }
 } elsif ( $inlabeldata{"nvertices"}!=$meshdata{"nvertices"} ) {
  printfatalerror "FATAL ERROR: Size mismatch between number of labels and mesh size.";
 }
}
## check data
printfatalerror "FATAL ERROR: Size mismatch between number of labels and number of vertices: #labels=".scalar(@labels).
            " != #vertices=".$meshdata{"nvertices"}."." if ( scalar(@labels)!=$meshdata{"nvertices"} );
## compute mesh and label data range
my @xRange = (+1000000,-1000000);
my @yRange = (+1000000,-1000000);
my @zRange = (+1000000,-1000000);
my @lRange = (+1000000,-1000000);
my @vertices = @{$meshdata{"vertices"}};
my $np = 0;
for ( my $i=0 ; $i<$nvertices ; $i++ ) {
 my $np = 3*$i;
 my $x = $vertices[$np+0];
 my $y = $vertices[$np+1];
 my $z = $vertices[$np+2];
 $xRange[0] = $x if ( $x<$xRange[0] );
 $xRange[1] = $x if ( $x>$xRange[1] );
 $yRange[0] = $y if ( $x<$yRange[0] );
 $yRange[1] = $y if ( $x>$yRange[1] );
 $zRange[0] = $z if ( $x<$zRange[0] );
 $zRange[1] = $z if ( $x>$zRange[1] );
 $lRange[0] = $labels[$i] if ( $labels[$i]<$lRange[0] );
 $lRange[1] = $labels[$i] if ( $labels[$i]>$lRange[1] );
 $np += 3;
}
print " + range: data=(".$lRange[0].":".$lRange[1]."), xyz=(".$xRange[0].":".$xRange[1]."|".$yRange[0].":".$yRange[1]."|".$zRange[0].":".$zRange[1].")\n" if ( $verbose );

#### >>>
my %datavalues = ();
my @offset = (-128.0,-148.0,-110.0);  ### (=) nifti-world to vff/internal-world: x->z flip

## oversampling, refinement
my $nDynamicPoints = 10;
my $nMidPlanes = 10;

## >>>
my %inBetweenVertices = ();
if ( $aspmap>0 ) {
 print " + extracting pmap of label ".$aspmap."...\n" if ( $verbose );
 my @vertices = @{$meshdata{"vertices"}};
 my $nvertices = scalar(@vertices);
 my @pmaplabels = ();
 for ( my $i=0 ; $i<$nvertices ; $i++ ) {
  push(@pmaplabels,0.0);
 }
 my @simplices = @{$meshdata{"simplices"}};
 # compute by adding gauss-kernels
 my $sigma = 1.5;
 my $gfactor = 1/(2.0*$sigma*$sigma);
 ## my $nfactor = 1/(sqrt(2*4*atan2(1,1))*$sigma);
 my %meshtopology = getVertexTopology(\%meshdata,$verbose,$debug);
 my $nlabels = scalar(@labels);
 for ( my $i=0 ; $i<$nlabels ; $i++ ) {
  if ( $labels[$i]==$aspmap ) {
   my $ii = 3*$i;
   my $cx = $vertices[$ii];
   my $cy = $vertices[$ii+1];
   my $cz = $vertices[$ii+2];
   ## get L1-Ln neighbors
   my @ring1vertices = @{$meshtopology{$i}};
   my $nring1vertices = scalar(@ring1vertices);
   for ( my $n=0 ; $n<$nring1vertices ; $n++ ) {
    my $nn = 3*$ring1vertices[$n];
    my $px = $vertices[$nn];
    my $py = $vertices[$nn+1];
    my $pz = $vertices[$nn+2];
    my $distance = sqrt(getPointToPointDistance($cx,$cy,$cz,$px,$py,$pz));
    my $gaussvalue = exp(-$distance*$distance*$gfactor);
    $pmaplabels[$ring1vertices[$n]] += $gaussvalue;
   }
   $pmaplabels[$i] += 1.0;
  }
 }
 # HeatKernel smoothing
 my $maxPValue = 0.0;
 my %normpvalues = ();
 my $heatKernelSmoothing = 1;
 if ( $heatKernelSmoothing==1 ) {
  my $sigma = 0.15;
  my $niter = 20;
  my $normalize = 1;
  my $likeValue = 1.0;
  my @flabels = heatKernelSmoothingMeshLabels(\@pmaplabels,\%meshdata,\%meshtopology,$sigma,$niter,$normalize,$likeValue,$verbose,$debug);
  for ( my $i=0 ; $i<$nvertices ; $i++ ) {
   if ( $flabels[$i]>0.0 ) {
    $normpvalues{$i} = $flabels[$i];
    $maxPValue = $normpvalues{$i} if ( $normpvalues{$i}>$maxPValue );
   }
  }
 } else {
  # normalize
  my $localNormalization = 1;
  if ( $localNormalization==1 ) {
   print "  + compute local data normalization...\n" if ( $verbose );
   for ( my $i=0 ; $i<$nvertices ; $i++ ) {
    if ( $pmaplabels[$i]>0.0 ) {
     my $nring1vertices = scalar(@{$meshtopology{$i}});
     $normpvalues{$i} = $pmaplabels[$i]/$nring1vertices;
     $maxPValue = $normpvalues{$i} if ( $normpvalues{$i}>$maxPValue );
    }
   }
  } else {
   print "  + compute global data normalization...\n" if ( $verbose );
   for ( my $i=0 ; $i<$nvertices ; $i++ ) {
    if ( $pmaplabels[$i]>0.0 ) {
     $normpvalues{$i} = $pmaplabels[$i];
     $maxPValue = $pmaplabels[$i] if ( $pmaplabels[$i]>$maxPValue );
    }
   }
  }
 }
 if ( $maxPValue!=0.0 ) {
  ### f(x) = 0.1*((‑(1.2^((‑x)+12.5)))+10)
  print "   + normalizing pmap data (max=".$maxPValue.")...\n" if ( $verbose );
  my $normfactor = 1.0/$maxPValue;
  while ( my ($key,$pvalue) = each(%normpvalues) ) {
   $normpvalues{$key} = $pvalue*$normfactor;
  }
 }
 # additional HeatKernel smoothing ???
 # save data
 open(FPout,">$outfilename") || printfatalerror "FATAL ERROR: Cannot create pmap file '".$outfilename."': $!";
  print FPout "# created by $0\n";
  print FPout "# inputfile='".$infilename."'\n";
  print FPout "# labelId=".$aspmap."\n";
  print FPout scalar(keys(%normpvalues))."\n";
  while ( my ($key,$pvalue) = each(%normpvalues) ) {
   print FPout $key." ".$pvalue."\n";
  }
 close(FPout);
 print "  + saved pmap file '".$outfilename."'.\n" if ( $verbose );
 exit(1);
} elsif ( $fill ) {
 print " + filling space in-betwenn...\n" if ( $verbose );
 my @vertices = @{$meshdata{"vertices"}};
 my @simplices = @{$meshdata{"simplices"}};
 my $nfaces = $meshdata{"nfaces"};
 my $ds = 0.0;
 my $dk = 1.0/$nMidPlanes;
 for ( my $k=0 ; $k<$nMidPlanes ; $k++ ) {
  print "  + processing mesh ".($k+1).".".$nMidPlanes." at isolevel ".$ds."...\n" if ( $verbose );
  my $ii = 0;
  for ( my $i=0 ; $i<$nfaces ; $i++ ) {
   # get vertices
    # triangle
    my $n1 = $simplices[$ii+0];
    my $lid1 = $labels[$n1];
    $n1 *= 3;
    my $n2 = $simplices[$ii+1];
    my $lid2 = $labels[$n2];
    $n2 *= 3;
    my $n3 = $simplices[$ii+2];
    my $lid3 = $labels[$n3];
    $n3 *= 3;
    # pial coords
     my $vpx1 = $pialvertices[$n1+0];
     my $vpy1 = $pialvertices[$n1+1];
     my $vpz1 = $pialvertices[$n1+2];
     my $vpx2 = $pialvertices[$n2+0];
     my $vpy2 = $pialvertices[$n2+1];
     my $vpz2 = $pialvertices[$n2+2];
     my $vpx3 = $pialvertices[$n3+0];
     my $vpy3 = $pialvertices[$n3+1];
     my $vpz3 = $pialvertices[$n3+2];
    # inner coords
     my $vix1 = $vertices[$n1+0];
     my $viy1 = $vertices[$n1+1];
     my $viz1 = $vertices[$n1+2];
     my $vix2 = $vertices[$n2+0];
     my $viy2 = $vertices[$n2+1];
     my $viz2 = $vertices[$n2+2];
     my $vix3 = $vertices[$n3+0];
     my $viy3 = $vertices[$n3+1];
     my $viz3 = $vertices[$n3+2];
    # distance
     my $dx1 = $vix1-$vpx1;
     my $dy1 = $viy1-$vpy1;
     my $dz1 = $viz1-$vpz1;
     my $dx2 = $vix2-$vpx2;
     my $dy2 = $viy2-$vpy2;
     my $dz2 = $viz2-$vpz2;
     my $dx3 = $vix3-$vpx3;
     my $dy3 = $viy3-$vpy3;
     my $dz3 = $viz3-$vpz3;
   # >>>
   my $vkx1 = $vpx1+$ds*$dx1;
   my $vky1 = $vpy1+$ds*$dy1;
   my $vkz1 = $vpz1+$ds*$dz1;
   my $vkx2 = $vpx2+$ds*$dx2;
   my $vky2 = $vpy2+$ds*$dy2;
   my $vkz2 = $vpz2+$ds*$dz2;
   my $vkx3 = $vpx3+$ds*$dx3;
   my $vky3 = $vpy3+$ds*$dy3;
   my $vkz3 = $vpz3+$ds*$dz3;
   ## dynamic filling
    my @points = ();
    my @pointlabels = ();
    push(@points,$vkx1); push(@points,$vky1); push(@points,$vkz1); push(@pointlabels,$lid1);
    push(@points,$vkx2); push(@points,$vky2); push(@points,$vkz2); push(@pointlabels,$lid2);
    push(@points,$vkx3); push(@points,$vky3); push(@points,$vkz3); push(@pointlabels,$lid3);
    for ( my $k=0 ; $k<$nDynamicPoints ; $k++ ) {
     my $alpha = rand();
     my $beta  = rand();
     if ( ($beta+$alpha)>=1.0 ) {
      $alpha = 1.0-$alpha;
      $beta = 1.0-$beta;
     }
     my $x = $vkx1+$alpha*($vkx2-$vkx1)+$beta*($vkx3-$vkx1);
     my $y = $vky1+$alpha*($vky2-$vky1)+$beta*($vky3-$vky1);
     my $z = $vkz1+$alpha*($vkz2-$vkz1)+$beta*($vkz3-$vkz1);
     my $d1 = getPointToPointDistance($x,$y,$z,$vkx1,$vky1,$vkz1);
     my $d2 = getPointToPointDistance($x,$y,$z,$vkx2,$vky2,$vkz2);
     my $d3 = getPointToPointDistance($x,$y,$z,$vkx3,$vky3,$vkz3);
     if ( $d1<$d2 && $d1<$d3 ) {
      push(@pointlabels,$lid1);
     } elsif ( $d2<$d1 && $d2<$d3 ) {
      push(@pointlabels,$lid2);
     } else {
      push(@pointlabels,$lid3);
     }
     push(@points,$x);
     push(@points,$y);
     push(@points,$z);
    }
    my $npoints = scalar(@points);
    my $pp = 0;
    for ( my $p=0 ; $p<$npoints ; $p++ ) {
     my $x = 256-floor(-$offset[0]+$points[$pp+0]);
     my $y = floor(-$offset[1]+$points[$pp+1]);
     my $z = floor(-$offset[2]+$points[$pp+2]);
     my $ploc = $x+256*$y+65536*$z;
     $datavalues{$ploc} = $pointlabels[$p] unless ( exists($datavalues{$ploc}) );
     $pp += 3;
    }
   ## >>>
   $ii += 3;
  }
  $ds += $dk;
 }
} elsif ( $oversampling>0 ) {
 print " + starting mesh oversampling...\n" if ( $verbose );
 my @vertices = @{$meshdata{"vertices"}};
 my @simplices = @{$meshdata{"simplices"}};
 ## >>>
  my $nfaces = $meshdata{"nfaces"};
  my $ii = 0;
  for ( my $i=0 ; $i<$nfaces ; $i++ ) {
   ## get old vertex coordinates
    my $n1 = $simplices[$ii+0];
    my $lid1 = $labels[$n1];
    $n1 *= 3;
    my $vx1 = $vertices[$n1+0];
    my $vy1 = $vertices[$n1+1];
    my $vz1 = $vertices[$n1+2];
    my $n2 = $simplices[$ii+1];
    my $lid2 = $labels[$n2];
    $n2 *= 3;
    my $vx2 = $vertices[$n2+0];
    my $vy2 = $vertices[$n2+1];
    my $vz2 = $vertices[$n2+2];
    my $n3 = $simplices[$ii+2];
    my $lid3 = $labels[$n3];
    $n3 *= 3;
    my $vx3 = $vertices[$n3+0];
    my $vy3 = $vertices[$n3+1];
    my $vz3 = $vertices[$n3+2];
   ## >>>
   if ( $dynamic ) { ### looks very good
    my @points = ();
    my @pointlabels = ();
    push(@points,$vx1); push(@points,$vy1); push(@points,$vz1); push(@pointlabels,$lid1);
    push(@points,$vx2); push(@points,$vy2); push(@points,$vz2); push(@pointlabels,$lid2);
    push(@points,$vx3); push(@points,$vy3); push(@points,$vz3); push(@pointlabels,$lid3);
    for ( my $k=0 ; $k<$nDynamicPoints ; $k++ ) {
     my $alpha = rand();
     my $beta  = rand();
     if ( ($beta+$alpha)>=1.0 ) {
      $alpha = 1.0-$alpha;
      $beta = 1.0-$beta;
     }
     my $x = $vx1+$alpha*($vx2-$vx1)+$beta*($vx3-$vx1);
     my $y = $vy1+$alpha*($vy2-$vy1)+$beta*($vy3-$vy1);
     my $z = $vz1+$alpha*($vz2-$vz1)+$beta*($vz3-$vz1);
     my $d1 = getPointToPointDistance($x,$y,$z,$vx1,$vy1,$vz1);
     my $d2 = getPointToPointDistance($x,$y,$z,$vx2,$vy2,$vz2);
     my $d3 = getPointToPointDistance($x,$y,$z,$vx3,$vy3,$vz3);
     if ( $d1<$d2 && $d1<$d3 ) {
      push(@pointlabels,$lid1);
     } elsif ( $d2<$d1 && $d2<$d3 ) {
      push(@pointlabels,$lid2);
     } else {
      push(@pointlabels,$lid3);
     }
     push(@points,$x);
     push(@points,$y);
     push(@points,$z);
    }
    my $npoints = scalar(@points);
    my $pp = 0;
    for ( my $p=0 ; $p<$npoints ; $p++ ) {
     my $x = 256-floor(-$offset[0]+$points[$pp+0]);
     my $y = floor(-$offset[1]+$points[$pp+1]);
     my $z = floor(-$offset[2]+$points[$pp+2]);
     my $ploc = $x+256*$y+65536*$z;
     $datavalues{$ploc} = $pointlabels[$p] unless ( exists($datavalues{$ploc}) );
     $pp += 3;
    }
   } else {
    ## compute new vertex positions (dynamic to take into account different triangle sizes)
    my @v12coord = getPointInBetween($vx1,$vy1,$vz1,$vx2,$vy2,$vz2);
    push(@v12coord,$labels[$n1]);
    my @v13coord = getPointInBetween($vx1,$vy1,$vz1,$vx3,$vy3,$vz3);
    push(@v13coord,$labels[$n2]);
    my @v23coord = getPointInBetween($vx2,$vy2,$vz2,$vx3,$vy3,$vz3);
    push(@v23coord,$labels[$n3]);
    my @v123coord = getCenterPoint($vx1,$vy1,$vz1,$vx2,$vy2,$vz2,$vx3,$vy3,$vz3);
    push(@v123coord,$labels[$n1]);
    ## create new vertex list
    my $vid12 = ($n1<$n2)?($n1.".".$n2):($n2.".".$n1);
    @{$inBetweenVertices{$vid12}} = @v12coord if ( !exists($inBetweenVertices{$vid12}) );
    my $vid13 = ($n1<$n3)?($n1.".".$n3):($n1.".".$n3);
    @{$inBetweenVertices{$vid13}} = @v13coord if ( !exists($inBetweenVertices{$vid13}) );
    my $vid23 = ($n2<$n3)?($n2.".".$n3):($n3.".".$n2);
    @{$inBetweenVertices{$vid23}} = @v23coord if ( !exists($inBetweenVertices{$vid23}) );
    my $vid123 = getMinIndex3($n1,$n2,$n3);
    @{$inBetweenVertices{$vid123}} = @v123coord if ( !exists($inBetweenVertices{$vid123}) );
   }
   $ii += 3;
  }
 ## >>>
} elsif ( $refinemesh ) {
 print " + starting mesh refinement...\n" if ( $verbose );
 my @vertices = @{$meshdata{"vertices"}};
 for ( my $k=0 ; $k<$oversampling ; $k++ ) {
  print "  + creating refined mesh for level of refinement ".$k." ...\n" if ( $verbose );
  my $nfaces = $meshdata{"nfaces"};
  my @simplices = @{$meshdata{"simplices"}};
  my @newsimplices = ();
  my @newvertices = ();
  my @newlabels = ();
  my %hlcVertices = ();
  my $ii = 0;
  for ( my $i=0 ; $i<$nfaces ; $i++ ) {
   ## get old vertex coordinates
    my $n1 = 3*$simplices[$ii+0];
    my $vx1 = $vertices[$n1+0];
    my $vy1 = $vertices[$n1+1];
    my $vz1 = $vertices[$n1+2];
    my $n2 = 3*$simplices[$ii+1];
    my $vx2 = $vertices[$n2+0];
    my $vy2 = $vertices[$n2+1];
    my $vz2 = $vertices[$n2+2];
    my $n3 = 3*$simplices[$ii+2];
    my $vx3 = $vertices[$n3+0];
    my $vy3 = $vertices[$n3+1];
    my $vz3 = $vertices[$n3+2];
   ## compute qc-value as ratio of inner versus outer radius of the triangle
   ## compute new vertex positions
    my @v12coord = getPointInBetween($vx1,$vy1,$vz1,$vx2,$vy2,$vz2);
    my @v13coord = getPointInBetween($vx1,$vy1,$vz1,$vx3,$vy3,$vz3);
    my @v23coord = getPointInBetween($vx2,$vy2,$vz2,$vx3,$vy3,$vz3);
   ## create new vertex list
    ## orig1
    my $vid1 = $n1;
    if ( !exists($hlcVertices{$vid1}) ) {
     $hlcVertices{$vid1} = scalar(@newvertices);
     push(@newvertices,$vx1);
     push(@newvertices,$vy1);
     push(@newvertices,$vz1);
     push(@newlabels,$labels[$n1]);
    }
    $vid1 = $hlcVertices{$vid1};
    ### orig2
    my $vid2 = $n2;
    if ( !exists($hlcVertices{$vid2}) ) {
     $hlcVertices{$vid2} = scalar(@newvertices);
     push(@newvertices,$vx2);
     push(@newvertices,$vy2);
     push(@newvertices,$vz2);
     push(@newlabels,$labels[$n2]);
    }
    $vid2 = $hlcVertices{$vid2};
    ### orig3
    my $vid3 = $n3;
    if ( !exists($hlcVertices{$vid3}) ) {
     $hlcVertices{$vid3} = scalar(@newvertices);
     push(@newvertices,$vx3);
     push(@newvertices,$vy3);
     push(@newvertices,$vz3);
     push(@newlabels,$labels[$n3]);
    }
    $vid3 = $hlcVertices{$vid3};
    ### orig1-orig2
    my $vid12 = ($n1<$n2)?($n1.".".$n2):($n2.".".$n1);
    if ( !exists($hlcVertices{$vid12}) ) {
     $hlcVertices{$vid12} = scalar(@newvertices);
     push(@newvertices,$v12coord[0]);
     push(@newvertices,$v12coord[1]);
     push(@newvertices,$v12coord[2]);
     push(@newlabels,$labels[(split("\.",$vid12))[0]]);
    }
    $vid12 = $hlcVertices{$vid12};
    ### orig1-orig3
    my $vid13 = ($n1<$n3)?($n1.".".$n3):($n3.".".$n1);
    if ( !exists($hlcVertices{$vid13}) ) {
     $hlcVertices{$vid13} = scalar(@newvertices);
     push(@newvertices,$v13coord[0]);
     push(@newvertices,$v13coord[1]);
     push(@newvertices,$v13coord[2]);
     push(@newlabels,$labels[(split("\.",$vid13))[0]]);
    }
    $vid13 = $hlcVertices{$vid13};
    ### orig2-orig3
    my $vid23 = ($n2<$n3)?($n2.".".$n3):($n3.".".$n2);
    if ( !exists($hlcVertices{$vid23}) ) {
     $hlcVertices{$vid23} = scalar(@newvertices);
     push(@newvertices,$v23coord[0]);
     push(@newvertices,$v23coord[1]);
     push(@newvertices,$v23coord[2]);
     push(@newlabels,$labels[(split("\.",$vid23))[0]]);
    }
    $vid23 = $hlcVertices{$vid23};
   ## create new triangles
    ## tri1
    push(@newsimplices,$vid1);
    push(@newsimplices,$vid12);
    push(@newsimplices,$vid13);
    ## tri2
    push(@newsimplices,$vid12);
    push(@newsimplices,$vid2);
    push(@newsimplices,$vid23);
    ## tri3
    push(@newsimplices,$vid23);
    push(@newsimplices,$vid3);
    push(@newsimplices,$vid13);
    ## tri4
    push(@newsimplices,$vid12);
    push(@newsimplices,$vid23);
    push(@newsimplices,$vid13);
   ##
   $ii += 3;
  }
  @{$meshdata{"simplices"}} = @newsimplices;
  $meshdata{"nfaces"} = scalar(@newsimplices)/3;
  @{$meshdata{"vertices"}} = @newvertices;
  $meshdata{"nvertices"} = scalar(@newvertices)/3;
  @labels = @newlabels;
  print "   + got ".$meshdata{"nvertices"}." vertices and ".$meshdata{"nfaces"}." triangles.\n" if ( $verbose );
 }
}

### >>>
unless ( $dynamic ) {
 print "adding data points...\n" if ( $verbose );
 my $np = 0;
 @vertices = @{$meshdata{"vertices"}};
 $nvertices = $meshdata{"nvertices"};
 for ( my $i=0 ; $i<$nvertices ; $i++ ) {
  my $x = 256-floor(-$offset[0]+$vertices[$np+0]); ## to flip left/right orientation
  my $y = floor(-$offset[1]+$vertices[$np+1]);
  my $z = floor(-$offset[2]+$vertices[$np+2]);
  my $ploc = $x+256*$y+65536*$z;
  ## print "offset=(".$offset[0].":".$offset[1].":".$offset[2]."), xyz=(".$x.":".$y.":".$z."), index=".$ploc."\n";
  $datavalues{$ploc} = $labels[$i];
  $np += 3;
 }
 ### processing inBetweenVertices, no overwriting
 print "adding ".scalar(keys(%inBetweenVertices))." inBetween data points...\n" if ( $verbose );
 while ( my ($ident,$positionsdata) = each(%inBetweenVertices) ) {
  my @coord = @{$positionsdata};
  my $x = 256-floor(-$offset[0]+$coord[0]); ## to flip left/right orientation
  my $y = floor(-$offset[1]+$coord[1]);
  my $z = floor(-$offset[2]+$coord[2]);
  my $ploc = $x+256*$y+65536*$z;
  $datavalues{$ploc} = $coord[3] unless ( exists($datavalues{$ploc}) );
 }
}

### save index file
if ( !defined($outfilename) ) {
 $outfilename = $infilename.".itxt";
}
open(FPout,">$outfilename") || printfatalerror "FATAL ERROR: Cannot create output file '".$outfilename."': $!";
if ( $binary ) {
 while ( my ($pos,$labelId) = each(%datavalues) ) {
  print FPout $pos." 255\n";
 }
} else {
 while ( my ($pos,$labelId) = each(%datavalues) ) {
  print FPout $pos." ".$labelId."\n";
 }
}
close(FPout);
print "Saved file '".$outfilename."'.\n" if ( $verbose );

### create volume file from index file (crude hack to get right origin value in final volume file)
my $volfilename = $outfilename;
$volfilename =~ s/\.itxt/\.nii\.gz/;
if ( ! -e $volfilename || $overwrite ) {
 my $tmpvolfilename = $outfilename;
 $tmpvolfilename =~ s/\.itxt/\_tmpVolFile\.nii\.gz/;
 my $volopts = "-in:size 256 256 256 -out:compress true";
 my %com = (
  "command" => "hitConverter",
  "options" => "-f $volopts -in:format ushort -out:world no -out:mniworld",
  "input"   => "-in ".$outfilename,
  "output"  => "-out ".$tmpvolfilename
 );
 hsystem(\%com,1,$debug);
 ssystem("hitSetHeader -f -i $tmpvolfilename -o $volfilename -origin -128 -148 -110",$debug);
 unlink($tmpvolfilename) if ( -e $tmpvolfilename );
 print "Created and saved volume file '".$volfilename."'.\n" if ( $verbose );
} else {
 print "WARNING: Output volume file '".$volfilename."' exists. No overwriting!.\n";
}
