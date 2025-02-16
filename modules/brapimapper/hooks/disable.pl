#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; # No buffering.

# Remove proxy configs.
# Nginx.
RemoveVolumeFiles('proxy/nginx/includes/brapimapper.conf');

# Apache2.
RemoveVolumeFiles('proxy/httpd/includes/brapimapper.conf');
