#!/usr/bin/env perl

use strict;
use warnings;
use File::Copy;
use File::Spec;

++$|; #no buffering

# Create JBrowse data directory.
my $jbrowse_volume_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'data', 'jbrowse');

# Add proxy configs.
require $ENV{'GENORING_DIR'} . '/modules/jbrowse/hooks/enable.pl';

# Returns 1 when called by "require".
1;
