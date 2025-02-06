#!/usr/bin/env perl

use strict;
use warnings;

++$|; #no buffering

# Remove proxy configs.
if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring') {
  if (-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring/gigwa.conf') {
    unlink $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring/gigwa.conf';
  }
}
if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/genoring') {
  if (-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/genoring/gigwa.conf') {
    unlink $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/genoring/gigwa.conf';
  }
}

# Returns 1 when called by "require".
1;
