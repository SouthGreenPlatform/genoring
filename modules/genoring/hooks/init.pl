#!/usr/bin/env perl

use strict;
use warnings;
use File::Spec;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; #no buffering
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

  if (!-d $Genoring::VOLUMES_DIR . '/www') {
    my $www_src_path = File::Spec->catfile($Genoring::MODULES_DIR, 'genoring', 'res', 'www');
    my $www_vol_path = File::Spec->catfile($Genoring::VOLUMES_DIR, 'www');
    CopyDirectory($www_src_path, $www_vol_path);
  }

  CreateVolumeDirectory('data');
  CreateVolumeDirectory('backups');
}
else {
  # We still want a visible backup directory.
  CreateVolumeDirectory('backups');
}

# Add proxy configs (NGINX and Apache HTTPd).
require $ENV{'GENORING_DIR'} . '/modules/genoring/hooks/start.pl';
