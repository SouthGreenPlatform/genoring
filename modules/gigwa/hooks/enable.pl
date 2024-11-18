#!/usr/bin/env perl

use strict;
use warnings;

++$|; # No buffering.

# Add proxy configs.
# NGINX.
if (-d './volumes/proxy/nginx/genoring') {
  if (!-e './volumes/proxy/nginx/genoring/gigwa.conf') {
    copy('./modules/gigwa/res/nginx/gigwa.conf', './volumes/proxy/nginx/genoring/gigwa.conf');
  }
}
# Apache 2.
if (-d './volumes/proxy/httpd/genoring') {
  if (!-e './volumes/proxy/httpd/genoring/gigwa.conf') {
    copy('./modules/gigwa/res/httpd/gigwa.conf', './volumes/proxy/httpd/genoring/gigwa.conf');
  }
}

# Returns 1 when called by "require".
1;
