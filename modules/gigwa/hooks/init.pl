#!/usr/bin/env perl

use strict;
use warnings;
use File::Copy;

++$|; #no buffering

# Install Gigwa config.
system("docker run -it -v ./volumes/gigwa:/copy --entrypoint=/bin/cp guilhemsempere/gigwa:2.8-RELEASE -r /usr/local/tomcat/config /copy");

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
