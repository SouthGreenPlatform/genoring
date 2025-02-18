#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; # No buffering.

# Add configs.
CopyModuleFiles('jbrowse/res/nginx/jbrowse.conf', 'proxy/nginx/genoring/jbrowse.conf');
CopyModuleFiles('jbrowse/res/httpd/jbrowse.conf', 'proxy/httpd/jbrowse.conf');

# Returns 1 when called by "require".
1;

