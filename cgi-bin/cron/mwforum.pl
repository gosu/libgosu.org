#!/usr/bin/perl

print "Content-Type: text/plain\n\n";

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

__DATA__
flock
