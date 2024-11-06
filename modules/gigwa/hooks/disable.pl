#!/usr/bin/env perl

use strict;
use warnings;

++$|; #no buffering

# Remove proxy configs.
if (-d './volumes/proxy/nginx/includes') {
  if (-e './volumes/proxy/nginx/includes/gigwa.conf') {
    unlink './volumes/proxy/nginx/includes/gigwa.conf';
  }
}

if (-d './volumes/proxy/httpd/includes') {
  if (-e './volumes/proxy/httpd/includes/gigwa.conf') {
    unlink './volumes/proxy/httpd/includes/gigwa.conf';
  }
}
