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

=cut

use strict;
use warnings;

use File::Find qw(find);
use File::Spec;
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

sub DiscoverTests {
  my @tests;
  find(
    {
      no_chdir => 1,
      wanted => sub {
        return unless -f $_ && /\.t\z/;
        my $path = File::Spec->abs2rel($File::Find::name, 't');
        my ($directory, $filename) = $path =~ m{^(?:(.*)/)?([^/]+)\.t\z};
        $directory = 'base' unless defined($directory) && length($directory);
        my $category = $directory;
        my $description = ReadTestName($File::Find::name);
        push @tests, {
          category => $category,
          name => $filename,
          id => "$category/$filename",
          description => $description,
          path => File::Spec->catfile('t', $path),
        };
      },
    },
    't',
  );
  return sort { $a->{id} cmp $b->{id} } @tests;
}

sub ReadTestName {
  my ($path) = @_;
  open(my $handle, '<', $path)
    or die "ERROR: Unable to read test '$path': $!\n";
  my $in_name = 0;
  while (my $line = <$handle>) {
    if ($line =~ /^=head1\s+NAME\s*$/) {
      $in_name = 1;
      next;
    }
    next unless $in_name;
    next if $line =~ /^\s*$/;
    close($handle);
    chomp($line);
    $line =~ s/^\s+|\s+$//g;
    $line =~ s/^\S+\s+-\s+//;
    return $line;
  }
  close($handle);
  return '(description unavailable)';
}

sub ListTests {
  my @tests = @_;
  my %categories;
  push @{ $categories{$_->{category}} }, $_ for @tests;
  for my $category (sort keys %categories) {
    print "$category:\n";
    for my $test (@{ $categories{$category} }) {
      print "  $test->{name} - $test->{description}\n";
    }
  }
}

sub SelectTests {
  my ($tests, $selection) = @_;
  return @$tests unless defined($selection) && length($selection);

  my %by_id = map { $_->{id} => $_ } @$tests;
  my %categories = map { $_->{category} => 1 } @$tests;
  my @selected;
  for my $item (split /,/, $selection) {
    $item =~ s/^\s+|\s+$//g;
    $item =~ s{/$}{};
    next unless length($item);
    if (exists $categories{$item}) {
      push @selected, grep { $_->{category} eq $item } @$tests;
      next;
    }
    $item =~ s{^base/}{};
    my $id = $item =~ m{/} ? $item : "base/$item";
    push @selected, $by_id{$id} if exists $by_id{$id};
  }
  my %seen;
  return grep { !$seen{$_->{id}}++ } @selected;
}

sub CleanTests {
  my ($selection, $force) = @_;
  my @instances = ListInstances();
  if (defined($selection) && length($selection)) {
    # Just remove the selected logs.
    RemoveInstanceLogs($selection);
    print "Logs cleared for instance $selection.\n";
    @instances = grep { $_ eq $selection } @instances;
    die "ERROR: Test instance '$selection' not found.\n" unless @instances;
  }
  else {
    # If no selection is provided, we can remove all the logs.
    RemoveInstanceLogs();
    print "Logs cleared.\n";
  }
  return print "No test instances to remove.\n" unless @instances;
  unless ($force) {
    print "Remove ", scalar(@instances), " test instance(s)? [y/N] ";
    my $answer = <STDIN> // '';
    return print "Cleanup cancelled.\n" unless $answer =~ /^y\s*\z/i;
  }
  RemoveInstances(@instances);
}

sub usage {
    my ($code, $message) = @_;
    print STDERR "$message\n" if $message;
    print <<'USAGE';
Usage: perl tests/test.pl [CATEGORY | TEST[,TEST...]] [OPTIONS]

Options:
  --clean              Remove old test instances (all, or an instance name).
    --force              Do not ask for confirmation with --clean.
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
USAGE
    exit($code);
}
