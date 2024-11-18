#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when a module needs to perform restore
# tasks.
# It is run from GenoRing base directory.
# It is normally called when all GenoRing dockers are down and receive as first
# argument a backup (machine) name.

use strict;
use warnings;
use File::Spec;

++$|; # No buffering.
my ($backup) = @ARGV;
$backup ||= 'default';
my $backup_path = File::Spec->catfile($ENV{'PWD'} || Cwd::cwd(), 'volumes', 'backups', $backup, 'MODULE');

# This script should be able to reverse the work done by its sibbling backup
# hook script.

# Returns 1 when called by "require".
1;
