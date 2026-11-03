#!/usr/bin/env perl

=pod

=head1 NAME

networks.t - Tests GenoRing instance additional Docker network management.

=cut

use strict;
use warnings;

use Cwd qw(getcwd);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/../../perllib";
use Genoring;
use Test::More tests => 35;

sub write_file {
  my ($path, $content) = @_;
  my (undef, $directory) = File::Spec->splitpath($path);
  make_path($directory) if $directory && !-d $directory;
  open(my $file, '>', $path) or die "Cannot create '$path': $!";
  print {$file} $content or die "Cannot write '$path': $!";
  close($file) or die "Cannot close '$path': $!";
}

# ParseNetworkFlag.
is_deeply([ParseNetworkFlag('genoring-hub')], ['genoring-hub', 'auto'], 'Network without service list uses auto mode');
is_deeply(
  [ParseNetworkFlag('hub:genoring-proxy,genoring')],
  ['hub', ['genoring', 'genoring-proxy']],
  'Network with service list'
);
is_deeply(
  [ParseNetworkFlag('hub: genoring-proxy , genoring,genoring-proxy,')],
  ['hub', ['genoring', 'genoring-proxy']],
  'Service list is trimmed and deduplicated'
);
is_deeply([ParseNetworkFlag('hub:')], ['hub', undef], 'Empty service list means removal');
foreach my $invalid ('', ':genoring', 'default', 'host', 'bad name', '-hub') {
  eval { ParseNetworkFlag($invalid); };
  ok($@, "Invalid network specification '$invalid' is rejected");
}
eval { ParseNetworkFlag('hub:bad service'); };
ok($@, 'Invalid service name is rejected');

# GetServiceNetworkMode.
my %module_info = (
  core => {
    'services' => {
      'genoring' => {'name' => 'CMS'},
      'genoring-proxy' => {'name' => 'Proxy', 'network' => 'auto'},
      'genoring-odd' => {'name' => 'Odd', 'network' => 'unsupported'},
    },
    'alternatives' => {
      'httpd' => {'substitute' => {'genoring-proxy' => 'genoring-proxy-httpd'}},
    },
  },
);
{
  local *Genoring::GetModuleInfo = sub { return $module_info{$_[0]} || {}; };
  is(GetServiceNetworkMode('core', 'genoring'), 'default', 'Omitted network mode is "default"');
  is(GetServiceNetworkMode('core', 'genoring-proxy'), 'auto', 'Explicit "auto" network mode');
  is(GetServiceNetworkMode('core', 'genoring-proxy-httpd'), 'auto', 'Alternative service inherits substituted service mode');
  is(GetServiceNetworkMode('core', 'genoring-other'), 'default', 'Unknown service uses "default" mode');
  my @warnings;
  local $SIG{__WARN__} = sub { push(@warnings, @_); };
  is(GetServiceNetworkMode('core', 'genoring-odd'), 'default', 'Unsupported mode falls back to "default"');
  ok(@warnings, 'Unsupported mode raises a warning');

  # GetServiceNetworks.
  my $services = {
    'genoring' => 'core',
    'genoring-proxy' => 'core',
    'genoring-db' => 'core',
  };
  @warnings = ();
  my $service_networks = GetServiceNetworks(
    $services,
    {
      'hub' => 'auto',
      'backnet' => ['genoring', 'genoring-db', 'genoring-missing'],
      'emptynet' => ['genoring-missing'],
    }
  );
  is_deeply(
    $service_networks,
    {
      'genoring' => ['backnet'],
      'genoring-db' => ['backnet'],
      'genoring-proxy' => ['hub'],
    },
    'Services are assigned to auto and explicit networks; unavailable services are ignored'
  );
  ok((grep { m/emptynet/ } @warnings), 'Network without enabled service raises a warning');
  is_deeply(GetServiceNetworks($services, undef), {}, 'No network config means no additional network');
}

# _AddServiceNetworks.
{
  my $definition = {'image' => 'nginx'};
  Genoring::_AddServiceNetworks($definition, ['hub']);
  is_deeply($definition->{'networks'}, ['default', 'hub'], 'Default network is kept when adding networks');
  $definition = {'networks' => ['custom', 'hub']};
  Genoring::_AddServiceNetworks($definition, ['hub', 'other']);
  is_deeply($definition->{'networks'}, ['custom', 'hub', 'other'], 'Existing network list is extended without duplicates');
  $definition = {'networks' => {'custom' => {'aliases' => ['x']}}};
  Genoring::_AddServiceNetworks($definition, ['hub']);
  is_deeply($definition->{'networks'}, {'custom' => {'aliases' => ['x']}, 'hub' => {}}, 'Existing network hash is extended');
}

# SetNetworks.
{
  my $config = {};
  my $save_count = 0;
  local *Genoring::GetConfig = sub { return $config; };
  local *Genoring::SaveConfig = sub { ++$save_count; };
  local *Genoring::GetModules = sub { return ['core']; };
  local *Genoring::GetModuleServices = sub { return ['genoring', 'genoring-proxy']; };
  my @warnings;
  local $SIG{__WARN__} = sub { push(@warnings, @_); };
  local *STDOUT;
  open(STDOUT, '>', File::Spec->devnull());

  ok(SetNetworks('hub', 'backnet:genoring,genoring-unknown'), 'New networks change the config');
  is_deeply($config->{'networks'}, {'hub' => 'auto', 'backnet' => ['genoring', 'genoring-unknown']}, 'Networks are stored in config');
  ok((grep { m/genoring-unknown/ } @warnings), 'Unknown service raises a warning');
  ok(!SetNetworks('hub'), 'Same settings do not change the config');
  is($save_count, 1, 'Config is only saved on changes');
  ok(SetNetworks('hub:', 'backnet:'), 'Network removals change the config');
  ok(!exists($config->{'networks'}), 'Networks key removed from config when empty');
}

# GenerateDockerComposeFile.
{
  my $work_dir = tempdir(CLEANUP => 1);
  my $previous_dir = getcwd();
  chdir($work_dir) or die "Cannot enter '$work_dir': $!";
  local $Genoring::MODULES_DIR = File::Spec->catdir($work_dir, 'modules');
  write_file(
    File::Spec->catfile($Genoring::MODULES_DIR, 'core', 'core.yml'),
    "name: core\nversion: 1.0\nservices:\n  genoring-proxy:\n    name: proxy\n    network: auto\n  genoring-app:\n    name: app\n"
  );
  write_file(File::Spec->catfile($Genoring::MODULES_DIR, 'core', 'services', 'genoring-proxy.yml'), "image: nginx\n");
  write_file(File::Spec->catfile($Genoring::MODULES_DIR, 'core', 'services', 'genoring-app.yml'), "image: app\n");
  write_file(
    $Genoring::CONFIG_FILE,
    "modules:\n  core:\n    status: enabled\n    version: '1.0'\nnetworks:\n  hub: auto\n"
  );
  my @ensured;
  local *Genoring::EnsureNetworks = sub { push(@ensured, @_); };
  local *Genoring::GetEnvironmentFiles = sub { return (); };
  local *STDOUT;
  open(STDOUT, '>', File::Spec->devnull());

  GenerateDockerComposeFile();
  my $compose = Genoring::ReadYaml($Genoring::DOCKER_COMPOSE_FILE)->[0];
  is_deeply($compose->{'services'}->{'genoring-proxy'}->{'networks'}, ['default', 'hub'], 'Auto service joins the network');
  ok(!exists($compose->{'services'}->{'genoring-app'}->{'networks'}), 'Default service keeps implicit default network');
  is_deeply($compose->{'networks'}, {'hub' => {'name' => 'hub', 'external' => 'true'}}, 'Network declared as external');
  is_deeply(\@ensured, ['hub'], 'Network creation is ensured');
  is_deeply(Genoring::ReadYaml($Genoring::CONFIG_FILE)->[0]->{'networks'}, {'hub' => 'auto'}, 'Networks are preserved when config is saved');

  chdir($previous_dir);
  ClearInternalCache();
}
