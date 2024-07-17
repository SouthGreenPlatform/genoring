#!/usr/bin/env perl

use strict;
use warnings;
use File::Copy;

++$|; #no buffering

# Add proxy configs.
if (-d './volumes/proxy/nginx') {
  if (!-e './volumes/proxy/nginx/jbrowse2.conf') {
    copy('./modules/jbrowse2/res/nginx/jbrowse2.conf', './volumes/proxy/nginx/jbrowse2.conf');
  }
}

if (-d './volumes/proxy/httpd') {
  if (!-e './volumes/proxy/httpd/jbrowse2.conf') {
    copy('./modules/jbrowse2/res/httpd/jbrowse2.conf', './volumes/proxy/httpd/jbrowse2.conf');
  }
}
