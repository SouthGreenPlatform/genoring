#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when a module needs to perform backup tasks.
# It is run from GenoRing base directory.
# It is normally called when all GenoRing dockers are down and receive as first
# argument a backup (machine) name.

use strict;
use warnings;
use Env;
use File::Spec;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; # No buffering.
my ($backup) = @ARGV;
$backup ||= 'default';
# Replace 'MY_MODULE' by your module name.
my $backup_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'backups', $backup, 'MY_MODULE');

# This script might work on backup data provided by container backup hooks to
# create a global archive of serveral services for instance.

# Returns 1 when called by "require".
1;
