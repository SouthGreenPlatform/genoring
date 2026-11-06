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
use Test::More tests => 137;

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
    "image: nginx\nenv_file:\n  - \${PWD}/env/core.env\nports:\n  - 8080:80\n"
  );
  write_file(
    File::Spec->catfile($Genoring::MODULES_DIR, 'addon', 'addon.yml'),
    "name: addon\nversion: 1.0\n"
  );
  write_file(
    File::Spec->catfile($Genoring::MODULES_DIR, 'addon', 'services', 'genoring-proxy.merge.yml'),
    "env_file:\n  - \${PWD}/env/addon_addon.env\nports:\n  - 443:443\n"
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
  is_deeply(
    $compose->{'services'}->{'genoring-proxy'}->{'env_file'},
    ['${PWD}/env/core_core.env', '${PWD}/env/addon_addon.env'],
    'Env files merged from another module keep their module prefix'
  );
  unlink($Genoring::CONFIG_FILE, $Genoring::DOCKER_COMPOSE_FILE);
  ClearInternalCache();
}

# Base path management.
{
  is(Genoring::_NormalizeBasePath(''), '', 'Empty base path is the root');
  is(Genoring::_NormalizeBasePath(undef), '', 'Undefined base path is the root');
  is(Genoring::_NormalizeBasePath('/'), '', 'Slash base path is the root');
  is(Genoring::_NormalizeBasePath('itc/'), '/itc', 'Base path is normalized');
  is(Genoring::_NormalizeBasePath('"/a/b.c/"'), '/a/b.c', 'Quoted multi-segment base path is normalized');
  foreach my $invalid ('/a b', '/../x', '/a//b', '/-x', '/x$y') {
    eval { Genoring::_NormalizeBasePath($invalid); };
    ok($@, "Invalid base path '$invalid' is rejected");
  }

  local *STDOUT = $null_fh;
  eval { SetBasePath('/itc'); };
  ok($@, 'Base path can not be set before the environment is set up');
  write_file('env/genoring_genoring.env', "GENORING_HOST=example.org\nGENORING_BASE_PATH=\n");
  is(GetBasePath(), '', 'No base path by default');
  ok(SetBasePath('itc/'), 'Setting a base path changes the environment');
  is(GetBasePath(), '/itc', 'Base path stored in the environment');
  ok(!SetBasePath('/itc'), 'Same base path does not change the environment');

  my %written;
  my @removed;
  local *Genoring::CopyFiles = sub {
    my ($source, $target) = @_;
    open(my $fh, '<', $source) or die "Cannot read '$source': $!";
    $written{$target} = do { local $/; <$fh> };
    close($fh);
  };
  local *Genoring::RemoveVolumeFiles = sub { push(@removed, ref($_[0]) ? @{$_[0]} : @_); };
  local $Genoring::VOLUMES_DIR = File::Spec->catdir($work_dir, 'volumes');
  write_file(File::Spec->catfile($Genoring::VOLUMES_DIR, 'proxy', 'nginx', 'genoring-fpm.conf'), "server {}\n");
  {
    my @warnings;
    local $SIG{__WARN__} = sub { push(@warnings, @_); };
    Genoring::_UpdateBasePathConfig();
    ok((grep { m/does not support base paths/ } @warnings), 'Outdated main proxy config raises a warning');
  }
  my $conf = $written{'proxy/nginx/genoring/base-path.conf'} || '';
  like($conf, qr{set \$genoring_base_path /itc;}, 'Base path config sets the base path variable');
  like($conf, qr{location \^~ /itc/ \{\s*rewrite \^/itc\(/\.\*\)\$ \$1 last;}, 'Base path config removes the base path');
  like($conf, qr#location = /itc \{[^}]*return 301 /itc/;#s, 'Base path without trailing slash is redirected');
  ok(SetBasePath(''), 'Removing the base path changes the environment');
  Genoring::_UpdateBasePathConfig();
  is_deeply(
    \@removed,
    ['proxy/nginx/genoring/base-path.conf', 'proxy/httpd/genoring/base-path.conf'],
    'Base path configs of both proxy servers removed without base path'
  );
  unlink('env/genoring_genoring.env');
}

# Managed instance directories.
my $instances_dir = File::Spec->catdir($work_dir, 'instances');
sub make_instance {
  my ($name, $config, $env) = @_;
  my $dir = File::Spec->catdir($instances_dir, $name);
  make_path(File::Spec->catdir($dir, 'volumes'));
  write_file(File::Spec->catfile($dir, 'config.yml'), $config // "project: $name\nno_exposed_ports: 1\nnetworks:\n  hub: auto\n");
  write_file(File::Spec->catfile($dir, 'env', 'genoring_genoring.env'), $env // "GENORING_HOST=$name.example.org\nGENORING_BASE_PATH=\n");
  return $dir;
}
my $slave1_dir = make_instance('slave1');
my $slave2_dir = make_instance('slave2');
my $noproject_dir = make_instance('noproject', "no_exposed_ports: 1\n");
my $badproject_dir = make_instance('badproject', "project: Bad Name\n");
my $sameproject_dir = make_instance('sameproject', "project: master\n");
my $nohost_dir = make_instance('nohost', undef, "GENORING_HOST=\n");
my $badhost_dir = make_instance('badhost', undef, "GENORING_HOST=bad_host!\n");
my $masterhost_dir = make_instance('masterhost', undef, "GENORING_HOST=MASTER.example.org\n");
my $badpath_dir = make_instance('badpath', undef, "GENORING_HOST=master.example.org\nGENORING_BASE_PATH=/a b\n");
my $otherhostpath_dir = make_instance('otherhostpath', undef, "GENORING_HOST=other.example.org\nGENORING_BASE_PATH=/other\n");
my $reservedpath_dir = make_instance('reservedpath', undef, "GENORING_HOST=master.example.org\nGENORING_BASE_PATH=/sites/x\n");
my $itc_dir = make_instance('itc', undef, "GENORING_HOST=\"master.example.org\"\nGENORING_BASE_PATH=/itc/\n");
my $itcsub_dir = make_instance('itcsub', undef, "GENORING_HOST=master.example.org\nGENORING_BASE_PATH=/itc/sub\n");
my $noenv_dir = File::Spec->catdir($instances_dir, 'noenv');
make_path(File::Spec->catdir($noenv_dir, 'volumes'));
write_file(File::Spec->catfile($noenv_dir, 'config.yml'), "project: noenv\n");
make_path(File::Spec->catdir($instances_dir, 'empty'));

# _CheckInstanceDirectory.
{
  my ($dir, $instance_config) = Genoring::_CheckInstanceDirectory($slave1_dir . '/');
  is($dir, Cwd::abs_path($slave1_dir), 'Instance directory is normalized');
  is($instance_config->{'project'}, 'slave1', 'Instance config is read');
  eval { Genoring::_CheckInstanceDirectory(File::Spec->catdir($instances_dir, 'missing')); };
  like($@, qr/not found/, 'Missing directory is rejected');
  eval { Genoring::_CheckInstanceDirectory(File::Spec->catdir($instances_dir, 'empty')); };
  like($@, qr/not an initialized GenoRing instance/, 'Uninitialized directory is rejected');
}

# AttachInstance and DetachInstance.
{
  my $config = {'networks' => {'hub' => 'auto'}};
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
  local *Genoring::RemoveVolumeFiles = sub { push(@removed, ref($_[0]) ? @{$_[0]} : @_); };
  my @warnings;
  local $SIG{__WARN__} = sub { push(@warnings, @_); };
  local *STDOUT = $null_fh;

  foreach my $invalid (
    undef,
    File::Spec->catdir($instances_dir, 'empty'),
    $work_dir,
    $noproject_dir,
    $badproject_dir,
    $sameproject_dir,
    $noenv_dir,
    $nohost_dir,
    $badhost_dir,
    $masterhost_dir,
    $badpath_dir,
    $otherhostpath_dir,
    $reservedpath_dir,
  ) {
    eval { AttachInstance($invalid); };
    ok($@, "Invalid instance rejected ('" . ($invalid // '') . "')");
  }

  # Virtual host.
  @warnings = ();
  AttachInstance($slave1_dir);
  is_deeply(
    $config->{'managed_instances'},
    {'slave1' => {'host' => 'slave1.example.org', 'path' => Cwd::abs_path($slave1_dir), 'proxy_server' => 'nginx'}},
    'Managed instance stored in config with its host and directory'
  );
  like($copied{'proxy/nginx/includes/instance-slave1.conf'} || '', qr/server_name slave1\.example\.org;/, 'Managed instance virtual host config written');
  ok((grep { m/not running/ } @warnings), 'Not running managed instance raises a warning');
  ok(!(grep { m/exposes its ports|does not share|SECURITY/ } @warnings), 'No warning for a properly configured managed instance');

  write_file(File::Spec->catfile($slave2_dir, 'env', 'genoring_genoring.env'), "GENORING_HOST=slave1.example.org\n");
  eval { AttachInstance($slave2_dir); };
  ok($@, 'Host already used by another managed instance is rejected');
  write_file(File::Spec->catfile($slave1_dir, 'env', 'genoring_genoring.env'), "GENORING_HOST=slave1-new.example.org\n");
  AttachInstance($slave1_dir);
  is($config->{'managed_instances'}->{'slave1'}->{'host'}, 'slave1-new.example.org', 'Attaching again updates the managed instance host');

  my $exposed_dir = make_instance('exposed', "project: exposed\n");
  @warnings = ();
  AttachInstance($exposed_dir);
  ok((grep { m/exposes its ports/ } @warnings), 'Managed instance exposing its ports raises a warning');
  ok((grep { m/does not share any Docker network/ } @warnings), 'Managed instance without shared network raises a warning');
  DetachInstance('exposed');

  # Base path.
  @warnings = ();
  %copied = ();
  @removed = ();
  AttachInstance($itc_dir);
  is_deeply(
    $config->{'managed_instances'}->{'itc'},
    {'host' => 'master.example.org', 'path' => Cwd::abs_path($itc_dir), 'base_path' => '/itc', 'proxy_server' => 'nginx'},
    'Managed instance stored in config with its base path'
  );
  my $conf = $copied{'proxy/nginx/genoring/instance-itc.conf'} || '';
  like($conf, qr{location \^~ /itc/ \{}, 'Base path location has priority over regular expression locations');
  like($conf, qr{set \$genoring_instance_upstream http://itc-proxy:80;}, 'Base path location targets the managed instance proxy');
  like($conf, qr#location = /itc \{[^}]*return 301 /itc/;#s, 'Base path without trailing slash is redirected');
  like($conf, qr{location \@genoring_instance_unavailable_itc \{}, 'Unavailable page location is specific to the managed instance');
  unlike($conf, qr/server_name|\$\{\w+\}/, 'No virtual host and no remaining placeholder');
  ok((grep { m{includes/instance-itc\.conf} } @removed), 'Virtual host config of the managed instance removed');
  ok((grep { m/SECURITY WARNING/ } @warnings), 'Base path raises a security warning');
  eval { AttachInstance($itcsub_dir); };
  like($@ || '', qr/overlaps/, 'Overlapping base path is rejected');

  @removed = ();
  DetachInstance('itc');
  is_deeply(
    [sort @removed],
    [
      'proxy/httpd/genoring/instance-itc.conf',
      'proxy/httpd/includes/instance-itc.conf',
      'proxy/nginx/genoring/instance-itc.conf',
      'proxy/nginx/includes/instance-itc.conf',
    ],
    'Both managed instance config kinds of both proxy servers removed on detach'
  );
  DetachInstance('slave1');
  ok(!exists($config->{'managed_instances'}), 'Managed instance removed from config');
  eval { DetachInstance('slave1'); };
  ok($@, 'Detaching an unknown instance fails');

  $config->{'no_exposed_ports'} = 1;
  eval { AttachInstance($slave1_dir); };
  ok($@, 'An instance without exposed ports can not manage other instances');
}

# RunManagedInstances.
{
  my $config = {
    'managed_instances' => {
      'slave2' => {'host' => 'slave2.example.org', 'path' => $slave2_dir},
      'slave1' => {'host' => 'slave1.example.org', 'path' => $slave1_dir},
      'legacy' => {'host' => 'legacy.example.org'},
      'gone' => {'host' => 'gone.example.org', 'path' => File::Spec->catdir($instances_dir, 'gone')},
    },
  };
  my @runs;
  local *Genoring::GetConfig = sub { return $config; };
  local *Genoring::_RunInstanceCommand = sub {
    my ($project, $path, @args) = @_;
    push(@runs, [$project, $path, @args]);
    return ('slave2' ne $project);
  };
  my @warnings;
  local $SIG{__WARN__} = sub { push(@warnings, @_); };
  local *STDOUT = $null_fh;
  is(RunManagedInstances('start', '-yes'), 3, 'Failures are counted (no path, missing directory, failed command)');
  is_deeply(
    \@runs,
    [['slave1', $slave1_dir, 'start', '-yes'], ['slave2', $slave2_dir, 'start', '-yes']],
    'Valid managed instances are processed in order with the given command and flags'
  );
  ok((grep { m/legacy.*attach/ } @warnings), 'Managed instance without directory raises a warning');
  ok((grep { m/gone/ } @warnings), 'Managed instance with missing directory raises a warning');
}

# _RunInstanceCommand runs genoring.pl in the instance directory with a
# cleaned environment.
{
  my $fake_genoring_dir = File::Spec->catdir($work_dir, 'fake_genoring');
  my $report = File::Spec->catfile($work_dir, 'run_report.txt');
  write_file(
    File::Spec->catfile($fake_genoring_dir, 'genoring.pl'),
    "use Cwd; open(my \$fh, '>', '$report') or die; print {\$fh} join(\"\\n\", 'cwd=' . getcwd(), 'args=' . join(' ', \@ARGV), map { \"\$_=\" . (\$ENV{\$_} // 'UNSET') } qw(COMPOSE_PROJECT_NAME PWD GENORING_VOLUMES_DIR GENORING_PORT COMPOSE_PROFILES)); close(\$fh); exit(\$ARGV[0] eq 'fail' ? 1 : 0);\n"
  );
  local $Genoring::GENORING_DIR = $fake_genoring_dir;
  local $ENV{'GENORING_VOLUMES_DIR'} = '/master/volumes';
  local $ENV{'GENORING_PORT'} = '8080';
  local $ENV{'COMPOSE_PROFILES'} = 'dev';
  my $cwd = getcwd();
  ok(Genoring::_RunInstanceCommand('slave1', $slave1_dir, 'status', '-yes'), 'Successful command');
  open(my $fh, '<', $report) or die "Cannot read '$report': $!";
  my %report = map { chomp; split(/=/, $_, 2) } <$fh>;
  close($fh);
  is(Cwd::abs_path($report{'cwd'}), Cwd::abs_path($slave1_dir), 'Command run in the instance directory');
  is($report{'args'}, 'status -yes', 'Command arguments passed');
  is($report{'COMPOSE_PROJECT_NAME'}, 'slave1', 'Instance project name set');
  is($report{'PWD'}, $slave1_dir, 'PWD set to the instance directory');
  is_deeply(
    [@report{qw(GENORING_VOLUMES_DIR GENORING_PORT COMPOSE_PROFILES)}],
    ['UNSET', 'UNSET', 'UNSET'],
    'Current instance specific variables are not passed'
  );
  is(getcwd(), $cwd, 'Current directory restored');
  is($ENV{'GENORING_VOLUMES_DIR'}, '/master/volumes', 'Current environment restored');
  ok(!Genoring::_RunInstanceCommand('slave1', $slave1_dir, 'fail'), 'Failed command');
}

# Apache HTTPd proxy alternative.
{
  # GetProxyServer and GetProxyService.
  my $module_config = {};
  {
    local *Genoring::GetModuleConf = sub { return $module_config; };
    is(GetProxyServer(), 'nginx', 'NGINX is the default proxy server');
    is(GetProxyService(), 'genoring-proxy', 'Default proxy service');
    $module_config = {'alternative' => 'httpd'};
    is(GetProxyServer(), 'httpd', 'Apache HTTPd is used with the "httpd" alternative');
    is(GetProxyService(), 'genoring-proxy-httpd', 'Apache HTTPd proxy service');
  }
  my $httpd_dir = make_instance('httpdslave', "project: httpdslave\nmodules:\n  genoring:\n    status: enabled\n    alternative: httpd\n");
  is(GetProxyServer($httpd_dir), 'httpd', 'Proxy server of another instance');
  is(GetProxyServer($slave2_dir), 'nginx', 'Default proxy server of another instance');
  is(GetProxyServer(File::Spec->catdir($instances_dir, 'missing')), 'nginx', 'Default proxy server of a missing instance');
  is(Genoring::_GetInstanceProxyContainer('httpdslave', $httpd_dir), 'httpdslave-proxy-httpd', 'Managed instance Apache HTTPd proxy container');
  is(Genoring::_GetInstanceProxyContainer('slave2', $slave2_dir), 'slave2-proxy', 'Managed instance NGINX proxy container');
  is(Genoring::_GetInstanceProxyContainer('legacy'), 'legacy-proxy', 'Default managed instance proxy container');

  local *Genoring::GetProxyServer = sub { return 'httpd'; };
  is(Genoring::_GetInstanceProxyConfigPath('slave1'), 'proxy/httpd/includes/instance-slave1.conf', 'Apache HTTPd virtual host config path');
  is(Genoring::_GetInstanceProxyConfigPath('itc', '/itc'), 'proxy/httpd/genoring/instance-itc.conf', 'Apache HTTPd base path config path');
  is(Genoring::_GetInstanceProxyConfigPath('itc', '/itc', 'nginx'), 'proxy/nginx/genoring/instance-itc.conf', 'Config path of a given proxy server');

  # GetInstanceProxyConfig.
  my $conf = GetInstanceProxyConfig('slave1', 'slave1.example.org', 0, undef, 'slave1-proxy-httpd');
  like($conf, qr/<VirtualHost \*:80>/, 'Default Apache HTTPd port is used');
  like($conf, qr/ServerName slave1\.example\.org/, 'Host is used as server name');
  like($conf, qr{ProxyPass "/" "http://slave1-proxy-httpd:80/" disablereuse=On}, 'Managed instance proxy is resolved at request time');
  unlike($conf, qr/SSLEngine/, 'No SSL settings by default');
  unlike($conf, qr/\$\{\w+\}/, 'No remaining placeholder');
  write_file('env/genoring_httpd.env', "HTTPD_PORT=8081\n");
  write_file('env/ssl_ssl.env', "SSL_PORT=8443\n");
  $conf = GetInstanceProxyConfig('slave1', 'slave1.example.org', 1);
  like($conf, qr/<VirtualHost \*:8081>/, 'Instance Apache HTTPd port is used');
  like($conf, qr/<VirtualHost \*:8443>\s*Use GenoRingInstance-slave1/, 'SSL virtual host uses the managed instance definition');
  like($conf, qr{SSLCertificateFile\s+/etc/ssl/certs/slave1\.example\.org\.crt}, 'Host certificate is used');
  like($conf, qr{http://slave1-proxy:80/}, 'Default managed instance proxy');
  unlike($conf, qr/\$\{\w+\}/, 'No remaining placeholder with SSL');
  unlink('env/genoring_httpd.env', 'env/ssl_ssl.env');
  $conf = GetInstanceProxyConfig('itc', 'master.example.org', 0, '/itc');
  like($conf, qr{<Location "/itc/">\s.*ProxyPass "http://itc-proxy:80/itc/"}s, 'Base path is passed unchanged to the managed instance');
  like($conf, qr{RedirectMatch 301 "\^/itc\$" "/itc/"}, 'Base path without trailing slash is redirected');
  unlike($conf, qr/VirtualHost|\$\{\w+\}/, 'No virtual host and no remaining placeholder');

  # Base path and managed instance synchronization.
  my %written;
  my $save_count = 0;
  local *Genoring::CopyFiles = sub {
    my ($source, $target) = @_;
    open(my $fh, '<', $source) or die "Cannot read '$source': $!";
    $written{$target} = do { local $/; <$fh> };
    close($fh);
  };
  local *STDOUT = $null_fh;
  write_file('env/genoring_genoring.env', "GENORING_HOST=example.org\nGENORING_BASE_PATH=/abc\n");
  {
    my @warnings;
    local $SIG{__WARN__} = sub { push(@warnings, @_); };
    Genoring::_UpdateBasePathConfig();
    ok(!@warnings, 'No warning for Apache HTTPd base path');
  }
  $conf = $written{'proxy/httpd/genoring/base-path.conf'} || '';
  like($conf, qr{Alias "/abc" "/opt/drupal/web"}, 'Apache HTTPd base path config serves Drupal under the base path');
  like($conf, qr{RedirectMatch 301 "\^/abc\$" "/abc/"}, 'Apache HTTPd base path without trailing slash is redirected');
  unlink('env/genoring_genoring.env');

  my $config = {
    'managed_instances' => {
      'slave1' => {'host' => 'slave1.example.org', 'path' => $httpd_dir},
      'itc' => {'host' => 'master.example.org', 'path' => $itc_dir, 'base_path' => '/itc', 'proxy_server' => 'httpd'},
    },
  };
  local *Genoring::GetConfig = sub { return $config; };
  local *Genoring::SaveConfig = sub { ++$save_count; };
  local *Genoring::GetModules = sub { return ['genoring']; };
  %written = ();
  Genoring::_SyncManagedInstancesProxy();
  is_deeply([sort keys(%written)], ['proxy/httpd/includes/instance-slave1.conf'], 'Only managed instances configured for another proxy server are regenerated');
  like($written{'proxy/httpd/includes/instance-slave1.conf'}, qr{http://slave1-proxy-httpd:80/}, 'Managed instance proxy container of the managed instance proxy service is used');
  is($config->{'managed_instances'}->{'slave1'}->{'proxy_server'}, 'httpd', 'Managed instance proxy server updated');
  is($save_count, 1, 'Config saved after synchronization');
  %written = ();
  Genoring::_SyncManagedInstancesProxy();
  ok(!%written, 'Synchronized managed instances are not regenerated');
  is($save_count, 1, 'Config not saved without changes');
}

chdir($previous_dir);
