#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when a module needs to perform update tasks.
# It is run from GenoRing base directory.
# It is normally called when all GenoRing dockers are down before any update is
# performed by container update hooks.

use strict;
use warnings;

++$|; #no buffering

# This script might adjust the local file system before container updates are
# run.
