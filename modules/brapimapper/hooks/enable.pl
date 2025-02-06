#!/usr/bin/env perl

use strict;
use warnings;
use File::Copy;
use File::Spec;

++$|; # No buffering.

# Add proxy configs.
# NGINX.
if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/includes') {
  if (!-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/includes/brapimapper.conf') {
    my $res_path = File::Spec->catfile($ENV{'GENORING_DIR'}, 'modules', 'brapimapper', 'res', 'nginx');
    my $volumes_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'proxy', 'nginx', 'includes');
    # Process NGINX config template to replace environment variables.
    my $output = qx(
      docker run --rm --env-file env/brapimapper_brapi.env --env-file env/genoring_nginx.env -v $res_path:/brapimapper -v $volumes_path:/nginx -w / alpine sh -c "apk add envsubst && envsubst < /brapimapper/brapimapper.template > /nginx/brapimapper.conf"
    );
  }
}
# Apache2.
if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/includes') {
  if (!-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/includes/brapimapper.conf') {
    # @todo
    # copy($ENV{'GENORING_DIR'} . '/modules/brapimapper/res/httpd/brapimapper.conf', $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/httpd/includes/brapimapper.conf');
  }
}

# Returns 1 when called by "require".
1;
