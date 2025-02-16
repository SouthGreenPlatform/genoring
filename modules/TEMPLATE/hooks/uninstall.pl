#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when a module is uninstalled. It is run from
# GenoRing base directory. It should do the reverse job of the 'init.pl' hook
# script, to cleanup directories.
# It is normally called when all GenoRing dockers are down.

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; # No buffering.

# Since files created in docker volumes are created by a docker container run by
# the docker daemon, current user running genoring.pl to uninstall a module may
# not have the appropriate permissions to remove those files. To get arround
# that problem, the simplest way is to delete those files using a temporary
# docker container. The example below shows how to do it. We mount the GenoRing
# "volumes" directory in an alpine docker as its "/genoring/" directory and
# perform a "rm -rf" on the directory we want.

# Remove all the content of data/my_module directory.
my $output = qx(
  $Genoring::DOCKER_COMMAND run --rm -v $ENV{'GENORING_VOLUMES_DIR'}:/genoring -w / alpine rm -rf /genoring/my_module 2>&1
);
HandleShellExecutionError();

# Returns 1 when called by "require".
1;
