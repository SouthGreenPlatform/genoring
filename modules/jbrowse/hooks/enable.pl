#!/usr/bin/env perl

use strict;
use warnings;

++$|; # No buffering.

# Disabled to use site integration. Maybe we will want to use an environment
# variable to enable/disable direct access (like for Gigwa module).
# Add proxy configs.
if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx') {
  if (!-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring/jbrowse.conf') {
    copy($ENV{'GENORING_DIR'} . '/modules/jbrowse/res/nginx/jbrowse.conf', $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring/jbrowse.conf');
  }
}

if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd') {
  if (!-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/jbrowse.conf') {
    copy($ENV{'GENORING_DIR'} . '/modules/jbrowse/res/httpd/jbrowse.conf', $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/jbrowse.conf');
  }
}

# Returns 1 when called by "require".
1;

