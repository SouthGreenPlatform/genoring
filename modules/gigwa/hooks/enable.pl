#!/usr/bin/env perl

use strict;
use warnings;

++$|; #no buffering

# Add proxy configs.
if (-d './volumes/proxy/nginx/includes') {
  if (!-e './volumes/proxy/nginx/includes/gigwa.conf') {
    copy('./modules/gigwa/res/nginx/gigwa.conf', './volumes/proxy/nginx/includes/gigwa.conf');
  }
}

if (-d './volumes/proxy/httpd/includes') {
  if (!-e './volumes/proxy/httpd/includes/gigwa.conf') {
    copy('./modules/gigwa/res/httpd/gigwa.conf', './volumes/proxy/httpd/includes/gigwa.conf');
  }
}
