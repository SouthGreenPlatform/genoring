#!/usr/bin/env perl

use strict;
use warnings;

++$|; #no buffering

# Remove proxy configs if one.
if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring') {
  if (-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring/jbrowse.conf') {
    unlink $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring/jbrowse.conf';
  }
}
if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/genoring') {
  if (-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/genoring/jbrowse.conf') {
    unlink $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/genoring/jbrowse.conf';
  }
}

# Returns 1 when called by "require".
1;
