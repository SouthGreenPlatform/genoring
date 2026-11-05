#!/usr/bin/env perl

=pod

=head1 NAME

backup_manifest.t - Tests the backup manifest and version validation.

=head1 DESCRIPTION

Verifies that backup manifests are generated with the expected metadata and that
restore validation checks the current installed versions against the backup.

=cut

use strict;
use warnings;

use Cwd qw(getcwd);
use File::Path qw(make_path remove_tree);
use File::Spec;
use FindBin;
use lib "$FindBin::Bin/../../perllib";
use Genoring;
use Test::More tests => 17;

my $backup_root = File::Spec->catdir($FindBin::Bin, '..', 'temptests', 'backup_manifest_test');
$backup_root = File::Spec->rel2abs($backup_root);
if (-d $backup_root) {
  remove_tree($backup_root);
}
make_path($backup_root);

my $manifest = Genoring::WriteBackupManifest(
  $backup_root,
  'backup_test',
  'genoring-volumes.tar.gz',
  ['genoring-data-volume', 'genoring-db-volume'],
  ['genoring', 'drupal'],
  {
    'source' => 'unit-test',
  }
);

ok('HASH' eq ref($manifest), 'Manifest is returned as a hash reference');
ok($manifest->{'backup_name'} eq 'backup_test', 'Backup name is stored in manifest');
ok($manifest->{'archive'} eq 'genoring-volumes.tar.gz', 'Archive name is stored in manifest');
ok($manifest->{'modules'}->[0] eq 'drupal' || $manifest->{'modules'}->[0] eq 'genoring', 'Active modules are stored');
ok(-f File::Spec->catfile($backup_root, 'manifest.yml'), 'Manifest file is created');

my $loaded = Genoring::ReadBackupManifest($backup_root);
ok($loaded->{'genoring_version'} eq $Genoring::GENORING_VERSION, 'Manifest contains the current GenoRing version');

my $single_module_volumes = Genoring::GetBackupVolumes(['genoring']);
my $repeated_module_volumes = Genoring::GetBackupVolumes(['genoring', 'genoring']);
ok(@$single_module_volumes, 'Volumes are discovered for the selected module');
is(
  Genoring::GetModuleInfo('genoring')->{'volumes'}->{'genoring-volume-db-data'}->{'mapping'},
  'volumes/db/data',
  'PostgreSQL exposed volume maps to the directory used by the database service'
);
ok(!(grep { $_ eq 'genoring-backups-volume' || $_ eq 'backups' } @$single_module_volumes), 'Backup storage volume is excluded');
is_deeply($repeated_module_volumes, $single_module_volumes, 'Module volume sets are deduplicated');

my $mapped_volume_dir = File::Spec->catdir($backup_root, 'volumes');
my $postgres_data_dir = File::Spec->catdir($mapped_volume_dir, 'db', 'data');
make_path($postgres_data_dir);
my @docker_commands;
{
  local $ENV{'GENORING_VOLUMES_DIR'} = $mapped_volume_dir;
  local *Genoring::GetModules = sub { ['genoring'] };
  local *Genoring::GetModuleInfo = sub {
    return {
      'volumes' => {
        'genoring-volume-db-data' => {
          'type' => 'exposed',
          'mapping' => 'volumes/db/data',
        },
      },
    };
  };
  local *Genoring::GetPathVolume = sub { return; };
  local *Genoring::Run = sub {
    push(@docker_commands, $_[0]);
    return '';
  };
  Genoring::CreateVolumeArchive(
    $backup_root,
    'genoring-volumes.tar.gz',
    ['genoring-volume-db-data']
  );
}
ok(
  (grep { index($_, "$postgres_data_dir:/source:ro") >= 0 } @docker_commands) > 0,
  'Exposed PostgreSQL data is copied from its mapped host directory'
);

my $archive_path = File::Spec->catfile($backup_root, 'genoring-volumes.tar.gz');
open(my $archive_fh, '>', $archive_path) or die "Could not create test archive: $!";
close($archive_fh);
@docker_commands = ();
{
  local $ENV{'GENORING_VOLUMES_DIR'} = $mapped_volume_dir;
  local *Genoring::GetModules = sub { ['genoring'] };
  local *Genoring::GetModuleInfo = sub {
    return {
      'volumes' => {
        'genoring-volume-db-data' => {
          'type' => 'exposed',
          'mapping' => 'volumes/db/data',
        },
      },
    };
  };
  local *Genoring::GetPathVolume = sub { return; };
  local *Genoring::Run = sub {
    push(@docker_commands, $_[0]);
    return '';
  };
  Genoring::RestoreVolumeArchive(
    $backup_root,
    'genoring-volumes.tar.gz',
    {'volumes' => ['genoring-volume-db-data']}
  );
}
ok(
  (grep { index($_, "$postgres_data_dir:/dest") >= 0 } @docker_commands) > 0,
  'Exposed PostgreSQL data is restored to its mapped host directory'
);

# Framework backups are stored in the instance "sysbackups" directory, not in
# the "backups" Docker volume shared with containers.
{
  my $instance_dir = File::Spec->catdir($backup_root, 'instance');
  make_path($instance_dir);
  my $original_dir = getcwd();
  chdir($instance_dir) or die "Could not enter test instance directory: $!";
  local $Genoring::VOLUMES_DIR = File::Spec->catdir($instance_dir, 'volumes');
  local $ENV{'GENORING_VOLUMES_DIR'} = $Genoring::VOLUMES_DIR;
  local *Genoring::IsInstalled = sub { return 0; };
  local *Genoring::GetModules = sub { return []; };
  local *Genoring::GetBackupVolumes = sub { return []; };
  local *Genoring::GetProjectName = sub { return 'testbackup'; };
  local *Genoring::CreateVolumeArchive = sub {
    my ($backupdir, $archive_name) = @_;
    my $archive = File::Spec->catfile($backupdir, $archive_name);
    open(my $fh, '>', $archive) or die "Could not create test archive: $!";
    close($fh);
    return $archive;
  };
  # Hide backup progress messages.
  my $output = '';
  {
    open(my $fake_stdout, '>', \$output) or die "Could not redirect output: $!";
    local *STDOUT = *$fake_stdout;
    Genoring::Backup('sysbackup_test', undef, 1);
  }
  my $backupdir = File::Spec->catdir($instance_dir, $Genoring::SYSBACKUPS_DIR, 'sysbackup_test');
  ok(-f File::Spec->catfile($backupdir, 'manifest.yml'), 'Framework backup is stored in the sysbackups directory');
  ok(-f File::Spec->catfile($backupdir, 'genoring-volumes.tar.gz'), 'Framework backup archive is stored in the sysbackups directory');
  ok(!-e File::Spec->catdir($Genoring::VOLUMES_DIR, 'backups'), 'Framework backup is not stored in the containers backups volume');

  # Restore looks for backups in the sysbackups directory.
  local *Genoring::ValidateBackupManifest = sub { die "RESTORE REACHED\n"; };
  {
    open(my $fake_stdout, '>', \$output) or die "Could not redirect output: $!";
    local *STDOUT = *$fake_stdout;
    eval { Genoring::Restore('sysbackup_test'); };
    like($@, qr/RESTORE REACHED/, 'Restore finds the backup in the sysbackups directory');
    eval { Genoring::Restore('missing_backup'); };
    like($@, qr/Backup 'missing_backup' does not exist/, 'Restore rejects a backup missing from the sysbackups directory');
  }
  chdir($original_dir);
}

remove_tree($backup_root);
