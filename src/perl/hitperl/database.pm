## hitperl::database package
########################################################################################################

### >>>
package hitperl::database;

### >>>
use DBI;
use Exporter;

### >>>
@ISA = ('Exporter');
@EXPORT = ( 'connectToDatabase', 'connectToAtlasDatabase', 'getAtlasDatabaseAccessData', 'fetchFromAtlasDatabase',
  'fetchRowFromAtlasDatabase', 'doAtlasDatabase', 'procAtlasDatabase', 'getProjectStructureIdsFromAtlasDatabase',
  'getBrainIdentFromAtlasDatabase', 'getSectionIdentFromAtlasDatabase', 'convertStructureIdentsToString',
  'getStructureIdentFromAtlasDatabase', 'getProjectStructureNamesFromAtlasDatabase', 'getBrainHasCerebellum',
  'getProjectInfoLine', 'getSectionGeometryFromAtlasDatabase', 'getStructureRGBAColorStringFromAtlasDatabase2',
  'getBrainNamedFieldFromAtlasDatabase', 'getSectionFieldFromAtlasDatabase', 'getBrainIdentsList',
  'getStructureFieldFromAtlasDatabase', 'getHEXColorStringFromAtlasDatabase', 'verifyStructuresInDatabase',
  'getTableFieldFromAtlasDatabase', 'getTableIdentFromAtlasDatabase', 'getTableFieldsFromAtlasDatabase',
  'getProjectNameOfStructureFromAtlasDatabase', 'getInvestigatorNameFromProjectName', 'tableExist',
  'getInvestigatorIdentFromProject', 'getListFromAtlasDatabase', 'getTableDim', 'getStructureColorsFromAtlasDatabase',
  'deleteFromAtlasDatabase', 'getRGBColorStringFromAtlasDatabase', 'getExtendedBrainInfoStringFromDB',
  'getStructureRGBAColorStringFromAtlasDatabase', 'getSectionROIFromAtlasDatabase', 'getStructureNameFromAtlasDatabase',
  'getAnatomicalStructureNameFromAtlasDatabase', 'getProjectStructureList', 'getProjectStructureColorList', 'getProjectBrainList',
  'getAtlasBrainsFromDatabase', 'getStructureIdentFromDB', 'getStructureDescriptionFromDB' );
$VERSION = 0.7;

### >>>
sub connectToDatabase {
 my ($hostname,$user,$passwd,$database) = @_;
 my $datasource = "DBI:mysql:database=$database;host=$hostname";
 my $dbh = DBI->connect($datasource,$user,$passwd,{'RaiseError'=>1}) ||
                 die "FATAL ERROR: Database connection not made: ".$DBI::errstr.".";
 return $dbh;
}
sub connectToAtlasDatabase {
 my ($hostname,$user,$passwd) = @_;
 return connectToDatabase($hostname,$user,$passwd,"atlas");
}

sub doAtlasDatabase {
 my ($dbh,$request,$debug) = @_;
 if ( $debug ) {
  print "database.doAtlasDatabase().DEBUG: command=".$request."\n";
  return;
 }
 $dbh->do($request);
}

sub procAtlasDatabase {
 my ($dbh,$request,$debug) = @_;
 if ( $debug ) {
  print "database.procAtlasDatabase().DEBUG: command=".$request."\n";
  return 0;
 }
 my $sth = $dbh->prepare($request);
 return $sth->execute();
}

sub fetchRowFromAtlasDatabase {
 my ($dbh,$request) = @_;
 ## print "request=$request\n";
 my $sth = $dbh->prepare($request);
 $sth->execute();
 return $sth->fetchrow_array();
}

sub fetchFromAtlasDatabase {
 my ($dbh,$request) = @_;
 my @row = fetchRowFromAtlasDatabase($dbh,$request);
 return $row[0];
 #return "not defined" unless ( defined($row[0]) );
 #return $row[0];
}

### >>>
sub tableExist {
 my ($dbh,$name,$verbose,$debug) = @_;
 my @tablenames = split(/\./,$name);
 my $sth = $dbh->prepare("SHOW TABLES IN $tablenames[0] LIKE '$tablenames[1]'");
 if ( $sth->execute() ) { 
  while( my $t = $sth->fetchrow_array() ) {
   return 1 if( $t =~ /^$tablenames[1]$/ );
  }
 }
 return 0;
}

### these are the most general database calls
sub getTableFieldsFromAtlasDatabase {
 my ($dbh,$table,$field,$request) = @_;
 my $sth;
 if ( defined($request) ) {
  $sth = $dbh->prepare("SELECT $field FROM $table WHERE $request");
 } else {
  $sth = $dbh->prepare("SELECT $field FROM $table");
 }
 $sth->execute();
 my @entries = ();
 while ( my @row = $sth->fetchrow_array() ) {
  push(@entries,$row[0]);
 }
 return @entries;
}

sub getTableFieldFromAtlasDatabase {
 my ($dbh,$table,$field,$request) = @_; ## $ident) = @_;
 # print " table='$table', field='$field', request='$request'\n";
 my @row = fetchRowFromAtlasDatabase($dbh,"SELECT $field FROM $table WHERE $request");
 return $row[0] if ( defined($row[0]) );
 return -1;
}

sub getTableIdentFromAtlasDatabase {
 my ($dbh,$table,$name) = @_;
 if ( defined($dbh) ) {
  my @row = fetchRowFromAtlasDatabase($dbh,"SELECT id FROM atlas.$table WHERE name='$name'");
  return $row[0] if ( defined($row[0]) );
 }
 return -1;
}

### get number of rows
sub getTableDim {
 my ($dbh,$table) = @_;
 my $sth = $dbh->prepare("SELECT id FROM atlas.$table");
 $sth->execute();
 my $nrows = $sth->rows;
 return $nrows;
}

###
sub getExtendedBrainInfoStringFromDB {
 my ($dbh,$brainname) = @_;
 my @row = fetchRowFromAtlasDatabase($dbh,"SELECT brainId,sectionplane,status FROM atlas.pmbrains WHERE name='$brainname'");
 return "$brainname\[id=$row[0], plane=$row[1], status=$row[2]\]";
}

sub getBrainIdentFromAtlasDatabase {
 my ($dbh,$brainname) = @_;
 if ( defined($dbh) ) {
  my @row = fetchRowFromAtlasDatabase($dbh,"SELECT id FROM atlas.pmbrains WHERE name='$brainname'");
  return $row[0] if ( defined($row[0]) );
 }
 return -1;
}

###
sub getBrainNamedFieldFromAtlasDatabase {
 my ($dbh,$field,$ident) = @_;
 my @row = fetchRowFromAtlasDatabase($dbh,"SELECT $field FROM atlas.pmbrains WHERE id='$ident'");
 return $row[0] if ( defined($row[0]) );
 return -1;
}

###
sub getBrainHasCerebellum {
 my ($dbh,$name,$verbose) = @_;
 my @row = fetchRowFromAtlasDatabase($dbh,"SELECT cerebellum FROM atlas.pmbrains WHERE name='$name'");
 return $row[0] if ( defined($row[0]) );
 return -1;
}

### >>>
sub getBrainIdentsList {
 my ($dbh,$verbose,$debug) = @_;
 my %idents = ();
 my $sth = $dbh->prepare("SELECT brainId,name FROM atlas.pmbrains");
 $sth->execute();
 while ( my @row = $sth->fetchrow_array() ) {
  print "database.getBrainIdentsList().DEBUG: name=$row[1], ident=$row[0].\n" if ( $debug );
  $idents{$row[1]} = $row[0];
 }
 return %idents;
}

###
sub getSectionIdentFromAtlasDatabase {
 my ($dbh,$number,$brainId) = @_;
 my @row = fetchRowFromAtlasDatabase($dbh,"SELECT id FROM atlas.histosections WHERE name='$number' AND brainId='$brainId'");
 return $row[0] if ( defined($row[0]) );
 return -1;
}

###
sub getSectionFieldFromAtlasDatabase {
 my ($dbh,$field,$ident) = @_;
 my @row = fetchRowFromAtlasDatabase($dbh,"SELECT $field FROM atlas.histosections WHERE id='$ident'");
 return $row[0] if ( defined($row[0]) );
 return -1;
}

### this is an older version
sub getSectionGeometryFromAtlasDatabase {
 my ($dbh,$number,$brainId) = @_;
 my @row = fetchRowFromAtlasDatabase($dbh,"SELECT roi FROM atlas.histosections WHERE name='$number' AND brainId='$brainId'");
 return $row[0] if ( defined($row[0]) );
 return -1;
}

### this is the new version
sub getSectionROIFromAtlasDatabase {
 my ($dbh,$brain,$section) = @_;
 my $brainIdent = getBrainIdentFromAtlasDatabase($dbh,$brain);
 return "1x1++" if ( $brainIdent==-1 );
 return getTableFieldFromAtlasDatabase($dbh,"histosections","roi","NAME='$section' AND brainId='$brainIdent'");
}

### *** DEPRECATED ***
### look first in the rename table (only if $projectId has not been defined) and then in the atlas.structures table
### WARNING: This is NOT unique for all cases. It fails for instance for the rename of FG3 and FG4.
### *** DEPRECATED ***
sub getStructureIdentFromAtlasDatabase {
 my ($dbh,$strucname,$projectId) = @_;
 my $request = "name='$strucname'";
 if ( defined($projectId) ) {
  $request .= " AND projectId='$projectId'";
  my @row = fetchRowFromAtlasDatabase($dbh,"SELECT id FROM atlas.structures WHERE $request");
  return $row[0] if ( defined($row[0]) );
 } else {
  my @row = fetchRowFromAtlasDatabase($dbh,"SELECT id FROM atlas.structurerename WHERE $request");
  if ( defined($row[0]) ) {
   return $row[0];
  } else {
   @row = fetchRowFromAtlasDatabase($dbh,"SELECT id FROM atlas.structures WHERE $request");
   return $row[0] if ( defined($row[0]) );
  }
 }
 return -1;
}
sub getStructureIdentFromDB {
 my ($dbh,$strucname,$projectname,$verbose,$debug) = @_;
 my $projectid = getTableIdentFromAtlasDatabase($dbh,"projects",$projectname);
 return getStructureIdentFromAtlasDatabase($dbh,$strucname,$projectid);
}

### >>>
sub getStructureDescriptionFromDB {
 my ($dbh,$ident,$verbose,$debug) = @_;
 my @row = fetchRowFromAtlasDatabase($dbh,"SELECT description FROM atlas.structures WHERE id='$ident'");
 return defined($row[0])?$row[0]:"";
}

### >>>
sub getStructureNameFromAtlasDatabase {
 my ($dbh,$ident,$verbose,$debug) = @_;
 my @structurerow = fetchRowFromAtlasDatabase($dbh,"SELECT name,projectId FROM atlas.structures WHERE id='$ident'");
 return "unknown_structure" unless ( defined($structurerow[0]) );
 my @projectrow = fetchRowFromAtlasDatabase($dbh,"SELECT name FROM atlas.projects WHERE id='$structurerow[1]'");
 return "unknown.".$structurerow[0] unless ( defined($projectrow[0]) );
 return $projectrow[0].".".$structurerow[0];
}

sub getAnatomicalStructureNameFromAtlasDatabase {
 my ($dbh,$ident,$fullName,$delimiter,$verbose,$debug) = @_;
 # get correct projectname first
 my $projectname = "unknownproject";
 if ( $fullName ) {
  $projectGroupNamesId = 0;
  ## check first whether we have a rename of the project
  my @projectrenamerow = fetchRowFromAtlasDatabase($dbh,"SELECT projectGroupId FROM atlas.structureprojectrename WHERE structureId='$ident'");
  if ( defined($projectrenamerow[0]) ) {
   $projectGroupNamesId = $projectrenamerow[0];
  } else {
   my @projectidrow = fetchRowFromAtlasDatabase($dbh,"SELECT projectId FROM atlas.structures WHERE id='$ident'"); 
   return "mismatched_structure" unless ( defined($projectidrow[0]) );
   my @projectgrouprow = fetchRowFromAtlasDatabase($dbh,"SELECT groupId FROM atlas.projectgroups WHERE projectId='$projectidrow[0]'");
   if ( !defined($projectgrouprow[0]) ) {
    my @projectrow = fetchRowFromAtlasDatabase($dbh,"SELECT name FROM atlas.projects WHERE id='$projectidrow[0]'");
    $projectname = $projectrow[0] if ( defined($projectrow[0]) );
   } else {
    $projectGroupNamesId = $projectgrouprow[0];
   }
  }
  my @projectgroupnamerow = fetchRowFromAtlasDatabase($dbh,"SELECT name FROM atlas.projectgroupnames WHERE id='$projectGroupNamesId'");
  $projectname = $projectgroupnamerow[0] if ( defined($projectgroupnamerow[0]) );
 }
 $delimiter = "." unless ( defined($delimiter) );
 # get correct structurename
 my @structurerrow = fetchRowFromAtlasDatabase($dbh,"SELECT name FROM atlas.structurerename WHERE structureId='$ident'");
 if ( defined($structurerrow[0]) ) {
  return $structurerrow[0] unless ( $fullName );
  return $projectname.$delimiter.$structurerrow[0];
 } 
 my @structurerow = fetchRowFromAtlasDatabase($dbh,"SELECT name FROM atlas.structures WHERE id='$ident'");
 unless ( defined($structurerow[0]) ) {
  return "unknownstructure" unless ( $fullName );
  return $projectname.$delimiter."unknownstructure";
 }
 return $structurerow[0] unless ( $fullName );
 return $projectname.$delimiter.$structurerow[0];
}

sub getStructureFieldFromAtlasDatabase {
 my ($dbh,$field,$ident) = @_;
 my @row = fetchRowFromAtlasDatabase($dbh,"SELECT $field FROM atlas.structures WHERE id='$ident'");
 return $row[0] if ( defined($row[0]) );
 return -1;
}

# returns a one-line description of the project (for LaTeX processing)
sub getProjectInfoLine {
 my ($dbh,$projectname,$revision,$debug) = @_;
 my $infoline = "Project:";
 if ( $dbh!=undef ) {
  my $projectId = -1;
  my @projects = split('_',$projectname);
  if ( scalar(@projects)>1 ) {
   return " Multiple (n=".scalar(@projects).") projects: ".$projectname;
  } else {
   $projectId = getTableIdentFromAtlasDatabase($dbh,"projects",$projectname);
   if ( $projectId<=0 ) {
    $infoline .= " $projectname, SERIOUS WARNING *** invalid project ***";
    return $infoline;
   }
  }
  ## project name
  my $denotation = getTableFieldFromAtlasDatabase($dbh,"projectrename","name","id='$projectId'");
  if ( $denotation!=-1 ) {
   $infoline .= " \\textbf{$denotation}";
  } else {
   $infoline .= " \\textbf{$projectname}";
  }
  ## principal investigator name
  $infoline .= ", PI: \\textbf{".getInvestigatorNameFromProjectName($dbh,$projectname)."}";
  ## last change line
  $infoline .= ", Last change: \\textbf{".getTableFieldFromAtlasDatabase($dbh,"projects","date","id='$projectId'")."}";
  ## Revision (this is NOT a database request!!!)
  $infoline .= ", Revision: \\textbf{".$revision."}";
 } else {
  $infoline .= " \\textbf{$projectname}, PI: \\textbf{unknown}, Last change: \\textbf{unknown}, Revision: 0";
 }
 return $infoline;
}

# >>>
sub getProjectBrainList {
 my ($dbh,$projectname,$verbose,$debug) = @_;
 my $projectId = fetchFromAtlasDatabase($dbh,"SELECT id FROM atlas.projects WHERE name='$projectname'");
 my $sth = $dbh->prepare("SELECT brainId FROM atlas.projectbrains WHERE projectId='$projectId'");
 $sth->execute();
 my %brains = ();
 while ( my @row = $sth->fetchrow_array() ) {
  my @brainrow = fetchRowFromAtlasDatabase($dbh,"SELECT name FROM atlas.pmbrains WHERE id='$row[0]'");
  $brains{$row[0]} = $brainrow[0];
 }
 return %brains;
}

# returns an rgb list of all project structures
# the first solution has problems when different structures of a project have the same colorId
sub getProjectStructureColorList_old {
 my ($dbh,$projectname,$debug) = @_;
 my $projectId = fetchFromAtlasDatabase($dbh,"SELECT id FROM atlas.projects WHERE name='$projectname'");
 print "database.getProjectStructureColorList_old().DEBUG: project[$projectname]=$projectId\n" if ( $debug );
 my @colorids = getTableFieldsFromAtlasDatabase($dbh,"structures","colorId","projectId='$projectId'");
 print "database.getProjectStructureColorList_old().DEBUG: colorids=@colorids\n" if ( $debug );
 my %colorlist = ();
 foreach my $colorid (@colorids) {
  my $strucname = fetchFromAtlasDatabase($dbh,"SELECT name FROM atlas.structures WHERE projectId='$projectId' AND colorId='$colorid'");
  $colorlist{$strucname} = getRGBColorStringFromAtlasDatabase($dbh,$colorid);
 }
 return %colorlist;
}
sub getProjectStructureColorList {
 my ($dbh,$project,$debug) = @_;
 my $projectId = fetchFromAtlasDatabase($dbh,"SELECT id FROM atlas.projects WHERE name='$project'");
 my @structures = getProjectStructureNamesFromAtlasDatabase($dbh,$project);
 my %colorlist = ();
 foreach my $structure (@structures) {
  my $colorId = fetchFromAtlasDatabase($dbh,"SELECT colorId FROM atlas.structures WHERE projectId='$projectId' AND name='$structue'");
  $colorlist{$structure} = getRGBColorStringFromAtlasDatabase($dbh,$colorId);
 }
 return %colorlist;
}

sub getProjectStructureList {
 my ($dbh,$projectname,$verbose,$debug) = @_;
 my $projectId = fetchFromAtlasDatabase($dbh,"SELECT id FROM atlas.projects WHERE name='$projectname'");
 my $sth = $dbh->prepare("SELECT id,name FROM atlas.structures WHERE projectId='$projectId'");
 $sth->execute();
 my %structurelist = ();
 while ( my @row = $sth->fetchrow_array() ) {
  $structurelist{$row[0]} = $row[1];
 }
 return %structurelist;
}

sub getProjectStructureNamesFromAtlasDatabase {
 my ($dbh,$projectname,$extended) = @_;
 my $projectId = fetchFromAtlasDatabase($dbh,"SELECT id FROM atlas.projects WHERE name='$projectname'");
 if ( defined($extended) && $extended==1 ) {
  my %structureinfos = ();
  my $sth = $dbh->prepare("SELECT name,id FROM atlas.structures WHERE projectId='$projectId'");
  $sth->execute();
  while ( my @row = $sth->fetchrow_array() ) {
   $structureinfos{$row[1]} = $row[0];
  }
  return %structureinfos;
 }
 my $sth = $dbh->prepare("SELECT name FROM atlas.structures WHERE projectId='$projectId'");
 $sth->execute();
 my @names = ();
 while ( my @row = $sth->fetchrow_array() ) {
  push(@names,$row[0]);
 }
 return @names;
}

sub getProjectStructureIdsFromAtlasDatabase {
 my ($dbh,$projectname) = @_;
 my $projectId = 0;
 if ( $projectname =~ /^[+-]?\d+$/ ) {
  ### is number
  $projectId = $projectname;
 } else {
  $projectId = fetchFromAtlasDatabase($dbh,"SELECT id FROM atlas.projects WHERE name='$projectname'");
 }
 my $sth = $dbh->prepare("SELECT id FROM atlas.structures WHERE projectId='$projectId'");
 $sth->execute();
 my @ids = ();
 while ( my @row = $sth->fetchrow_array() ) {
  push(@ids,$row[0]);
 }
 return @ids;
}

### deprecated: do not use it because the name of a structure is NOT unique
sub getProjectNameOfStructureFromAtlasDatabase {
 my ($dbh,$structurename) = @_;
 my @row = fetchRowFromAtlasDatabase($dbh,"SELECT projectId FROM atlas.structures WHERE name='$structurename'");
 return "unknown" unless ( defined($row[0]) );
 return getTableFieldFromAtlasDatabase($dbh,"projects","name",$row[0]);
}

sub getProjectStructureNeighborNamesFromAtlasDatabase {
 my ($dbh,$projectname) = @_;
 my $projectId = fetchFromAtlasDatabase($dbh,"SELECT id FROM atlas.projects WHERE name='$projectname'");
 my @names = ();
 return @names;
}

sub getInvestigatorIdentFromProject {
 my ($dbh,$projectname) = @_;
 return fetchFromAtlasDatabase($dbh,"SELECT investigatorId FROM atlas.projects WHERE name='$projectname'");
}

sub getInvestigatorNameFromProjectName {
 my ($dbh,$projectname,$withMail) = @_;
 my $investigatorId = getInvestigatorIdentFromProject($dbh,$projectname);
 return "unknown" if ( $investigatorId==0 );
 if ( defined($withMail) ) {
  my @row = fetchRowFromAtlasDatabase($dbh,"SELECT name,vorname,email FROM atlas.user WHERE id='$investigatorId'");
  return "$row[1] $row[0]:$row[2]" if ( defined($row[0]) );
 } else {
  my @row = fetchRowFromAtlasDatabase($dbh,"SELECT name,vorname FROM atlas.user WHERE id='$investigatorId'");
  return "$row[1] $row[0]" if ( defined($row[0]) );
 }
 return "unknown";
}

sub getRGBColorStringFromAtlasDatabase {
 my ($dbh,$ident) = @_;
 return "255 0 0" if ( $ident<=0 );
 my @row = fetchRowFromAtlasDatabase($dbh,"SELECT red,green,blue FROM atlas.structurecolors WHERE id='$ident'");
 return "$row[0] $row[1] $row[2]";
}

sub getHEXColorStringFromAtlasDatabase {
 my ($dbh,$ident) = @_;
 my @row = fetchRowFromAtlasDatabase($dbh,"SELECT red,green,blue FROM atlas.structurecolors WHERE id='$ident'");
 if ( defined($row[0]) ) {
  my $hex = "#";
  for ( my $i=0 ; $i<3 ; $i++ ) {
   if ( $row[$i]<16 ) {
    $hex .= sprintf("0%x",$row[$i]);
   } else {
    $hex .= sprintf("%x",$row[$i]);
   }
  }
  return $hex;
 }
 return "#FF0000";
}

### this is bad because the name of a structure is NOT a unique identifier
sub getStructureRGBAColorStringFromAtlasDatabase {
 my ($dbh,$structure) = @_;
 my $colorident = getTableFieldFromAtlasDatabase($dbh,"structures","colorId","NAME='$structure'");
 if ( $colorident==-1 ) {
  print "WARNING: could not fetch colorident of structure '$structure' from atlas database.\n";
  return "255:0:0:255";
 }
 my $colorline = getRGBColorStringFromAtlasDatabase($dbh,$colorident);
 $colorline =~ s/\ /\:/g;
 $colorline .= ":255";
 return $colorline;
}
### this is better!!!
sub getStructureRGBAColorStringFromAtlasDatabase2 {
 my ($dbh,$structureId,$format) = @_;
 my $colorId = getTableFieldFromAtlasDatabase($dbh,"atlas.structures","colorId","id='$structureId'");
 if ( $colorId==-1 ) {
  print "WARNING: could not fetch colorId of structure '$structureId' from atlas database.\n";
  return "#FF0000" if ( defined($format) && $format =~ m/^hex$/i );
  return "255:0:0:255";
 }
 if ( defined($format) && $format =~ m/^hex$/i ) {
  return getHEXColorStringFromAtlasDatabase($dbh,$colorId);
 }
 my $colorline = getRGBColorStringFromAtlasDatabase($dbh,$colorId);
 $colorline =~ s/\ /\:/g;
 if ( defined($format) ) {
  if ( $format =~ m/^rgb$/i ) {
   return "rgb(".$colorline.")";
  } elsif ( $format =~ m/^rgba$/i ) {
   return "rgba(".$colorline.":255)";
  }
 }
 $colorline .= ":255";
 return $colorline;
}
### >>>>
sub getStructureColorsFromAtlasDatabase {
 my ($dbh,$verbose,$debug) = @_;
 my %structurecolors = ();
 my $sth = $dbh->prepare("SELECT id FROM atlas.structures");
 $sth->execute();
 while ( my @row = $sth->fetchrow_array() ) {
  my @rgbcolors = split(/\:/,getStructureRGBAColorStringFromAtlasDatabase2($dbh,$row[0]));
  @{$structurecolors{$row[0]}} = ($rgbcolors[0]/255.0,$rgbcolors[1]/255.0,$rgbcolors[2]/255.0);
  print "database.getStructureColorsFromAtlasDatabase().DEBUG: structure id=$row[0] -> rgbcolor=($rgbcolors[0]:$rgbcolors[1]:$rgbcolors[2])\n" if ( $debug );
 }
 return %structurecolors;
}

### ??? cypher access data ???
sub getAtlasDatabaseAccessData {
 my $accessfile = shift;
 my @accessdata = ("","");
 open(FPin,"<$accessfile") || die "FATAL ERROR: Cannot open database access file '".$accessfile."': $!";
  while ( <FPin> ) {
   chomp($_);
   my @values = split(/\=/,$_);
   if ( $_ =~ m/^login/i ) {
    $accessdata[0] = $values[1];
   } elsif ( $_ =~ m/^password/i ) {
    $accessdata[1] = $values[1];
   }
  }
 close(FPin);
 return @accessdata;
}

### get list of the atlas.database
sub getListFromAtlasDatabase {
 my ($dbh,$field,$table) = @_;
 my @results = ();
 my $sth = $dbh->prepare("SELECT $field FROM atlas.$table");
 $sth->execute();
 while ( my @outcomes = $sth->fetchrow_array() ) {
  push(@results,$outcomes[0]);
 }
 return @results;
}

### >>>
sub getAtlasBrainsFromDatabase {
 my ($dbh,$type) = @_;
 my $request = "SELECT name FROM atlas.pmbrains";
 if ( defined($type) ) {
  if ( $type =~ m/^isAtlasBrain$/i ) {
   $request .= " WHERE isAtlasBrain='1'";
  } else {
   $request .= " WHERE status='$type'";
  }
 }
 my $sth = $dbh->prepare($request);
 $sth->execute();
 my @atlasbrains = ();
 while ( my @outcomes = $sth->fetchrow_array() ) {
  push(@atlasbrains,$outcomes[0]);
 }
 return @atlasbrains;
}

### >>>
sub deleteFromAtlasDatabase {
 my ($dbh,$tablename,$opcommand,$debug) = @_;
 if ( $debug ) {
  print "DEBUG: sql[DELETE FROM $tablename WHERE $opcommand].\n";
  return;
 }
 my $sth = $dbh->prepare("DELETE FROM $tablename WHERE $opcommand");
 $sth->execute();
 $sth->finish();
}

### >>>
sub convertStructureIdentsToString {
 my ($dbh,$idents_ptr,$debug) = @_;
 my @strucidents = @{$idents_ptr};
 my @strucnames = ();
 foreach my $strucident (@strucidents) {
  my $strucname = fetchFromAtlasDatabase($dbh,"SELECT name FROM atlas.structures WHERE id='$strucident'");
  push(@strucnames,$strucname);
 }
 return @strucnames;
}

### checks whether the structures of a named project are in the database
sub verifyStructuresInDatabase {
 my ($dbh,$project,$projectstructures_ptr,$verbose,$debug) = @_;
 my @projectstructures = @{$projectstructures_ptr};
 my $prjident = getTableIdentFromAtlasDatabase($dbh,"projects",$project);
 print "database.verifyStructureDatabase(): processing project=$project, id=$prjident, structures[n=".scalar(@projectstructures)."]=@projectstructures\n" if ( $verbose );
 my @dbprojectstructures = getProjectStructureNamesFromAtlasDatabase($dbh,$project);
 print "database.verifyStructureDatabase().DEBUG: dbprojectstructures=@dbprojectstructures\n" if ( $debug );
 my @missings = ();
 foreach my $prjstructure (@projectstructures) {
  my $found = 0;
  foreach my $a (@dbprojectstructures) {
   if ( $a eq $prjstructure ) {
    $found = 1;
    last;
   }
  }
  push(@missings,$prjstructure) if ( $found==0 );
 }
 return @missings;
}

sub _debug { warn "@_\n" if $DEBUG; }

### return value
1;
