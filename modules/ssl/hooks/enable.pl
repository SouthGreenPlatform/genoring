#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; # No buffering.

my $config = GetConfig();
if ($config->{'no_exposed_ports'}) {
  print "\nWARNING: This instance does not expose its ports. HTTPS should be managed by the master GenoRing instance proxy instead.\n";
}
if ($config->{'managed_instances'} && %{$config->{'managed_instances'}}) {
  # Certificates can only be generated once the proxy runs with SSL volume.
  print "\nNOTE: Run the 'attach' command again for each managed instance once GenoRing is started to enable HTTPS on them.\n";
}
