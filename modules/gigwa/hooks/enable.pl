#!/usr/bin/env perl

use strict;
use warnings;

++$|; # No buffering.

if ($ENV{'GIGWA_DIRECT_ACCESS'}) {
  # Add proxy configs.
  # NGINX.
  if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring') {
    if (!-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring/gigwa.conf') {
      copy($ENV{'GENORING_DIR'} . '/modules/gigwa/res/nginx/gigwa.conf', $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring/gigwa.conf');
    }
  }
  # Apache 2.
  if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/genoring') {
    if (!-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/genoring/gigwa.conf') {
      copy($ENV{'GENORING_DIR'} . '/modules/gigwa/res/httpd/gigwa.conf', $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/genoring/gigwa.conf');
    }
  }
}

# Returns 1 when called by "require".
1;
