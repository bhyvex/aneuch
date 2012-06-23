#!/usr/bin/perl
package Aneuch;
# NOTE: This is the default config.pl included with the distribution. Feel
#  free to modify it to suit your needs. I have attempted to document as much
#  of the tunable settings for Aneuch as I can within this file. Read the
#  comments preceeding each variable for information on what it does, and how
#  to use it.
# ****************************************************************************
#
# $DataDir - This setting tells Aneuch where to store its data. It defaults to
#  /tmp/aneuch, which is probably not where you want it. Change this to point
#  to a directory that your webserver has write access to (or if running
#  SUExec, a directory that YOU can write to. All other directories that
#  Aneuch uses will be created within this directory (i.e. pages, archive, etc)
#  Note that you should not include the trailing slash. But if you do by
#  mistake, Aneuch is sensible enough to remove it for you.
$DataDir = '/tmp/aneuch';

# $SiteName - This is the name of your site, and defaults to 'Aneuch'. The site
#  name will appear in the HTML title element, as well as in the footer of your
#  site.
$SiteName = 'Aneuch';

# $SiteMode - This is quite possibly one of the most important settings you
#  NEED to change. This variable controls if your site is wide open (anyone
#  can post) or closed (only you can post). The default value is 0, which 
#  is wide open. Here is a list of potential values and what they mean:
#	0 = Wide open, anyone can edit.
#	1 = Anyone can add to Discussion pages, but cannot edit anything
#	2 = Nobody can post anything, unless authenticated.
$SiteMode = 0;

# @Passwords - This goes hand in hand with the $SiteMode variable above. If
#  $SiteMode > 0, then you must set a password in this array to be able to
#  allow someone to edit pages. As I mentioned, this is an array, so you can
#  set it in one of the following manners:
#	@Passwords = qw(entry1 entry2 entry3);
#   -or-
#	@Passwords = ('entry1', 'entry2', 'entry3');
#  Note that Aneuch needs this to be an array. It defaults to empty.
@Passwords = ();

# $DefaultPage - This variable sets what is to be displayed by default if no
#  page is requsted (for example, if a visitor merely types your website
#  address, and does not include 'SomePage'). The default value is 'HomePage',
#  and is a fairly sane default.
$DefaultPage = 'HomePage';

# $DiscussPrefix - This variable determines the prefix that your discussion
#  pages will use. The default is 'Discuss_', which means the discussion page
#  for 'HomePage' would be 'Discuss_HomePage'. This is a sane default.
$DiscussPrefix = 'Discuss_';

# $CookieName - This variable tells your browser what to save the
#  authentication cookie as, and defaults to 'Aneuch'. This is NOT a sane
#  default, and should be changed. You should avoid using anything but 
#  alphanumeric values in this variable. An example: 'MySiteC0oki3'
$CookieName = 'Aneuch';

# $TimeZone - This variable controls how Aneuch will display time elements,
#  but it might not quite work how you expect it to. This variable is numeric,
#  allowing either a 0 or 1. The default value of 0 means that times on your
#  wiki are UTC or GMT. This is probably not a bad idea if your wiki will
#  entertain contributors from around the world. If you set this to 1, it will
#  default to the local time zone of your server.
$TimeZone = 0;

# $LockExpire - When a user is editing an existing page, it is locked for
#  editing by other users. If the user who has locked the page carelessly
#  navigates away from the page, or simply walks away from his desk, the
#  file remains locked forever. This variable exists to prevent such an 
#  event from happening. It sets the maximum amount of time a lock is valid, in
#  seconds. Once this time has lapsed, the lock is released, and others are
#  allowed to edit once again. The default value is 60*5, which is 300 seconds,
#  or 5 minutes. This is a fairly sane default. You may want to adjust it based
#  on your particular site's usage patterns.
$LockExpire = 60*5;

# $MaxVisitorLog - This variable controls the maximum amount of entries in your
#  visitor log file before it starts getting trimmed. The default value is
#  1,000 entries, and is considered a sane default. Feel free to adjust this
#  to your particular site's need.
$MaxVisitorLog = 1000;

# $NewPage - This variable controls what is shown to users who visit a link
#  within your wiki that leads to a page that has not been created yet. The
#  default value is set below:
$NewPage = '<p>It appears that there is nothing here.</p>';

# $NewComment - This variable controls what is shown in the comment textarea
#  on your site. The default is:
$NewComment = 'Add your comment here.';

# $NavBar - This variable sets anything additional you want to display in the
#  links across the top of your page, in addition to what is set by 
#  $DefaultPage as well as "RecentChanges". The default is nothing, however
#  you could set this to something like:
#    $NavBar = '<a href="' . $ShortUrl . 'About>About</a>';
#  to link to an 'About' page. I don't think you'll break anything, so play
#  around a bit. The default is blank.
$NavBar = '';

# $Debug - This variable controls whether or not error messages should be shown
#  at the bottom of the page, and is really only useful to developers. The
#  default is 0, which will not show errors. Set to 1 to see errors.
$Debug = 0;

# $Header and $Footer - These variables are used in "theming" your site. If
#  either one is blank, the default theme will be used. You can either fill
#  the variables with content, or import the contents of a file into each.
#  I leave that as an excercise for the reader. Caution: There be dragons ahead!
# $Header = '';
# $Footer = '';

# $ConfFile - Note that this variable is optional. Aneuch will use the current
#  directory that it resides in to find the configuration file. However, it
#  will not look anywhere else if it does not find one there. Now obviously
#  it makes absolutely no sense whatsoever to set this variable within the
#  configuration file itself. The only place it would be sensible is if you
#  called aneuch.pl from within a wrapper. An example of such a use would be:
# FILE: index.cgi
#
# #!/usr/bin/perl
# package Aneuch;
# $DataDir = '/tmp/myaneuch';
# $ConfFile = $DataDir . '/config.pl';
# do 'aneuch.pl';
