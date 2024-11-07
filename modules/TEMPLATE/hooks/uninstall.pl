#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when a module is uninstalled. It is run from
# GenoRing base directory. It should do the reverse job of the 'init.pl' hook
# script, to cleanup directories.
# It is normally called when all GenoRing dockers are down.

use strict;
use warnings;

++$|; #no buffering

# Since files created in docker volumes are created by a docker container run by
# the docker daemon, current user running genoring.pl to uninstall a module may
# not have the appropriate permissions to remove those files. To get arround
# that problem, the simplest way is to delete those files using a temporary
# docker container. The example below shows how to do it. We mount the GenoRing
# "volumes" directory in an alpine docker as its "/genoring/" directory and
# perform a "rm -rf" on the directory we want.

# Remove all the content of data/my_module directory.
my $failed = system(
  "docker run --rm -v ./volumes:/genoring -w / --platform linux/amd64 alpine rm -rf /genoring/my_module"
);

# Then we need to report any problem encountered to the user.
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
