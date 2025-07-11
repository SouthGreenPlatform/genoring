#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when a module is enabled. It is run from
# GenoRing base directory.
# It is normally called when all GenoRing dockers are already down.

use strict;
use warnings;
use Env;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; # No buffering.

# This type of hook can be used to manage external services or log events.
# To copy files, you can use CopyModuleFiles and CopyVolumeFiles().
# To copy a directory, you can use CopyDirectory().

# Returns 1 when called by "require".
1;
