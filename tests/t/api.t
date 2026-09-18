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
use FindBin;
use Getopt::Long qw(GetOptions);
use IO::Select;
use IPC::Open3 qw(open3);
use lib "$FindBin::Bin/../../perllib";
use Genoring;
use Genoring::GenoringTest;
use Test::More tests => 53;
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

# SaveConfig() && ClearCache()
$config->{'project'} = $instance;
SaveConfig();
$config->{'project'} = 'xyz';
ClearCache();
$config = GetConfig();
is($config->{'project'}, $instance, 'Config saved');
$expected_config->{'project'} = $instance;

# @todo Test:
# SetupGenoringEnvironment
# GenerateDockerComposeFile
# ParseVersion
# CompareVersions
# GetAvailableVersions
# EnableAlternative
# DisableAlternative
# ToExternalService
# ToGenoringService

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

# GetModuleAlternatives()
is_deeply(
  GetModuleAlternatives('genoring'),
  {
    'httpd' => {
      'description' => 'Replaces NGINX server with Apache 2 HTTPd.',
      'substitue' => {
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
        'REQUIRES genoring genoring-proxy OR genoring-proxy-http',
        'genoring-gigwa BEFORE genoring genoring-proxy OR genoring-proxy-http',
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
    'genoring-volume-db-pgdata' => [
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
    'genoring-volume-db-pgdata',
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
    'genoring-volume-db-pgdata',
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

# InstallModule()
my $test_output = '';
{
  # Mock complicated functions to not test here.
  local *Genoring::ApplyLocalHooks = sub { return {}; };
  local *Genoring::PrepareOperations = sub { return {}; };
  local *Genoring::BuildMissingContainers = sub {};
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
    'version' => '1.0',
    'status' => 'enabled',
  };
  # Test InstallModule().
  InstallModule('mongodb42');
  $config = GetConfig();
  is_deeply(
    $config,
    $expected_config,
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
