#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

# Checks if php-fpm is running. If not, it means the system is still
# initializing.
my $is_running = qx($Genoring::DOCKER_COMMAND exec -it $ENV{'COMPOSE_PROJECT_NAME'} pidof php-fpm);
if ($is_running && ($is_running =~ m/^[\d\s]+$/)) {
  print 'running';
}
else {
  print 'created';
}

1;
