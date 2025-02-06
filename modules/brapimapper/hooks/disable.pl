#!/usr/bin/env perl

use strict;
use warnings;

++$|; # No buffering.

# Remove proxy configs.
# Nginx.
if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/includes') {
  if (-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/includes/brapimapper.conf') {
    unlink $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/includes/brapimapper.conf';
  }
}

# Apache2.
if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/includes') {
  if (-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/includes/brapimapper.conf') {
    unlink $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/includes/brapimapper.conf';
  }
}
