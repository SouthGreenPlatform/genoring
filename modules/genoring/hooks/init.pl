#!/usr/bin/env perl

use strict;
use warnings;
use File::Spec;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; #no buffering
print "DEBUG init\n"; #+debug
if (!-d $Genoring::VOLUMES_DIR) {
  mkdir $Genoring::VOLUMES_DIR;
}
if (!$ENV{'GENORING_NO_EXPOSED_VOLUMES'}) {
  if (!-e $Genoring::VOLUMES_DIR . '/drupal') {
    CreateVolumeDirectory('drupal');
  }
  else {
    opendir(my $dh, $Genoring::VOLUMES_DIR . '/drupal')
      or die "ERROR: '$Genoring::VOLUMES_DIR/drupal' is not a directory!";
    my @dir_content = grep { $_ ne "." && $_ ne ".." } readdir($dh);
    closedir($dh);
    if (scalar(@dir_content) != 0) {
      die "ERROR: '$Genoring::VOLUMES_DIR/drupal' is not empty! Please empty it before installation.\nContent:\n\"" . join('", "', @dir_content) . '".';
    }
  }

  CreateVolumeDirectory('proxy/nginx/includes');
  CreateVolumeDirectory('proxy/nginx/genoring');
  CopyModuleFiles(
    'genoring/res/nginx/genoring-fpm.conf',
    'proxy/nginx/genoring-fpm.conf'
  );

  if (!-d $Genoring::VOLUMES_DIR . '/offline') {
    my $offline_src_path = File::Spec->catfile($Genoring::MODULES_DIR, 'genoring', 'res', 'offline');
    my $offline_vol_path = File::Spec->catfile($Genoring::VOLUMES_DIR, 'offline');
    DirCopy($offline_src_path, $offline_vol_path);
  }

  CreateVolumeDirectory('data');
  CreateVolumeDirectory('backups');
}
else {
  CreateVolumeDirectory('proxy/nginx');
  CopyModuleFiles(
    'genoring/res/nginx/genoring-fpm.conf',
    'proxy/nginx/genoring-fpm.conf'
  );
}
