#!/usr/bin/env perl

use strict;
use warnings;
use File::Spec;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; #no buffering

# Remove proxy configs if one.
RemoveVolumeFiles('proxy/nginx/genoring/jbrowse.conf');
RemoveVolumeFiles('proxy/httpd/genoring/jbrowse.conf');

# Move JBrowse web files aside (they are restored by the
# enable_genoring-jbrowse.sh hook when the module is enabled again).
# Note: JBrowse service is not available anymore, so a temporary container is
# used.
my $www_dir = File::Spec->rel2abs(File::Spec->catdir($ENV{'GENORING_VOLUMES_DIR'}, 'www'));
Run(
  "$Genoring::DOCKER_COMMAND run --rm -v \"$www_dir:/www\" alpine sh -c \"if [ -d /www/.jbrowse-disabled ]; then rm -rf /www/jbrowse; elif [ -d /www/jbrowse ]; then mv /www/jbrowse /www/.jbrowse-disabled; fi\"",
  "Failed to disable JBrowse web files",
  1
);

# Returns 1 when called by "require".
1;
