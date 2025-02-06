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
    if (!-d $target) {
      if (!mkdir $target) {
        die "ERROR: Failed to create target directory '$target'!\n$!\n";
      }
    }
    foreach my $item (readdir($dh)) {
      # Skip "." and "..".
      if ($item =~ m/^\.\.?$/) {
        next;
      }
      if (-d "$source/$item") {
        # Sub-directory.
        if (!-e "$target/$item") {
          if (!mkdir "$target/$item") {
            warn "WARNING: Failed to create directory '$target/$item'!\n$!\n";
          }
        }
        dircopy("$source/$item", "$target/$item");
      }
      else {
        # File.
        if (!copy("$source/$item", "$target/$item")) {
          warn "WARNING: Failed to copy '$source/$item'.\n$!\n";
        }
      }
    }
    closedir($dh);
  }
  else {
    warn "WARNING: Failed to access '$source' directory!\n$!";
  }
}

++$|; #no buffering
if (!-d $ENV{'GENORING_VOLUMES_DIR'}) {
  mkdir $ENV{'GENORING_VOLUMES_DIR'};
}
if (!$ENV{'GENORING_NO_EXPOSED_VOLUMES'}) {
  if (!-e $ENV{'GENORING_VOLUMES_DIR'} . '/drupal') {
    mkdir $ENV{'GENORING_VOLUMES_DIR'} . '/drupal'
  }
  else {
    opendir(my $dh, $ENV{'GENORING_VOLUMES_DIR'} . '/drupal') or die "ERROR: '$ENV{'GENORING_VOLUMES_DIR'}/drupal' is not a directory!";
    my @dir_content = grep { $_ ne "." && $_ ne ".." } readdir($dh);
    closedir($dh);
    if (scalar(@dir_content) != 0) {
      die "ERROR: '$ENV{'GENORING_VOLUMES_DIR'}/drupal' is not empty! Please empty it before installation.\nContent:\n\"" . join('", "', @dir_content) . '".';
    }
  }

  if (!-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/includes') {
    make_path($ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/includes');
  }

  if (!-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring') {
    make_path($ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring');
  }

  if (!-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring-fpm.conf') {
    copy($ENV{'GENORING_DIR'} . '/modules/genoring/res/nginx/genoring-fpm.conf', $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring-fpm.conf');
  }

  if (!-d $ENV{'GENORING_VOLUMES_DIR'} . '/offline') {
    my $offline_src_path = File::Spec->catfile($ENV{'GENORING_DIR'}, 'modules', 'genoring', 'res', 'offline');
    my $offline_vol_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'offline');
    dircopy($offline_src_path, $offline_vol_path);
  }

  if (!-d $ENV{'GENORING_VOLUMES_DIR'} . '/data') {
    mkdir $ENV{'GENORING_VOLUMES_DIR'} . '/data';
  }

  if (!-d $ENV{'GENORING_VOLUMES_DIR'} . '/backups') {
    mkdir $ENV{'GENORING_VOLUMES_DIR'} . '/backups';
  }
}
else {
  if (!-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx') {
    make_path($ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx');
  }
  if (!-e $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring-fpm.conf') {
    copy($ENV{'GENORING_DIR'} . '/modules/genoring/res/nginx/genoring-fpm.conf', $ENV{'GENORING_VOLUMES_DIR'} . '/proxy/nginx/genoring-fpm.conf');
  }
}
