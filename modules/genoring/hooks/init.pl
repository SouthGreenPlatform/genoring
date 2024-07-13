#!/usr/bin/env perl

use strict;
use warnings;

++$|; #no buffering
if (!-d './volumes/') {
  mkdir './volumes/';
}

if (!-e './volumes/drupal') {
  mkdir './volumes/drupal'
}
else {
  opendir(my $dh, './volumes/drupal') or die "ERROR: './volumes/drupal' is not a directory!";
  if (scalar(grep { $_ ne "." && $_ ne ".." } readdir($dh)) == 0) {
    die "ERROR: './volumes/drupal' is not empty! Please empty it before installation.";
  }
}

if (!-d './volumes/data') {
  mkdir './volumes/data'
}

if (!-d './volumes/offline') {
  system('cp -r ./modules/genoring/res/offline ./volumes/offline');
}
