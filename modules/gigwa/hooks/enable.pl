#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; # No buffering.

if ($ENV{'GIGWA_DIRECT_ACCESS'}) {
  # Add proxy configs.
  # NGINX.
  CopyModuleFiles('gigwa/res/nginx/gigwa.conf', 'proxy/nginx/genoring/gigwa.conf');
  # Apache 2.
  CopyModuleFiles('gigwa/res/httpd/gigwa.conf', 'proxy/httpd/genoring/gigwa.conf');
}

# Returns 1 when called by "require".
1;
