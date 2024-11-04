#!/usr/bin/env perl

use strict;
use warnings;

++$|; #no buffering

# Remove proxy configs.
if (-d './volumes/proxy/nginx') {
  if (-e './volumes/proxy/nginx/gigwa.conf') {
    unlink './volumes/proxy/nginx/gigwa.conf';
  }
}

if (-d './volumes/proxy/httpd') {
  if (-e './volumes/proxy/httpd/gigwa.conf') {
    unlink './volumes/proxy/httpd/gigwa.conf';
  }
}
