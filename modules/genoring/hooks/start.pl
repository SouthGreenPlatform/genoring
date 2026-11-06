#!/usr/bin/env perl

# Makes sure the proxy configuration files of both proxy servers (NGINX and its
# Apache HTTPd alternative) are available, so the proxy alternative can be
# switched at any time (including on instances initialized before the Apache
# HTTPd alternative was supported). Existing files are left unchanged.

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; # No buffering.

my %main_configs = (
  'nginx' => 'genoring-fpm.conf',
  'httpd' => 'genoring-httpd.conf',
);
foreach my $server (sort keys(%main_configs)) {
  if (!$ENV{'GENORING_NO_EXPOSED_VOLUMES'}) {
    CreateVolumeDirectory("proxy/$server/includes");
    CreateVolumeDirectory("proxy/$server/genoring");
  }
  else {
    # Files are not (exposed) volumes so we need to keep them copied.
    CreateVolumeDirectory("proxy/$server");
  }
  CopyModuleFiles(
    "genoring/res/$server/$main_configs{$server}",
    "proxy/$server/$main_configs{$server}"
  );
}

# Returns 1 when called by "require".
1;
