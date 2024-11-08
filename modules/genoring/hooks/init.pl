#!/usr/bin/env perl

use strict;
use warnings;
use Cwd qw();
use File::Copy;
use File::Path qw(make_path);
use File::Spec;

# Recursive function to copy directories.
sub dircopy {
  my ($source, $target) = @_;
  if (opendir(my $dh, $source)) {
    foreach my $item (readdir($dh)) {
      # Skip "." and "..".
      if ($item =~ m/^\.\.?$/) {
        next;
      }
      if (-d "$source/$item") {
        # Sub-directory.
        if (!-e "$target/$item") {
          mkdir "$target/$item";
        }
        dircopy("$source/$item", "$target/$item");
      }
      else {
        # File.
        copy("$source/$item", "$target/$item");
      }
    }
    closedir($dh);
  }
  else {
    warn "WARNING: Failed to access '$source' directory!\n$!";
  }
}

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

if (!-d './volumes/proxy/nginx/includes') {
  make_path('./volumes/proxy/nginx/includes');
}

if (!-e './volumes/proxy/nginx/genoring-fpm.conf') {
  copy('./modules/genoring/res/nginx/genoring-fpm.conf', './volumes/proxy/nginx/genoring-fpm.conf');
}

if (!-d './volumes/offline') {
  my $offline_src_path = File::Spec->catfile($ENV{'PWD'} || Cwd::cwd(), 'modules', 'genoring', 'res', 'offline');
  my $offline_vol_path = File::Spec->catfile($ENV{'PWD'} || Cwd::cwd(), 'volumes', 'offline');
  dircopy($offline_src_path, $offline_vol_path);
}

if (!-d './volumes/data') {
  mkdir './volumes/data';
}

if (!-d './volumes/backups') {
  mkdir './volumes/backups';
}
