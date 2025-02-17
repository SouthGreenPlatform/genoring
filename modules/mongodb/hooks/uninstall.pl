#!/usr/bin/env perl

use strict;
use warnings;
use File::Path;
use File::Spec;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; #no buffering

# Remove Gigwa config.
my $output = qx(
  $Genoring::DOCKER_COMMAND run --rm -v $Genoring::VOLUMES_DIR:/genoring -w / alpine rm -rf /genoring/mongodb
);
HandleShellExecutionError();

# Returns 1 when called by "require".
1;
