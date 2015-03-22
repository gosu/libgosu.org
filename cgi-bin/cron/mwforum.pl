#!/usr/bin/perl

print "Content-Type: text/plain\n\n";

use strict;
use warnings;
use Fcntl qw(:flock);

flock(DATA, LOCK_EX|LOCK_NB) or die "Must not run in parallel";

# Go to mwForum CGI bin.
chdir "../mwf";

print `perl cron_jobs.pl`;
print `perl cron_subscriptions.pl`;
print `perl cron_rss.pl`;

__DATA__
flock
