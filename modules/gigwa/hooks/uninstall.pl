#!/usr/bin/env perl

use strict;
use warnings;
use File::Path;

++$|; #no buffering

# Remove Gigwa config.
my $failed = system(
  "docker run --rm -v ./volumes:/genoring -w / --platform linux/amd64 alpine rm -rf /genoring/gigwa /genoring/mongodb"
);

if ($failed) {
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
