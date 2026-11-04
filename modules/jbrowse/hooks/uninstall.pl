#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; #no buffering

# Remove JBrowse data.
my $output = qx(
  $Genoring::DOCKER_COMMAND run --rm -v $ENV{'GENORING_VOLUMES_DIR'}:/genoring -w / alpine rm -rf /genoring/data/jbrowse /genoring/www/jbrowse /genoring/www/.jbrowse-disabled
);
HandleShellExecutionError() or exit(1);

# Returns 1 when called by "require".
1;
