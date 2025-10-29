#!/usr/bin/env perl

use strict;
use warnings;
use File::Spec;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; # No buffering.

if (!$ENV{'GENORING_NO_EXPOSED_VOLUMES'}) {
  # Install Gigwa config.
  my $gigwa_volume_path = File::Spec->catfile($Genoring::VOLUMES_DIR, 'gigwa');
  my $output = qx($Genoring::DOCKER_COMMAND run -it -v $gigwa_volume_path:/confcopy --entrypoint=/bin/cp guilhemsempere/gigwa:2.8-RELEASE -r /usr/local/tomcat/config /confcopy);
  HandleShellExecutionError();
}

# Add proxy configs.
require $ENV{'GENORING_DIR'} . '/modules/gigwa/hooks/enable.pl';

# Returns 1 when called by "require".
1;
