#!/usr/bin/env perl

=pod

=head1 NAME

instances.t - Tests GenoRing port exposition and managed instance support.

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
use Test::More tests => 43;

sub write_file {
  my ($path, $content) = @_;
  my (undef, $directory) = File::Spec->splitpath($path);
  make_path($directory) if $directory && !-d $directory;
  open(my $file, '>', $path) or die "Cannot create '$path': $!";
  print {$file} $content or die "Cannot write '$path': $!";
  close($file) or die "Cannot close '$path': $!";
}

my $previous_dir = getcwd();
my $work_dir = tempdir(CLEANUP => 1);
chdir($work_dir) or die "Cannot enter '$work_dir': $!";

# GetProjectName.
{
  local $Genoring::_g_config = {};
  local $Genoring::CONFIG_FILE = File::Spec->catfile($work_dir, 'missing-config.yml');
  local $Genoring::DOCKER_COMPOSE_FILE = File::Spec->catfile($work_dir, 'missing-compose.yml');
  local $ENV{'COMPOSE_PROJECT_NAME'} = undef;
  is(GetProjectName(), 'genoring', 'Default project name is used when no instance is configured');
}

# Silence regular outputs.
my $null_fh;
open($null_fh, '>', File::Spec->devnull()) or die "Cannot open null device: $!";

# _ReadTemplate.
{
  my $template = File::Spec->catfile($work_dir, 'test.template');
  write_file($template, 'a=${A} b=${B} $nginx_var');
  is(Genoring::_ReadTemplate($template, {'A' => '1'}), 'a=1 b=${B} $nginx_var', 'Only known placeholders are replaced');
}

# GetInstanceProxyConfig.
{
  my $conf = GetInstanceProxyConfig('slave1', 'slave1.example.org');
  like($conf, qr/^\s*listen 80;/m, 'Default HTTP port is used');
  like($conf, qr/server_name slave1\.example\.org;/, 'Host is used as server name');
  like($conf, qr{set \$genoring_instance_upstream http://slave1-proxy:80;}, 'Managed instance proxy is the upstream');
  like($conf, qr/proxy_pass \$genoring_instance_upstream;/, 'Upstream is resolved at request time');
  like($conf, qr/resolver 127\.0\.0\.11/, 'Docker DNS resolver is used');
  unlike($conf, qr/ssl/, 'No SSL settings by default');
  unlike($conf, qr/\$\{\w+\}/, 'No remaining placeholder');

  write_file('env/genoring_nginx.env', "NGINX_PORT=8081\n");
  write_file('env/ssl_ssl.env', "SSL_PORT=8443\n");
  $conf = GetInstanceProxyConfig('slave1', 'slave1.example.org', 1);
  like($conf, qr/^\s*listen 8081;/m, 'Instance NGINX port is used');
  like($conf, qr/^\s*listen 8443 ssl;/m, 'SSL port is used');
  like($conf, qr{ssl_certificate\s+/etc/ssl/certs/slave1\.example\.org\.crt;}, 'Host certificate is used');
  unlike($conf, qr/\$\{\w+\}/, 'No remaining placeholder with SSL');
  unlink('env/genoring_nginx.env', 'env/ssl_ssl.env');
}

# SetExposedPorts.
{
  my $config = {};
  my $save_count = 0;
  local *Genoring::GetConfig = sub { return $config; };
  local *Genoring::SaveConfig = sub { ++$save_count; };
  local *STDOUT = $null_fh;
  ok(!SetExposedPorts(1), 'Ports are exposed by default');
  ok(SetExposedPorts(0), 'Disabling port exposition changes the config');
  is($config->{'no_exposed_ports'}, 1, 'Setting stored in config');
  ok(!SetExposedPorts(0), 'Same setting does not change the config');
  ok(SetExposedPorts(1), 'Enabling port exposition changes the config');
  ok(!exists($config->{'no_exposed_ports'}), 'Setting removed from config');
  is($save_count, 2, 'Config only saved on changes');
}

# GetReverseProxyAddresses.
{
  my $config = {};
  local *Genoring::GetConfig = sub { return $config; };
  local *Genoring::_GetComposeExternalNetworks = sub { return []; };
  is(GetReverseProxyAddresses(), '', 'No reverse proxy by default');
  write_file('env/genoring_genoring.env', "DRUPAL_REVERSE_PROXY_ADDRESSES=\"10.0.0.1, 172.20.0.0/16\"\n");
  is(GetReverseProxyAddresses(), '10.0.0.1,172.20.0.0/16', 'Explicit addresses are used');
  write_file('env/genoring_genoring.env', "DRUPAL_REVERSE_PROXY_ADDRESSES=10.0.0.1;rm -rf /\n");
  {
    my @warnings;
    local $SIG{__WARN__} = sub { push(@warnings, @_); };
    is(GetReverseProxyAddresses(), '', 'Invalid addresses are ignored');
    ok(@warnings, 'Invalid addresses raise a warning');
  }
  unlink('env/genoring_genoring.env');
}

# SaveConfig keeps instance settings.
{
  local $Genoring::_g_config = {
    'no_exposed_ports' => 1,
    'networks' => {'hub' => 'auto'},
    'managed_instances' => {'slave1' => {'host' => 'slave1.example.org'}},
  };
  local $Genoring::_g_modules = {'config' => {}};
  SaveConfig();
  my $saved = Genoring::ReadYaml($Genoring::CONFIG_FILE)->[0];
  is($saved->{'no_exposed_ports'}, 1, 'no_exposed_ports saved');
  is_deeply($saved->{'managed_instances'}, {'slave1' => {'host' => 'slave1.example.org'}}, 'managed_instances saved');
  unlink($Genoring::CONFIG_FILE);
}

# GenerateDockerComposeFile without exposed ports.
{
  local $Genoring::MODULES_DIR = File::Spec->catdir($work_dir, 'modules');
  write_file(
    File::Spec->catfile($Genoring::MODULES_DIR, 'core', 'core.yml'),
    "name: core\nversion: 1.0\nservices:\n  genoring-proxy:\n    name: proxy\n"
  );
  write_file(
    File::Spec->catfile($Genoring::MODULES_DIR, 'core', 'services', 'genoring-proxy.yml'),
    "image: nginx\nports:\n  - 8080:80\n"
  );
  write_file(
    File::Spec->catfile($Genoring::MODULES_DIR, 'addon', 'addon.yml'),
    "name: addon\nversion: 1.0\n"
  );
  write_file(
    File::Spec->catfile($Genoring::MODULES_DIR, 'addon', 'services', 'genoring-proxy.merge.yml'),
    "ports:\n  - 443:443\n"
  );
  write_file(
    $Genoring::CONFIG_FILE,
    "modules:\n  core:\n    status: enabled\n    version: '1.0'\n  addon:\n    status: enabled\n    version: '1.0'\nno_exposed_ports: 1\n"
  );
  local *Genoring::EnsureNetworks = sub {};
  local *Genoring::GetEnvironmentFiles = sub { return (); };
  local *STDOUT = $null_fh;
  GenerateDockerComposeFile();
  my $compose = Genoring::ReadYaml($Genoring::DOCKER_COMPOSE_FILE)->[0];
  ok(!exists($compose->{'services'}->{'genoring-proxy'}->{'ports'}), 'Ports (including merged ones) are removed');
  is(Genoring::ReadYaml($Genoring::CONFIG_FILE)->[0]->{'no_exposed_ports'}, 1, 'Setting preserved after generation');

  write_file(
    $Genoring::CONFIG_FILE,
    "modules:\n  core:\n    status: enabled\n    version: '1.0'\n  addon:\n    status: enabled\n    version: '1.0'\n"
  );
  GenerateDockerComposeFile();
  $compose = Genoring::ReadYaml($Genoring::DOCKER_COMPOSE_FILE)->[0];
  is_deeply($compose->{'services'}->{'genoring-proxy'}->{'ports'}, ['8080:80', '443:443'], 'Ports are kept by default');
  unlink($Genoring::CONFIG_FILE, $Genoring::DOCKER_COMPOSE_FILE);
  ClearInternalCache();
}

# AttachInstance and DetachInstance.
{
  my $config = {};
  my %copied;
  my @removed;
  local $ENV{'COMPOSE_PROJECT_NAME'} = 'master';
  local $ENV{'GENORING_HOST'} = 'master.example.org';
  local *Genoring::GetConfig = sub { return $config; };
  local *Genoring::SaveConfig = sub {};
  local *Genoring::GetModules = sub { return ['genoring']; };
  local *Genoring::IsContainerRunning = sub { return (); };
  local *Genoring::CopyFiles = sub {
    my ($source, $target) = @_;
    open(my $fh, '<', $source) or die "Cannot read '$source': $!";
    $copied{$target} = do { local $/; <$fh> };
    close($fh);
  };
  local *Genoring::RemoveVolumeFiles = sub { push(@removed, @_); };
  my @warnings;
  local $SIG{__WARN__} = sub { push(@warnings, @_); };
  local *STDOUT = $null_fh;

  foreach my $invalid (['', 'slave.example.org'], ['Bad Name', 'slave.example.org'], ['slave1', ''], ['slave1', 'bad_host!'], ['master', 'slave.example.org'], ['slave1', 'MASTER.example.org']) {
    eval { AttachInstance(@$invalid); };
    ok($@, "Invalid attach parameters rejected ('" . join("', '", @$invalid) . "')");
  }

  AttachInstance('slave1', 'slave1.example.org');
  is_deeply($config->{'managed_instances'}, {'slave1' => {'host' => 'slave1.example.org'}}, 'Managed instance stored in config');
  like($copied{'proxy/nginx/includes/instance-slave1.conf'} || '', qr/server_name slave1\.example\.org;/, 'Managed instance proxy config written');
  ok((grep { m/not running/ } @warnings), 'Not running managed instance raises a warning');

  eval { AttachInstance('slave2', 'slave1.example.org'); };
  ok($@, 'Host already used by another managed instance is rejected');

  DetachInstance('slave1');
  ok(!exists($config->{'managed_instances'}), 'Managed instance removed from config');
  is_deeply(\@removed, ['proxy/nginx/includes/instance-slave1.conf'], 'Managed instance proxy config removed');
  eval { DetachInstance('slave1'); };
  ok($@, 'Detaching an unknown instance fails');

  $config->{'no_exposed_ports'} = 1;
  eval { AttachInstance('slave1', 'slave1.example.org'); };
  ok($@, 'An instance without exposed ports can not manage other instances');
}

chdir($previous_dir);
