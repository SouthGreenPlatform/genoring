#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when a module needs to upgrade itself to its
# latest version.
# It is run from GenoRing base directory.
# It is normally called when all GenoRing dockers are down before any update is
# performed by container update hooks.
# Parameters are: current version string, and new version string.

use strict;
use warnings;
use Cwd qw(abs_path getcwd);
BEGIN {
  $ENV{'GENORING_DIR'} ||= getcwd();
}
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; #no buffering

# Perform the module's upgrade tasks on the local file system.


my ($current_version, $new_version, $module) = @ARGV;

if (!$module) {
  print "INFO: No module specified; skipping framework upgrade hook.\n";
  return 1;
}

if ('genoring' ne $module) {
  print "INFO: No action required for module '$module'.\n";
  return 1;
}

if ('1.0' ne ($current_version || '')) {
  print "INFO: Module '$module' is not on version 1.0; no 1.0->1.1 migration is required for '$current_version'.\n";
  return 1;
}

if ('1.1' ne ($new_version || '')) {
  die "ERROR: Unsupported upgrade path for '$module' from $current_version to $new_version.\n";
}

use File::Spec;

my $genoring_dir = $ENV{'GENORING_DIR'} || getcwd();
my $volumes_dir = $ENV{'GENORING_VOLUMES_DIR'} || File::Spec->catdir($genoring_dir, 'volumes');
my $db_volume_dir = File::Spec->catdir($volumes_dir, 'db');
my $legacy_pgdata_dir = File::Spec->catdir($db_volume_dir, 'pgdata');
my $legacy_backup_dir = File::Spec->catdir($volumes_dir, 'data', 'pgdata.16');
my $new_db_data_dir = File::Spec->catdir($db_volume_dir, 'data');
my $dump_file = File::Spec->catfile($volumes_dir, 'data', 'v16.sql');
my $db_env_file = File::Spec->catfile($genoring_dir, 'env', 'genoring_db.env');

if (-d $legacy_pgdata_dir) {
  Run("mkdir -p " . File::Spec->catdir($volumes_dir, 'data'), "Failed to create database upgrade staging directory.", 1, 1);
  if (-d $legacy_backup_dir) {
    Run("rm -rf '$legacy_backup_dir'", "Failed to remove previous PostgreSQL 16 backup directory.", 1, 1);
  }
  Run("mv '$legacy_pgdata_dir' '$legacy_backup_dir'", "Failed to move PostgreSQL data directory to '$legacy_backup_dir'.", 1, 1);
}

if (!-d $new_db_data_dir) {
  Run("mkdir -p '$new_db_data_dir'", "Failed to create '$new_db_data_dir'.", 1, 1);
}

Run("chown 999 '$db_volume_dir'", "Failed to fix ownership on '$db_volume_dir'.", 1, 1);

Run(
  "$Genoring::DOCKER_COMMAND run --rm --name pg_upgrade_temp --env-file '$db_env_file' -v '$volumes_dir/data:/data' -v '$legacy_backup_dir:/var/lib/postgresql/data/pgdata' -d postgis/postgis:16-3.5",
  "Failed to start PostgreSQL 16 dump container.",
  1,
  1
);
Run(
  "$Genoring::DOCKER_COMMAND exec -t pg_upgrade_temp bash -lc \"pg_dumpall -U postgres > /data/v16.sql\"",
  "Failed to dump PostgreSQL 15 database before migration.",
  1,
  1
);
Run("$Genoring::DOCKER_COMMAND stop pg_upgrade_temp", "Failed to stop temporary PostgreSQL dump container.", 1, 1);
Run("$Genoring::DOCKER_COMMAND rm -f pg_upgrade_temp", "Failed to remove temporary PostgreSQL dump container.", 1, 1);

Run(
  "perl '$genoring_dir/genoring.pl' build genoring genoring-db --no-cache",
  "Failed to rebuild the genoring-db image for the 1.1 migration.",
  1,
  1
);

Run(
  "$Genoring::DOCKER_COMMAND run --rm --name pg_upgrade_temp --env-file '$db_env_file' -v '$volumes_dir/data:/data' -v '$new_db_data_dir:/var/lib/postgresql' -d genoring-db",
  "Failed to start migrated PostgreSQL container for import.",
  1,
  1
);
Run(
  "$Genoring::DOCKER_COMMAND exec -t pg_upgrade_temp bash -lc \"psql -U postgres -f /data/v16.sql\"",
  "Failed to restore PostgreSQL 15 dump into the migrated PostgreSQL 16 database.",
  1,
  1
);
Run("$Genoring::DOCKER_COMMAND stop pg_upgrade_temp", "Failed to stop temporary PostgreSQL import container.", 1, 1);
Run("$Genoring::DOCKER_COMMAND rm -f pg_upgrade_temp", "Failed to remove temporary PostgreSQL import container.", 1, 1);

print "INFO: PostgreSQL data migration from 1.0 to 1.1 completed successfully.\n";

# Returns 1 when called by "require".
1;
