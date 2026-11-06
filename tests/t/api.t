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
use File::Copy;
use File::Path qw(make_path remove_tree);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin;
use Getopt::Long qw(GetOptions);
use IO::Select;
use IPC::Open3 qw(open3);
use lib "$FindBin::Bin/../../perllib";
use Genoring;
use Genoring::GenoringTest;
use Test::More tests => 83;
++$|; #no buffering
use Data::Dumper; #+debug

# Enter test directory.
ok(chdir($Genoring::GenoringTest::TEST_DIR), "Enter test directory");

# Create test instance directory.
my $instance = GetNewInstance();
ok($instance, "New instance directory created");
$ENV{'COMPOSE_PROJECT_NAME'} = $instance;

# Create a default config file for testing.
my $instance_dir = abs_path(File::Spec->catdir($Genoring::GenoringTest::TEMP_TEST_DIR, $instance));
ok(chdir($instance_dir), "Enter instance test directory");

# Copy test default environment directory to instance directory.
my $default_env_dir = File::Spec->catdir($Genoring::GenoringTest::TEST_DIR, 'data', 'default_env');
my $instance_env_dir = File::Spec->catdir($instance_dir, 'env');
ok(CopyDirectory($default_env_dir, $instance_env_dir), 'Env directory copied');
ok(-d $instance_env_dir, 'Instance env directory exists');
ok(-f File::Spec->catdir($instance_env_dir, 'genoring_db.env'), 'GenoRing DB env file copied');
ok(-f File::Spec->catdir($instance_env_dir, 'genoring_genoring.env'), 'GenoRing env file copied');
ok(-f File::Spec->catdir($instance_env_dir, 'genoring_httpd.env'), 'GenoRing HTTPd env file copied');
ok(-f File::Spec->catdir($instance_env_dir, 'genoring_nginx.env'), 'GenoRing Nginx env file copied');

# Create a fake installation.
ok(!IsInstalled(), 'No installed');
# CopyFiles()
my $default_config_yml = File::Spec->catdir($Genoring::GenoringTest::TEST_DIR, 'data', 'default_config.yml');
my $instance_config_yml = File::Spec->catdir($instance_dir, 'config.yml');
CopyFiles($default_config_yml, $instance_config_yml);
ok(-f $instance_config_yml, 'Config file created');
my $default_docker_compose_yml = File::Spec->catdir($Genoring::GenoringTest::TEST_DIR, 'data', 'default_docker-compose.yml');
my $instance_docker_compose_yml = File::Spec->catdir($instance_dir, 'docker-compose.yml');
CopyFiles($default_docker_compose_yml, $instance_docker_compose_yml);
ok(-f $instance_docker_compose_yml, 'Docker compose file created');
ok(IsInstalled(), 'Installed');

# CopyFiles() into GenoRing volumes (exposed or not).
subtest 'CopyFiles() copies files to volumes or host' => sub {
  plan tests => 21;
  my $copy_dir = tempdir(CLEANUP => 1);
  my $source = File::Spec->catfile($copy_dir, 'source.txt');
  open(my $source_fh, '>', $source) or die "ERROR: Unable to create test source file: $!";
  print {$source_fh} "test\n";
  close($source_fh);
  my $volumes_dir = File::Spec->catdir($copy_dir, 'volumes');
  make_path(File::Spec->catdir($volumes_dir, 'sub'));
  my $outside_dir = File::Spec->catdir($copy_dir, 'outside');
  make_path($outside_dir);

  # Mock config, volume detection and Docker commands.
  local $Genoring::VOLUMES_DIR = $volumes_dir;
  my $no_exposed_volumes = 1;
  my @path_volume = ();
  my @run_commands;
  my @warnings;
  local *Genoring::GetConfig = sub { return {'no_exposed_volumes' => $no_exposed_volumes}; };
  local *Genoring::GetPathVolume = sub { return @path_volume; };
  local *Genoring::Run = sub { push(@run_commands, $_[0]); return ''; };
  local $SIG{__WARN__} = sub { push(@warnings, $_[0]); };
  my $reset = sub { @run_commands = (); @warnings = (); };

  # Non-exposed volumes, volume found: copied into the Docker volume.
  @path_volume = ('test-volume', '/sub');
  foreach my $files (['single', [$source, "$volumes_dir/sub/volume_single.txt"]], ['hash', [{$source => "$volumes_dir/sub/volume_hash.txt"}]]) {
    my ($type, $args) = @$files;
    $reset->();
    CopyFiles(@$args);
    is(scalar(@run_commands), 1, "Volume copy ($type): Docker copy command run");
    like($run_commands[0] || '', qr/-v test-volume:\/volume .*cp -rfT \/source \/volume\/sub/, "Volume copy ($type): copied into the volume");
    is(scalar(@warnings), 0, "Volume copy ($type): no warning");
  }
  ok(!-e "$volumes_dir/sub/volume_single.txt" && !-e "$volumes_dir/sub/volume_hash.txt", 'Volume copy: nothing copied on host');

  # Non-exposed volumes, no volume but valid host directory: copied to host
  # with a warning.
  @path_volume = ();
  foreach my $files (['single', [$source, "$volumes_dir/sub/host_single.txt"], "$volumes_dir/sub/host_single.txt"], ['hash', [{$source => "$volumes_dir/sub/host_hash.txt"}], "$volumes_dir/sub/host_hash.txt"]) {
    my ($type, $args, $target) = @$files;
    $reset->();
    CopyFiles(@$args);
    ok(-f $target, "No volume ($type): copied to host directory");
    is(scalar(@run_commands), 0, "No volume ($type): no Docker command");
    ok((1 == @warnings) && ($warnings[0] =~ m/copied to the corresponding host directory.*unexpected behaviors/s), "No volume ($type): fallback warning issued");
  }

  # Non-exposed volumes, no volume and missing host directory: not copied.
  $reset->();
  CopyFiles({$source => "$volumes_dir/missing/no_target.txt"});
  ok(!-e "$volumes_dir/missing/no_target.txt", 'No volume nor host directory: not copied');
  ok((1 == @warnings) && ($warnings[0] =~ m/Cannot copy file .* nor to host directory/), 'No volume nor host directory: warning issued');

  # Non-exposed volumes but target outside "volumes": regular copy (both
  # syntaxes).
  $reset->();
  CopyFiles($source, "$outside_dir/outside_single.txt");
  CopyFiles({$source => "$outside_dir/outside_hash.txt"});
  ok(-f "$outside_dir/outside_single.txt" && -f "$outside_dir/outside_hash.txt", 'Target outside volumes: copied to host');
  ok(!@run_commands && !@warnings, 'Target outside volumes: no Docker command nor warning');

  # Exposed volumes: regular copy.
  $no_exposed_volumes = 0;
  @path_volume = ('test-volume', '/sub');
  $reset->();
  CopyFiles($source, "$volumes_dir/sub/exposed.txt");
  ok(-f "$volumes_dir/sub/exposed.txt", 'Exposed volumes: copied to host');
  ok(!@run_commands && !@warnings, 'Exposed volumes: no Docker command nor warning');

  # Existing target is only replaced when requested.
  my $existing = "$volumes_dir/sub/exposed.txt";
  open(my $existing_fh, '>', $existing) or die "ERROR: Unable to update test target file: $!";
  print {$existing_fh} "old\n";
  close($existing_fh);
  CopyFiles($source, $existing);
  is(-s $existing, 4, 'Existing target kept');
  CopyFiles($source, $existing, undef, undef, 1);
  is(-s $existing, 5, 'Existing target replaced when requested');
};

# ExpandYamlArrays()
is_deeply(
  Genoring::ExpandYamlArrays(
    {
      'testarray' => [
        'value1',
        'value2',
        '["value3","value4","val,ue5","value6"]',
      ],
    }
  ),
  {
    'testarray' => [
      'value1',
      'value2',
      [
        'value3',
        'value4',
        'val,ue5',
        'value6',
      ],
    ],
  },
  'Expanded YAML structure matches expected structure'
);

# ReadYaml()
my $docker_compose_yml = Genoring::ReadYaml($instance_docker_compose_yml);
is_deeply(
  $docker_compose_yml,
  [
    {
      'volumes' => {
        'genoring-backups-volume' => {
          'driver' => 'local',
            'driver_opts' => {
              'device' => '${GENORING_VOLUMES_DIR}/backups',
              'o' => 'bind',
              'type' => 'none',
            },
          'name' => 'testxxxxxxxx-backups-volume',
        },
      'genoring-drupal-volume' => {
        'name' => 'testxxxxxxxx-drupal-volume',
        'driver_opts' => {
          'device' => '${GENORING_VOLUMES_DIR}/drupal',
          'type' => 'none',
          'o' => 'bind',
        },
        'driver' => 'local',
      },
      'genoring-www-volume' => {
        'driver' => 'local',
        'name' => 'testxxxxxxxx-www-volume',
        'driver_opts' => {
          'device' => '${GENORING_VOLUMES_DIR}/www',
          'type' => 'none',
          'o' => 'bind',
        }
      },
      'genoring-data-volume' => {
        'driver' => 'local',
        'driver_opts' => {
          'o' => 'bind',
          'type' => 'none',
          'device' => '${GENORING_VOLUMES_DIR}/data',
        },
        'name' => 'testxxxxxxxx-data-volume',
      }
    },
    'services' => {
      'genoring' => {
        'volumes' => [
          '/home/vguignon/dev/git:/opt/drupal/git',
          'genoring-drupal-volume:/opt/drupal',
          'genoring-data-volume:/data',
          'genoring-backups-volume:/backups',
          'genoring-www-volume:/var/www/html2',
        ],
        'depends_on' => {
          'genoring-db' => {
            'condition' => 'service_started',
          },
        },
        'image' => 'genoring',
        'build' => '${GENORING_DIR}/modules/genoring/src/genoring',
        'container_name' => 'testxxxxxxxx',
        'restart' => 'unless-stopped',
        'healthcheck' => {
          'test' => [
            'CMD-SHELL',
            'test -f /opt/drupal/web/index.php || test -f /tmp/disable-healthcheck',
          ],
        },
        'pull_policy' => 'never',
        'profiles' => [
          'prod',
          'staging',
          'dev',
          'backend',
          'offline',
        ],
        'env_file' => [
          '${PWD}/env/genoring_genoring.env',
          '${PWD}/env/genoring_db.env',
          '${PWD}/env/genoring_nginx.env',
        ],
      },
      'genoring-proxy' => {
        'ports' => [
          '${GENORING_PORT}:80',
        ],
        'profiles' => [
          'prod',
          'staging',
          'dev',
          'backend',
          'offline',
        ],
        'env_file' => [
          '${PWD}/env/genoring_nginx.env',
          '${PWD}/env/genoring_genoring.env'
        ],
        'depends_on' => {
          'genoring' => {
            'condition' => 'service_started',
          },
        },
        'volumes' => [
          '/home/vguignon/dev/git:/opt/drupal/git',
          {
            'target' => '/etc/nginx/templates/default.conf.template',
            'type' => 'bind',
            'source' => '${GENORING_VOLUMES_DIR}/proxy/nginx/genoring-fpm.conf'
          },
          '${GENORING_VOLUMES_DIR}/proxy/nginx/includes:/etc/nginx/includes',
          '${GENORING_VOLUMES_DIR}/proxy/nginx/genoring:/etc/nginx/genoring',
          'genoring-drupal-volume:/opt/drupal',
          'genoring-www-volume:/usr/share/www',
          'genoring-data-volume:/data',
        ],
        'image' => 'nginx',
        'restart' => 'always',
        'container_name' => 'testxxxxxxxx-proxy',
      },
      'genoring-db' => {
        'image' => 'genoring-db',
        'volumes' => [
          '${GENORING_VOLUMES_DIR}/db/data:/var/lib/postgresql/data',
          'genoring-data-volume:/data',
        ],
        'pull_policy' => 'never',
        'env_file' => [
          '${PWD}/env/genoring_db.env',
        ],
        'build' => '${GENORING_DIR}/modules/genoring/src/genoring-db',
        'container_name' => 'testxxxxxxxx-db',
        'restart' => 'always',
        },
      },
    },
  ],
  'Parsed YAML file matches expected structure'
);
# Adjust instance name where needed.
$docker_compose_yml->[0]->{'volumes'}->{'genoring-backups-volume'}->{'name'} = $instance . '-backups-volume';
$docker_compose_yml->[0]->{'volumes'}->{'genoring-drupal-volume'}->{'name'} = $instance . '-drupal-volume';
$docker_compose_yml->[0]->{'volumes'}->{'genoring-www-volume'}->{'name'} = $instance . '-www-volume';
$docker_compose_yml->[0]->{'volumes'}->{'genoring-data-volume'}->{'name'} = $instance . '-data-volume';
$docker_compose_yml->[0]->{'services'}->{'genoring'}->{'container_name'} = $instance;
$docker_compose_yml->[0]->{'services'}->{'genoring-proxy'}->{'container_name'} = $instance . '-proxy';
$docker_compose_yml->[0]->{'services'}->{'genoring-db'}->{'container_name'} = $instance . '-db';

# WriteYaml()
my $HEADER = "# This is a test docker-compose.yml file generated by GenoRing for testing purposes.\n";
Genoring::WriteYaml($instance_docker_compose_yml, $docker_compose_yml->[0], $HEADER);
# Test new YAML file content.
is_deeply(
  Genoring::ReadYaml($instance_docker_compose_yml),
  $docker_compose_yml,
  'Written YAML file matches expected structure'
);
# Check if YAML header is present in the written file.
my $yaml_header_found = 0;
open(my $fh, '<', $instance_docker_compose_yml) or die "Could not open file '$instance_docker_compose_yml' $!";
while (my $line = <$fh>) {
  if ($line =~ /^$HEADER/) {
    $yaml_header_found = 1;
    last;
  }
}
close($fh);
ok($yaml_header_found, 'YAML header found in the written file');

my $config = GetConfig();
my $expected_config = {
  'volume_mapping' => {
    'genoring-www-volume' => '${GENORING_VOLUMES_DIR}/www',
    'genoring-data-volume' => '${GENORING_VOLUMES_DIR}/data',
    'genoring-drupal-volume' => '${GENORING_VOLUMES_DIR}/drupal',
    'genoring-backups-volume' => '${GENORING_VOLUMES_DIR}/backups',
  },
  'project' => 'testxxxxxxxx',
  'no_exposed_volumes' => '',
  'modules' => {
    'genoring' => {
      'version' => '1.1',
      'status' => 'enabled',
    },
  },
  'version' => '1.0-alpha8',
};
is_deeply(
  $config,
  $expected_config,
  'Default config matches expected config'
);

# Stored override images replace source images in the generated Compose file.
{
  ClearInternalCache('services');
  $config->{'service_overrides'} = {
    'genoring' => {'image' => 'genoring-test-override'},
  };
  local *Genoring::ClearInternalCache = sub {};
  local *Genoring::SaveConfig = sub {};
  local *Genoring::Run = sub { return ''; };
  GenerateDockerComposeFile();
  my $overridden_compose = Genoring::ReadYaml($instance_docker_compose_yml)->[0];
  is(
    $overridden_compose->{'services'}->{'genoring'}->{'image'},
    'genoring-test-override',
    'Compose uses the effective image recorded for an override'
  );
  is(
    $overridden_compose->{'services'}->{'genoring'}->{'pull_policy'},
    'never',
    'Compose does not pull the generated local override image'
  );
  ok(
    !exists($overridden_compose->{'services'}->{'genoring'}->{'build'}),
    'Compose does not rebuild the unoverridden source image'
  );
  delete($config->{'service_overrides'});
  GenerateDockerComposeFile();
}

# SaveConfig() && ClearInternalCache()
$config->{'modules'}->{'genoring'}->{'services'} = {
  'genoring' => {'status' => 'enabled'},
  'genoring-proxy.merge' => {'status' => 'enabled'},
  'genoring-proxy.override' => {'status' => 'disabled'},
};
SaveConfig();
is_deeply(
  Genoring::ReadYaml($instance_config_yml)->[0]->{'modules'}->{'genoring'}->{'services'},
  {'genoring' => {'status' => 'enabled'}},
  'Config save removes merge and override files mistakenly stored as services'
);
delete($config->{'modules'}->{'genoring'}->{'services'});
SaveConfig();
$config->{'project'} = $instance;
SaveConfig();
$config->{'project'} = 'xyz';
ClearInternalCache();
$config = GetConfig();
is($config->{'project'}, $instance, 'Config saved');
$expected_config->{'project'} = $instance;

# ClearModuleCaches() uses the shared operation lifecycle without a backup.
my @cache_operation_calls;
{
  local *Genoring::PrepareOperations = sub {
    my ($skip_backup) = @_;
    push(@cache_operation_calls, ['prepare', $skip_backup]);
    return {};
  };
  local *Genoring::PerformLocalOperations = sub {
    my ($context) = @_;
    push(@cache_operation_calls, ['local', $context->{'local_hooks'}]);
  };
  local *Genoring::PerformContainerOperations = sub {
    my ($context) = @_;
    push(@cache_operation_calls, ['container', $context->{'container_hooks'}]);
  };
  local *Genoring::CleanupOperations = sub { push(@cache_operation_calls, ['cleanup']); };
  local *Genoring::EndOperations = sub { push(@cache_operation_calls, ['end']); };

  ClearModuleCaches();
}
is_deeply(
  \@cache_operation_calls,
  [
    ['prepare', 1],
    ['local', {'clearcache' => {}}],
    ['container', {'clearcache' => {}}],
    ['cleanup'],
    ['end'],
  ],
  'Module cache clearing uses the standard operation lifecycle'
);

# Alternative service lists use service names (not hash keys or indexes).
{
  local *Genoring::GetModuleAlternatives = sub {
    return {
      listed => {
        'add' => ['genoring-proxy-httpd'],
        'remove' => ['genoring-db'],
      },
      substituted => {
        'substitute' => {
          'genoring-proxy' => 'genoring-proxy-httpd',
        },
      },
      legacy_substituted => {
        'substitue' => {
          'genoring-proxy' => 'genoring-proxy-httpd',
        },
      },
    };
  };
  is_deeply(
    GetModuleServices('genoring', undef, 'listed'),
    ['genoring', 'genoring-proxy', 'genoring-proxy-httpd'],
    'Alternative add/remove lists are applied to the service set'
  );
  is_deeply(
    GetModuleServices('genoring', undef, 'substituted'),
    ['genoring', 'genoring-db', 'genoring-proxy-httpd'],
    'Documented substitute key replaces the default service'
  );
  is_deeply(
    GetModuleServices('genoring', undef, 'legacy_substituted'),
    ['genoring', 'genoring-db', 'genoring-proxy-httpd'],
    'Legacy substitue key remains supported'
  );
}

# Enabling and disabling alternatives updates config and Compose and runs only
# the standard service hooks for the services being replaced.
my @alternative_calls;
{
  local *Genoring::PrepareOperations = sub {
    push(@alternative_calls, ['prepare']);
    return {'operation_mode' => 'backend'};
  };
  local *Genoring::StartGenoring = sub {
    push(@alternative_calls, ['start', $_[0]]);
  };
  local *Genoring::ApplyContainerHooks = sub {
    my ($hook, $module, $related, $args, $services) = @_;
    push(@alternative_calls, ['hook', $hook, $module, $related, [@$services]]);
    return {};
  };
  local *Genoring::CleanupOperations = sub {
    push(@alternative_calls, ['cleanup', $_[0]->{'failed'} || '']);
  };
  local *Genoring::EndOperations = sub {
    push(@alternative_calls, ['end']);
  };

  EnableAlternative('genoring', 'httpd');
  my $alternative_config = Genoring::ReadYaml($instance_config_yml)->[0];
  is(
    $alternative_config->{'modules'}->{'genoring'}->{'alternative'},
    'httpd',
    'Alternative selection is stored in config.yml'
  );
  is(
    $alternative_config->{'modules'}->{'genoring'}->{'status'},
    'enabled',
    'Changing an alternative keeps its owning module enabled'
  );
  my $alternative_compose = Genoring::ReadYaml($instance_docker_compose_yml)->[0];
  is_deeply(
    [sort keys(%{$alternative_compose->{'services'}})],
    ['genoring', 'genoring-db', 'genoring-proxy-httpd'],
    'Alternative service replaces the default service in docker-compose.yml'
  );
  is_deeply(
    [grep { $_->[0] eq 'hook' } @alternative_calls],
    [
      ['hook', 'disable', 'genoring', 1, ['genoring-proxy']],
      ['hook', 'enable', 'genoring', 1, ['genoring-proxy-httpd']],
    ],
    'Alternative activation runs standard hooks for the replaced services'
  );
  is_deeply(
    [grep { $_->[0] eq 'prepare' || $_->[0] eq 'cleanup' || $_->[0] eq 'end' } @alternative_calls],
    [['prepare'], ['cleanup', ''], ['end']],
    'Alternative activation uses the operation lifecycle'
  );

  @alternative_calls = ();
  DisableAlternative('genoring', 'httpd');
  ok(
    !exists(Genoring::ReadYaml($instance_config_yml)->[0]->{'modules'}->{'genoring'}->{'alternative'}),
    'Disabling the alternative removes its config selection'
  );
  my $default_compose = Genoring::ReadYaml($instance_docker_compose_yml)->[0];
  is_deeply(
    [sort keys(%{$default_compose->{'services'}})],
    ['genoring', 'genoring-db', 'genoring-proxy'],
    'Disabling the alternative restores the default service in docker-compose.yml'
  );
  is_deeply(
    [grep { $_->[0] eq 'hook' } @alternative_calls],
    [
      ['hook', 'disable', 'genoring', 1, ['genoring-proxy-httpd']],
      ['hook', 'enable', 'genoring', 1, ['genoring-proxy']],
    ],
    'Alternative removal runs standard hooks to restore the default service'
  );
  is_deeply(
    [grep { $_->[0] eq 'prepare' || $_->[0] eq 'cleanup' || $_->[0] eq 'end' } @alternative_calls],
    [['prepare'], ['cleanup', ''], ['end']],
    'Alternative removal uses the operation lifecycle'
  );
}

# A service-hook failure restores the previous config and generated services.
{
  my @rollback_calls;
  my $enable_failed = 0;
  local *Genoring::PrepareOperations = sub {
    push(@rollback_calls, ['prepare']);
    return {'operation_mode' => 'backend'};
  };
  local *Genoring::StartGenoring = sub {
    push(@rollback_calls, ['start', $_[0]]);
  };
  local *Genoring::ApplyContainerHooks = sub {
    my ($hook, $module, $related, $args, $services) = @_;
    push(@rollback_calls, ['hook', $hook, [@$services]]);
    if (('enable' eq $hook) && !$enable_failed++) {
      return {'enable_genoring-proxy-httpd.sh' => 'forced test failure'};
    }
    return {};
  };
  local *Genoring::CleanupOperations = sub {
    push(@rollback_calls, ['cleanup', $_[0]->{'failed'} || '']);
  };
  local *Genoring::EndOperations = sub {
    push(@rollback_calls, ['end']);
  };

  my $error;
  eval { EnableAlternative('genoring', 'httpd'); };
  $error = $@;
  like($error, qr/Failed to change alternative.*forced test failure/s, 'Alternative hook failure is reported');
  ok(
    !exists(Genoring::ReadYaml($instance_config_yml)->[0]->{'modules'}->{'genoring'}->{'alternative'}),
    'Alternative hook failure restores the previous config.yml selection'
  );
  my $rolled_back_compose = Genoring::ReadYaml($instance_docker_compose_yml)->[0];
  is_deeply(
    [sort keys(%{$rolled_back_compose->{'services'}})],
    ['genoring', 'genoring-db', 'genoring-proxy'],
    'Alternative hook failure restores default docker-compose.yml services'
  );
  is_deeply(
    [grep { $_->[0] eq 'hook' } @rollback_calls],
    [
      ['hook', 'disable', ['genoring-proxy']],
      ['hook', 'enable', ['genoring-proxy-httpd']],
      ['hook', 'disable', ['genoring-proxy-httpd']],
      ['hook', 'enable', ['genoring-proxy']],
    ],
    'Alternative rollback reverses service hooks in both directions'
  );
  ok(
    (grep { $_->[0] eq 'cleanup' && $_->[1] =~ /forced test failure/ } @rollback_calls),
    'Alternative failure enters standard backup restoration cleanup'
  );
}

# GetModulesConfig()
is_deeply(
  GetModulesConfig(),
  {
    'genoring' => {
      'version' => '1.1',
      'status' => 'enabled'
    }
  },
  'Module config matches expected config'
);

# GetModules (only core modules)
my %modules = map {$_ => 1;} @{GetModules()};
ok(exists($modules{'brapimapper'}), 'Module brapimapper exists');
ok(exists($modules{'cas_server'}), 'Module cas_server exists');
ok(exists($modules{'genoring'}), 'Module genoring exists');
ok(exists($modules{'genoringtools'}), 'Module genoringtools exists');
ok(exists($modules{'gigwa'}), 'Module gigwa exists');
ok(exists($modules{'jbrowse'}), 'Module jbrowse exists');
ok(exists($modules{'mongodb42'}), 'Module mongodb42 exists');
ok(exists($modules{'ssl'}), 'Module ssl exists');

# GetServices()
is_deeply(
  GetServices(),
  {
    'genoring' => 'genoring',
    'genoring-db' => 'genoring',
    'genoring-proxy' => 'genoring'
  },
  'Services match expected services'
);

# GetContainerName
is_deeply(
  GetContainerName('genoring-proxy'),
  $instance . '-proxy',
  'Container name matches expected container name'
);

# GetVolumeName
is_deeply(
  GetContainerName('genoring-backups-volume'),
  $instance . '-backups-volume',
  'Volume name matches expected volume name'
);

# GetModuleServices
is_deeply(
  GetModuleServices('genoring'),
  [
    'genoring',
    'genoring-db',
    'genoring-proxy',
  ],
  'Genoring default services match expected services'
);
is_deeply(
  GetModuleServices('genoring', 'enabled'),
  [
    'genoring',
    'genoring-db',
    'genoring-proxy',
  ],
  'Genoring enabled services match expected services'
);
is_deeply(
  GetModuleServices('genoring', 'all'),
  [
    'genoring',
    'genoring-db',
    'genoring-proxy',
    'genoring-proxy-httpd',
  ],
  'Genoring all services match expected services'
);
is_deeply(
  GetModuleServices('genoring', 'alt'),
  [
    'genoring-proxy-httpd',
  ],
  'Genoring alternative services match expected services'
);
is_deeply(
  GetModuleServices('genoring', 'disabled'),
  [
  ],
  'Genoring disabled services match no services'
);
is_deeply(
  GetModuleServices('genoring', 'xxx'),
  [
  ],
  'Genoring unexpected service type match no services'

);

{
  my $module_root = tempdir(CLEANUP => 1);
  my $services_dir = File::Spec->catdir($module_root, 'service-filter-test', 'services');
  make_path($services_dir);
  foreach my $service_file (
    qw(external-service.yml external-service.merge.yml external-service.override.yml
      disabled-service.yml disabled-service.merge.yml disabled-service.override.yml)
  ) {
    open(my $service_fh, '>', File::Spec->catfile($services_dir, $service_file))
      or die "Unable to create test service file '$service_file': $!";
    close($service_fh);
  }
  local $Genoring::MODULES_DIR = $module_root;
  local *Genoring::GetModuleConf = sub {
    return {
      'external_services' => {'external-service' => '127.0.0.1'},
      'services' => {
        'disabled-service' => {'status' => 'disabled'},
        'disabled-service.merge' => {'status' => 'disabled'},
        'external-service.override' => {'status' => 'disabled'},
      },
    };
  };
  is_deeply(
    GetModuleServices('service-filter-test'),
    [],
    'External and disabled services do not expose their merge or override files as services'
  );
  is_deeply(
    GetModuleServices('service-filter-test', 'all'),
    ['disabled-service', 'external-service'],
    'Service listing includes disabled and external services without merge or override entries'
  );
}

# GetModuleAlternatives()
is_deeply(
  GetModuleAlternatives('genoring'),
  {
    'httpd' => {
      'description' => 'Replaces NGINX server with Apache 2 HTTPd (genoring-proxy-httpd service).',
      'substitute' => {
        'genoring-proxy' => 'genoring-proxy-httpd',
      },
    },
  },
  'Genoring alternative service details match expected service details'
);

# GetModuleInfo()
is_deeply(
  GetModuleInfo('gigwa'),
  {
    'volumes' => {
      'genoring-volume-gigwa-config' => {
        'description' => 'Contains Gigwa Tomcat config files.',
        'type' => 'exposed',
        'mapping' => 'volumes/gigwa/config',
        'name' => 'Gigwa config files',
      },
    },
    'dependencies' => {
      'services' => [
        'REQUIRES genoring genoring-proxy OR genoring genoring-proxy-httpd',
        'genoring-gigwa BEFORE genoring genoring-proxy OR genoring genoring-proxy-httpd',
        'REQUIRES mongodb42 genoring-mongodb42',
        'genoring-gigwa AFTER mongodb42 genoring-mongodb42',
      ],
      'volumes' => [
        'REQUIRES genoring genoring-data-volume',
        'REQUIRES genoring genoring-backups-volume',
      ],
    },
    'tags' => [
      'gigwa',
      'mongodb',
      'genotype',
      'genotyping',
      'visualization',
      'vcf',
      'brapi',
      'ga4gh',
    ],
    'version' => '1.0',
    'name' => 'Gigwa',
    'genoring_script_version' => '1.0-alpha8',
    'description' => 'A tool to explore large amounts of genotyping data by filtering it.',
    'services' => {
      'genoring-gigwa' => {
        'description' => 'The Gigwa web application part.',
        'name' => 'Gigwa Tomcat',
        'version' => '1.0',
      },
    },
  },
  'Gigwa module info matches expected module info',
);

# GetVolumes()
is_deeply(
  GetVolumes(),
  {
    'genoring-volume-proxy-nginx-genoring' => [
      'genoring',
    ],
    'genoring-volume-proxy-httpd-genoring' => [
      'genoring',
    ],
    'genoring-volume-proxy-httpd-includes' => [
      'genoring',
    ],
    'genoring-volume-www' => [
      'genoring',
    ],
    'genoring-drupal-volume' => [
      'genoring',
    ],
    'genoring-volume-proxy-nginx-includes' => [
      'genoring',
    ],
    'genoring-data-volume' => [
      'genoring',
    ],
    'genoring-volume-db-data' => [
      'genoring',
    ],
    'genoring-backups-volume' => [
      'genoring',
    ],
  },
  'Got default volumes'
);

# GetModuleVolumes()
is_deeply(
  GetModuleVolumes('genoring'),
  [
    'genoring-backups-volume',
    'genoring-data-volume',
    'genoring-drupal-volume',
    'genoring-www-volume'
  ],
  'Genoring volumes'
);
is_deeply(
  GetModuleVolumes('genoring', 'defined'),
  [
    'genoring-backups-volume',
    'genoring-data-volume',
    'genoring-drupal-volume',
    'genoring-www-volume',
  ],
  'Genoring volumes (defined)'
);
is_deeply(
  GetModuleVolumes('genoring', 'shared'),
  [
    'genoring-backups-volume',
    'genoring-data-volume',
    'genoring-drupal-volume',
    'genoring-volume-www',
  ],
  'Genoring volumes (shared)'
);
is_deeply(
  GetModuleVolumes('genoring', 'exposed'),
  [
    'genoring-volume-db-data',
    'genoring-volume-proxy-httpd-genoring',
    'genoring-volume-proxy-httpd-includes',
    'genoring-volume-proxy-nginx-genoring',
    'genoring-volume-proxy-nginx-includes',
  ],
  'Genoring volumes (exposed)'
);
is_deeply(
  GetModuleVolumes('genoring', 'used'),
  [],
  'Genoring volumes (used)'
);
is_deeply(
  GetModuleVolumes('genoring', 'all'),
  [
    'genoring-backups-volume',
    'genoring-data-volume',
    'genoring-drupal-volume',
    'genoring-volume-db-data',
    'genoring-volume-proxy-httpd-genoring',
    'genoring-volume-proxy-httpd-includes',
    'genoring-volume-proxy-nginx-genoring',
    'genoring-volume-proxy-nginx-includes',
    'genoring-volume-www',
  ],
  'Genoring volumes (all)'
);

# GetEnvVariable()
is(
  GetEnvVariable(File::Spec->catdir($instance_env_dir, 'genoring_genoring.env'), 'GENORING_HOST'),
  'test',
  'Got GenoRing host environment variable'
);

# SetEnvVariable()
SetEnvVariable(File::Spec->catdir($instance_env_dir, 'genoring_genoring.env'), 'GENORING_HOST', $instance);
is(
  GetEnvVariable(File::Spec->catdir($instance_env_dir, 'genoring_genoring.env'), 'GENORING_HOST'),
  $instance,
  'Got GenoRing host environment variable'
);

# GetEnvironmentFiles
is_deeply(
  [GetEnvironmentFiles('genoring')],
  [
    './env/genoring_nginx.env',
    './env/genoring_genoring.env',
    './env/genoring_db.env',
    './env/genoring_httpd.env',
  ],
  'Environment files listed'
);

# RemoveDependencyFiles
# RemoveEnvFiles

# GetProjectName()
is(GetProjectName(), $instance, 'Got project name');

# GetProfile()
is(GetProfile(), 'dev', 'Got profile');

# CompareVersions()
{
  # Versions in strictly increasing order. Qualifier order is:
  # alpha < beta < RC < (none) < dev.
  my @ordered_versions = (
    '0.9',
    '1.0-alpha',
    '1.0-alpha1',
    '1.0-alpha2',
    '1.0-alpha10',
    '1.0-beta',
    '1.0-beta3',
    '1.0-RC',
    '1.0-RC1',
    '1.0-RC2',
    '1.0',
    '1.0-dev',
    '1.1-alpha1',
    '1.1',
    '1.2',
    '1.9',
    '1.10',
    '2.0-alpha1',
    '2.0',
    '9.0',
    '10.0',
  );
  subtest 'CompareVersions() orders versions' => sub {
    plan tests => scalar(@ordered_versions) ** 2;
    foreach my $i (0..$#ordered_versions) {
      foreach my $j (0..$#ordered_versions) {
        my ($version_a, $version_b) = ($ordered_versions[$i], $ordered_versions[$j]);
        if ($i < $j) {
          cmp_ok(CompareVersions($version_a, $version_b), '<', 0, "$version_a < $version_b");
        }
        elsif ($i > $j) {
          cmp_ok(CompareVersions($version_a, $version_b), '>', 0, "$version_a > $version_b");
        }
        else {
          cmp_ok(CompareVersions($version_a, $version_b), '==', 0, "$version_a == $version_a");
        }
      }
    }
  };

  # Different syntaxes of the same version (missing qualifier version is 0).
  my @equal_versions = (
    ['1.0-alpha', '1.0-alpha0'],
    ['1.0-beta', '1.0-beta0'],
    ['1.0-RC', '1.0-RC0'],
    ['1.0-dev', '1.0-dev0'],
  );
  subtest 'CompareVersions() equal versions' => sub {
    plan tests => 2 * scalar(@equal_versions);
    foreach my $versions (@equal_versions) {
      my ($version_a, $version_b) = @$versions;
      cmp_ok(CompareVersions($version_a, $version_b), '==', 0, "$version_a == $version_b");
      cmp_ok(CompareVersions($version_b, $version_a), '==', 0, "$version_b == $version_a");
    }
  };
}

# ParseVersion()
{
  my %valid_versions = (
    '1.0'         => [1, 0, '', 0],
    '0.9'         => [0, 9, '', 0],
    '1.10'        => [1, 10, '', 0],
    '1.0-alpha'   => [1, 0, 'alpha', 0],
    '1.0-alpha10' => [1, 0, 'alpha', 10],
    '2.3-beta1'   => [2, 3, 'beta', 1],
    '5.12-RC'     => [5, 12, 'RC', 0],
    '3.4-dev2'    => [3, 4, 'dev', 2],
  );
  my @invalid_versions = (
    undef, '', 'unknown', '1', '1.', '.1', '1.0.0', '1.0.0-alpha6', 'v1.0',
    '1.0-rc1', '1.0-gamma', '1.0-alpha-1', '1.0 ', ' 1.0', '1.0-',
  );
  subtest 'ParseVersion() parses versions' => sub {
    plan tests => 2 * (scalar(keys(%valid_versions)) + scalar(@invalid_versions));
    foreach my $version (sort keys(%valid_versions)) {
      is_deeply([ParseVersion($version)], $valid_versions{$version}, "'$version' parsed");
      ok(scalar(ParseVersion($version)), "'$version' is valid in scalar context");
    }
    foreach my $version (@invalid_versions) {
      my $label = defined($version) ? "'$version'" : 'undef';
      is_deeply([ParseVersion($version)], [], "$label not parsed (empty list)");
      ok(!scalar(ParseVersion($version)), "$label is invalid in scalar context");
    }
  };
  subtest 'CompareVersions() dies on invalid versions' => sub {
    plan tests => 2 * scalar(@invalid_versions);
    foreach my $version (@invalid_versions) {
      my $label = defined($version) ? "'$version'" : 'undef';
      ok(!eval { CompareVersions($version, '1.0'); 1 }, "$label rejected as first version");
      ok(!eval { CompareVersions('1.0', $version); 1 }, "$label rejected as second version");
    }
  };
}

# GetModuleConf
# SetModuleConf
# RemoveModuleConf
# DeepCopy
# OverrideData
# MergeData
# ParseDependencies

# GetVolumeMapping
# GetPathVolume
# CreateVolumeDirectory
# ExportVolume
# ImportIntoVolume

# Module dependency resolution adds compatible available dependencies.
{
  local *Genoring::ApplyLocalHooks = sub { return {}; };
  my $plan = Genoring::_GetModuleActivationPlan(['gigwa']);
  is_deeply(
    $plan->{'order'},
    ['mongodb42', 'gigwa'],
    'Module dependencies are planned before their dependents'
  );
}

# InstallModule()
my $test_output = '';
{
  # Mock complicated functions to not test here.
  local *Genoring::ApplyLocalHooks = sub { return {}; };
  local *Genoring::PrepareOperations = sub { return {}; };
  local *Genoring::BuildMissingContainers = sub {};
  local *Genoring::ApplyServiceOverrides = sub {};
  local *Genoring::PerformLocalOperations = sub {};
  local *Genoring::PerformContainerOperations = sub {};
  local *Genoring::CleanupOperations = sub {};
  local *Genoring::EndOperations = sub {};

  # Mock user inputs.
  my $test_input = "d\nd\nd\ny\n";
  open(my $fake_stdin, '<', \$test_input) or die "ERROR: Unable to create test input stream: $!";
  local *STDIN = *$fake_stdin;
  # Hide STDOUT.
  open(my $fake_stdout, '>', \$test_output) or die "ERROR: Unable to create test output stream: $!";
  local *STDOUT = *$fake_stdout;
  # Note: if user input queries change, disable STDIN and STDOUT redirections
  # and run the test again to get the new queries.

  $expected_config->{'modules'}->{'mongodb42'} = {
    'version' => '1.1',
    'status' => 'enabled',
  };
  # Test InstallModule().
  InstallModule('mongodb42');
  $config = GetConfig();
  is_deeply(
    $config->{'modules'},
    $expected_config->{'modules'},
    'MongoDB 4.2 module enabled'
  );
};

# Cleanups test instance.
chdir($Genoring::GenoringTest::TEST_DIR);
SKIP: {
  skip 'Test instance cleaning disabled', 1 if $ENV{'GENORING_TEST_KEEP_INSTANCES'};
  # @todo Test:
  # RemoveVolumeDirectories
  # RemoveVolumeFiles
  ok(0 == RemoveInstances($instance), 'Instance removed');
}
