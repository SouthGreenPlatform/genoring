#!/usr/bin/env perl

use strict;
use warnings;
use Cwd qw();
use File::Copy;
use File::Spec;
use File::Path qw(make_path);

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
my ($backup) = @ARGV;
$backup ||= 'default';

if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy') {
  my $proxy_src_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'proxy');
  my $proxy_vol_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'backups', $backup, 'genoring', 'proxy');
  make_path($proxy_vol_path);
  dircopy($proxy_src_path, $proxy_vol_path);
}

if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/offline') {
  my $offline_src_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'offline');
  my $offline_vol_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'backups', $backup, 'genoring', 'offline');
  make_path($offline_vol_path);
  dircopy($offline_src_path, $offline_vol_path);
}
