#!/usr/bin/env perl

use strict;
use warnings;
use Cwd qw();
use File::Copy;
use File::Spec;
use File::Path qw(make_path);
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; #no buffering

my ($backup) = @ARGV;
$backup ||= 'default';

if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/proxy') {
  my $proxy_src_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'proxy');
  my $proxy_vol_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'backups', $backup, 'genoring', 'proxy');
  make_path($proxy_vol_path);
  DirCopy($proxy_src_path, $proxy_vol_path);
}

if (-d $ENV{'GENORING_VOLUMES_DIR'} . '/www') {
  my $www_src_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'www');
  my $www_vol_path = File::Spec->catfile($ENV{'GENORING_VOLUMES_DIR'}, 'backups', $backup, 'genoring', 'www');
  make_path($www_vol_path);
  DirCopy($www_src_path, $www_vol_path);
}
