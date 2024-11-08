#!/usr/bin/env perl

use strict;
use warnings;
use File::Copy;
use File::Spec;

++$|; #no buffering

# Install Gigwa config.
my $gigwa_volume_path = File::Spec->catfile('.', 'volumes', 'gigwa');
my $output = qx(docker run -it -v $gigwa_volume_path:/copy --entrypoint=/bin/cp guilhemsempere/gigwa:2.8-RELEASE -r /usr/local/tomcat/config /copy);

# Add proxy configs.
if (-d './volumes/proxy/nginx') {
  if (!-e './volumes/proxy/nginx/includes/gigwa.conf') {
    copy('./modules/gigwa/res/nginx/gigwa.conf', './volumes/proxy/nginx/includes/gigwa.conf');
  }
}

if (-d './volumes/proxy/httpd') {
  if (!-e './volumes/proxy/httpd/includes/gigwa.conf') {
    copy('./modules/gigwa/res/httpd/gigwa.conf', './volumes/proxy/httpd/includes/gigwa.conf');
  }
}
