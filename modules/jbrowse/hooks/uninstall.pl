#!/usr/bin/env perl

use strict;
use warnings;
use File::Path;
use File::Spec;

++$|; #no buffering

# Remove JBrowse data.
my $volume_path = $ENV{'GENORING_VOLUMES_DIR'};
my $output = qx(
  docker run --rm -v $volume_path:/genoring -w / alpine rm -rf /genoring/data/jbrowse
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
  else {
    $error_message = sprintf("ERROR %d", $? >> 8);
  }
  warn($error_message);
}

# Returns 1 when called by "require".
1;
