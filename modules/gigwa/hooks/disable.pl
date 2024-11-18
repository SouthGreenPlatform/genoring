#!/usr/bin/env perl

use strict;
use warnings;

++$|; #no buffering

# Remove proxy configs.
if (-d './volumes/proxy/nginx/genoring') {
  if (-e './volumes/proxy/nginx/genoring/gigwa.conf') {
    unlink './volumes/proxy/nginx/genoring/gigwa.conf';
  }
}

if (-d './volumes/proxy/httpd/genoring') {
  if (-e './volumes/proxy/httpd/genoring/gigwa.conf') {
    unlink './volumes/proxy/httpd/genoring/gigwa.conf';
  }
}

# Returns 1 when called by "require".
1;
