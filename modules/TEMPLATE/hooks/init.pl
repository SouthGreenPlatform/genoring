#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when a module is installed. It is run from
# GenoRing base directory. It should NOT be run again when the module is
# disabled and re-enabled unless the module has also been uninstalled.
# It is normally called when all GenoRing dockers are down.

use strict;
use warnings;
use File::Copy;

++$|; #no buffering

# The purpose of this script is generally to make sure directories that will be
# mounted by docker exist. Ex.:
if (!-e './volumes/my_module') {
  mkdir './volumes/my_module'
}

# It can also be used to copy files from the module resource directory (res) to
# a future shared docker volume. Ex.
if (!-e './volumes/my_module/somefile.ext') {
  copy('./modules/my_module/res/somefile.ext', './volumes/my_module/somefile.ext');
}
