#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; # No buffering.

# Remove HTTPS from managed instance proxy configs as certificates will not be
# available anymore.
RefreshManagedInstances();
