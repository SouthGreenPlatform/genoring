#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; #no buffering

# Remove proxy configs if one.
RemoveVolumeFiles('proxy/nginx/genoring/jbrowse.conf');
RemoveVolumeFiles('proxy/httpd/jbrowse.conf');

# Returns 1 when called by "require".
1;
