#!/usr/bin/env perl

use strict;
use warnings;

++$|; #no buffering

# Install Gigwa config.
system("docker run -it -v ./volumes/gigwa:/copy  --entrypoint=/bin/cp guilhemsempere/gigwa:2.8-RELEASE -r /usr/local/tomcat/config /copy");
