## hitperl::image package
## note: this package is mainly a front end for Imagemagick calls
########################################################################################################

### >>>
package hitperl::image;

### >>>
use File::stat;
use File::Path;
use File::Basename;
use Exporter;

### >>>
use hitperl;
use hitperl::rtlog;

@ISA = ('Exporter');
@EXPORT = ( 'getImageSize', 'getROIStringFromImageFile', 'getPixelCoords', 'createImageTableau',
             'createCanvasImage', 'getHistogramVolume', 'parseGeometryString', 'isEmptyImage',
             'createGridImage', 'createNiftiFile', 'imageFileIsCorrupted' );
$VERSION = 0.1;

#### start public modules

### returns 1 if png image file is corrupted
sub imageFileIsCorrupted {
 my $filename = shift;
 if ( $filename =~ m/\.png$/ ) {
  my $rtext = `pngcheck $filename`;
  return 1 unless ( $rtext =~ m/^OK/ );
 }
 return 0;
}

### generate nifti files always in mni world
sub createNiftiFile {
 my ($infilename,$overwrite,$verbose,$debug) = @_;
 return "" unless ( -e $infilename );
 return $infilename if ( $infilename =~ m/\.nii$/ || $infilename =~ m/\.nii\.gz$/ );
 my $niftifilename = $infilename;
 $niftifilename =~ s/\.vff/\.nii/;
 if ( ! -e $niftifilename || fileIsNewer($infilename,$niftifilename) || $overwrite ) {
  my $opts = "-f";
  $opts .= " -verbose" if ( $verbose );
  $opts .= " -out:mniworld";
  my %com = (
   "command" => "hitConverter",
   "options" => $opts,
   "input"   => "-in ".$infilename,
   "output"  => "-out ".$niftifilename
  );
  hsystem(\%com,1,1);
  print "Created nifti file '".$niftifilename."'.\n" if ( $verbose );
 }
 return $niftifilename;
}

### get the coordinates of specfific pixel values
sub getPixelCoords {
 my ($filename,$pixel,$debug) = @_;
 my @coords = ();
 return @coords unless ( -e $filename );
 my $tmpoutfile = "tmp/tmpGetPixelCoords_".basename($filename);
 $tmpoutfile =~ s/\.png/\.txt/i;
 system("hitImageText -i $filename -l $pixel -o $tmpoutfile");
 open(FPpin,"<$tmpoutfile") || die "FATAL ERROR: Cannot open temporary file '".$tmpoutfile."': $!";
  while ( <FPpin> ) {
   next if ( $_ =~ m/^#/ );
   my @values = split(/:/,$_);
   push(@coords,$values[0]);
  }
 close(FPpin);
 unlink($tmpoutfile) if ( -e $tmpoutfile );
 return @coords;
}

### get data roi using ImageMagick::convert
sub getROIStringFromImageFile {
 my ($filename,$debug) = @_;
 return "0x0+0+0" unless ( -e $filename );
 my $roifilename = "tmp/${tmp}_".basename($filename);
 $roifilename =~ s/.png/.roi/i;
 my $com = "convert $filename -trim info:- > $roifilename";
 if ( $debug ) {
  print "DEBUG: '$com'.\n";
  return "0x0+0+0";
 }
 system($com);
 open(FProiin,"<$roifilename") || die "FATAL ERROR: Cannot open roi info file '".$roifilename."': $!";
  my $infoline = <FProiin>;
 close(FProiin);
 unlink($roifilename) || die "FATAL ERROR: Cannot remove temporary roi file '".$roifilename."': $!";
 my @values = split(/\ /,$infoline);
 my @rvalues = split(/\+/,$values[3]);
 my $roiline = "$values[2]+$rvalues[1]+$rvalues[2]";
 return $roiline;
}

### every element of the geometry string must be positive
sub parseGeometryString {
 my $geometrystring = shift;
 return split(/\D+/,$geometrystring);
}

### get image size using ImageMagick::convert
sub getImageSize {
 my ($imgfile,$debug) = @_;
 my @size = (0,0);
 return @size unless ( -e $imgfile );
 if ( $debug ) {
  print "DEBUG: 'identify $imgfile'.\n";
  return @size;
 }
 my $tmpfile = "tmp_getimagesize_";
 $tmpfile .= sprintf "%06x.txt",int(rand(100000));
 system("identify $imgfile > $tmpfile");
 open(FPin,"<$tmpfile") || die "FATAL ERROR: Cannot open '".$tmpfile."' for reading: $!";
  my $infoline = <FPin>;
 close(FPin);
 unlink($tmpfile);
 my @elements = split(/\ /,$infoline);
 return split(/x/,$elements[2]);
}

### this will create our standard image tableau
sub createImageTableau {
 my ($filename,$verbose,$debug) = @_;
 my $piccorefilename = $filename;
 $piccorefilename =~ s/\.off//;
 my $picoutfilename = $piccorefilename."_tableau.png";
 my @sides = ("top","left","front","bottom","right","back");
 my $sidestring = join("\,",@sides);
 my $opts = "--width 400 --height 400";
 $opts .= " --view $sidestring";
 $opts .= ",left"; ## to handle render bug
 my $cmd = "hitRenderToImage $opts -i \"$filename\" -o \"$piccorefilename\"";
 if ( $debug ) {
  print "DEBUG: $cmd\n";
  return $picoutfilename;
 } else {
  system($cmd);
 }
 my @picoutfiles = ();
 foreach my $sside (@sides) {
  push(@picoutfiles,"\"${piccorefilename}_${sside}.png\"");
 }
 system("montage @picoutfiles -tile 3x2 -geometry +0+0 \"$picoutfilename\"");
 return $picoutfilename;
}

### >>>
sub createCanvasImage {
 my ($xsize,$ysize,$color) = @_;
 $color = "black" unless ( defined($color) );
 createOutputPath("canvas");
 my $filename = "canvas/".$color."_".$xsize."x".$ysize.".png";
 system("convert -size ${xsize}x${ysize} xc:$color png8:$filename") unless ( -e $filename );
 return $filename;
}

### >>>
sub createGridImage {
 my ($filename,$xsize,$ysize,$nlines,$color,$debug) = @_;
 my $drawlines = "-fill white -stroke white";
 my $xdelta = int($xsize/$nlines);
 my $xoffset = 0.5*($xsize-$nlines*$xdelta);
 my $ydelta = int($ysize/$nlines);
 my $yoffset = 0.5*($ysize-$nlines*$ydelta);
 my $xpos = $xoffset;
 my $ylength = $ysize-$yoffset;
 for ( my $nx=0 ; $nx<=$nlines ; $nx++ ) {
  $drawlines .= " -draw \"line $xpos,$yoffset $xpos,$ylength\"";
  $xpos += $xdelta;
 }
 my $ypos = $yoffset;
 my $xlength = $xsize-$xoffset;
 for ( my $ny=0 ; $ny<=$nlines ; $ny++ ) {
  $drawlines .= " -draw \"line $xoffset,$ypos $xlength,$ypos\"";
  $ypos += $ydelta;
 }
 if ( defined($debug) && $debug!=0 ) {
  print "image.createGridImage().DEBUG: nlines=$nlines, delta=($xdelta,$ydelta), offset=($xoffset:$yoffset), length=($xlength,$ylength).\n";
 }
 system("convert -size ${xsize}x${ysize} xc:$color $drawlines png8:$filename");
 return $filename;
}

### >>>
sub getHistogramVolume {
 my ($infile,$keepfile) = @_;
 return 0.0 unless ( -e $infile );
 my $histofile = $infile;
 $histofile =~ s/\.gz//i;
 my ($name,$path,$suffix) = fileparse($histofile,qr/\.[^.]*/);
 $histofile =~ s/${suffix}$/\.hst/;
 if ( ! -e $histofile || stat($infile)->mtime>stat($histofile)->mtime ) {
  system("hitHistogram -f -in $infile -r -out $histofile");
 }
 my $volume = 0;
 open(FPhistoin,"<$histofile") || die "FATAL ERROR: Cannot open histogram file '".$histofile."' for reading: $!";
  while ( <FPhistoin> ) {
   chomp($_);
   my @values = split(/\ /,$_);
   $volume += $values[1]*$values[0]/255.0 if ( $values[0]!=0 );
  }
 close(FPhistoin);
 unlink($histofile) unless ( (defined($keepfile) && $keepfile==1) );
 return $volume;
}

### >>>
sub isEmptyImage {
 my ($imagefile,$debug) = @_;
 my $ncolors = `convert $imagefile -format \"\%k\" info:`;  ### more stable than hitHistogram
 chomp($ncolors);
 return 1 if ( $ncolors<=1 );
 return 0;
}

#### end of modules
sub _debug { warn "@_\n" if $DEBUG; }

### return value
1;
