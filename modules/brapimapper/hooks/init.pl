#!/usr/bin/env perl

use strict;
use warnings;

# Add proxy configs.
require $ENV{'GENORING_DIR'} . '/modules/brapimapper/hooks/enable.pl';

# Returns 1 when called by "require".
1;
