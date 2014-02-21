#!/usr/bin/perl
## **********************************************************************
## Copyright (c) 2012-2014, Aaron J. Graves (cajunman4life@gmail.com)
## All rights reserved.
##
## Redistribution and use in source and binary forms, with or without 
## modification, are permitted provided that the following conditions are met:
##
## 1. Redistributions of source code must retain the above copyright notice, 
##    this list of conditions and the following disclaimer.
## 2. Redistributions in binary form must reproduce the above copyright notice,
##    this list of conditions and the following disclaimer in the documentation
##    and/or other materials provided with the distribution.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
## AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
## ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
## LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
## CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
## SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
## INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
## CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
## POSSIBILITY OF SUCH DAMAGE.
## **********************************************************************
## This is Aneuch, which means 'enough.' I hope this wiki is enough for you.
## **********************************************************************
package Aneuch;
use 5.010;		# Require perl 5.10 or higher
use strict;		# Require strict declarations
use POSIX qw(strftime);	# String from time
use Fcntl qw(:flock :seek); # import LOCK_* and SEEK_END constants
#use CGI::Carp qw(fatalsToBrowser);
local $| = 1;		# Do not buffer output
# Some variables
use vars qw($DataDir $SiteName $Page $ShortPage @Passwords $PageDir $ArchiveDir
$ShortUrl $SiteMode $ScriptName $ShortScriptName $Header $Footer $PluginDir 
$Url $DiscussText $DiscussPrefix $DiscussLink $DefaultPage $CookieName 
$PageName %FORM $TempDir @Messages $command $contents @Plugins $TimeStamp
$PostFooter $TimeZone $VERSION $EditText $RevisionsText $NewPage $NewComment
$NavBar $ConfFile $UserIP $UserName $VisitorLog $LockExpire %Filec $MTime
$RecentChangesLog $Debug $DebugMessages $PageRevision $MaxVisitorLog
%Commands %AdminActions %AdminList $RemoveOldTemp $ArgList $ShortDir
@NavBarPages $BlockedList %PostingActions $HTTPStatus $PurgeRC %MaintActions
$PurgeArchives $SearchPage $SearchBox $TemplateDir $Template $FancyUrls
%QuestionAnswer $BannedContent %Param %SpecialPages $SurgeProtectionTime
$SurgeProtectionCount @PostInitSubs $EditorLicenseText $AdminText $RandomText
$CountPageVisits $PageVisitFile);
my %srvr = (
  80 => 'http://',	443 => 'https://',
);

$VERSION = '0.30';	# Set version number

# Subs
sub InitConfig  {
  $ConfFile = 'config.pl' unless $ConfFile; # Set default unless we get it
  if(-f $ConfFile) {		# File exists
    do $ConfFile;		# Execute the config
  }
}

sub InitScript {
  # Figure out the script name, URL, etc.
  # Initially includes script name. If $FancyUrls is set, we'll get rid of it.
  $ShortUrl = $ENV{'SCRIPT_NAME'};
  $Url = $srvr{$ENV{'SERVER_PORT'}} . $ENV{'HTTP_HOST'} . $ShortUrl;
  $ScriptName = $ENV{'SCRIPT_NAME'};
  $ShortScriptName = $0;
}

sub InitVars {
  # Safe path
  $ENV{'path'} = '/usr/bin:/bin';
  # We must be the first entry in Plugins
  @Plugins = ("aneuch.pl, version $VERSION, <a href='http://aneuch.myunixhost.com/' target='_blank'>Aneuch Wiki Engine</a>");
  # Define settings
  $DataDir = '/tmp/aneuch' unless $DataDir;	# Location of docs
  $DefaultPage = 'HomePage' unless $DefaultPage; # Default page
  @Passwords = qw() unless @Passwords;		# No password by default
  $SiteMode = 0 unless $SiteMode;		# 0=All, 1=Discus only, 2=None
  $DiscussPrefix = 'Discuss_' unless $DiscussPrefix; # Discussion page prefix
  $SiteName = 'Aneuch' unless $SiteName;	# Default site name
  $CookieName = 'Aneuch' unless $CookieName;	# Default cookie name
  $TimeZone = 0 unless $TimeZone;		# Default to GMT, 1=localtime
  $LockExpire = 60*5 unless $LockExpire;	# 5 mins, unless set elsewhere
  $Debug = 0 unless $Debug;			# Assume no debug
  $MaxVisitorLog = 1000 unless $MaxVisitorLog;	# Keep at most 1000 entries in
						#  visitor log
  $RemoveOldTemp = 60*60*24*7 unless $RemoveOldTemp; # > 7 days
  $PurgeRC = 60*60*24*7 unless $PurgeRC;	# > 7 days
  $PurgeArchives = -1 unless $PurgeArchives;	# Default to keep all!
  $Template = "" unless $Template;		# No theme by default
  $FancyUrls = 1 unless defined $FancyUrls;	# Use fancy urls w/.htaccess
  # New page and new comment default text
  $NewPage = 'It appears that there is nothing here.' unless $NewPage;
  $NewComment = 'Add your comment here.' unless $NewComment;
  # $SurgeProtectionTime is the number of seconds in the past to check hits
  $SurgeProtectionTime = 20 unless defined $SurgeProtectionTime;
  # $SurgeProtectionCount is the number of hits in the defined amount of time
  $SurgeProtectionCount = 20 unless defined $SurgeProtectionCount;
  # Count the number of visits to each page
  $CountPageVisits = 1 unless defined $CountPageVisits;

  # If $FancyUrls, remove $ShortScriptName from $ShortUrl
  if(($FancyUrls) and ($ShortUrl =~ m/$ShortScriptName/)) {
    $ShortUrl =~ s/$ShortScriptName//;
    $Url =~ s/$ShortScriptName//;
  } else {
    $ShortUrl .= "/";
    $Url .= "/";
  }

  # Some cleanup
  #  Remove trailing slash from $DataDir, if it exists
  $DataDir =~ s!/\z!!;

  # Initialize Directories
  InitDirs();

  # Get page name that is being requested
  #$Page = ((defined $ENV{'PATH_INFO'}) and ($ENV{'QUERY_STRING'} eq '')) ? $ENV{'PATH_INFO'} : $ENV{'QUERY_STRING'};
  #if($ENV{'QUERY_STRING'} and $ENV{'QUERY_STRING'} !~ m/=/ and !$ENV{'PATH_INFO'}) {
  #  $Page = $ENV{'QUERY_STRING'};
  #} elsif($ENV{'PATH_INFO'}) {
  #  $Page = $ENV{'PATH_INFO'};
  #}
  $Page = $ENV{'PATH_INFO'};
  $Page =~ s/^\/{1,}//;
  if($Page) {
    $Param{'page'} = $Page;
  }
  if($ENV{'QUERY_STRING'} and $ENV{'QUERY_STRING'} !~ /=/ and !$Page) {
    $Page = $ENV{'QUERY_STRING'};
    $ENV{'QUERY_STRING'} = '';
  }
  #$Page =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;   # Get "plain"
  s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg for ($Page,
    $ENV{'QUERY_STRING'});
  #$Page =~ s/&/;/g;	# Replace ampersand with semicolon
  s/&/;/g for ($Page, $ENV{'QUERY_STRING'});
  #$Page =~ s/^\?{1,}//;	# Get rid of leading '?', if it's there.
  s/^\?{1,}// for ($Page, $ENV{'QUERY_STRING'});
  #if($Page =~ m/=/) {	# We're getting some variables
  if($ENV{'QUERY_STRING'} =~ m/=/) {
    # Read them, split them, add them to %Param
    #foreach my $arg (split(/;/,$Page)) {
    foreach my $arg (split(/;/,$ENV{'QUERY_STRING'})) {
      my @args = split(/=/,$arg);
      $Param{$args[0]} = $args[1];
    }
    if(!GetParam('page') and !$Page) {	# Set Param 'page' if it's not already
      $Param{page} = (GetParam('do',0)) ? GetParam('do') : $Page;
    }
  }
  if(GetParam('page',0)) { $Page = $Param{page}; }
  if($Page =~ m/^\//) { $Page =~ s!/!!; }
  # If there is a space in the page name, and it's not part of a command,
  #  we're going to convert all the spaces to underscores and re-direct.
  if(($Page =~ m/.*\s.*/ or $Page =~ m/^\s.*/) and !$Page =~ m/^?/) {
    $Page =~ s/ /_/g;             # Convert spaces to underscore
    ReDirect($Url.$Page);
    exit 0;
  }
  if(GetParam('search',0)) { $Param{search} =~ s/\+/ /g; }
  $Page =~ s!^/!!;		# Remove leading slash, if it exists
  $Page =~ s/^\.+//g;		# Remove leading periods
  $Page =~ s!\.{2,}!!g;         # Remove every instance of double period
  # Wait! If there's a trailing slash, let's remove and redirect...
  if($Page =~ m!/$!) {
    $Page =~ s!/$!!;		# Remove the trailing slash
    $HTTPStatus = "Status: 301 Moved Permanently"; # Set 301 status
    print "$HTTPStatus\n";	# 301 Moved for search engines
    ReDirect($Url.$Page);	# Redirect to the page sans trailing slash
    exit 0;
  }
  if($Page eq "") { 
    $Page = $DefaultPage;	# Default if blank
  }
  $PageName = $Page;		# PageName is Page with spaces
  $PageName =~ s/_/ /g;		# Change underscore to space

  $ShortDir = substr($Page,0,1);	# Get first letter
  $ShortDir =~ tr/[a-z]/[A-Z]/;		# Capitalize it

  # I know we just went through all that crap, but if command=admin, we need:
  # FIXME: Is this needed anymore?
  if(GetParam('do','') eq 'admin') {
    #$PageName = 'Admin';
    #$ShortPage = '';
    #$Page = '';
  }

  # Discuss, edit links
  if(!GetParam('do')) {
    if($Page !~ m/^$DiscussPrefix/) {	# Not a discussion page
      $DiscussLink = $ShortUrl . $DiscussPrefix . $Page;
      $DiscussText = $DiscussPrefix;
      $DiscussText =~ s/_/ /g;
      $DiscussText .= $Page . " (".DiscussCount().")";
      $DiscussText = '<a title="'.$DiscussText.'" href="'.$DiscussLink.'">'.
	$DiscussText.'</a>';
    } else {				# Is a discussion page
      $DiscussLink = $Page;
      $DiscussLink =~ s/^$DiscussPrefix//;	# Strip discussion prefix
      $DiscussText = $DiscussLink;
      $DiscussLink = $ShortUrl . $DiscussLink;
      $DiscussText = '<a title="Return to '.$DiscussText.'" href="'.
	$DiscussLink.'">'.$DiscussText.'</a>';
    }
    # Edit link
    if(CanEdit()) {
      $EditText = '<a title="Click to edit this page" rel="nofollow" href="'.
	$ShortUrl;
      if($ShortUrl !~ m/\?$/) { $EditText .= "?"; }
      $EditText .= 'do=edit;page='.$Page.'">Edit Page</a>';
    } else {
      $EditText = '<a title="Read only page" rel="nofollow" href="'.$ShortUrl;
      if($ShortUrl !~ m/\?$/) { $EditText .= "?"; }
      $EditText .= 'do=edit;page='.$Page.'">Read Only</a>';
    }
    $RevisionsText = '<a title="Click here to see info and history" '.
      'rel="nofollow" href="'.$ShortUrl;
    if($ShortUrl !~ m/\?$/) { $RevisionsText .= "?"; }
    $RevisionsText .= 'do=history;page='.$Page.'">Page Info &amp; History</a>';
  }

  # Admin link
  $AdminText = "<a title=\"Administration options\" rel=\"nofollow\" href=\"$ShortUrl?do=admin;page=admin\">Admin</a>";

  # Random link
  $RandomText = "<a title=\"Random page\" rel=\"nofollow\" href=\"$ShortUrl?do=random;page=$Page\">Random Page</a>";

  # If we're a command, change the page title
  if(GetParam('do') eq 'search') {
    $PageName = "Search for: ".GetParam('search','');
  }

  # Set the TimeStamp
  $TimeStamp = time;

  # Set visitor IP address
  $UserIP = $ENV{'REMOTE_ADDR'};
  ($UserName) = &ReadCookie;
  if(!$UserName) { $UserName = $UserIP; }

  # Navbar
  $NavBar = "<ul id=\"navbar\"><li><a href='$ShortUrl$DefaultPage' ".
    "title='$DefaultPage'>$DefaultPage</a></li><li><a href='".$ShortUrl.
    "RecentChanges' title='RecentChanges'>RecentChanges</a></li>".$NavBar;
  foreach (@NavBarPages) {
    #$_ =~ s/ /_/g;
    #$_ = ReplaceSpaces($_);
    $NavBar .= '<li><a href="'.$ShortUrl.ReplaceSpaces($_).
      '" title="'.$_.'">'.$_.'</a></li>';
  }
  $NavBar .= "</ul>";

  # Search box
  $SearchBox = SearchForm() unless $SearchBox;  # Search box code

  # Register the built-in commands (?do= directives)
  RegCommand('admin', \&DoAdmin);	# Administrative menu
  RegCommand('edit', \&DoEdit);		# Editing screen
  RegCommand('search', \&DoSearch);	# Search feature
  RegCommand('history', \&DoHistory);	# Page history
  RegCommand('random', \&DoRandom);	# Random page
  RegCommand('diff', \&DoDiff);		# Differences between revisions
  RegCommand('delete', \&DoDelete);	# Page deletion
  RegCommand('revision', \&DoRevision);	# Show a previous page version
  RegCommand('revert', \&DoRevert);	# Revert a page to a previous version
  RegCommand('spam', \&DoSpam);		# For spam submissions
  RegCommand('recentchanges', \&DoRecentChanges); # Just in case...
  RegCommand('index', \&DoAdminIndex);	# Index of all pages

  # Now register the admin actions (?do=admin;page= directives)
  # 'password' has to be set by itself, since technically there isn't a menu
  #  item for it in the %AdminList (it's hard coded)
  $AdminActions{'password'} = \&DoAdminPassword;
  RegAdminPage('version', 'View version information', \&DoAdminVersion);
  RegAdminPage('index', 'List all pages', \&DoAdminIndex);
  RegAdminPage('reindex', 'Rebuild page index', \&DoAdminReIndex);
  RegAdminPage('rmlocks', 'Force delete page locks', \&DoAdminRemoveLocks);
  RegAdminPage('visitors', 'Display visitor log', \&DoAdminListVisitors);
  RegAdminPage('clearvisits', 'Clear visitor log', \&DoAdminClearVisits);
  RegAdminPage('lock',
    (-f "$DataDir/lock") ? 'Unlock the site' : 'Lock the site', \&DoAdminLock);
  #RegAdminPage('unlock', 'Unlock the site', \&DoAdminUnlock);
  RegAdminPage('block', 'Block users', \&DoAdminBlock);
  RegAdminPage('bannedcontent', 'Ban certain types of content',
   \&DoAdminBannedContent);
  RegAdminPage('css', "Edit the site's style (CSS)", \&DoAdminCSS);

  # Register POSTing actions
  RegPostAction('login', \&DoPostingLogin);		# Login
  RegPostAction('editing', \&DoPostingEditing);		# Editing
  RegPostAction('discuss', \&DoPostingDiscuss);		# Discussions
  RegPostAction('blocklist', \&DoPostingBlockList);	# Block list
  RegPostAction('commenting', \&DoPostingSpam);		# Spam submissions
  RegPostAction('bannedcontent', \&DoPostingBannedContent); # Banned content
  RegPostAction('css', \&DoPostingCSS);			# Style/CSS

  # Maintenance actions FIXME: No fancy Reg* sub (yet)
  %MaintActions = (
    purgerc => \&DoMaintPurgeRC,	purgetemp => \&DoMaintPurgeTemp,
    purgeoldr => \&DoMaintPurgeOldRevs, trimvisit => \&DoMaintTrimVisit,
  );

  # Register the "Special Pages"
  RegSpecialPage('RecentChanges', \&DoRecentChanges);	# Recent Changes
  RegSpecialPage("$DiscussPrefix.*", \&DoDiscuss);	# Discussion pages
}

sub DoPostInit {
  # Runs any subs that want to be called at the tail end of Init()
  if(@PostInitSubs) {
    foreach my $SubToRun (@PostInitSubs) {
      &{$SubToRun};
    }
  }
}

sub DoHeader {
  if(!$Template or !-d "$TemplateDir/$Template") {
    #chomp(my @TEMPLATE = <DATA>);
    #($Header, $Footer) = split("!!CONTENT!!", join("\n", @TEMPLATE));
    #print Interpolate($Header);
    print "<!DOCTYPE html>\n".
      '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">'.
      "<head><title>$PageName - $SiteName</title>\n".
      "<meta name=\"generator\" content=\"Aneuch $VERSION\" />\n".
      '<style type="text/css">'.DoCSS().
      "</style></head>\n<body>\n<div id=\"container\">\n".
      "<div id=\"header\"><div id=\"search\">".SearchForm().
      "</div>\n".
      "<a title=\"Return to $DefaultPage\" href=\"$Url\">$SiteName</a>: <h1>";
    if(PageExists(GetParam('page',''))) {
      print "<a title=\"Search for references to $SearchPage\" ".
	"rel=\"nofollow\" href=\"$ShortUrl?do=search;search=".
	"$SearchPage\">$PageName</a>";
    } else {
      print "$PageName";
    }
    print "</h1>\n</div>\n<div class=\"navigation\">\n<ul>$NavBar</ul></div>".
      "<div id=\"content\"";
    if((CanEdit()) and (!IsDiscussionPage()) and (!GetParam('do'))) {
      print " ondblclick=\"window.location.href='$Url?do=edit;page=$Page'\"";
    }
    print '><span id="top"></span>';
  } else {
    if(-f "$TemplateDir/$Template/head.pl") {
      do "$TemplateDir/$Template/head.pl";
    } elsif(-f "$TemplateDir/$Template/head.html") {
      print Interpolate(FileToString("$TemplateDir/$Template/head.html"));
    }
  }
}

sub DoFooter {
  if(!$Template or !-d "$TemplateDir/$Template") {
    #chomp(my @TEMPLATE = <DATA>);
    #print Interpolate((split(/!!CONTENT!!/, join("\n", @TEMPLATE)))[1]);
    #print Interpolate($Footer);
    print '<span id="bottom"></span></div> <!-- content -->'.
      '<div class="navigation">'."<ul><li>$DiscussText</li>".
      "<li>$EditText</li><li>$RevisionsText</li><li>$AdminText</li>".
      "<li>$RandomText</li></ul>".'<div id="identifier"><strong>'.
      $SiteName.'</strong> is powered by <em>Aneuch</em>.</div>'.
      '</div> <!-- navigation --><div id="footer"><div id="mtime">';
    if(PageExists($Page)) {
      print Commify(GetPageViewCount($Page))." view(s).&nbsp;&nbsp;";
    }
    print "$MTime</div>$PostFooter</div> <!-- footer --></div> ".
      "<!-- container --></html>";
  } else {
    if(-f "$TemplateDir/$Template/foot.pl") {
      do "$TemplateDir/$Template/foot.pl";
    } elsif(-f "$TemplateDir/$Template/foot.html") {
      print Interpolate(FileToString("$TemplateDir/$Template/foot.html"));
    }
  }
}

sub DoCSS {
  # Style sheet for the template. This is in it's own sub to facilitate
  #  CSS Customization in the future.
  if(-f "$DataDir/style.css") {
    return FileToString("$DataDir/style.css");
  } else {
    my $data_pos = tell DATA;	# Find the position of __DATA__
    chomp(my @CSS = <DATA>);	# Read in __DATA__
    seek DATA, $data_pos, 0;	# So we can re-read __DATA__ later
    return join("\n", @CSS);
  }
}

sub MarkupBuildLink {
  # This sub takes everything between [[ and ]] and builds a link out of it.
  my $data = shift;
  my $return;
  my $href;
  my $text;
  my $url = $Url; $url =~ s/\/$//;
  if($data =~ m/\|/) {        # Seperate text
    ($href,$text) = split(/\|/, $data);
  } else {                    # No seperate text
    $href = $data; $text = $data;
  }
  if($text =~ /#/ and $text !~ /^#/) {
    $text = (split(/#/,$text))[0];
  } elsif($text =~ /^#/) {
    $text =~ s/^#+//;
  }
  if($text =~ /\?/ and $text !~ /^\?/) {
    $text = (split(/\?/,$text))[0];
  } elsif($text =~ /^\?/) {
    $text =~ s/^\?+//;
  }
  if(($href =~ m/^htt(p|ps):/) and ($href !~ m/^$url/)) { # External link!
    $return = "<a class='external' rel='nofollow' title='External link: ".
      $href."' target='_blank' href='".$href."'>".$text."</a>";
  } else {			# Internal link!
    #my $testhref = ($href =~ /^#/) ? $href : (split(/#/,$href))[0];
    #if($href =~ /^#/) {
    #  $href = $Page.$href;
    #}
    my $testhref = (split(/#/,$href))[0];
    $testhref = (split(/\?/,$testhref))[0];
    #if((PageExists(ReplaceSpaces($href))) or ($href =~ m/^\?/) or (ReplaceSpaces($href) =~ m/^$DiscussPrefix/) or ($href =~ m/^$url/)) {
    if((PageExists(ReplaceSpaces($testhref))) or ($testhref =~ m/^\?/) or (ReplaceSpaces($testhref) =~ m/^$DiscussPrefix/) or ($testhref =~ m/^$url/) or ($testhref eq '') or (!CanEdit())) {
      $return = "<a title='".$href."' href='";
      if(($href !~ m/^$url/) and ($href !~ m/^#/)) {
	$return .= $ShortUrl.ReplaceSpaces($href);
      } else {
	$return .= $href;
      }
      $return .= "'>".$text."</a>";
    } else {
      $return = "[$text<a rel='nofollow' title='Create page ".$href.
	"' href='".$ShortUrl."?do=edit;page=".ReplaceSpaces($href)."'>?</a>]";
    }
  }
  return $return;
}

sub Markup {
  # Markup is a cluster. It's so ugly and nasty, but it works. In the future,
  #  this thing will be re-written to be much cleaner.
  my $cont = shift;
  if($cont =~ m/^#NOWIKI\n/) {
    $cont =~ s/^#NOWIKI\n//;
    return $cont;
  }
  $cont = QuoteHTML($cont);
  my @contents = split("\n", $cont);

  # If nomarkup is requested
  #if($contents[0] eq "!! nomarkup") { return @contents; }
  my $ulstep = 0;		# FIXME: not used!?
  my $olstep = 0;
  my $openul = 0;		# For building <ul>
  my $openol = 0;		# For building <ol>
  my $ulistlevel = 0;		# List levels
  my $olistlevel = 0;
  my @build;			# What will be returned
  my $line;			# Line-by-line
  foreach $line (@contents) {
    # Are we doing lists?
    # UL
    if($line =~ m/^[\s\t]*(\*{1,})[ \t]/) {
      if(!$openul) { $openul=1; }
      $ulstep=length($1);
      if($ulstep > $ulistlevel) {
	until($ulistlevel == $ulstep) { push @build, "<ul>"; $ulistlevel++; }
      } elsif($ulstep < $ulistlevel) {
	until($ulistlevel == $ulstep) { push @build, "</ul>"; $ulistlevel--; }
      }
    }
    if(($openul) && ($line !~ m/^[\s\t]*\*{1,}[ \t]/)) {
      $openul=0; 
      #$step=$1;
      until($ulistlevel == 0) { push @build, "</ul>"; $ulistlevel--; }
    }
    # OL
    if($line =~ m/^[\s\t]*(#{1,})/) {
      if(!$openol) { $openol=1; }
      $olstep=length($1);
      if($olstep > $olistlevel) {
	until($olistlevel == $olstep) { push @build, "<ol>"; $olistlevel++; }
      } elsif($olstep < $olistlevel) {
	until($olistlevel == $olstep) { push @build, "</ol>"; $olistlevel--; }
      }
    }
    if(($openol) && ($line !~ m/^[\s\t]*#{1,}/)) {
      $openol=0;
      until($olistlevel == 0) { push @build, "</ol>"; $olistlevel--; }
    }

    # Get rid of comments
    #$line =~ s/^#//;

    # Signature
    #  This is only for preview!!!!!!!
    #$line =~ s/~{4}/GetSignature((ReadCookie())[0])/eg;
    $line =~ s/~{4}/GetSignature($UserName)/eg;

    # Forced line breaks
    $line =~ s#\\\\#<br/>#g;

    # Headers
    #$line =~ s#^={5}(.*?)(=*)$#<h5>$1</h5>#;
    #$line =~ s#^={4}(.*?)(=*)$#<h4>$1</h4>#;
    #$line =~ s#^={3}(.*?)(=*)$#<h3>$1</h3>#;
    #$line =~ s#^={2}(.*?)(=*)$#"<h2 id=".ReplaceSpaces($1).">$1</h2>"#e;
    $line =~ s#^(={1,5})(.*?)(=*)$#"<h".length($1)." id='".ReplaceSpaces(StripMarkup($2))."'>$2</h".length($1).">"#e;

    # HR
    $line =~ s#^-{4,}$#<hr/>#;

    # <tt>
    $line =~ s#\`{1}(.*?)\`{1}#<tt>$1</tt>#g;

    # Extra tags
    #$line =~ s#^{(.*)$#<$1>#;
    #$line =~ s#^}(.*)$#</$1>#;

    # NOTE: I changed the #s to #m on the next two, to match multi-line.
    #  However, multiline is impossible the way the markup engine currently
    #  works (by splitting the text into lines and operating on individual
    #  lines).
    # UL LI
    $line =~ s#^[\s\t]*\*{1,5}[ \t](.*)#<li>$1</li>#m;

    # OL LI
    $line =~ s!^[\s\t]*#{1,5}[ \t](.*)!<li>$1</li>!m;

    # Bold
    $line =~ s#\*{2}(.*?)\*{2}#<strong>$1</strong>#g;

    # Images
    #$line =~ s#<{2}([^\|]+)\|([^>{2}]+)>{2}#<img src="$1" $2 />#g;
    $line =~ s#\{{2}(left|right):(.*?)\|(.*?)\}{2}#<img src="$2" alt="$3" align="$1" />#g;
    $line =~ s#\{{2}(left|right):(.*?)\}{2}#<img src="$2" align="$1" />#g;
    $line =~ s#\{{2}(.*?)\|(.*?)\}{2}#<img src="$1" alt="$2" />#g;
    $line =~ s#\{{2}(.*?)\}{2}#<img src="$1" />#g;

    # Links
    $line =~ s#\[{2}(.+?)\]{2}#MarkupBuildLink($1)#eg;

    # Fix for italics...
    $line =~ s#htt(p|ps)://#htt$1:~/~/#g;
    # Italics
    $line =~ s#/{2}(.*?)/{2}#<em>$1</em>#g;
    # Fix for italics...
    $line =~ s#htt(p|ps):~/~/#htt$1://#g;

    # Strikethrough
    $line =~ s#-{2}(.*?\S)-{2}#<del>$1</del>#g;

    # Underline
    $line =~ s#_{2}(.*?)_{2}#<span style="text-decoration:underline">$1</span>#g;

    # Add it
    push @build, $line;
  }
  # Do we have anything open?
  push @build, "</ol>" if $openol;
  push @build, "</ul>" if $openul;
  # Ok, now let's do paragraphs.
  my $prevblank = 1;    # Assume true
  my $openp = 0;        # Assume false
  my $i = 0;
  for($i=0;$i<=$#build;$i++) {
    if($prevblank and ($build[$i] !~ m/^<(h|div)/) and ($build[$i] ne '')) {
      $prevblank = 0;
      if(!$openp) {
        $build[$i] = "<p>".$build[$i];
        $openp = 1;
      }
    }
    if(($build[$i] =~ m/^<(h|div)/) || ($build[$i] eq '')) {
      $prevblank = 1;
      if(($i > 0) && ($build[$i-1] !~ m/^<(h|div)/) && ($openp)) {
        $build[$i-1] .= "</p>"; $openp = 0;
      }
    }
  }
  if($openp) { $build[$#build] .= "</p>"; }

  # Build output
  my $returnout = join("\n",@build);

  # Output
  return "<!-- start of Aneuch markup -->\n".$returnout."\n<!-- end of Aneuch markup -->\n";
}

sub MarkupHelp {
  # This sub will be called at the end of the edit form, and provides 
  #  assistance to the users for markup
  print '<div id="markup-help"><dl>'.
    '<dt>Styling</dt><dd>**<strong>bold</strong>**, '.
    '//<em>italic</em>//, __<span style="text-decoration:underline">'.
    'underline</span>__, --<del>strikethrough</del>--, '.
    '`<tt>teletype</tt>`</dd>'.
    '<dt>Headers</dt><dd>= Level 1 =, == Level 2 ==, === Level 3 ===, '.
    "==== Level 4 ====, ===== Level 5 ===== (ending ='s optional)</dd>".
    '<dt>Lists</dt><dd>* Unordered List, # Ordered List, ** Level 2 unordered,'.
    ' ### Level 3 ordered (up to 5 levels, NO SPACES IN FRONT)</dd>'.
    '<dt>Links</dt><dd>[[Page]], [[Page|description]], [[http://link]], '.
    '[[http://link|description]]</dd>'.
    '<dt>Images</dt><dd>{{image.jpg}}, {{right:image.jpg}} (right aligned), '.
    '[[link|{{image.jpg}}]] (image linked to link), '.
    '{{image.jpg|alt text}}</dd>'.
    '<dt>Extras</dt><dd>---- (horizonal rule), ~~~~ (signature)</dd></div>';
}

sub Commify {
  local $_  = shift;
  1 while s/^([-+]?\d+)(\d{3})/$1,$2/;
  return $_;
}

sub Trim {
  # Trim removes all leading and trailing whitespace
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string;
}

sub Interpolate {
  # Interpolate will replace any variables that exist in a string with their
  #  data. This is used for themeing.
  my $work = shift;
  $work =~ s/(\$\w+(?:::)?\w*)/"defined $1 ? $1 : ''"/gee;
  return $work;
}

sub RegPostInitSub {
  my $Sub = shift;
  push @PostInitSubs, $Sub;
}

sub RegSpecialPage {
  my ($page, $sref) = @_;
  return unless $page;
  $SpecialPages{$page} = $sref;
}

sub UnregSpecialPage {
  my $name = shift;
  if(exists $SpecialPages{$name}) {
    delete $SpecialPages{$name};
    return 1;
  } else {
    return 0;
  }
}

sub IsSpecialPage {
  # Determines of the current requested page is a special page
  foreach my $spage (sort keys %SpecialPages) {
    if($Page =~ m/^$spage$/) { return 1; }
  }
  return 0;
}

sub DoSpecialPage {
  #if(exists $SpecialPages{$Page} and defined $SpecialPages{$Page}) {
  foreach my $spage (sort keys %SpecialPages) {
    if($Page =~ m/^$spage$/) { &{$SpecialPages{$spage}}; return; }
  }
}

sub RegAdminPage {
  my ($name, $description, $sref) = @_;
  if(!exists $AdminList{$name}) {
    $AdminList{$name} = $description;
    $AdminActions{$name} = $sref;
    return 1;
  } else {
    return 0;
  }
}

sub UnregAdminPage {
  my $name = shift;
  if(exists $AdminList{$name}) {
    delete $AdminList{$name};
    delete $AdminActions{$name};
    return 1;
  } else {
    return 0;
  }
}

sub RegPostAction {
  my ($name, $sref) = @_;
  if(!exists $PostingActions{$name}) {
    $PostingActions{$name} = $sref;
    return 1;
  } else {
    return 0;
  }
}

sub UnregPostAction {
  my $name = shift;
  if(exists $PostingActions{$name}) {
    delete $PostingActions{$name};
    return 1;
  } else {
    return 0;
  }
}

sub RegCommand {
  my ($name, $sref) = @_;
  if(!exists $Commands{$name}) {
    $Commands{$name} = $sref;
    return 1;
  } else {
    return 0;
  }
}

sub UnregCommand {
  my $name = shift;
  if(exists $Commands{$name}) {
    delete $Commands{$name};
    return 1;
  } else {
    return 0;
  }
}

sub GetParam {
  (my $ParamToGet, my $Default) = @_;
  if(exists $Param{$ParamToGet} and defined $Param{$ParamToGet}) {
    return $Param{$ParamToGet};
  } else {
    return (defined $Default) ? $Default : 0;
  }
}

sub GetPage {
  # GetPage will read the file into a hash, and return it.
  my $file = shift;
  # Get short dir
  my $archive = substr($file,0,1); $archive =~ tr/[a-z]/[A-Z]/;  
  # Call ReadDB!
  return ReadDB("$PageDir/$archive/$file");
}

sub GetPageViewCount {
  my $page = shift;
  my %f = ReadDB($PageVisitFile);
  return ($f{$page}) ? $f{$page} : 0;
}

sub GetTotalViewCount {
  my $sum;
  my %f = ReadDB($PageVisitFile);
  for(keys %f) {
    $sum += $f{$_};
  }
  return $sum;
}

sub GetArchivePage {
  my ($file, $revision) = shift;
  # Get short dir
  my $archive = substr($file,0,1); $archive =~ tr/[a-z]/[A-Z]/;
  return ReadDB("$ArchiveDir/$archive/$file.$revision");
}

sub InitDirs {
  # Sets the directories, and creates them if need be.
  eval { mkdir $DataDir unless -d $DataDir; }; push @Messages, $@ if $@;
  $PageDir = "$DataDir/pages";
  eval { mkdir $PageDir unless -d $PageDir; }; push @Messages, $@ if $@;
  $ArchiveDir = "$DataDir/archive";
  eval { mkdir $ArchiveDir unless -d $ArchiveDir; }; push @Messages, $@ if $@;
  $PluginDir = "$DataDir/plugins";
  eval { mkdir $PluginDir unless -d $PluginDir; }; push @Messages, $@ if $@;
  $TempDir = "$DataDir/temp";
  eval { mkdir $TempDir unless -d $TempDir; }; push @Messages, $@ if $@;
  $TemplateDir = "$DataDir/templates";
  eval { mkdir $TemplateDir unless -d $TemplateDir; }; push @Messages, $@ if $@;
  $VisitorLog = "$DataDir/visitors.log";
  $RecentChangesLog = "$DataDir/rc.log";
  $BlockedList = "$DataDir/banned";
  $BannedContent = "$DataDir/bannedcontent";
  $PageVisitFile = "$DataDir/visitcount";
}

sub LoadPlugins {
  # Scan $PluginDir for .pl and .pm files, and load them.
  if($PluginDir and -d $PluginDir) {
    foreach my $plugin (glob("$PluginDir/*.pl $PluginDir/*.pm")) {
      next unless ($plugin =~ /^($PluginDir\/[-\w.]+\.p[lm])$/o);
      $plugin = $1;
      do $plugin;
    }
  }
}

sub ReadCookie {
  # Read cookies
  my $rcvd_cookies = $ENV{'HTTP_COOKIE'};
  my ($uname, $passwd) = ('','');
  my @cookies = split(/;/, $rcvd_cookies);
  foreach my $c (@cookies) {
    if(grep(/^$CookieName=/,&Trim($c))) {
      ($uname, $passwd) = split(/:/, (split(/=/,$c))[1]);
    }
  }
  return ($uname, $passwd);
}

sub SetCookie {
  # Save user and pass to cookie
  my ($user, $pass) = @_; #($FORM{user}, $FORM{pass});
  #my ($cname, $cdata, $cexp) = @_;
  my $matchedpass = grep(/^$pass$/, @Passwords); # Did they provide right pass?
  my $cookie = $user if $user;		# Username first, if they gave it
  if($matchedpass and $user) {		# Need both...
    $cookie .= ':' . $pass;
  }
  my $futime = gmtime($TimeStamp + 31556926)." GMT";	# Now + 1 year
  my $cookiepath = $ShortUrl;
  $cookiepath =~ s/$ShortScriptName\?//;
  $cookiepath =~ s/$ShortScriptName\///;
  print "Set-cookie: $CookieName=$cookie; path=$cookiepath; expires=$futime;\n";
}

sub IsAdmin {
  # Figure out if user has admin rights
  my ($u, $p) = ReadCookie();
  if(@Passwords == 0) {		# If no password set...
    return 1;
  }
  return scalar(grep(/^$p$/, @Passwords));
}

sub CanEdit {
  # If lock is set, return false automatically
  if(-f "$DataDir/lock") { return 0; }
  my ($u, $p) = ReadCookie();
  my $matchedpass = grep(/^$p$/, @Passwords);
  if($SiteMode == 0 or $matchedpass > 0) {
    return 1;
  } else {
    return 0;
  }
}

sub CanView {
  # Determine if the site can be viewed
  if($SiteMode < 3) { return 1; }	# Automatic if not 3
  if(IsLoggedIn()) {
    return 1;
  } else {
    # Check if we're requesting the password page
    if((GetParam('do') eq 'admin') and (GetParam('page') eq "password")) {
      return 1;
    } else {
      return 0;
    }
  }
}

sub IsLoggedIn {
  # Determine if user is logged in
  #  NOTE: Right now, it does the same thing as IsAdmin
  my ($u, $p) = ReadCookie();
  if(@Passwords == 0) {         # If no password set...
    return 1;
  }
  return scalar(grep(/^$p$/, @Passwords));
}

sub CanDiscuss {
  # If lock is set, return false automatically
  if(-f "$DataDir/lock") { return 0; }
  if(($SiteMode < 2 or IsAdmin()) and $Page =~ m/^$DiscussPrefix/) {
    return 1;
  } else {
    return 0;
  }
}

sub LogRecent {
  my ($file,$un,$mess) = @_;
  # Log for RecentChanges
  my $day; my $time;
  my @rc = ();
  if($TimeZone == 0) {	# GMT
    $day = strftime "%Y%m%d", gmtime($TimeStamp);
    $time = strftime "%H%M%S", gmtime($TimeStamp);
  } else {		# Local
    $day = strftime "%Y%m%d", localtime($TimeStamp);
    $time = strftime "%H%M%S", localtime($TimeStamp);
  }
  if(-f "$RecentChangesLog") {
    open(RCL,"<$RecentChangesLog") or push @Messages, "LogRecent: Unable to read from $RecentChangesLog: $!";
    @rc = <RCL>;
    close(RCL);
  }
  # Remove any old entry...
  @rc = grep(!/^$day(\d{6})\t$file\t/,@rc);
  # Now update...
  push @rc, "$day$time\t$file\t$un\t$mess\t$TimeStamp\n";
  # Now write it back out...
  open(RCL,">$RecentChangesLog") or push @Messages, "LogRecent: Unable to write to $RecentChangesLog: $!";
  print RCL @rc;
  close(RCL);
  Notify($file, $un, $mess);
}

sub Notify {
  my ($file, $user, $message) = @_;
  # Prepare to notify people
}

sub RefreshLock {
  # Refresh a lock on $Page
  if(-f "$TempDir/$Page.lock") {
    chomp(my @lock = FileToArray("$TempDir/$Page.lock"));
    if($lock[0] eq $UserIP and $lock[1] eq $UserName) {
      $lock[2] = $TimeStamp;
      open(LOCK,">$TempDir/$Page.lock") or push @Messages, "RefreshLock: Error opening $Page.lock for write: $!";
      print LOCK join("\n", @lock);
      close(LOCK);
      return 1;
    } else { return 0; }
  } else { return 0; }
}

sub DoEdit {
  my $canedit = CanEdit();
  # Let's begin
  my ($contents, $revision);
  my @preview;
  if(-f "$TempDir/$Page.$UserName") {
    @preview = FileToArray("$TempDir/$Page.$UserName");
    s/\r//g for @preview;
    $revision = $preview[0]; shift @preview;
    $contents = join("\n", @preview);
    RefreshLock();
  } else {
    my %f = GetPage($Page);
    chomp($contents = $f{text});
    $revision = $f{revision} if defined $f{revision};
    $revision = 0 unless $revision;
  }
  if($canedit) {
    RedHerringForm();
    print '<form action="' . $ScriptName . '" method="post">';
    print '<input type="hidden" name="doing" value="editing">';
    print '<input type="hidden" name="file" value="' . $Page . '">';
    print '<input type="hidden" name="revision" value="'. $revision . '">';
    if(-f "$PageDir/$ShortDir/$Page") {
      print '<input type="hidden" name="mtime" value="' . (stat("$PageDir/$ShortDir/$Page"))[9] . '">';
    }
  }
  if(@preview) {
    print "<div class=\"preview\">" . Markup($contents) . "</div>";
  }
  print '<textarea name="text" cols="100" rows="25" style="width:100%">'.
    QuoteHTML($contents).'</textarea><br/>';
  if($canedit) {
    # Set a lock
    if(@preview or SetLock()) {
      #print 'Summary: <input type="text" name="summary" size="60" />';
      print '<br/>Summary:<br/><textarea name="summary" cols="100" rows="2" '.
      'style="width:100%" placeholder="Edit summary (required)"></textarea>'.
      '<br/><br/>';
      print ' User name: <input type="text" name="uname" size="30" value="'.$UserName.'" /> ';
      print ' <a rel="nofollow" href="'.$ShortUrl.'?do=delete;page='.$Page.'">'.
	'Delete Page</a> ';
      AntiSpam();
      print '<input type="submit" name="whattodo" value="Save" /> ';
      print '<input type="submit" name="whattodo" value="Preview" /> ';
      print '<input type="submit" name="whattodo" value="Cancel" />';
    }
    print '</form>';
    if($EditorLicenseText) {
      print "<p>$EditorLicenseText</p>";
    }
    MarkupHelp();
  }
}

sub SetLock {
  # Sets a page log
  if(-f "$TempDir/$Page.lock" and ((stat("$TempDir/$Page.lock"))[9] <= ($TimeStamp - $LockExpire))) {
    UnLock();
  }
  # Set a lock on $Page
  if(-f "$TempDir/$Page.lock") {
    chomp(my @lock = FileToArray("$TempDir/$Page.lock"));
    my ($u, $p) = ReadCookie();
    if($lock[0] ne $UserIP and $lock[1] ne $u) {
      print "<p><span style='color:red'>This file is locked by <strong>".
	"$lock[0] ($lock[1])</strong> since <strong>".
	(FriendlyTime($lock[2]))[$TimeZone]."</strong>.</span>";
      print "<br/>Lock should expire by ".
	(FriendlyTime($lock[2] + $LockExpire))[$TimeZone].", and it is now ".
	(FriendlyTime())[$TimeZone].".</p>";
      return 0;
    } else {
      # Let's refresh the lock!
      return RefreshLock();
    }
  } else {
    open(LOCK,">$TempDir/$Page.lock") or push @Messages, "Error opening $Page.lock for write: $!";
    print LOCK "$UserIP\n$UserName\n$TimeStamp";
    close(LOCK);
    return 1;
  }
}

sub UnLock {
  # Removed a page lock
  my $pg = $Page;
  ($pg) = @_ if @_ >= 1;
  if(-f "$TempDir/$pg.lock") {
    if(!unlink "$TempDir/$pg.lock") {
      push @Messages, "Unable to delete lock file $pg.lock: $!";
    }
  }
}

sub Index {
  # Adds a page to the pageindex file.
  #  FIXME: Replace all the open..close with FileToArray or similar
  my $pg = $Page;
  ($pg) = @_ if @_ >= 1;
  #open(INDEX,"<$DataDir/pageindex") or push @Messages, "Index: Unable to open pageindex for read: $!";
  #my @pagelist = <INDEX>;
  #close(INDEX);
  my @pagelist = FileToArray("$DataDir/pageindex");
  if(!grep(/^$pg$/,@pagelist)) {
    open(INDEX,">>$DataDir/pageindex") or push @Messages, "Index: Unable to open pageindex for append: $!";
    print INDEX "$pg\n";
    close(INDEX);
  }
}

sub DoArchive {
  my $file = shift;	# The file we're working on
  # $archive will be the 1-letter dir under /archive that we're writing to
  my $archive = substr($file,0,1); $archive =~ tr/[a-z]/[A-Z]/;
  #if(!-f "$PageDir/$archive/$file") { return; }
  if(!PageExists($file)) { return; }
  # If $archive doesn't exist, we'd better create it...
  if(! -d "$ArchiveDir/$archive") { mkdir "$ArchiveDir/$archive"; }
  my %F = GetPage($file);
  # Now copy...
  system("cp $PageDir/$archive/$file $ArchiveDir/$archive/$file.$F{revision}");
}

sub WritePage {
  my ($file, $content, $user) = @_;
  if(-f "$TempDir/$file.$UserName") {	# Remove preview files
    unlink "$TempDir/$file.$UserName";
  }
  # $archive will be the 1-letter dir under /archive that we're writing to
  my $archive = substr($file,0,1); $archive =~ tr/[a-z]/[A-Z]/;
  # If $archive doesn't exist, we'd better create it...
  if(! -d "$PageDir/$archive") { mkdir "$PageDir/$archive"; }
  chomp($content);
  # Catch any signatures!
  $content =~ s/~{4}/GetSignature($UserName)/eg;
  $content .= "\n";
  DoArchive($file);
  $content =~ s/\r//g;
  StringToFile($content, "$TempDir/new");
  #$content =~ s/\n/\n\t/g;
  my %T = GetPage($file);
  StringToFile($T{text}, "$TempDir/old");
  my $diff = `diff $TempDir/old $TempDir/new`;
  $diff =~ s/\\ No newline.*\n//g;
  $diff =~ s/\r//g;
  #$diff =~ s/\n/\n\t/g;
  my %F;
  # Build file information
  $F{summary} = $FORM{summary};
  $F{summary} =~ s/\r//g; $F{summary} =~ s/\n//g;
  $F{ip} = $UserIP;
  $F{author} = $user;
  $F{ts} = $TimeStamp;
  $F{text} = $content;
  $F{revision} = $FORM{revision} + 1;
  $F{diff} = $diff;
  #open(FILE, ">$PageDir/$archive/$file") or push @Messages, "Unable to write to $file: $!";
  # FIXME: Need locks here!
  #foreach my $key (keys %F) {
  #  print FILE "$key: " . $F{$key} . "\n";
  #}
  #close(FILE);
  WriteDB("$PageDir/$archive/$file", \%F);
  UnLock($file);
  Index($file);
  LogRecent($file,$user,$FORM{summary});
}

sub WriteDB {
  # We receive file name, and hash
  my $filename = shift;
  my %filedata = %{shift()};
  open(FILE, ">$filename") or push @Messages, "WriteDB: Unable to write to $filename: $!";
  flock(LOGFILE, LOCK_EX);	# Lock, exclusive
  seek(LOGFILE, 0, SEEK_SET);	# Go to beginning of file...
  foreach my $key (sort keys %filedata) {
    $filedata{$key} =~ s/\n/\n\t/g;
    $filedata{$key} =~ s/\r//g;
    print FILE "$key: ".$filedata{$key}."\n";
  }
  close(FILE);
}

sub ReadDB {
  # Reads in the DB format that Aneuch wants...
  my $file = shift;
  my @return;
  my %F;
  my $currentkey;	# Current key of the hash that we're reading in
  if(-f "$file") { # If the file exists
    open(FH,"$file") or push @Messages, "ReadDB: Unable to open file $file: $!"; # Push error
    chomp(@return = <FH>);	# Remove \n
    close(FH);
    s/\r//g for @return;
    foreach (@return) {
      if(/^\t/) {
        $F{$currentkey} .= "\n$_";
      } else {
        my $e = index($_, ': ');
        $currentkey = substr($_,0,$e);
        $F{$currentkey} = substr($_,$e+2);
      }
    }
    foreach my $key (keys %F) {
      $F{$key} =~ s/\n\t/\n/g;
    }
    return %F;
  } else {
    return ();
  }
}

sub GetSignature {
  my ($author, $url) = @_;
  my $ret = '-- ';
  if(!$url) {
    if(PageExists(ReplaceSpaces($author))) {
      $ret .= "[[$author|$author]] //";
    } else {
      $ret .= "$author //";
    }
  } else {
    $ret .= "[[$url|$author]] //";
  }
  return $ret . (FriendlyTime($TimeStamp))[$TimeZone] . "// ($UserIP)";
}

sub GetDiscussionSeparator {
  return "\n----\n";
}

sub AppendPage {
  my ($file, $content, $user, $url) = @_;
  DoArchive($file);				# Keep history
  $content =~ s/\r//g;
  #$content =~ s/\n/\n\t/g;
  if(!$user) { $user = $UserIP; }
  my %F; my %T;
  $F{summary} = $content;
  $F{summary} =~ s/\n//g;
  $F{ip} = $UserIP;
  $F{author} = $user;
  $F{ts} = $TimeStamp;
  # $archive will be the 1-letter dir under /archive that we're writing to
  my $archive = substr($file,0,1); $archive =~ tr/[a-z]/[A-Z]/;
  if(!-d "$PageDir/$archive") { mkdir "$PageDir/$archive"; }
  if(-f "$PageDir/$archive/$file") {
    %T = GetPage($file);
  } else {
    $T{revision} = 0;
    $T{text} = '';
  }
  $F{revision} = $T{revision} + 1;
  $F{text} = $T{text} . "\n" . $content . "\n\n";
  $F{text} .= GetSignature($user, $url).GetDiscussionSeparator();
  $F{text} =~ s/\r//g;
  StringToFile($T{text}, "$TempDir/old");
  StringToFile($F{text}, "$TempDir/new");
  my $diff = `diff $TempDir/old $TempDir/new`;
  $diff =~ s/\\ No newline.*\n//g;
  $F{diff} = $diff;
  #s/\n/\n\t/g for ($F{text}, $F{diff});
  #open(FILE, ">$PageDir/$archive/$file") or push @Messages, "AppendPage: Unable to append to $file: $!";
  # FIXME: Need locks here!
  #foreach my $key (sort keys %F) {
  #  print FILE "$key: " . $F{$key} . "\n";
  #}
  #close(FILE);
  WriteDB("$PageDir/$archive/$file", \%F);
  LogRecent($file,$user,"Comment by $user");
  Index();
}

sub ListAllPages {
  my @files = (glob("$PageDir/*/*"));
  s#^$PageDir/.*?/## for @files;
  @files = sort(@files);
  return @files;
}

sub CountAllRevisions {
  # Counts the total number of revisions
  my @files = (glob("$ArchiveDir/*/*"));
  return scalar(@files);
}

sub AdminForm {
  # Displays the admin login form
  my ($u,$p) = ReadCookie();
  print '<form action="' . $ScriptName . '" method="post">';
  print '<input type="hidden" name="doing" value="login" />';
  print 'User: <input type="text" maxlength="30" size="20" name="user" value="'.
  $u.'" />';
  print ' Pass: <input type="password" size="20" name="pass" value="'.$p.'" />';
  print ' <input type="submit" value="Go" /></form>';
}

sub DoAdminPassword {
  my ($u,$p) = ReadCookie();
  if(!$u) {
    print "<p>Presently, you do not have a user name set.</p>";
  } else {
    print "<p>Your user name is set to '$u'.</p>";
  }
  AdminForm();
}

sub DoAdminVersion {
  # Display the version information of every plugin listed
  print '<p>Versions used on this site:</p>';
  foreach my $c (@Plugins) {
    print "<p>$c</p>\n";
  }
  print "<p>$ENV{'SERVER_SOFTWARE'}</p>";
  print "<p>perl: ".`perl -v`."</p>";
  print "<p>diff: ".`diff --version`."</p>";
  print "<p>grep: ".`grep --version`."</p>";
  print "<p>awk: ".`awk --version`."</p>";
}

sub DoAdminIndex {
  # Shows the pageindex
  my @indx = FileToArray("$DataDir/pageindex");
  @indx = sort(@indx);
  #my @indx = sort(ListAllPages());
  print '<p>Note: This displays what is in the page index file. If results '.
    'are inaccurate, please run the "Rebuild page index" task from the '.
    'Admin panel.</p>';
  print "<h3>" . @indx . " pages found.</h3><p>";
  print "<ol>";
  foreach my $pg (@indx) {
    print "<li><a href=\"$ShortUrl$pg\">$pg</a>";
    if($CountPageVisits) {
      print " <small><em>(".Commify(GetPageViewCount($pg))." views)</em></small>";
    }
    print "</li>";
  }
  print "</ol></p>";
}

sub DoAdminReIndex {
  # Re-index the site
  my @files = ListAllPages();
  StringToFile(join("\n",@files)."\n","$DataDir/pageindex");
  print "Reindex complete, ".scalar(@files)." pages found and added to index.";
}

sub DoAdminRemoveLocks {
  # Force remove all locks...
  my @files = glob("$TempDir/*.lock");
  foreach (@files) {
    unlink $_;
  }
  s!^$TempDir/!! for @files;
  print "Removed the following locks:<br/>".join("<br/>",@files);
}

sub DoAdminClearVisits {
  # Clears out $VisitorLog after confirming (too many accidental deletes)
  if(GetParam('confirm','no') eq "yes") {
    if(unlink $VisitorLog) {
      print "Log file successfully cleared.";
    } else {
      print "Error while deleting visitors.log: $!";
    }
  } else {
    print "<p>Are you sure you want to clear the visitor log? ".
      "This cannot be undone.</p><p><a href=\"$ShortUrl".
      "?do=admin;page=clearvisits;confirm=yes\">YES</a>&nbsp;&nbsp;".
      "<a href=\"javascript:history.go(-1)\">NO</a></p>";
  }
}

sub DoAdminListVisitors {
  my $lim;
  # If we're getting 'limit='... (to limit by IP)
  #if($ArgList and $ArgList =~ m/^limit=(.*)$/) {
  if(GetParam('limit',0)) {
  #  #m/^limit=(\d+\.\d+\.\d+\.\d+)$/) {
    $lim = GetParam('limit'); #$1;
  #  print "Limiting by '$lim', <a href='$ShortUrl?do=admin;page=visitors'>".
  #    "remove limit</a>"
  #} else {
  }
    print '<form method="get"><input type="hidden" name="do" value="admin"/>
      <input type="hidden" name="page" value="visitors"/>
      <input type="text" name="limit" size="40" value="'.$lim.'" />
      <input type="submit" value="Search"/>';
  #}
  if($lim) {
    print " <a href='$ShortUrl?do=".GetParam('do','admin').
      ";page=".GetParam('page','visitors')."'>Remove</a>";
  }
  print "</form>";
  # Display the visitors.log file
  my @lf = FileToArray($VisitorLog);
  @lf = reverse(@lf);	# Most recent entries are on bottom... fix that.
  chomp(@lf);
  if($lim) {
    @lf = grep(/$lim/i,@lf);
  }
  my $curdate;
  my @IPs;
  print "<h2>Visitor log entries (newest to oldest, ".@lf." entries)</h2><p>";
  foreach my $entry (@lf) {
    my @e = split(/\t/, $entry);
    my $date = YMD($e[1]);
    my $time = HMS($e[1]);
    if($curdate ne $date) { print "</p><h2>$date</h2><p>"; $curdate = $date; }
    print "$time, user <strong>";
    print QuoteHTML($e[0])."</strong> (<strong>".QuoteHTML($e[3])."</strong>)";
    my @p = split(/\s+/,$e[2]);
    if(@p > 1) {
      tr/(//d for @p;
      tr/)//d for @p;
      if($p[1] eq "edit") {
	print " was editing <strong>".QuoteHTML($p[0])."</strong>";
      } elsif($p[1] eq "history") {
	print " was viewing the history of <strong>".QuoteHTML($p[0]).
	  "</strong>";
      } elsif($p[1] eq "search") {
	print " was searching for <strong>&quot;".QuoteHTML($p[0]).
	  "&quot;</strong>";
      } elsif($p[1] eq "diff") {
	print " was viewing differences on <strong>".QuoteHTML($p[0]).
	  "</strong>";
      } elsif($p[1] eq "admin") {
	print " was in Administrative mode, doing <strong>".QuoteHTML($p[0]).
	  "</strong>";
      } elsif($p[1] eq "random") {
	print " was redirected to a random page from <strong>".QuoteHTML($p[0]).
	  "</strong>";
      } elsif($p[1] eq "delete") {
	print " was deleting the page <strong>".QuoteHTML($p[0])."</strong>";
      } elsif($p[1] =~ m/revision(\d{1,})/) { 
        print " was viewing revision <strong>$1</strong> of page <strong>".
	  QuoteHTML($p[0])."</strong>";
	if($p[2]) { print " (error $p[2])"; }
      } elsif($p[1] eq "revert") {
	print " was reverting the page <strong>".QuoteHTML($p[0])."</strong>";
      } elsif($p[1] eq "spam") {
	print " was spamming the page <strong>".QuoteHTML($p[0])."</strong>";
      } elsif($p[1] eq "index") {
	print " was viewing the page index";
      } else {
	my $tv = $p[1];
	$tv =~ s/\(//;
	$tv =~ s/\)//;
	print " hit page <strong>".QuoteHTML($p[0])."</strong> (error ".
	  QuoteHTML($tv).")";
      }
    } else { print " hit page <strong>".QuoteHTML($p[0])."</strong>"; }
    print "<br/>";
    if(!grep(/^$e[0]$/,@IPs)) { push @IPs, $e[0]; }
  }
  print "</p>";
  print "<div class=\"toc\"><strong>IPs:</strong><br/>";
  foreach my $entry (sort @IPs) {
    print "$entry<br/>";
  }
  print "</div>";
}

sub DoAdminLock {
  if(!-f "$DataDir/lock") {
    open(LOCKFILE,">$DataDir/lock") or push @Messages, "DoAdminLock: Unable to write to lock: $!";
    print LOCKFILE "";
    close(LOCKFILE);
    print "Site is locked.";
  } else {
    if(unlink "$DataDir/lock") {
      print "Site has been unlocked.";
    } else {
      print "Error while attempting to unlock the site: $!";
    }
  }
}

sub DoAdminUnlock {
  if(-f "$DataDir/lock") {
    unlink "$DataDir/lock";
    print "Site has been unlocked.";
  } else {
    print "Site is already unlocked!";
  }
}

sub DoAdminBlock {
  my $blocked = FileToString($BlockedList);
  my @bl = split(/\n/,$blocked);
  print "<p>".scalar(grep { length($_) and $_ !~ /^#/ } @bl)." user(s) blocked. Add an IP address, one per line, ".
    "that you wish to block. Regular expressions are allowed (be careful!). ".
    "Lines that begin with '#' are considered comments and ignored.</p>";
  print "<form action='$ScriptName' method='post'>".
    "<input type='hidden' name='doing' value='blocklist' />".
    "<textarea name='blocklist' rows='30' cols='100'>".$blocked.
    "</textarea><br/><input type='submit' value='Save' /></form>";
}

sub DoAdminBannedContent {
  my $content = FileToString($BannedContent);
  print "<p>".scalar(grep { length($_) and $_ !~ /^#/ } split(/\n/,$content)).
    " rules loaded (blank lines and comments don't count).</p>";
  print "<p>CAUTION! This is very powerful! If you're not careful, you can ".
    "easily block all forms of editing on your site.</p>";
  print "<p>Enter regular expressions for content you wish to ban. Any edit ".
    "by a non-administrative user that matches this content will immediately ".
    "be rejected as spam. Any line that begins with a '#' is considered ".
    "a comment, and will be ignored by the parser.</p>";
  print "<form action='$ScriptName' method='post'>".
    "<input type='hidden' name='doing' value='bannedcontent' />".
    "<textarea name='bannedcontent' rows='30' cols='100'>".$content.
    "</textarea><br/><input type='submit' value='Save' /></form>";
}

sub DoAdminCSS {
  if(GetParam('action') eq "restore") {
    if(GetParam('confirm') eq "yes") {
      unlink "$DataDir/style.css";
      print "<p>Default stylesheet has been restored.</p>";
    } else {
      print "<p>Are you sure you want to restore the default CSS? This cannot".
	" be undone.</p>";
      print "<p><a href='$ShortUrl?do=admin;page=css;action=restore;".
	"confirm=yes'>YES</a>&nbsp;&nbsp;<a href='javascript:history.go(-1)".
	"'>NO</a></p>";
    }
  } else {
    my $content = DoCSS();
    print "<p>You may edit your site's CSS here. If you need to, you may ".
      "<a href='$ShortUrl?do=admin;page=css;action=restore'>restore the ".
      "default</a> configuration.</p>";
    print "<form action='$ScriptName' method='post'>".
      "<input type='hidden' name='doing' value='css' />".
      "<textarea name='css' rows='30' cols='100'>".$content.
      "</textarea><br/><input type='submit' value='Save' /></form>";
  }
}

sub DoAdmin {
  # Command? And can we run it?
  if($Page and $AdminActions{$Page}) {
    if($Page eq 'password' or IsAdmin()) {
      &{$AdminActions{$Page}};	# Execute it.
      print "<p><a href=\"javascript:history.go(-1)\">&larr; Back</a></p>";
    }
  } else {
    print '<p>You may:<ul><li><a href="'.$ShortUrl.
    '?do=admin;page=password">Authenticate</a></li>';
    if(IsAdmin()) {
      my %al = reverse %AdminList;
      foreach my $listitem (sort keys %al) {
	print '<li><a href="'.$ShortUrl.'?do=admin;page='.$al{$listitem}.
	'">'.$listitem.'</a></li>';
      }
    }
    print '</ul></p>';
    print '<p>This site has ' . Commify(scalar(ListAllPages())) . ' pages, '.
      Commify(CountAllRevisions()).' revisions, and '.
      Commify(GetTotalViewCount()).' page views.</p>';
  }
}

sub ReadIn {
  my $buffer;
  if($ENV{'REQUEST_METHOD'} ne "POST") { return 0; }
  read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
  if ($buffer eq "") {
    return 0;
  }
  my @pairs = split(/&/, $buffer);
  foreach my $pair (@pairs) {
    my ($name, $value) = split(/=/, $pair);
    $value =~ tr/+/ /;
    $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    $FORM{$name} = $value;
  }
  return 1;
}

sub Init {
  InitScript();
  InitConfig();
  InitVars();
  #InitDirs();		# Now called inside InitVars();
  #DoPostInit();
  LoadPlugins();
  DoPostInit();
  #InitTemplate();
}

sub RedHerringForm {
  # This sub will print the "red herring" or honeypot form. This is an
  #  anti-spam measure.
  print '<form action="'.$ScriptName.'" method="post" style="display:none;">'.
    '<input type="hidden" name="doing" value="commenting" />'.
    '<input type="hidden" name="file" value="'.$Page.'" />'.
    'Name: <input type="text" name="hname" size="20" /><br/>'.
    'Message:<br/><textarea name="htext" cols="80" rows="5"></textarea>'.
    '<input type="submit" value="Save" /></form>';
}

sub AntiSpam {
  # Provides several anti-spam features to forms

  # If we're an admin user, we probably don't need this.
  if(IsAdmin()) { return; }

  # Let's do a hidden value, maybe?

  # If the %QuestionAnswer hash is empty, forget about it.
  if(!%QuestionAnswer) {	# Evaluates the hash in scalar context, returns
    return;			#  0 if there are 0 elements, which with the
  } else {			#  '!' used here, will match and exit.
    my $question = (keys %QuestionAnswer)[rand keys %QuestionAnswer];
    print '<input type="hidden" name="session" value="'. unpack("%32W*",$question) % 65535;
    print '" />';
    print "<br/><br/>$question&nbsp;";
    print '<input type="text" name="answer" size="30" /> ';
  }
}

sub IsBannedContent {
  # Checks the edit for banned content.
  my @bc = FileToArray($BannedContent);
  #@bc = grep(!/^#/,@bc);	# Remove comments
  #@bc = grep(/\S/,@bc);	# Remove blanks
  @bc = grep { length($_) and $_ !~ /^#/ } @bc;
  foreach my $c (@bc) {
    # If trailing comments...
    $c = (split("#",$c))[0];
    if($FORM{'text'} =~ m/$c/i) {
      #print STDERR "Matched rule: $c";
      return 1;
    }
  }
  return 0;
}

sub PassesSpamCheck {
  # Checks to see if the form submitted passes all spam checks. Returns 1 if
  #  passed, 0 otherwise.
  if(IsAdmin()) { return 1; }	# If admin, assume passed.
  # Check BannedContent
  if(IsBannedContent()) { return 0; }
  # If there are no questions, assume passed
  if(!%QuestionAnswer) { return 1; }
  # If the form was sumbitted without "question" or if it wasn't defined, fail
  if((!exists $FORM{'session'}) or (!defined $FORM{'session'})) {
    return 0;
  }
  # If the form was submitted without the answer or it wasn't defined, fail
  if((!exists $FORM{'answer'}) or (!defined $FORM{'answer'}) or (Trim($FORM{'answer'}) eq '')) {
    return 0;
  }
  # Check the answer against the question asked
  my %AnswerQuestions = reverse %QuestionAnswer;
  $FORM{'answer'} = lc($FORM{'answer'});
  if((!exists $AnswerQuestions{$FORM{'answer'}}) or (!defined $AnswerQuestions{$FORM{'answer'}})) {
    return 0;
  }
  my $question = $AnswerQuestions{$FORM{'answer'}};
  # "Checksum" of the question
  my $qcs = unpack("%32W*",$question) % 65535;
  # If checksum doesn't match, don't pass
  if($qcs != $FORM{'session'}) { return 0; }
  # Nothing else? Return 1.
  return 1;
}

sub DoDiscuss {
  # Displays the discussion form
  my $newtext;# = $NewComment;
  #my @returndiscuss = ();
  if(!CanDiscuss()) {
    return;
  }
  # Check if a preview exists
  if(-f "$TempDir/$Page.$UserIP") {
    # If the preview is older than 10 seconds, remove it and don't display it
    if((stat("$TempDir/$Page.$UserIP"))[9] < ($TimeStamp - 10)) {
      unlink "$TempDir/$Page.$UserIP";
    } else {
      $newtext = FileToString("$TempDir/$Page.$UserIP");
      print "<div class=\"preview\">".Markup($newtext)."</div>";
      my @ta = split(/\n\n/,$newtext); pop @ta;
      $newtext = join("\n\n", @ta);
    }
  }
  RedHerringForm();
  print "<p id=\"discuss-form\"></p><form action='$ScriptName' method='post'>
    <input type='hidden' name='doing' value='discuss' />
    <input type='hidden' name='file' value='$Page' />
    <textarea name='text' style='width:100%;' placeholder='$NewComment'"; 
    #onfocus=\"if(this.value=='$NewComment')this.value='';\"
    #onblur=\"if(this.value=='')this.value='$NewComment';\"
    print" cols='80' rows='10'>$newtext</textarea><br/><br/>
    Name: <input type='text' name='uname' size='30' value='$UserName' /> 
    URL (optional): <input type='text' name='url' size='50' />";
  AntiSpam();
  print " <input type='submit' name='whattodo' value='Save' />
    <input type='submit' name='whattodo' value='Preview' /></form>";
  print '<script language="javascript" type="text/javascript">'.
    "function ShowHide() {
	document.getElementById('discuss-help').style.display = (document.getElementById('discuss-help').style.display == 'none') ? 'block' : 'none';
	document.getElementById('showhidehelp').innerHTML = (document.getElementById('showhidehelp').innerHTML == 'Show markup help') ? 'Hide markup help' : 'Show markup help';
	return true; }".
    '</script>';
  print "<br/><a title=\"Markup help\" id=\"showhidehelp\"".
    #"onclick=\"if(document.getElementById('markup-help').style.display == 'none') ".
    #"{document.getElementById('markup-help').style.display = 'block'} else ".
    #"{document.getElementById('markup-help').style.display = 'none'}\">".
    "href=\"#discuss-form\" onclick=\"ShowHide();\">".
    "Show markup help</a>";
  print "<br/><div id=\"discuss-help\" style=\"display:none;\">";
  MarkupHelp();
  print "</div>";
}

sub DoRecentChanges {
  print "<hr/>";
  my @rc;
  my $curdate;
  my $tz;
  my $openul=0;
  open(RCF,"<$RecentChangesLog") or push @Messages, "DoRecentChanges: Unable to read $RecentChangesLog: $!";
  @rc = <RCF>;
  close(RCF);
  chomp(@rc);
  if($TimeZone == 0) {
    $tz = "UTC";
  } else {
    $tz = strftime "%Z", localtime(time);
  }
  # If none, say so.
  if(($rc[0] eq "") or (@rc == 0)) {
    print "No recent changes.";
    return;
  }
  # Sort them
  @rc = sort { $b <=> $a } (@rc);
  # Now show them...
  foreach my $entry (@rc) {
    my @ent = split(/\t/,$entry);
    my $day = $ent[0];
    $day =~ s#^(\d{4})(\d{2})(\d{2})\d{6}$#$1/$2/$3#;
    my $tme = $ent[0];
    $tme =~ s#^\d{8}(\d{2})(\d{2})\d{2}$#$1:$2#;
    if($curdate ne $day) { 
      $curdate = $day;
      if($openul) { print "</ul>"; }
      print "<strong>$day</strong><ul>";
      $openul = 1;
    }
    print "<li>$tme $tz (". #<a href='$ShortUrl?do=diff;page=$ent[1]".
    #  "'>diff</a>, ".
      "<a href='$ShortUrl?do=history;page=$ent[1]".
      "'>history</a>) ";
    print "<a href='$ShortUrl$ent[1]'>$ent[1]</a> . . . . ";
    if(PageExists(ReplaceSpaces($ent[2]))) {
      print "<a href='$ShortUrl$ent[2]'>$ent[2]</a><br/>";
    } else {
      print "$ent[2]<br/>";
    }
    print QuoteHTML($ent[3])."</li>";
  }
}

sub DoSearch {
  ## NOTE: /x was removed from the match regex's below as it broke search
  ##   for terms that included spaces... Not sure why I had /x to begin with.
  # First, get a list of all files...
  my @files = (glob("$PageDir/*/*"));
  # Sort by modification time, newest first
  @files = sort {(stat($b))[9] <=> (stat($a))[9]} @files;
  #my $search = $ArgList;
  my $search = GetParam('search','');
  if($search eq '') {
    print "<p>What in the world are you searching for!?</p>";
    return;
  }
  #my $altsearch = $search; $altsearch =~ s/ /_/g;
  my $altsearch = ReplaceSpaces($search);
  my %result;
  print "<p>Search results for &quot;$search&quot;</p>";
  foreach my $file (@files) {
    my $fn = $file;
    my $linkedtopage;
    my $matchcount;
    $fn =~ s#^$PageDir/.*?/##;
    my %F = GetPage($fn); #GetPage($file);
    if($fn =~ m/.*?($search|$altsearch).*?/i) {
      $linkedtopage = 1;
      $result{$fn} = '<small>Last modified '.
	(FriendlyTime($F{ts}))[$TimeZone]."</small><br/>";
    }
    while($F{text} =~ m/(.{0,75}($search|$altsearch).{0,75})/gsi) {
      if(!$linkedtopage) {
	$linkedtopage = 1;
	$result{$fn} = '<small>Last modified '.
	  (FriendlyTime($F{ts}))[$TimeZone]."</small><br/>";
      }
      if($matchcount == 0) { $result{$fn} .= " . . . "; }
      my $res = QuoteHTML($1); 
      $res =~ s#(.*?)($search|$altsearch)(.*?)#$1<strong>$2</strong>$3#gsi;
      $result{$fn} .= "$res . . . ";
      $matchcount++;
    }
  }
  # Now sort them by value...
  my @keys = sort {length $result{$b} <=> length $result{$a}} keys %result;
  if(scalar @keys == 0) {
    print "Nothing found!<br/><br/>";
  }
  foreach my $key (@keys) {
    print "<a href='$ShortUrl$key'>$key</a><br/>".
      $result{$key}."<br/><br/>";
  }
  print scalar(@keys)." pages found.";
}

sub SearchForm {
  my $ret;
  #$ret = "<form enctype=\"multipart/form-data\" class='searchform' ".
  #  "action='$ScriptName' method='get'>";
  #$ret = "<script language=\"javascript\" type=\"text/javascript\">\n".
  #  'function validateForm() {'."\n".
  #  'var x=document.forms["SearchForm"]["search"].value;'."\n".
  #  'if (x!=null || x!="") {'."\n".
  #  '  alert("\'".x."\'");'."\n".
  #  '  document.getElementById("SearchForm").submit();'."\n".
  #  "}\n}\n</script>".
  $ret = "<form class='searchform' action='$ShortUrl' method='get'>".
    "<input type='hidden' name='do' value='search' />".
    "<input type='text' name='search' size='40' placeholder='Search' ";
  if(GetParam('search')) {
    $ret .= "value='".GetParam('search')."' ";
  }
  $ret .= "/> <input type='submit' value='Search' /></form>";
  #$ret .= "/> <input type='button' onclick='validateForm();' value='Search' />".
  #  "</form>";
  return $ret;
}

sub YMD {
  # Takes timestamp, and returns YYYY/MM/DD
  my $time = shift;
  if($TimeZone == 0) {	# GMT
    return strftime "%Y/%m/%d", gmtime($time);
  } else {		# Local
    return strftime "%Y/%m/%d", localtime($time);
  }
}

sub HM {
  # Takes timestamp, and returns HH:MM
  my $time = shift;
  if($TimeZone == 0) {	# GMT
    return strftime "%H:%M UTC", gmtime($time);
  } else {		# Local
    return strftime "%H:%M %Z", localtime($time);
  }
}

sub HMS {
  # Takes timestamp, and returns HH:MM:SS
  my $time = shift;
  if($TimeZone == 0) {	# GME
    return strftime "%H:%M:%S UTC", gmtime($time);
  } else {
    return strftime "%H:%M:%S %Z", localtime($time);
  }
}

sub QuoteHTML {
  # Escape html characters
  my $html = shift;
  $html =~ s/&/&amp;/g;	# Found on the hard way, this must go first.
  $html =~ s/</&lt;/g;
  $html =~ s/>/&gt;/g;
  return $html;
}

sub DoHistory {
  my $author; my $summary; my %f;
  my $topone = " checked";
  #if(-f "$PageDir/$ShortDir/$Page") {
  if(PageExists($Page)) {
    %f = GetPage($Page);
    my $currentday = YMD($f{ts});
    my $linecount = (split(/\n/,$f{text}));
    my $wordcount = @{[ $f{text} =~ /\S+/g ]};
    my $scharcount = length($f{text}) - (split(/\n/,$f{text}));
    my $charcount = $scharcount - ($f{text} =~ tr/ / /);
    print "<p><strong>$Page</strong><br/>".
      "The most recent revision number of this page is $f{'revision'}. ".
      "It has been viewed ".Commify(GetPageViewCount($Page))." time(s). ".
      "It was last modified ".(FriendlyTime($f{'ts'}))[$TimeZone].
      " by ".QuoteHTML($f{author}).". ".
      "There are ".Commify($linecount)." lines of text, ".Commify($wordcount).
      " words, ".Commify($scharcount)." characters with spaces and ".
      Commify($charcount)." without. ".
      "The total page size (including metadata) is ".Commify((stat("$PageDir/$ShortDir/$Page"))[7])." bytes.";
    print "</p>";
    #print "<form action='$ScriptName' method='get'>";
    print "<form action='$ShortUrl' method='get'>";
    print "<input type='hidden' name='do' value='diff' />";
    print "<input type='hidden' name='page' value='$Page' />";
    print "<input type='submit' value='Compare' />";
    print "<table><tr><td colspan='3'><strong>$currentday</strong></td></tr>";
    print "<tr valign='top'><td><input type='radio' name='v1' value='cur'>".
      "</td><td><input type='radio' name='v2' value='cur' checked></td>";
    print "<td>" . HM($f{ts}) . " (current) ".
      "<a href=\"$ShortUrl$Page\">Revision " . $f{revision} . "</a>";
    #if($f{revision} > 1) {
    #  print " (<a href='$ShortUrl?do=diff;page=$Page'>diff</a>)";
    #}
    if(PageExists(ReplaceSpaces($f{author}))) {
      print " . . . . <a href=\"$ShortUrl" . QuoteHTML($f{author}) . "\">".
        QuoteHTML($f{author}) . "</a>";
    } else {
      print " . . . . ".QuoteHTML($f{author});
    }
    print " ($f{ip}) &ndash; " . QuoteHTML($f{summary}) . "</td></tr>";

    if($ArchiveDir and $ShortDir and -d "$ArchiveDir/$ShortDir") {
      my @history = (glob("$ArchiveDir/$ShortDir/$Page.*"));
      # This sort MUST be done by file mod time the way archive is currently
      #  laid out (file.x, file.xx, etc).
      @history = sort { -M $a <=> -M $b } @history;
      foreach my $c (@history) {
	# This next line needs to use ReadDB as it references a full path
	%f = ReadDB($c); #GetPage($c);
	my $nextrev;
        my $day = YMD($f{ts});
        if($day ne $currentday) {
	  $currentday = $day;
	  print "<tr><td colspan='3'><strong>$day</strong></td></tr>";
	}
	if($f{revision} == 1) {
	  $nextrev = '';
	} else {
	  $nextrev = 'v1='.($f{revision} - 1).';v2='.$f{revision};
	}
	print "<tr valign='top'><td><input type='radio' name='v1'".
	  "value='$f{revision}'$topone></td><td><input type='radio' name='v2'".
	  " value='$f{revision}'></td>";
	if($topone) { $topone = ''; }
	print "<td>".HM($f{ts})." ".
	  "<input type=\"button\" onClick=\"location.href='$ShortUrl?do=".
	  "revert;page=$Page;ver=$f{revision}'\" value=\"Revert\">".
	  " <a href=\"$ShortUrl?do=revision;page=$Page;".
	  "rev=$f{revision}\"> Revision $f{revision}</a>";
	#if($nextrev) {
 	#  print " (<a href='$ShortUrl?do=diff;page=$Page;$nextrev'>".
	#    "diff</a>)";
	#}
	if(PageExists(QuoteHTML($f{author}))) {
	  print " . . . . <a href=\"$ShortUrl" . QuoteHTML($f{author}) . "\">".
	    QuoteHTML($f{author}) . "</a>";
	} else {
	  print " . . . . ".QuoteHTML($f{author});
	}
        print " ($f{ip}) &ndash; " . QuoteHTML($f{summary}) . "</td></tr>";
      }
    }
    print "</table><input type='submit' value='Compare'></form>";
  } else {
    print "<p>No log entries found.</p>";
  }
}

sub FriendlyTime {
  my ($rcvd) = @_ if @_ >= 0;
  # FriendlyTime gives us a human readable time rather than num of seconds
  $TimeStamp = time() unless $TimeStamp;	# If it wasn't set before...
  my $tv = $TimeStamp;
  $tv = $rcvd if $rcvd;
  my $localtime = strftime "%a %b %e %H:%M:%S %Z %Y", localtime($tv);
  my $gmtime = strftime "%a %b %e %H:%M:%S UTC %Y", gmtime($tv);
  # Send them back in an array... GMT first, local second.
  return ($gmtime, $localtime);
}

sub Preview {
  # Preview will show us what changes would look like
  my $file = shift;
  # First off, we need to save a temp file...
  my $tempfile = $Page.".".$UserName;
  # Save contents to temp file
  StringToFile($FORM{'revision'}."\n".$FORM{'text'}, "$TempDir/$tempfile");
}

sub ReDirect {
  my $loc = shift;
  print "Location: $loc\n\n";
}

sub DoPostingSpam {
  # Someone submitted the red herring form!
  my $redir = $Url;
  if($redir !~ m/\?$/) { $redir .= "?"; }
  $redir .= "do=spam;page=".$FORM{'file'};
  ReDirect($redir);
}

sub DoPostingLogin {
  SetCookie($FORM{'user'}, $FORM{'pass'});
  ReDirect($Url.$FORM{'file'});
}

sub DoPostingEditing {
  my $redir;
  if(CanEdit()) {
    # Set user name if not already done
    my ($u, $p) = ReadCookie();
    if($u ne $FORM{uname} or !$u) {
      SetCookie($FORM{uname}, $p);
    }
    if($FORM{'whattodo'} eq "Cancel") {
      UnLock($FORM{'file'});
      my @tfiles = (glob("$TempDir/".$FORM{'file'}.".*"));
      foreach my $file (@tfiles) { unlink $file; }
    } elsif($FORM{'whattodo'} eq "Preview") {
      Preview($FORM{'file'});
      $redir = 1;
    } else {
      if(PassesSpamCheck()) {
	WritePage($FORM{'file'}, $FORM{'text'}, $FORM{'uname'});
      } else {
        DoPostingSpam();
        return;
      }
    }
  }
  if($redir) {
    ReDirect($Url."?do=edit;page=".$FORM{'file'});
  } else {
    ReDirect($Url.$FORM{'file'});
  }
}

sub DoPostingDiscuss {
  if(CanDiscuss()) {
    if($FORM{'whattodo'} eq "Preview" or PassesSpamCheck()) {
      # Set user name if not already done
      my ($u, $p) = ReadCookie();
      if($u ne $FORM{uname} or !$u) {
	SetCookie($FORM{uname}, $p);
      }
      if($FORM{'whattodo'} eq "Save") {
	if(-f "$TempDir/$FORM{'file'}.$UserIP") {
	  unlink "$TempDir/$FORM{'file'}.$UserIP";
	}
	AppendPage($FORM{'file'}, $FORM{'text'}, $FORM{'uname'}, $FORM{'url'});
      } elsif($FORM{'whattodo'} eq "Preview") {
	StringToFile($FORM{'text'}."\n\n".GetSignature($FORM{'uname'},
	  $FORM{'url'}).GetDiscussionSeparator(),
	  "$TempDir/$FORM{'file'}.$UserIP");
      } else {
	# What!?
      }
    } else {
      DoPostingSpam();
    }
  }
  ReDirect($Url.$FORM{'file'}."#discuss-form");
}

sub DoPostingBlockList {
  if(IsAdmin()) {
    StringToFile($FORM{'blocklist'},$BlockedList);
  }
  ReDirect($Url."?do=admin;page=block");
}

sub DoPostingBannedContent {
  if(IsAdmin()) {
    StringToFile($FORM{'bannedcontent'},$BannedContent);
  }
  ReDirect($Url."?do=admin;page=bannedcontent");
}

sub DoPostingCSS {
  if(IsAdmin()) {
    StringToFile($FORM{'css'},"$DataDir/style.css");
  }
  ReDirect($Url."?do=admin;page=css");
}

sub DoPosting {
  my $action = $FORM{doing};
  # Remove all slashes from file name (if any)
  $FORM{'file'} =~ s!/!!g;
  # Remove any leading periods
  $FORM{'file'} =~ s/^\.+//g;
  $Page = $FORM{'file'};
  if($action and $PostingActions{$action}) {	# Does it exist?
    &{$PostingActions{$action}};		# Run it
  }
}

sub DoVisit {
  # Log a visit to the visitor log
  #my $mypage = $Page; 
  #my $mypage = (GetParam('search')) ? GetParam('search') : $Page;
  my $mypage = (GetParam('do') eq 'search') ? GetParam('search','') : $Page;
  $mypage =~ s/ /+/g;
  if($MaxVisitorLog > 0) {
    my $logentry = "$UserIP\t$TimeStamp\t$mypage";
    #if($PageRevision) { $command .= "$PageRevision"; }
    #if($command) { $logentry .= " ($command)"; }
    if(GetParam('do')) { 
      $logentry .= " (".GetParam('do');
      if($PageRevision) { $logentry .= "$PageRevision"; }
      $logentry .= ")";
    }
    if($HTTPStatus) { 
      chomp(my $tv = $HTTPStatus);
      $tv =~ s/Status: //;
      $tv = (split(/ /,$tv))[0];
      $logentry .= " ($tv)";
    }
    $logentry .= "\t$UserName";
    my @rc;
    open(LOGFILE,">>$VisitorLog");
    flock(LOGFILE, LOCK_EX);		# Lock, exclusive
    seek(LOGFILE, 0, SEEK_END);		# In case data was appeded after lock
    print LOGFILE "$logentry\n";
    close(LOGFILE);			# Lock is removed upon close
  }
  if($CountPageVisits and PageExists($Page) and !GetParam('do',0)) {
    my %f = ReadDB($PageVisitFile);
    if(defined $f{$Page}) {
      $f{$Page}++;
    } else {
      $f{$Page} = 1;
    }
    WriteDB($PageVisitFile, \%f);
  }
}

sub DoMaintPurgeTemp {
  # Remove files from temp older than $RemoveOldTemp
  # First, get all files
  my @filelist = (glob("$TempDir/*"));
  # Next, find out when the cutoff is
  my $cutoff = $TimeStamp - $RemoveOldTemp;
  # Finally, walk though the file list and remove
  foreach my $file (@filelist) {
    if((stat($file))[9] <= $cutoff) {
      unlink $file;
    }
  }
}

sub DoMaintPurgeRC {
  # Remove old RC entries
  # First, read the RC file
  chomp(my @rclines = FileToArray($RecentChangesLog));
  my @newrc;
  # Determine cutoff
  my $cutoff = $TimeStamp - $PurgeRC;
  # Walk through the entries, and remove them if they are older...
  foreach my $entry (@rclines) {
    if((split(/\t/,$entry))[4] > $cutoff) {
      push @newrc, $entry;
    }
  }
  my $rcout = join("\n",@newrc) . "\n";
  if(@newrc != @rclines) {	# Only write out if there's a difference!
    StringToFile($rcout, $RecentChangesLog);
  }
}

sub DoMaintPurgeOldRevs {
  # Purge old revisions...
  # If -1, simply exit as the admin wants to keep all revisions
  if($PurgeArchives == -1) { return; }
  # Determine the timestamp for removal
  my $RemoveTime = $TimeStamp - $PurgeArchives;
  # Get list of files
  my @files = glob("$ArchiveDir/*/*.*");
  # Walk through each file and remove if it's older...
  foreach my $f (@files) {
    if((stat("$f"))[9] <= $RemoveTime) { unlink $f; }
    #my %fc = GetPage($f);
    #if($fc{ts} <= $RemoveTime) { unlink $f; }
  }
}

sub DoMaintTrimVisit {
  # Trim visitor log...
  # Open file and lock it...
  chomp(my @lf = FileToArray($VisitorLog));	# Read in
  if(scalar @lf > $MaxVisitorLog) {
    open(LOGFILE,">$VisitorLog") or return;	# Return if can't open
    flock(LOGFILE,LOCK_EX) or return;	# Exclusive lock or return
    seek(LOGFILE, 0, SEEK_SET);		# Beginning
    @lf = reverse(@lf);
    my @new = @lf[0 .. ($MaxVisitorLog - 1)];
    @lf = reverse(@new);
    seek(LOGFILE, 0, SEEK_SET);		# Return to the beginning
    print LOGFILE "" . join("\n", @lf) . "\n";
    close(LOGFILE);
  }
}

sub DoMaint {
  # Run each maintenance task
  #my $key;
  foreach my $key (keys %MaintActions) {	# Step through list, and...
    &{$MaintActions{$key}};		# Execute
  }
}

sub StringToFile {
  my ($string, $file) = @_;
  open(FILE,">$file") or push @Messages, "StringToFile: Can't write to $file: $!";
  flock(FILE,LOCK_EX);		# Exclusive lock
  seek(FILE, 0, SEEK_SET);	# Beginning
  print FILE $string;
  close(FILE);
}

sub AppendStringToFile {
  # Appends string to file
  my ($string, $file) = @_;
  my $current = FileToString($file);
  $current .= "\n$string";
  StringToFile($current, $file);
}

sub FileToString {
  my $file = shift;
  #my @return = FileToArray($file);
  return join("\n", FileToArray($file)); #@return);
}

sub FileToArray {
  my $file = shift;
  my @return;
  open(FILE,"<$file") or push @Messages, "FileToArray: Can't read from $file: $!";
  chomp(@return = <FILE>);
  close(FILE);
  s/\r//g for @return;
  return @return;
}

sub GetDiff {
  my ($old, $new) = @_;
  my %OldFile = ReadDB("$ArchiveDir/$ShortDir/$old"); #GetPage("$ArchiveDir/$ShortDir/$old");
  my %NewFile;
  if(($new =~ m/\.\d+$/) and (-f "$ArchiveDir/$ShortDir/$new")) {
    %NewFile = ReadDB("$ArchiveDir/$ShortDir/$new"); #GetPage("$ArchiveDir/$ShortDir/$new");
  } else {
    %NewFile = ReadDB("$PageDir/$ShortDir/$new"); #GetPage("$PageDir/$ShortDir/$new");
  }
  # Write them out
  StringToFile($OldFile{text}, "$TempDir/old");
  StringToFile($NewFile{text}, "$TempDir/new");
  my $diff = `diff $TempDir/old $TempDir/new`;
  $diff =~ s/\\ No newline.*\n//g;
  return $diff;
}

sub HTMLDiff {
  my $diff = shift;
  my @blocks = split(/^(\d+,?\d*[dca]\d+,?\d*\n)/m, $diff);
  my $return = "<div class='diff'>";
  shift @blocks;
  while($#blocks > 0) {
    my $h = shift @blocks;
    $h =~ s#^(\d+.*d.*)#<p><strong>Deleted:</strong></p>#
	or $h =~ s#^(\d+.*c.*)#<p><strong>Changed:</strong></p>#
	or $h =~ s#^(\d+.*a.*)#<p><strong>Added:</strong></p>#;
    $return .= $h;
    my $next = shift @blocks;
    $next = QuoteHTML($next);
    my ($o, $n) = split(/\n---\n/,$next,2);
    s#\n#<br/>#g for ($o,$n);
    if($o and $n) {
      $return .= "<div class='old'>$o</div><p><strong>to</strong></p>\n".
	"<div class='new'>$n</div><hr/>";
    } else {
      if($h =~ m/Added:/) {
	$return .= "<div class='new'>";
      } else {
	$return .= "<div class='old'>";
      }
      $return .= "$o</div><hr/>";
    }
  }
  $return .= "</div>";
  return $return;
}

sub DoDiff {
  # If there are no more arguments, assume we want most recent diff
  #if(!$ArgList) {
  if(!GetParam('v1') and !GetParam('v2')) {
    my %F = GetPage($Page);
    print "Showing changes to the most recent revision";
    print HTMLDiff($F{diff});
    print "<hr/>";
    if(defined &Markup) {
      print Markup($F{text});
    } else {
      print $F{text};
    }
  } else {
    #if($ArgList =~ m/^rev=(\d+)($|\.?(\d+))/) {
    #my @args = split(/;/,$ArgList);
    my %rv;
    #if($#args = 1) {
    if(!GetParam('v1')) {
      #foreach my $cc (@args) {
	#my @aaa = split(/=/,$cc);
	#if($aaa[1] ne 'cur') { $rv{$aaa[0]} = $aaa[1]; }
      #}
      $Param{v1} = $Param{v2};
    #} else {
      #$rv{v1} = (split(/=/,$ArgList))[1];
    }
    foreach my $v ('v1', 'v2') {
      if($Param{$v} ne 'cur') { $rv{$v} = GetParam($v); }
    }
    #if($ArgList =~ m
      my %F;
      my $oldrev = "$Page.$rv{v1}";
      #my $newrev = $3 ? "$Page.$3" : "$Page";
      my $newrev = defined $rv{v2} ? "$Page.$rv{v2}" : "$Page";
      print "<p>Comparing revision $rv{v1} to ".
	(defined $rv{v2} ? $rv{v2} : "current") . "</p>";
      print HTMLDiff(GetDiff($oldrev, $newrev));
      print "<hr/>";
      if(($newrev =~ m/\.\d+$/) and (-f "$ArchiveDir/$ShortDir/$newrev")) {
	%F = ReadDB("$ArchiveDir/$ShortDir/$newrev"); #GetPage("$ArchiveDir/$ShortDir/$newrev");
      } else {
	%F = ReadDB("$PageDir/$ShortDir/$newrev"); #GetPage("$PageDir/$ShortDir/$newrev");
      }
      if(defined &Markup) {
	print Markup($F{text});
      } else {
	print $F{text};
      }
    #}
  }
}

sub DoRandom {
  my @files = ListAllPages();
  my $count = @files;
  if($count < 1) {
    push @files, $DefaultPage;
    $count = 1;
  }
  my $randompage = int(rand($count));
  #print '<script language="javascript" type="text/javascript">'.
  #  'window.location.href="'.$ShortUrl.$files[$randompage].'"; </script>';
  ReDirect($Url.$files[$randompage]);
}

sub PageExists {
  my $pagename = shift;
  # $archive will be the 1-letter dir under /archive that we're writing to
  my $archive = substr($pagename,0,1); $archive =~ tr/[a-z]/[A-Z]/;
  if(-f "$PageDir/$archive/$pagename") {
    return 1;
  } else {
    return 0;
  }
}

sub DiscussCount {
  # Returns the number of comments on a Discuss page
  if(PageExists("${DiscussPrefix}${Page}")) {
    my $DShortDir = substr($DiscussPrefix,0,1); $DShortDir =~ tr/[a-z]/[A-Z]/;
    my %DiscussPage = ReadDB("$PageDir/$DShortDir/${DiscussPrefix}${Page}"); #GetPage("$PageDir/$DShortDir/${DiscussPrefix}${Page}");
    #my @comments = split("----", $DiscussPage{text});
    my @comments = split(GetDiscussionSeparator(), $DiscussPage{text});
    #return $#comments; #scalar(@comments);
    return scalar(@comments);
  } else {
    return 0;
  }
}

sub DoDelete {
  # Delete pages
  # Can edit?
  #if(!CanEdit) {
  if(!IsAdmin()) {
    print "You can't perform this operation.";
    return;
  }
  # Does page exist?
  if(!PageExists($Page)) {
    print "That page doesn't exist!";
    return;
  }
  #if($ArgList eq "confirm=yes") {
  if(GetParam('confirm','') eq "yes") {
    # Delete the page
    print "<p>Removing page... ";
    if(unlink "$PageDir/$ShortDir/$Page") {
      print "Done!</p>";
    } else {
      print "Error: $!</p>";
    }
    # Delete revisions
    print "<p>Removing any archived versions... ";
    my @arvers = glob("$ArchiveDir/$ShortDir/$Page.*");
    if(@arvers) {
      print "<br/>Found " . scalar @arvers . " revisions, removing... ";
      foreach (@arvers) {
	unlink $_;
      }
    } else {
      print "No revisions found. Done.</p>";
    }
    # Rebuild page index
    print "<p>Rebuilding page index... ";
    DoAdminReIndex();
    print "</p>";
    # Remove entries from rc.log
    print "<p>Removing any instances of $Page from rc.log... ";
    chomp(my @rclines = FileToArray($RecentChangesLog));
    my @newrc = grep(!/^\d{14}\t$Page\t.*$/, @rclines);
    my $rcout = join("\n",@newrc) . "\n";
    if(@newrc != @rclines) {      # Only write out if there's a difference!
      StringToFile($rcout, $RecentChangesLog);
    }
    print "Done.</p>";
    print "<p><strong>Page $Page successfully deleted!</strong></p>";
  } else {
    # Do we want to delete it?
    print "<p>Are you sure you want to delete the page <strong>&quot;".
      "$Page&quot;</strong>? This cannot be undone!</p>";
    print "<p><a href='$ShortUrl?do=delete;page=$Page;confirm=yes'>YES</a>";
    print "&nbsp;&nbsp; <a href='javascript:history.go(-1)'>NO</a></p>";
  }
}

sub DoRevision {
  #if($ArgList =~ m/rev=(\d{1,})$/) {
  if(GetParam('rev',0)) {
    $PageRevision = GetParam('rev'); #$1;
    if(-f "$ArchiveDir/$ShortDir/$Page.$PageRevision") {
      my %Filec = ReadDB("$ArchiveDir/$ShortDir/$Page.$PageRevision"); #GetPage("$ArchiveDir/$ShortDir/$Page.$PageRevision");
      print "<h1>Revision $Filec{revision}</h1>\n<a href=\"".
        "$ShortUrl$Page\">view current</a><hr/>\n";
      if(exists &Markup) {
        print Markup($Filec{text});
      } else {
        print join("\n", $Filec{text});
      }
    } else {
      print "That revision does not exist!";
    }
  } else {
    print "What are you trying to do?";
  }
}

sub DoRevert {
  if(!CanEdit()) {
    print "Can't do that, I'm afraid.";
    return;
  }
  #my @vals = split(/=/,$ArgList);
  #if($vals[0] eq 'ver' and $vals[1]) {
  if(GetParam('confirm','no') eq "yes") {
    if(GetParam('ver',0)) {
      #if(-f "$ArchiveDir/$ShortDir/$Page.$vals[1]") {
      if(-f "$ArchiveDir/$ShortDir/$Page.".GetParam('ver')) {
	#my %f = GetPage("$ArchiveDir/$ShortDir/$Page.$vals[1]");
	my %f = ReadDB("$ArchiveDir/$ShortDir/$Page.".GetParam('ver'));
	my %t = GetPage($Page);
	$FORM{summary} = "Revert to ".(FriendlyTime($f{ts}))[$TimeZone];
	$FORM{revision} = $t{revision};
	WritePage($Page, $f{text}, $UserName);
	print "Reverted to page revision ".GetParam('ver'); #$vals[1]";
      } else {
	print "That revision doesn't exist!";
      } 
    } else {
      print "Malformed request";
    }
  } else {
    print "<p>Are you sure you want to revert the page <strong>&quot;".
      "$Page&quot;</strong> to revision ".GetParam('ver').
      "? This cannot be undone!</p>";
    print "<p><a href='$ShortUrl?do=revert;page=$Page;ver=".GetParam('ver').
      ";confirm=yes'>YES</a>";
    print "&nbsp;&nbsp; <a href='javascript:history.go(-1)'>NO</a></p>";
  }
}

sub DoSpam {
  # Someone posted spam, now tell them about it.
  print "It appears that you are attempting to spam $Page. ".
    "Please don't do that.";
}

sub IsBlocked {
  if(!-f $BlockedList) { return 0; }
  #chomp(my @blocked = FileToArray($BlockedList));
  #my @blocked = FileToArray($BlockedList);
  #if(grep(/^$UserIP$/,@blocked)) {
  foreach my $blocked (FileToArray($BlockedList)) {
    next if $blocked =~ /^#/;
    if($UserIP =~ m/$blocked/) { return 1; }
  #} else {
  #  return 0;
  }
  return 0;
}

sub ReplaceSpaces {
  my $replacetext = shift;
  $replacetext =~ s/\s/_/g;
  return $replacetext;
}

sub StripMarkup {
  # Returns only alphanumeric... essentially wiping out any characters that
  #  might be used in the markup syntax.
  my $ret = shift;
  $ret =~ s/[^a-zA-Z0-9 _]//g;
  return $ret;
}

sub ErrorPage {
  (my $code, my $message) = @_;
  my %codes = (
    '404' => '404 Not Found',	'403' => '403 Forbidden',
    '500' => '500 Internal Server Error',	'501' => '501 Not Implemented',
    '503' => '503 Service Unavailable',
  );

  my $header;
  if($codes{$code}) { $header = "Status: $codes{$code}\n"; }
  $HTTPStatus = $header;
  $header .= "Content-type: text/html\n\n";
  print $header;
  print "<html><head><title>$codes{$code}</title></head><body>";
  print '<h1 style="border-bottom: 2px solid rgb(0,0,0); font-size:medium; margin: 4ex 0px 1ex; padding:0px;">'.$codes{$code}.'</h1>';
  print "<p>$message</p>";
  print '</body></html>';
  #exit 1;
}

sub DoSurgeProtection {
  # We need to check if there have been a large number of requests
  # If neither of the variables are defined, or if they are 0, get out of here
  return 0 unless $SurgeProtectionTime or $SurgeProtectionCount;
  # If the user is an admin, let's go ahead and forgive them
  return 0 if IsAdmin();
  # Get the time in the past we're starting to look
  my $spts = $TimeStamp - $SurgeProtectionTime;
  # Now, count the elements that match
  chomp(my @counts = split(/\n/,`grep ^$UserIP $VisitorLog | awk '\$2>$spts'`));
  if($#counts >= $SurgeProtectionCount) {
    # Surge protection has been triggered! Give an error page and bug out.
    return 1;
  } else {
    return 0;
  }
}

sub IsDiscussionPage {
  # Determines if the current page is a discussion page
  if($Page =~ m/^$DiscussPrefix/) {
    return 1;
  } else {
    return 0;
  }
}

sub DoRequest {
  # Blocked?
  if(IsBlocked()) {
    #$HTTPStatus = "Status: 403 Forbidden\n";
    #print $HTTPStatus . "Content-type: text/html\n\n";
    #print '<html><head><title>403 Forbidden</title></head><body>'.
    #  "<h1>Forbidden</h1><p>You've been banned. Please don't come back.</p>".
    #  "</body></html>";
    ErrorPage(403, "You've been banned. Please don't come back.");
    return;
  }

  # Surge protection
  if(DoSurgeProtection()) {
    ErrorPage('503', "You've attempted to fetch more than $SurgeProtectionCount pages in $SurgeProtectionTime seconds.");
    return;
  }

  # Are we receiving something?
  if(ReadIn()) {
    DoPosting();
    return;
  }

  # Can view?
  unless(CanView()) {
    ReDirect($Url."?do=admin;page=password");
    return;
  }

  # Random page? Do it!
  if(GetParam('do') eq 'random') {
    #DoRandom();
    &{$Commands{'random'}};
    return;
  }

  # Check if page exists or not, and not calling a command
  #if(! -f "$PageDir/$ShortDir/$Page" and !$command and !$Commands{$command}) {
  if(! -f "$PageDir/$ShortDir/$Page" and !GetParam('do') and !$Commands{GetParam('do')}){ # and !IsSpecialPage()) {
    $HTTPStatus = "Status: 404 Not Found\n";
  }

  # Check if we're looking for a revision, and see if it exists...
  # Unfortunately this is the best place to check, but I still don't like it.
  #if($command eq 'revision') {
  if(GetParam('do') eq 'revision') {
    #if($ArgList =~ m/rev=(\d{1,})$/) {
    if(defined $Param{rev}) {
      #my $rev = $1;
      my $rev = $Param{rev};
      if(! -f "$ArchiveDir/$ShortDir/$Page.$rev") {
	$HTTPStatus = "Status: 404 Not Found\n";
      }
    }
  }

  # Build $SearchPage
  $SearchPage = $PageName;    # SearchPage is PageName with + for spaces
  $SearchPage =~ s/Search for: //;
  $SearchPage =~ s/ /+/g;     # Change spaces to +

  # HTTP Header
  print $HTTPStatus . "Content-type: text/html\n\n";

  # Header
  #print Interpolate($Header);
  DoHeader();
  # This is where the magic happens
  #if($command and $Commands{$command}) {	# Command directive?
  if(defined $Param{do} and $Commands{$Param{do}}) {
    #&{$Commands{$command}};			# Execute it.
    &{$Commands{$Param{do}}};
  } else {
    if(! -f "$PageDir/$ShortDir/$Page") {	# Doesn't exist!
      print $NewPage;
    } else {
      %Filec = GetPage($Page);
      if(exists &Markup) {	# If there's markup defined, do markup
	print Markup($Filec{text});
      } else {
	print join("\n", $Filec{text});
      }
    }
    if($Filec{ts}) {
      $MTime = "Last modified: ".(FriendlyTime($Filec{ts}))[$TimeZone]." by ".
	$Filec{author} . "<br/>";
    }
    #if($Page eq 'RecentChanges') {
    #  DoRecentChanges();
    #}
    DoSpecialPage();
    #if($Page =~ m/^$DiscussPrefix/ and ($SiteMode < 2 or IsAdmin())) {
    #  DoDiscuss();
    #}
  }
  if($Debug) {
    $DebugMessages = join("<br/>", @Messages);
  }
  # Footer
  #print Interpolate($Footer);
  DoFooter();
}

## START
Init();		# Load
DoRequest();	# Handle the request
DoVisit();	# Log visitor
DoMaint();	# Run maintenance commands
1;		# In case we're being called elsewhere

# Everything below the DATA line is the default CSS

__DATA__
html
{
  font-family: sans-serif;
  font-size: 1em;
}

body
{
  padding:0;
  margin:0;
}

pre
{
  overflow: auto;
  word-wrap: normal;
  border: 1px solid rgb(204, 204, 204);
  border-radius: 2px 2px 2px 2px;
  box-shadow: 0px 0px 0.5em rgb(204, 204, 204) inset;
  padding: 0.7em 1em;
  font-family: Consolas,"Andale Mono WT","Andale Mono","Bitstream Vera Sans Mono","Nimbus Mono L",Monaco,"Courier New",monospace;
  font-size: 1em;
  direction: ltr;
  text-align: left;
  background-color: rgb(251, 250, 249);
  color: rgb(51, 51, 51);
}

#container
{
  /*margin: 0 30px;*/
  background: #fff;
}

#header
{
  /*background: #ccc;*/
  background: rgb(230, 234, 240); /*rgb(243,243,243);*/
  border:1px solid rgb(221,221,221);
  padding: 15px;
  color: rgb(68, 119, 255);
}

#header h1
{
  margin: 0;
  display:inline;
  color: rgb(68, 119, 255);
  font-size: 20pt;
}

#header a {
  text-decoration: none;
  color: rgb(68, 119, 255);
}

#header h1 a
{
  color: rgb(68, 119, 255);
  text-decoration:none;
}

#header a:hover {
  color: green;
  text-decoration: underline;
}

#search {
  float:right;
  clear:left;
}

.navigation
{
  float: left;
  width: 100%;
  background: #333;
  /*background:rgb(214, 228, 249);*/
}

.navigation ul
{
  margin: 0;
  padding: 0;
}

.navigation ul li
{
  list-style-type: none;
  display: inline;
}

.navigation li a
{
  display: block;
  float: left;
  padding: 5px 10px;
  color: #fff;
  text-decoration: none;
  border-right: 1px solid #fff;
}

.navigation li a:hover {
  background: rgb(129, 187, 242);/*#383;*/
  color: #000;
}

#identifier {
  float:right;
  font-size:0.9em;
  color:white;
  padding:5px;
}

#content
{
  clear: left;
  padding: 20px;
  text-align:justify;
  position:relative;
}

#content img
{
  padding:5px;
  margin:10px;
  /*border:1px solid rgb(221,221,221);
  background-color: rgb(243,243,243);
  border-radius: 3px 3px 3px 3px;*/
}

#content a
{
  color:rgb(68, 119, 255);
  text-decoration: none;
}

#content a:hover
{
  text-decoration: underline;
  color:green;
}

#content a.external:hover
{
  text-decoration: underline;
  color:red;
}

#content h2
{
  color: #000;
  font-size: 160%;
  margin: 0 0 .5em;
}

#content hr {
  border:none;
  color:black;
  background-color:#000;
  height:2px; 
  margin-top:2ex;
}

#markup-help
{
  border: 1px solid #8CACBB;
  background: #EEEEFF;
  padding: 10px;
  margin-top: 20px;
  font-size: 0.9em;
  font-family: "Courier New", Courier, monospace;
}

#markup-help dt
{
  font-weight: bold;
}

#footer
{
  /*background: #ccc;
  text-align: right;*/
  background:rgb(230, 234, 240); /*rgb(243,243,243);*/
  border:1px solid rgb(221,221,221);
  padding: 15px;
  height: 1%;
  clear:left;
}

#mtime {
  color:gray;
  font-size:0.75em;
  float:right;
  font-style: italic;
}

#content .toc {
  /*float:right;*/
  background-color: rgb(230, 234, 240);
  padding:5px;
  margin:10px;
  border: 1px solid rgb(221,221,221);
  border-radius: 3px 3px 3px 3px;
  /*font-size:0.9em;*/
  position:absolute;
  top:0;
  right:0;
}

textarea {
  border-color:black;
  border-style:solid;
  border-width:thin;
  padding: 3px;
  width: 100%;
}

input {
  border-color:black;
  border-style:solid;
  border-width:thin;
  padding: 3px;
}

.preview {
  margin: 10px;
  padding: 5px;
  border: 1px solid rgb(221,221,221);
  background-color: lightyellow;
}

.diff {
  padding-left: 5%;
  padding-right: 5%;
}

.old {
  background-color: lightpink;
}

.new {
  background-color: lightgreen;
}
