#!/usr/bin/env perl

use strict;
use warnings;
use File::Copy;

++$|; #no buffering
if (!-d './volumes/') {
  mkdir './volumes/';
}

if (!-e './volumes/drupal') {
  mkdir './volumes/drupal'
}
else {
  opendir(my $dh, './volumes/drupal') or die "ERROR: './volumes/drupal' is not a directory!";
  my @dir_content = grep { $_ ne "." && $_ ne ".." } readdir($dh);
  closedir($dh);
  if (scalar(@dir_content) != 0) {
    die "ERROR: './volumes/drupal' is not empty! Please empty it before installation.\nContent:\n\"" . join('", "', @dir_content) . '".';
  }
}

if (!-d './volumes/proxy') {
  mkdir './volumes/proxy';
}

if (!-d './volumes/proxy/nginx') {
  mkdir './volumes/proxy/nginx';
}

if (!-e './volumes/proxy/genoring-fpm.conf') {
  copy('./modules/genoring/res/nginx/genoring-fpm.conf', './volumes/proxy/genoring-fpm.conf');
}

if (!-d './volumes/offline') {
  system('cp -r ./modules/genoring/res/offline ./volumes/offline');
}

if (!-d './volumes/data') {
  mkdir './volumes/data';
}

if (!-d './volumes/backups') {
  mkdir './volumes/backups';
}
