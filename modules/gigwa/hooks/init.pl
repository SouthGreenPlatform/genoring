#!/usr/bin/env perl

use strict;
use warnings;

++$|; #no buffering

# Install Gigwa config.
system("docker run -it -v ./volumes/gigwa:/copy --entrypoint=/bin/cp guilhemsempere/gigwa:2.8-RELEASE -r /usr/local/tomcat/config /copy");

if (!-d './volumes/proxy/genoring') {
  mkdir './volumes/proxy/genoring';
}

if (!-e './volumes/proxy/genoring/gigwa.conf') {
  copy('./modules/gigwa/res/nginx/gigwa.conf', './volumes/proxy/genoring/gigwa.conf');
}
