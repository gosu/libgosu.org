#!/usr/bin/perl

print "Content-Type: text/plain\n\n";

use strict;
use warnings;
use Fcntl qw(:flock);

flock(DATA, LOCK_EX|LOCK_NB) or die "Must not run in parallel";

# Go to libgosu.org root.
chdir "../..";

print "*** Update Gosu headers from Subversion\n";
print `svn checkout https://github.com/jlnr/gosu/trunk/Gosu`;
print "\n\n";

# Extend PATH, this is where doxygen lives on my cheap server.
print "*** Generate C++ reference in /cpp\n\n";
print `PATH=../doxygen/bin:PATH doxygen`;
print "\n\n";

print "*** Done\n";

__DATA__
flock
