#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when the running state of the module is
# requested and is run from GenoRing base directory.
# It is the only local hook script that can be called when GenoRing dockers
# are running, due to its special task that checks the container status.
# The expected valid return values are just a string with one of the following
# values: "created", "running", "restarting", "paused", "dead", "exited" or an
# empty string.
#
# Here is a description of those values:
# "created": means the container exists but has not finished its initialization.
# "running": means the container is operation and ready to accept requests.
# "restarting": means the containter is currently restarting.
# "paused": means the container is paused.
# "dead": means the container crashed or has been stopped.
# "exited": means the container has stopped.
# an empty string: means either we can't get the container status or the
#   has not been started at all. This answer should be treated with care as it
#   does not necessarily means that the container is not running: it could be
#   but we don't know. It can be the only answer that could provide modules that
#   don't provide container services but rather rely on other containers of
#   other modules they depend on.
#
# Usually, just answering 'running' or nothing is fine with genoring.pl.

use strict;
use warnings;

# Example: checks if php-fpm is running in the genoring docker container. If
# not, it means the system is still initializing.
my $is_running = qx(docker exec -it genoring pidof php-fpm);
if ($is_running && ($is_running =~ m/^[\d\s]+$/)) {
  print 'running';
}
# Nothing is returned otherwise as we don't know the state of the container but
# it could be improved by checking what docker says about this container.