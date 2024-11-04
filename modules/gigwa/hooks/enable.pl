#!/usr/bin/env perl

use strict;
use warnings;

++$|; #no buffering

# Add proxy configs.
if (-d './volumes/proxy/nginx') {
  if (!-e './volumes/proxy/nginx/gigwa.conf') {
    copy('./modules/gigwa/res/nginx/gigwa.conf', './volumes/proxy/nginx/gigwa.conf');
  }
}

if (-d './volumes/proxy/httpd') {
  if (!-e './volumes/proxy/httpd/gigwa.conf') {
    copy('./modules/gigwa/res/httpd/gigwa.conf', './volumes/proxy/httpd/gigwa.conf');
  }
}
