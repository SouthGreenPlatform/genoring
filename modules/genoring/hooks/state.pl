#!/usr/bin/env perl

use strict;
use warnings;

# Checks if php-fpm is running. If not, it means the system is still
# initializing.
my $is_running = qx(docker exec -it genoring pidof php-fpm);
if ($is_running && ($is_running =~ m/^[\d\s]+$/)) {
  print 'running';
}
else {
  print 'created';
}
