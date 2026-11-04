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
  # Use the same image as the Gigwa service.
  my $service = Genoring::ReadYaml(File::Spec->catfile($ENV{'GENORING_DIR'}, 'modules', 'gigwa', 'services', 'genoring-gigwa.yml'))->[0];
  my $platform = $service->{'platform'} ? "--platform $service->{'platform'} " : '';
  my $output = qx($Genoring::DOCKER_COMMAND run --rm $platform-v $gigwa_volume_path:/confcopy --entrypoint=/bin/cp $service->{'image'} -r /usr/local/tomcat/config /confcopy);
  HandleShellExecutionError() or exit(1);
}

# Add proxy configs.
require $ENV{'GENORING_DIR'} . '/modules/gigwa/hooks/enable.pl';

# Returns 1 when called by "require".
1;
