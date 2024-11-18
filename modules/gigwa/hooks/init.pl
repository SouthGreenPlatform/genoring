#!/usr/bin/env perl

use strict;
use warnings;
use File::Copy;
use File::Spec;

++$|; # No buffering.

# Install Gigwa config.
my $gigwa_volume_path = File::Spec->catfile(' .', 'volumes', 'gigwa');
my $output = qx(docker run -it -v $gigwa_volume_path:/confcopy --entrypoint=/bin/cp guilhemsempere/gigwa:2.8-RELEASE -r /usr/local/tomcat/config /confcopy);

# Add proxy configs.
require './modules/gigwa/hooks/enable.pl';

# Returns 1 when called by "require".
1;
