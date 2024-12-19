#!/usr/bin/env perl

use strict;
use warnings;

++$|; #no buffering

# Remove proxy configs.
if (-d './volumes/proxy/nginx/genoring') {
  if (-e './volumes/proxy/nginx/genoring/jbrowse.conf') {
    unlink './volumes/proxy/nginx/genoring/jbrowse.conf';
  }
}
if (-d './volumes/proxy/httpd/genoring') {
  if (-e './volumes/proxy/httpd/genoring/jbrowse.conf') {
    unlink './volumes/proxy/httpd/genoring/jbrowse.conf';
  }
}

# Returns 1 when called by "require".
1;
