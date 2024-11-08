#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when a module should check if its
# requirements are met.
# It is run from GenoRing base directory.
# It is normally called when all GenoRing dockers are down.

use strict;
use warnings;

++$|; #no buffering

# This script is often not needed unless it has specific needs (a given non-core
# PERL module, an external non-GenoRing service, some specific hardware, etc.).
# It should display an explicit error message and return a non-zero error code
# in case requirements are not met.
warn "ERROR: it seems some unnecessary hook scripts were not removed!\n";
exit(1);
