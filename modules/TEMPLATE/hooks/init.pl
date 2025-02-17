#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when a module is installed. It is run from
# GenoRing base directory. It should NOT be run again when the module is
# disabled and re-enabled unless the module has also been uninstalled.
# It is normally called when all GenoRing dockers are down.

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; # No buffering.

# The purpose of this script is generally to make sure directories that will be
# mounted by docker exist. Ex.: CreateVolumeDirectory('my_module/subdir');
# To copy files, you can use CopyModuleFiles() and CopyVolumeFiles().
# To copy a directory, you can use CopyDirectory().
# Also, to avoid code duplication, it is possible to call the 'enable.pl' hook
# script from here: 
require $Genoring::MODULES_DIR . '/MY_MODULE/hooks/enable.pl';

# Returns 1 when called by "require".
1;
