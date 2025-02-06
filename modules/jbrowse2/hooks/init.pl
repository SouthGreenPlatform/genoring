#!/usr/bin/env perl

use strict;
use warnings;
use File::Copy;

++$|; #no buffering

# Add proxy configs.
if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx') {
  if (!-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/jbrowse2.conf') {
    copy($ENV{'GENORING_DIR'} . '/modules/jbrowse2/res/nginx/jbrowse2.conf', $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/jbrowse2.conf');
  }
}

if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd') {
  if (!-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/jbrowse2.conf') {
    copy($ENV{'GENORING_DIR'} . '/modules/jbrowse2/res/httpd/jbrowse2.conf', $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/jbrowse2.conf');
  }
}
