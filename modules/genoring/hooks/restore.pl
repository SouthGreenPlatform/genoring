#!/usr/bin/env perl

use strict;
use warnings;
use Cwd qw();
use File::Copy;
use File::Path qw( remove_tree );
use File::Spec;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; #no buffering

my ($backup) = @ARGV;
$backup ||= 'default';

if (-d $ENV{'GENORING_VOLUMES_DIR'} . "/backups/$backup/genoring/proxy") {
  my $proxy_backup_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'backups', $backup, 'genoring', 'proxy');
  my $proxy_restore_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'proxy');
  remove_tree($proxy_restore_path);
  DirCopy($proxy_backup_path, $proxy_restore_path);
}

if (-d $ENV{'GENORING_VOLUMES_DIR'} . "/backups/$backup/genoring/offline") {
  my $offline_backup_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'backups', $backup, 'genoring', 'offline');
  my $offline_restore_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'offline');
  remove_tree($offline_restore_path);
  DirCopy($offline_backup_path, $offline_restore_path);
}
