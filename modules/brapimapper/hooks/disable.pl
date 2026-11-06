#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; # No buffering.

# Remove proxy configs (NGINX and Apache HTTPd).
RemoveVolumeFiles('proxy/nginx/includes/brapimapper.conf');
RemoveVolumeFiles('proxy/httpd/includes/brapimapper.conf');
