#!/usr/bin/env perl

use strict;
use warnings;
use File::Spec;

++$|; #no buffering

# Remove all data directories. (the space before the dot is required for
# Windows)
my $volumes_path = File::Spec->catfile(' .', 'volumes');
my $output = qx(
  docker run --rm -v $volumes_path:/genoring -w / alpine rm -rf /genoring/drupal /genoring/db /genoring/proxy /genoring/offline /genoring/data
);

if ($?) {
  my $error_message = 'ERROR';
  if ($? == -1) {
    $error_message = "ERROR $?\n$!";
  }
  elsif ($? & 127) {
    $error_message = sprintf(
      "ERROR: Child died with signal %d, %s coredump\n",
      ($? & 127), ($? & 128) ? 'with' : 'without'
    );
  }
  elsif ($?) {
    $error_message = sprintf("ERROR %d", $? >> 8);
  }
  warn($error_message);
}
