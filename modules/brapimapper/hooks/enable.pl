#!/usr/bin/env perl

use strict;
use warnings;
use File::Copy;
use File::Spec;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;


++$|; # No buffering.

# Add proxy configs (NGINX and Apache HTTPd).
foreach my $server ('nginx', 'httpd') {
  my $volumes_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'proxy', $server, 'includes');
  if ((-d $volumes_path) && (!-e File::Spec->catfile($volumes_path, 'brapimapper.conf'))) {
    my $res_path = File::Spec->catfile($Genoring::MODULES_DIR, 'brapimapper', 'res', $server);
    # Process proxy config template to replace environment variables.
    my $output = qx(
      $Genoring::DOCKER_COMMAND run --rm --env-file $ENV{'PWD'}/env/brapimapper_brapi.env --env-file $ENV{'PWD'}/env/genoring_$server.env --env-file $ENV{'PWD'}/env/genoring_genoring.env -v $res_path:/brapimapper -v $volumes_path:/proxy -w / alpine sh -c "apk add envsubst && envsubst < /brapimapper/brapimapper.template > /proxy/brapimapper.conf"
    );
  }
}

# Returns 1 when called by "require".
1;
