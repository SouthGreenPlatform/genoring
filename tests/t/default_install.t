#!/usr/bin/env perl

=pod

=head1 NAME

default_install.t - Tests GenoRing default installation process.

=head1 DESCRIPTION

Tests GenoRing default installation process.

=cut

use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use File::Basename qw(dirname);
use File::Path qw(make_path remove_tree);
use File::Spec;
use FindBin;
use Getopt::Long qw(GetOptions);
use IO::Select;
use IPC::Open3 qw(open3);
use lib "$FindBin::Bin/../../perllib";
use Genoring::GenoringTest;
use Test::More tests => 21;
++$|; #no buffering

# Enter test directory.
ok(chdir($Genoring::GenoringTest::TEST_DIR), "Enter test directory");

# Create test instance directory.
my $instance = GetNewInstance();
ok($instance, "New instance directory created");

# Initializes test instance.
ok(0 == InitializeInstance(
    $instance,
    {
      'env' => {
        'genoring_genoring' => {
          'GENORING_HOST' => $instance,
        },
      },
    }
  ),
  'Instance initialized'
);

# Stops test instance.
ok(0 == RunGenoring($instance, ['stop']), 'Instance stopped');

# Make sure expected files were created.
my $instance_dir = File::Spec->catdir($Genoring::GenoringTest::TEST_DIR, $Genoring::GenoringTest::TEMP_TEST_DIR, $instance);
my $expected_files = [
  File::Spec->catfile($instance_dir, 'env', 'genoring_genoring.env'),
  File::Spec->catfile($instance_dir, 'env', 'genoring_db.env'),
  File::Spec->catfile($instance_dir, 'env', 'genoring_nginx.env'),
  File::Spec->catfile($instance_dir, 'config.yml'),
  File::Spec->catfile($instance_dir, 'docker-compose.yml'),
  File::Spec->catfile($instance_dir, 'volumes', 'backups'),
  File::Spec->catfile($instance_dir, 'volumes', 'data', 'genoring'),
  File::Spec->catfile($instance_dir, 'volumes', 'data', 'upload'),
  File::Spec->catfile($instance_dir, 'volumes', 'db', 'data', 'pgdata'),
  File::Spec->catfile($instance_dir, 'volumes', 'drupal', 'web', 'sites', 'default', 'settings.php'),
  File::Spec->catfile($instance_dir, 'volumes', 'drupal', 'web', 'sites', 'default', 'db_settings.php'),
  File::Spec->catfile($instance_dir, 'volumes', 'proxy', 'nginx', 'genoring'),
  File::Spec->catfile($instance_dir, 'volumes', 'proxy', 'nginx', 'genoring-fpm.conf'),
  File::Spec->catfile($instance_dir, 'volumes', 'proxy', 'nginx', 'includes'),
  File::Spec->catfile($instance_dir, 'volumes', 'www', 'offline.html'),
];
foreach my $file (@$expected_files) {
  ok(-e $file, "Expected file/directory exists: $file");
}

# Make sure Drupal installation went well.
my $db_settings_file = File::Spec->catfile($instance_dir, 'volumes', 'drupal', 'web', 'sites', 'default', 'db_settings.php');
my $db_settings_ok = 0;
open(my $db_settings_fh, '<', $db_settings_file) or die "Unable to open $db_settings_file: $!";
while (my $line = <$db_settings_fh>) {
  if ($line =~ /^(?:\s*\*\/\s*)?\$databases\['default'\]\['default'\] = array \(/) {
    $db_settings_ok = 1;
    last;
  }
}
close($db_settings_fh);
ok($db_settings_ok, "Drupal database settings are present in db_settings.php");

# Cleanups test instance.
SKIP: {
  skip 'Test instance cleaning disabled', 1 if $ENV{'GENORING_TEST_KEEP_INSTANCES'};
  ok(0 == RemoveInstances($instance), 'Instance removed');
}
