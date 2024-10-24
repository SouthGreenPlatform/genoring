#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when a module needs to perform restore
# tasks.
# It is run from GenoRing base directory.
# It is normally called when all GenoRing dockers are down and receive as first
# argument a backup (machine) name.

use strict;
use warnings;

++$|; #no buffering

# This script should be able to reverse the work done by its sibbling backup
# hook script.
