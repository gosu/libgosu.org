#!/usr/bin/perl

use strict;
use warnings;
use Fcntl qw(:flock);

flock(DATA, LOCK_EX|LOCK_NB) or die "Only one instance of this script can run at the same time.";

chdir "../mwf";
# Run all scripts with `env -i` to prevent CGI variables from leaking into sub-processes.
# (The cron_*.pl scripts cannot run in a CGI environment.)
print `env -i perl cron_jobs.pl 2>&1`;
print `env -i perl cron_subscriptions.pl 2>&1`;
print `env -i perl cron_rss.pl 2>&1`;

use lib '../mwf';
use MwfMain;
use Image::Magick;

# Now pick a random Project of the Day and write an HTML snippet about it to potd.inc (+potd.jpg).
my ($m, $cfg, $lng) = MwfMain->newShell(allowCgi => 1);
my $projects = $m->fetchAllArray("SELECT t.id, t.subject, a.postId, a.fileName
                                  FROM topics t JOIN attachments a ON (t.basePostId = a.postId)
                                  WHERE boardId = (SELECT id FROM boards WHERE title = 'Gosu Showcase')
                                  AND (a.filename LIKE '%.png' OR a.filename LIKE '%.jpg')");

while (1) {
  my $project = $projects->[rand @$projects];
  my $filename = "../../mwf/attachments/" . ($project->[2] % 100) . "/" . $project->[2] . "/" . $project->[3];
  # Some forum attachments were lost, so loop until we find an image that really exists.
  if (-f $filename) {
    # Write potd.inc.
    my $fh;
    open ($fh, '>', "../../potd.inc") or die "could not open potd.inc for writing";
    print $fh "Project of the Day:<br>";
    print $fh "<a href='/cgi-bin/mwf/topic_show.pl?tid=" . $project->[0] . "'>" . $m->escHtml($project->[1]) . "</a><br>\n";
    print $fh "<a href='/cgi-bin/mwf/topic_show.pl?tid=" . $project->[0] . "'>\n";
    print $fh "  <img src='potd.jpg' alt='Project of the Day screenshot'>\n";
    print $fh "</a><br>\n";
    print $fh "Discover more awesome projects in the <a href='/cgi-bin/mwf/board_show.pl?bid=2'>Gosu Showcase</a>.\n";
    close ($fh);
    # Write potd.jpg.
    $m->resizeImage($filename, "../../potd.jpg", 276, 350, 1, 100);
    last;
  }
}

$m->finish();

__DATA__
flock
