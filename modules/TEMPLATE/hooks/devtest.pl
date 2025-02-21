#!/usr/bin/env perl

# This is not properly a real hook but rather a testing hook Perl script.
# You can have it called by GenoRing using the command line:
#   perl genoring.pl -verbose localhooks devtest your_module_name [args...]
# See Genoring::ApplyLocalHooks() GenoRing Perl library function.

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

print "Hello! GenoRing is set to be accessed through http://" . $ENV{'GENORING_HOST'} . ':' . $ENV{'GENORING_PORT'} . "/\n";

# Returns 1 when called by "require".
1;
