#!/usr/bin/env perl

=pod

=head1 NAME

operations.t - Tests GenoRing running mode detection and module hook execution.

=head1 DESCRIPTION

Verifies that:
- GetState() reads the running mode from the main container profiles instead of
  the current process environment;
- "disable" container hooks of a disabled module are run on services that
  remain enabled but not on the services of the disabled module;
- local hooks inherit the current environment, overridden by module
  environment files.

=cut

use strict;
use warnings;

use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/../../perllib";
use Genoring;
use Test::More tests => 13;

sub write_file {
  my ($path, $content) = @_;
  my (undef, $directory) = File::Spec->splitpath($path);
  make_path($directory) if $directory && !-d $directory;
  open(my $file, '>', $path) or die "Cannot create '$path': $!";
  print {$file} $content or die "Cannot write '$path': $!";
  close($file) or die "Cannot close '$path': $!";
}

local $g_exec_prefix = '';
my $output = '';
open(my $null_fh, '>', \$output) or die "Cannot redirect output: $!";

# GetState() reads the running mode from the main container.
{
  local $ENV{'COMPOSE_PROFILES'} = '';
  local $ENV{'COMPOSE_PROJECT_NAME'} = 'testproj';
  my $profiles = '';
  my @commands;
  no warnings 'redefine';
  local *Genoring::Run = sub {
    my ($command) = @_;
    push(@commands, $command);
    return ($command =~ m/\bexec\b/)
      ? $profiles
      : "testproj running\ntestproj-proxy running\n";
  };
  $profiles = 'backend';
  is(GetState(), 'backend', 'Backend mode is read from the main container');
  $profiles = 'offline';
  is(GetState(), 'offline', 'Offline mode is read from the main container');
  $profiles = 'prod';
  is(GetState(), 'running', 'Online mode is reported as running');
  $profiles = '';
  is(GetState(), 'running', 'Missing profiles are reported as running');
  ok((grep { m/\bexec testproj sh -c 'printf "\$COMPOSE_PROFILES"'/ } @commands), 'Profiles are read from the main container');

  @commands = ();
  local *Genoring::IsContainerRunning = sub { return ('id', 'running', 'testproj', 'image'); };
  $profiles = 'backend';
  is(GetState('testproj'), 'running', 'Container states do not include the running mode');
  ok(!(grep { m/\bexec\b/ } @commands), 'Container states do not query profiles');
}

my $modules_dir = tempdir(CLEANUP => 1);
local $Genoring::MODULES_DIR = $modules_dir;

# Disable container hooks of a disabled module.
{
  write_file(File::Spec->catfile($modules_dir, 'addon', 'hooks', 'disable_genoring.sh'), "#!/bin/sh\n");
  write_file(File::Spec->catfile($modules_dir, 'addon', 'hooks', 'disable_genoring-addon.sh'), "#!/bin/sh\n");
  my (@commands, @warnings);
  no warnings 'redefine';
  local *Genoring::GetModules = sub { return ['genoring']; };
  local *Genoring::GetServices = sub { return {'genoring' => 'genoring'}; };
  local *Genoring::GetModuleServices = sub {
    return ('addon' eq $_[0]) ? ['genoring-addon'] : ['genoring'];
  };
  local *Genoring::GetContainerName = sub { return "testproj-$_[0]"; };
  local *Genoring::IsContainerRunning = sub { return ('id', 'running', $_[0], 'image'); };
  local *Genoring::GetEnvironmentFiles = sub { return (); };
  local *Genoring::Run = sub { push(@commands, $_[0]); $? = 0; return ''; };
  local $SIG{__WARN__} = sub { push(@warnings, @_); };
  local *STDOUT = $null_fh;
  my $errors = ApplyContainerHooks('disable', ['addon'], 1);
  is_deeply($errors, {}, 'Disable container hooks succeed');
  ok(
    (grep { m~/genoring/modules/addon/hooks/disable_genoring\.sh~ } @commands),
    'Disable hook of a disabled module is run on a remaining service'
  );
  ok(
    !(grep { m~disable_genoring-addon\.sh~ } @commands),
    'Disable hook is not run on a service of the disabled module'
  );
  ok(
    (grep { m~Container hook 'addon/hooks/disable_genoring-addon\.sh' ignored~ } @warnings),
    'A warning is issued for hooks targeting a service of the disabled module'
  );
}

# Local hooks inherit the current environment.
{
  my $work_dir = tempdir(CLEANUP => 1);
  my $result_file = File::Spec->catfile($work_dir, 'env.txt');
  my $env_file = File::Spec->catfile($work_dir, 'addon_addon.env');
  write_file(
    File::Spec->catfile($modules_dir, 'addon', 'hooks', 'envtest.pl'),
    "open(my \$fh, '>', \$ENV{'RESULT_FILE'}) or die \$!;\n"
    . "print {\$fh} join(\"\\n\", map { \"\$_=\" . (\$ENV{\$_} // '') } qw(PATH GENORING_TEST_SHARED GENORING_TEST_PARENT)), \"\\n\";\n"
    . "close(\$fh);\n"
  );
  write_file($env_file, "RESULT_FILE=$result_file\nGENORING_TEST_SHARED=module\n");
  no warnings 'redefine';
  local *Genoring::GetEnvironmentFiles = sub { return ($env_file); };
  local $ENV{'GENORING_TEST_SHARED'} = 'parent';
  local $ENV{'GENORING_TEST_PARENT'} = 'parent';
  local *STDOUT = $null_fh;
  ApplyLocalHooks('envtest', 'addon');
  open(my $fh, '<', $result_file) or die "Cannot read '$result_file': $!";
  my %hook_env = map { chomp; split(/=/, $_, 2) } <$fh>;
  close($fh);
  is_deeply(
    \%hook_env,
    {
      'PATH' => $ENV{'PATH'},
      'GENORING_TEST_SHARED' => 'module',
      'GENORING_TEST_PARENT' => 'parent',
    },
    'Local hooks inherit the current environment, overridden by module values'
  );
  ok(!exists($ENV{'RESULT_FILE'}), 'Module environment does not leak after the hook');
}
