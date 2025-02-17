#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; #no buffering

# Remove proxy configs.
RemoveVolumeFiles('proxy/nginx/genoring/gigwa.conf');
RemoveVolumeFiles('proxy/httpd/genoring/gigwa.conf');

# Returns 1 when called by "require".
1;
