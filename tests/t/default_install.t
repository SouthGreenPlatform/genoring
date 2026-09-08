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
use Test::More tests => 5;
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

# Cleanups test instance.
SKIP: {
  skip 'Test instance cleaning disabled', 1 if $ENV{'GENORING_TEST_KEEP_INSTANCES'};
  ok(0 == RemoveInstances($instance), 'Instance removed');
}
