#!/usr/bin/env perl

use strict;
use warnings;
use File::Copy;
use File::Spec;

++$|; # No buffering.

# Add proxy configs.
require './modules/brapimapper/hooks/enable.pl';

# Returns 1 when called by "require".
1;
