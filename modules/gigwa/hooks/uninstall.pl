#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; #no buffering

if (!$ENV{'GENORING_NO_EXPOSED_VOLUMES'}) {
  # Remove Gigwa config.
  my $output = qx(
    $Genoring::DOCKER_COMMAND run --rm -v $Genoring::VOLUMES_DIR:/genoring -w / alpine rm -rf /genoring/gigwa
  );
  HandleShellExecutionError();
}

# Returns 1 when called by "require".
1;
