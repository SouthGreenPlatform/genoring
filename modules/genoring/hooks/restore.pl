#!/usr/bin/env perl

use strict;
use warnings;
use Cwd qw();
use File::Copy;
use File::Path qw( remove_tree );
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
my ($backup) = @ARGV;
$backup ||= 'default';

if (-d "./volumes/backups/$backup/genoring/proxy") {
  my $proxy_backup_path = File::Spec->catfile($ENV{'PWD'} || Cwd::cwd(), 'volumes', 'backups', $backup, 'genoring', 'proxy');
  my $proxy_restore_path = File::Spec->catfile($ENV{'PWD'} || Cwd::cwd(), 'volumes', 'proxy');
  remove_tree($proxy_restore_path);
  dircopy($proxy_backup_path, $proxy_restore_path);
}

if (-d "./volumes/backups/$backup/genoring/offline") {
  my $offline_backup_path = File::Spec->catfile($ENV{'PWD'} || Cwd::cwd(), 'volumes', 'backups', $backup, 'genoring', 'offline');
  my $offline_restore_path = File::Spec->catfile($ENV{'PWD'} || Cwd::cwd(), 'volumes', 'offline');
  remove_tree($offline_restore_path);
  dircopy($offline_backup_path, $offline_restore_path);
}
