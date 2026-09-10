#!/usr/bin/env perl

=pod

=head1 NAME

upgrade.t - Tests GenoRing upgrade system.

=head1 DESCRIPTION

Tests GenoRing upgrade system.

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
use Genoring;
use Genoring::GenoringTest;
use Test::More tests => 7;
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
my $config_file = File::Spec->catfile($instance_dir, 'config.yml');
ok(-e $config_file, "Expected file/directory exists: $config_file");

# Regression test: failing module upgrade hook must mark operation as failed.
my $upgrade_tmp_dir = File::Spec->catdir($Genoring::GenoringTest::TEST_DIR, $Genoring::GenoringTest::TEMP_TEST_DIR, 'upgrade-hook-failure');
remove_tree($upgrade_tmp_dir) if -d $upgrade_tmp_dir;
my $upgrade_module_dir = File::Spec->catdir($upgrade_tmp_dir, 'modules', 'fake');
make_path(File::Spec->catdir($upgrade_module_dir, 'hooks'));
my $upgrade_hook = File::Spec->catfile($upgrade_module_dir, 'hooks', 'upgrade.pl');
open(my $hook_fh, '>', $upgrade_hook) or die "Unable to create $upgrade_hook: $!";
print {$hook_fh} "#!/usr/bin/env perl\nexit 1;\n";
close($hook_fh);
chmod 0755, $upgrade_hook;
my $previous_modules_dir = $Genoring::MODULES_DIR;
my $previous_genoring_dir = $Genoring::GENORING_DIR;
$Genoring::MODULES_DIR = File::Spec->catdir($upgrade_tmp_dir, 'modules');
$Genoring::GENORING_DIR = $upgrade_tmp_dir;
my $upgrade_context = {
  'operation_mode' => 'offline',
  'current_mode' => 'offline',
  'local_hooks' => {
    'upgrade' => { 'args' => '1.0 1.1 fake' },
  },
  'module' => 'fake',
};
PerformLocalOperations($upgrade_context);
ok(exists($upgrade_context->{'failed'}), 'Failed upgrade hook marks operation context as failed');
$Genoring::MODULES_DIR = $previous_modules_dir;
$Genoring::GENORING_DIR = $previous_genoring_dir;
remove_tree($upgrade_tmp_dir) if -d $upgrade_tmp_dir;

# Cleanups test instance.
SKIP: {
  skip 'Test instance cleaning disabled', 1 if $ENV{'GENORING_TEST_KEEP_INSTANCES'};
  ok(0 == RemoveInstances($instance), 'Instance removed');
}
