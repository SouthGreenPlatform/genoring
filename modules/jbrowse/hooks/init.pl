#!/usr/bin/env perl

use strict;
use warnings;
use File::Copy;
use File::Spec;

++$|; #no buffering

# Add proxy configs.
require './modules/jbrowse/hooks/enable.pl';
