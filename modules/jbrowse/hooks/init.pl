#!/usr/bin/env perl

use strict;
use warnings;
use File::Copy;

++$|; #no buffering

# Add proxy configs.
if (-d './volumes/proxy/nginx') {
  if (!-e './volumes/proxy/nginx/jbrowse.conf') {
    copy('./modules/jbrowse/res/nginx/jbrowse.conf', './volumes/proxy/nginx/jbrowse.conf');
  }
}

if (-d './volumes/proxy/httpd') {
  if (!-e './volumes/proxy/httpd/jbrowse.conf') {
    copy('./modules/jbrowse/res/httpd/jbrowse.conf', './volumes/proxy/httpd/jbrowse.conf');
  }
}
