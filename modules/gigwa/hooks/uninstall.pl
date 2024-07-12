#!/usr/bin/env perl

use strict;
use warnings;
use File::Path;

++$|; #no buffering

# Remove Gigwa config.
rmtree("./volumes/gigwa");
