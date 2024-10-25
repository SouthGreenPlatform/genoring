#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when GenorRing is stopped. It is run from
# GenoRing base directory.
# It is normally called when all GenoRing dockers are already down.

use strict;
use warnings;

++$|; #no buffering

# This type of hook can be used to manage external services or log events.