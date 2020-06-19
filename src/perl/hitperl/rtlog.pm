## hitperl::rtlog package
########################################################################################################

### >>>
package hitperl::rtlog;

### core system includes
use hitperl;
use hitperl::atlas;

### >>>
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use File::stat;
use Time::localtime;
use Digest::MD5;
use Digest::MD5 qw(md5_base64);
use Exporter;

### do not use strict here otherwise it will not work
@ISA = ('Exporter');
@EXPORT = ( 'hsystem', 'printCommand', 'getFileChecksum' );
$VERSION = 0.1;

### local helpers
sub getFileListFromString {
 my $stringname = shift;
 my @filelist = ();
 my @coms = split(/\ /,$stringname);
 my $ncoms = scalar(@coms);
 for ( my $i=0 ; $i<$ncoms ; ) {
  if ( $coms[$i] =~ m/^\-/ ) {
   my $ostring = $coms[$i];
   my $ii = $i+1;
   while ( $ii<$ncoms && !($coms[$ii] =~ m/^\-/) ) {
    $ostring .= " ".$coms[$ii];
    $ii += 1;
   }
   push(@filelist,$ostring);
   $i = $ii;
  } else {
   push(@filelist,$coms[$i]);
   $i += 1;
  }
 }
 ### print "DEBUG.getFileListFromString(): input='$stringname', output(n=".scalar(@filelist)."): @filelist.\n";
 return @filelist;
}
## sensitive to multiple numbers of spaces between option flag and value
sub getOptions {
 my $name = shift;
 my %options = ();
 my @elements = split(/\ /,$name);
 if ( scalar(@elements)==2 ) {
  $options{"argument"} = $elements[0];
  $options{"value"} = $elements[1];
 } elsif ( scalar(@elements)==1 ) {
  $options{"value"} = $elements[0];
 } else {
  $options{"value"} = $name;
 }
 return %options;
}
sub isInFileList {
 my ($comlist,$com) = @_;
 return "regular" unless ( defined($comlist) );
 my @elements = getFileListFromString($comlist);
 foreach my $element (@elements) {
  ## print "+++ checking '$com' with '$element'...\n";
  return "tmp" if ( $com =~ m/$element/ );
 }
 return "regular";
}
sub getLogFileName {
 my $filename = shift;
 my $file_basename = basename($filename);
 $file_basename =~ s/\.gz$// if ( $file_basename =~ m/\.gz$/ );
 return dirname($filename)."/.log/".$file_basename.".xml";
}
sub logFileIsReadable {
 my ($filename,$debug) = @_;
 my $logfilename = getLogFileName($filename);
 print "rtlog.logFileIsReadable().DEBUG: Logfilename='".$logfilename."'.\n" if ( $debug );
 return 1 if ( -e $logfilename );
 print "rtlog.logFileIsReadable().DEBUG: Cannot read '".$logfilename."'.\n" if ( $debug );
 return 0;
}
sub getSystemFullName {
 my $sysname = `uname -vmp`;
 chomp($sysname);
 return $sysname;
}
sub getSharedLibs {
 my ($program,$verbose,$debug) = @_;
 my @outlibs = ();
 return @outlibs unless ( -x $program );
 my $libstring = undef;
 if ( $^O =~ m/^darwin/ ) {
  $libstring = `otool -L $program`;
 } elsif ( $^O =~ m/^linux/ ) {
  $libstring = `ldd $program`;
 } else { 
  return @outlibs;
 }
 my @libs = split(/\n/,$libstring);
 for ( my $i=1 ; $i<scalar(@libs) ; $i++ ) {
  my $lib = $libs[$i];
  $lib =~ s/^\s+//;
  push(@outlibs,$lib);
 }
 return(@outlibs);
}
sub getFileRevision {
 my ($filename,$versionflag,$debug) = @_;
 print "rtlog.getFileRevision().DEBUG: filename='".$filename."', versionflag='$versionflag'.\n" if ( $debug );
 return "not available" if ( $versionflag eq "unknown" );
 my $result = `$filename $versionflag`;
 chomp($result);
 my @elements = split(/\;/,$result);
 return $elements[0];
}
sub getUniqueIdent {
 my $filename = shift;
 my $foo = {
  api => POST,
  username => "hartmut",
  filename => $filename,
  time => getTimeString(1)
 };
 return md5_base64(sort %$foo);
}

### end of local helpers

### not available for BiGTIFF images because it is too time consuming
sub getFileChecksum {
 my ($filename,$verbose,$debug) = @_;
 my @elements = split(/\ /,$filename);
 my $cfilename = $elements[-1];
 if ( ! -e $cfilename ) {
  warn "WARNING: Cannot compute checksum for '".$cfilename."'!\n";
  return "unknown";
 } elsif ( $filename =~ m/\.tif$/ ) {
  return "xxxx";
 }
 open(my $fh,'<',$cfilename) || die "FATAL ERROR: Cannot open file '".$cfilename."' for reading: $!";
  binmode($fh);
  my $checksum = Digest::MD5->new->addfile($fh)->hexdigest;
 close($fh);
 return $checksum;
}

### print full command line to stdout
sub printCommand {
 my $com_ptr = shift;
 my %comlist = %{$com_ptr};
 my $comline = $comlist{"command"};
 while ( my ($key,$value) = each(%comlist) ) {
  next if ( $key =~ m/^command$/ );
  $comline .= " ".$value;
 }
 print $comline."\n";
}

### >>>
# available options:
#   command, options, input, tmpinput, output, tmpoutput, inoutput
#   versionflag
#
sub hsystem {
 my ($com_ref_ptr,$execute,$debug) = @_;
 my %comlist = %{$com_ref_ptr};
 if ( $debug ) {
  print " rtlog.hsystem().DEBUG:\n";
  while ( my ($key,$value) = each(%comlist) ) {
   print " > $key => $value\n";
  }
 }
 my ($startTime,$endTime) = (0,0);
 my $rValue = undef;
 if ( $execute ) {
  my $call = "";
  if ( exists($comlist{"commandline"}) ) {
   ### use commandline option to run an unparsed system call
   $call = $comlist{"commandline"};
  } else {
   $call = $comlist{"command"};
   $call .= " ".$comlist{"options"} if ( exists($comlist{"options"}) );
   $call .= " ".$comlist{"input"} if ( exists($comlist{"input"}) );
   $call .= " ".$comlist{"inoutput"} if ( exists($comlist{"inoutput"}) );
   $call .= " ".$comlist{"tmpinput"} if ( exists($comlist{"tmpinput"}) );
   $call .= " ".$comlist{"minput"} if ( exists($comlist{"minput"}) );
   $call .= " ".$comlist{"output"} if ( exists($comlist{"output"}) );
   $call .= " ".$comlist{"tmpoutput"} if ( exists($comlist{"tmpoutput"}) );
  }
  print " rtlog.hsystem().DEBUG: call='$call'.\n" if ( $debug );
  $startTime = getTimeString(1);
   $rValue = rsystem($call,$debug);
   if ( $rValue!=0 ) {
    # removing output files
    my @coms = ();
    push(@coms,split(/\ /,$comlist{"output"})) if ( exists($comlist{"output"}) );
    push(@coms,split(/\ /,$comlist{"tmpoutput"})) if ( exists($comlist{"tmpoutput"}) );
    foreach my $com (@coms) {
     next if ( $com =~ m/^-/ );
     unlink($com) if ( -f $com );
    }
    return 0;
   }
  $endTime = getTimeString(1);
 }
 ### processing output file entries (create a xml log file for every output file)
 $comlist{"versionflag"} = "--version" unless ( exists $comlist{"versionflag"} );
 if ( exists($comlist{"output"}) || exists($comlist{"tmpoutput"}) || exists($comlist{"inoutput"}) ) {
  my @coms = ();
  push(@coms,split(/\ /,$comlist{"output"})) if ( exists($comlist{"output"}) );
  push(@coms,split(/\ /,$comlist{"tmpoutput"})) if ( exists($comlist{"tmpoutput"}) );
  push(@coms,split(/\ /,$comlist{"inoutput"})) if ( exists($comlist{"inoutput"}) );
  my $ncoms = scalar(@coms);
  my $outfile = "";
  for ( my $i=0 ; $i<$ncoms ; ) {
   if ( $coms[$i] =~ m/^\-/ ) {
    $outfile = $coms[$i+1];
    $i += 2;
   } else {
    $outfile = $coms[$i];
    $i += 1;
   }
   ### >>> outfilename processing
   my $callId = getUniqueIdent(basename($outfile));
   my $outfilename = basename($outfile);
   $outfilename =~ s/\.gz$// if ( $outfilename =~ m/\.gz$/ );
   my $outfilepath = dirname($outfile);
   $logfilename = createOutputPath($outfilepath."/.log")."/".$outfilename;
   $logfilename .= ".xml";
   my $prevSystemCall = undef;
   if ( exists($comlist{"inoutput"}) ) {
    if ( -e $logfilename ) {
     ### loading previous log file for that particular file
     open(FPin,"<$logfilename") || die "FATAL ERROR: Cannot read log file '".$logfilename."': $!";
      while ( <FPin> ) {
       next if ( $_ =~ m/HITPerlLog\>/ || $_ =~ m/\<System\>/ || $_ =~ m/\<File\>/ || $_ =~ m/\<Path\>/ );
       $prevSystemCall .= $_;
      }
     close(FPin);
    }
    $logfilename .= ".1";
   }
   print "rtlog.hsystem().DEBUG: writing log file '".$logfilename."'.\n" if ( defined($debug) && $debug>0 );
   open(FPlogout,">$logfilename") || die "FATAL ERROR: cannot create log file '".$logfilename."': $!";
    print FPlogout "<HITPerlLog version=\"0.1\" date=\"".getTimeString(1)."\">\n";
    if ( exists($comlist{"cpuname"}) ) {
     print FPlogout " <System node=\"".$comlist{"cpuname"}."\">".getSystemFullName()."</System>\n";
    } else {
     print FPlogout " <System>".getSystemFullName()."</System>\n";
    }
    print FPlogout " <User id=\"".$<."\">".(getpwuid($<))[0]."</User>\n" unless ( $^O =~ /Win/ );
    print FPlogout " <File>".basename($outfile)."</File>\n";
    print FPlogout " <Paths>\n";
    print FPlogout "  <data>".$outfilepath."</data>\n";
    ## print FPlogout "  <contourreconprojects>".getAtlasContourDataDrive()."</contourreconprojects>\n";
    ## print FPlogout "  <atlasdata>".getAtlasDataDrive()."</atlasdata>\n";
    print FPlogout " </Paths>\n";
    print FPlogout $prevSystemCall if ( defined($prevSystemCall) );
    print FPlogout " <SystemCall id=\"".$callId."\">\n";
    my $f = $comlist{"command"};
    my @exec = map {
     my $p = $_;
     grep { -f and -x } map File::Spec->catfile($p,"$f$_"),'',qw(.exe .com .bat)
    } File::Spec->path;
    ## or die "FATAL ERROR: Can't find executable '$f': $!";
    if ( scalar(@exec)>0 ) {
     my $filetime = ctime(stat($exec[0])->mtime);
     chomp($filetime);
     print FPlogout "  <command name=\"".$comlist{"command"}."\" filetime=\"".$filetime."\"";
     print FPlogout " revision=\"".getFileRevision($exec[0],$comlist{"versionflag"},$debug)."\"";
     print FPlogout " checksum=\"".getFileChecksum($exec[0],$verbose,$debug)."\">\n";
     my $libtool = "otool -L"; ### use ldd for linux machines
     my @sharedlibs = getSharedLibs($exec[0],$verbose,$debug);
     if ( scalar(@sharedlibs)>0 ) {
      print FPlogout "   <sharedlibs tool=\"".$libtool."\" numlibs=\"".scalar(@sharedlibs)."\">\n";
      my $nn = 0;
      foreach my $sharedlib (@sharedlibs) {
       print FPlogout "    <sharedlib num=\"".$nn."\">".$sharedlib."</sharedlib>\n";
       $nn += 1;
      }
      print FPlogout "   </sharedlibs>\n";
     } else {
      print FPlogout "   <sharedlibs>not available</sharedlibs>\n";
     }
    } else {
     print FPlogout "  <command name=\"".$comlist{"command"}."\">\n";
    }
    print FPlogout "   <startAt date=\"".$startTime."\"/>\n";
    ### >>>
    if ( exists($comlist{"commandline"}) ) {
     print FPlogout "    <commandline>".$comlist{"commandline"}."</commandline>\n";
    }
    ### >>>
    if ( exists($comlist{"options"}) ) {
     my @optionlist = getFileListFromString($comlist{"options"});
     print FPlogout "    <options numOptions=\"".scalar(@optionlist)."\">\n";
     my $num = 0;
     foreach my $option (@optionlist) {
      print FPlogout "     <option num=\"".$num."\">".$option."</option>\n";
      $num += 1;
     }
     print FPlogout "    </options>\n";
    }
    ### >>>
    my $n = 1;
    my $inputoutstring = "";
    my $ninputfiles = 0;
    if ( exists($comlist{"tmpinput"}) ) {
     my @inputfiles = getFileListFromString($comlist{"tmpinput"});
     print "rtlog.hsystem().DEBUG: tmpinputfiles(n=".scalar(@inputfiles).")=(".join(":",@inputfiles).")\n" if ( $debug );
     $ninputfiles += scalar(@inputfiles);
     foreach my $inputfile (@inputfiles) {
      my @fileelements = split(/\ /,$inputfile);
      my @cinputfiles = split(/\,/,(scalar(@fileelements)==1)?$inputfile:$fileelements[1]);
      print "rtlog.hsystem().DEBUG: nfileelements=".scalar(@fileelements)."=(".join(":",@fileelements).")\n" if ( $debug );
      my $tagIsOpen = 0;
      if ( scalar(@fileelements)>1 && 1==2 ) {
       $inputoutstring .= "     <inputfile num=\"".$n."\" name=\"".$fileelements[0]."\"";
      } else {
       # $inputoutstring .= "     <inputfile num=\"".$n."\"";
       # $tagIsOpen = 1;
      }
      my $presuffix = "";
      if ( $tagIsOpen ) {
       if ( scalar(@cinputfiles)>1 ) {
        $inputoutstring .= " type=\"multipletmp\" numFiles=\"".scalar(@cinputfiles)."\">\n";
        $presuffix = "m";
       } else {
        $inputoutstring .= " type=\"tmp\">\n";
       }
      }
      my $nn = 0;
      foreach my $cinputfile (@cinputfiles) {
       my $basefilename = basename($cinputfile);
       if ( $basefilename =~ m/^tmp/ && logFileIsReadable($cinputfile,$debug) ) {
        $inputoutstring .= "     <".$presuffix."inputfile num=\"".$nn."\" type=\"tmp\">\n";
        $inputoutstring .= "      <name>$inputfile</name>\n";
        $inputoutstring .= "      <Creator>\n";
        my $logfilename = getLogFileName($cinputfile);
        open(FPin,"<$logfilename") || die "FATAL ERROR: Cannot read log file '".$logfilename."' for reading: $!";
         while ( <FPin> ) {
          next if ( $_ =~ m/HITPerlLog/ );
          $inputoutstring .= "      ".$_;
         }
        close(FPin);
        unlink($logfilename) unless ( $debug );
        $inputoutstring .= "       </Creator>\n";
        $inputoutstring .= "      </".$presuffix."inputfile>\n";
       } else {
        $inputoutstring .= "      <".$presuffix."inputfile num=\"".$nn."\" type=\"tmp\"";
        $inputoutstring .= " checksum=\"".getFileChecksum($cinputfile,$verbose,$debug)."\">".$cinputfile."</".$presuffix."inputfile>\n";
       }
       $nn += 1;
      }
      $n += 1;
     }
    }
    if ( exists($comlist{"input"}) || exists($comlist{"inoutput"}) ) {
     my @inputfiles = ();
     push(@inputfiles,getFileListFromString($comlist{"input"})) if ( exists($comlist{"input"}) );
     push(@inputfiles,getFileListFromString($comlist{"inoutput"})) if ( exists($comlist{"inoutput"}) );
     ## push(@inputfiles,getFileListFromString($comlist{"minput"})) if ( exists($comlist{"input"}) );
     print "rtlog.hsystem().DEBUG: inputfiles(n=".scalar(@inputfiles).")=@inputfiles\n" if ( $debug );
     foreach my $inputfile (@inputfiles) {
      print "rtlog.hsystem().DEBUG: Processing '".$inputfile."'...\n" if ( $debug );
      if ( $inputfile =~ m/\,/ ) {
       my $tmpstring = "";
       my @cinfiles = split(/\,/,$inputfile);
       $nfiles = 0;
       foreach my $cinfile (@cinfiles) {
        ### !!! multiple files have often a separated defined input path !!!
        $tmpstring .= "      <file num=\"".$nfiles."\" checksum=\"".getFileChecksum($cinfile,$verbose,$debug)."\">".$cinfile."</file>\n";
        $nfiles += 1;
       }
       $inputoutstring .= "     <inputfile type=\"multiple\" numFiles=\"".$nfiles."\">\n";
       $inputoutstring .= $tmpstring;
       $inputoutstring .= "     </inputfile>\n";
      } else {
       $inputoutstring .= "     <inputfile num=\"".$n."\" type=\"regular\"";
       $inputoutstring .= " checksum=\"".getFileChecksum($inputfile,$verbose,$debug)."\">".$inputfile."</inputfile>\n";
       $n += 1;
      }
      $ninputfiles += 1;
     }
    }
    if ( exists($comlist{"minput"}) ) {
     my @liststrings = getFileListFromString($comlist{"minput"});
     foreach $liststring (@liststrings) {
      my %options = getOptions($liststring);
      if ( exists($options{"value"}) ) {
       my $cliststring = $options{"value"};
       ## my $files = `ls $cliststring`;
       my @inputfiles = split(/\n/,`ls $cliststring`);
       if ( scalar(@inputfiles)>0 ) {
        $nfiles = 0;
        my $tmpstring = "";
        foreach my $inputfile (@inputfiles) {
         $tmpstring .= "      <file num=\"".$nfiles."\" checksum=\"".getFileChecksum($inputfile,$verbose,$debug)."\">".$inputfile."</file>\n";
         $nfiles += 1;
        }
        $inputoutstring .= "     <inputfile num=\"".$ninputfiles." \"type=\"multiple\" option=\"";
        $inputoutstring .= $options{"argument"}." " if ( exists($options{"argument"}) );
        $inputoutstring .= $options{"value"}."\"";
        $inputoutstring .= " numFiles=\"".$nfiles."\">\n";
        $inputoutstring .= $tmpstring;
        $inputoutstring .= "     </inputfile>\n";
        $ninputfiles += 1;
       }
      } else {
       warn "rtlog.hsystem(): Parsing failure for argument '".$liststring."'.\n";
      }
     }
    }
    ### *** WHY *** $ninputfiles += $n-1; ***
    # write data to file ...
    if ( $ninputfiles>0 ) {
     print FPlogout "    <inputfiles numFiles=\"".$ninputfiles."\">\n";
     print FPlogout $inputoutstring;
     print FPlogout "    </inputfiles>\n";
    }
    ### output files (combined for output and tmpoutput)
    my @outputfiles = ();
    push(@outputfiles,getFileListFromString($comlist{"output"})) if ( exists($comlist{"output"}) );
    push(@outputfiles,getFileListFromString($comlist{"tmpoutput"})) if ( exists($comlist{"tmpoutput"}) );
    if ( scalar(@outputfiles)>0 ) {
     print FPlogout "    <outputfiles numFiles=\"".scalar(@outputfiles)."\">\n";
     my $n = 0;
     foreach my $outputfile (@outputfiles) {
      print FPlogout "     <outputfile num=\"".$n."\" type=\"".isInFileList($comlist{"tmpoutput"},$outputfile)."\"";
      print FPlogout " checksum=\"".getFileChecksum($outputfile,$verbose,$debug)."\">".$outputfile."</outputfile>\n";
      $n += 1;
     }
     print FPlogout "    </outputfiles>\n";
    }
    ### misc >>>
    print FPlogout "    <rValue>".$rValue."</rValue>\n" if ( defined($rValue) );
    print FPlogout "   <endAt date=\"".$endTime."\"/>\n";
    print FPlogout "  </command>\n";
    print FPlogout " </SystemCall>\n";
    print FPlogout "</HITPerlLog>\n";
   close(FPlogout);
   print "rtlog.hsystem().DEBUG: Created log file '".$logfilename."'.\n" if ( $debug );
  }
 }
 return 1;
}

### return value (required to evaluate to TRUE)
return 1;
