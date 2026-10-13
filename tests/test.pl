#!/usr/bin/env perl

=pod

=head1 NAME

test.pl - Run GenoRing framework regression test runner.

=head1 SYNOPSIS

    perl test.pl [TEST_NAME] [OPTIONS]
    perl test.pl --clean [TEST_NAME] [--force]

=head1 DESCRIPTION

Manages regression tests. It can be used to run all or a set of regression
tests, as well as to clean up tests artifacts.

Tests are defined in the "t" subdirectory.

GenoRing test instances are generated into the "temptests" subdirectory. Each
instance has its own sub-directory starting with "test" followed by a random
string.

Note: To run accurate tests, you may need to rebuild Docker images used by
GenoRing before running the tests. This can be done by using the GenoRing
"build" command with the "-no-cache" option:

    perl genoring.pl build -no-cache <module> <service>

=cut

use strict;
use warnings;

use FindBin;
use Getopt::Long qw(GetOptions);
use lib "$FindBin::Bin/../perllib";
use Genoring::GenoringTest;

chdir($Genoring::GenoringTest::TEST_DIR)
  or die "ERROR: Unable to enter test directory: $!\n";

my $clean = 0;
my $force = 0;
my $dry_run = 0;
my $list = 0;
my $help = 0;

GetOptions(
  'clean'    => \$clean,
  'force'    => \$force,
  'dry-run'  => \$dry_run,
  'list'     => \$list,
  'help|?'   => \$help,
) or usage(1);

usage(0) if $help;

usage(1, 'Unexpected option combination.') if $clean && $list;
usage(1, '--force and --dry-run cannot be combined.') if $force && $dry_run;

my $selection = shift(@ARGV);
usage(1, 'Unexpected arguments.') if @ARGV;

if ($clean) {
  CleanTests($selection, $force);
  exit(0);
}

my @tests = DiscoverTests();
if ($list) {
  ListTests(@tests);
  exit(0);
}

my @selected_tests = SelectTests(\@tests, $selection);
usage(1, "No tests match '$selection'.") if $selection && !@selected_tests;
usage(1, 'No test files were found.') unless @tests;

my @paths = map { $_->{path} } @selected_tests;
my @command = ('prove', '-I../perllib', @paths);
print "COMMAND: ", join(' ', @command), "\n" if $dry_run;
exit(0) if $dry_run;

my $status = system(@command);
exit($status == -1 ? 1 : ($status >> 8));

=pod

=head2 usage

B<Description>: Displays an optional error message on standard error, then the
script usage help on standard output, and exits the script with the given
code.

B<ArgsCount>: 0-2

=over 4

=item $code: (integer) (U)

The exit code (i.e. 0 for a help request, 1 for an error). Defaults to 0 if
not provided.

=item $message: (string) (U)

An optional error message to display on standard error before the usage.

=back

B<Return>: (nothing)

=cut

sub usage {
    my ($code, $message) = @_;
    print STDERR "$message\n" if $message;
    print <<'___USAGE___';
Usage: perl tests/test.pl [CATEGORY | TEST[,TEST...]] [OPTIONS]

Options:
  --clean              Remove old test instances (all, or an instance name).
    --force            Do not ask for confirmation with --clean.
  --dry-run            Show the prove command without running it.
  --list               List tests grouped by category and their descriptions.
  --help               Show this help.

Examples:
  perl tests/test.pl
  perl tests/test.pl base
  perl tests/test.pl base/default_install
  perl tests/test.pl base/default_install,other/test
  perl tests/test.pl --list
  perl tests/test.pl --clean --force
___USAGE___
    exit($code);
}
