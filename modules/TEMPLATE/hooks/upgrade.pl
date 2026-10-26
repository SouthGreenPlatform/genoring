#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when a module needs to upgrade itself to a
# given version.
# It is run from GenoRing base directory.
# It is normally called when all GenoRing dockers are down before any update is
# performed by container update hooks.
# Parameters are: current version string, new version string, and upgraded
# module (if empty, GenoRing framework is upgraded).

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; #no buffering

my ($current_version, $new_version, $module) = @ARGV;

if (!$module) {
  # Framework upgrade...
}
elsif ('TEMPLATE' eq $module) {
  # Upgrading this module (TEMPLATE).
  # Perform the module's upgrade tasks on the local file system.
}

# Returns 1 when called by "require".
1;
