#!/usr/bin/env perl

use strict;
use warnings;
use File::Spec;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; #no buffering

if (-e $ENV{'GENORING_VOLUMES_DIR'}) {
  # Remove all data directories. (the space before the dot is required for
  # Windows)
  my $output = qx(
    $Genoring::DOCKER_COMMAND run --rm -v $ENV{'GENORING_VOLUMES_DIR'}:/genoring -w / alpine rm -rf /genoring/drupal /genoring/db /genoring/proxy /genoring/www /genoring/data
  );
  HandleShellExecutionError();
}
