#!/usr/bin/env perl

use strict;
use warnings;

++$|; # No buffering.

# Remove proxy configs.
# Nginx.
if (-d './volumes/proxy/nginx/includes') {
  if (-e './volumes/proxy/nginx/includes/brapimapper.conf') {
    unlink './volumes/proxy/nginx/includes/brapimapper.conf';
  }
}

# Apache2.
if (-d './volumes/proxy/httpd/includes') {
  if (-e './volumes/proxy/httpd/includes/brapimapper.conf') {
    unlink './volumes/proxy/httpd/includes/brapimapper.conf';
  }
}
