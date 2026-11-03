#!/usr/bin/env perl

=pod

=head1 NAME

run_quotes.t - Tests command quote handling in debug mode.

=head1 DESCRIPTION

Verifies that Run() preserves shell quoting when displaying command output in
debug mode.

=cut

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../perllib";
use Genoring;
use Test::More tests => 1;

my $expected = "/tmp/archive stage:/source:ro\n";
my $command = "printf '%s\\n' '/tmp/archive stage:/source:ro'";
my $output;

{
  local $g_debug = 1;
  local *STDOUT;
  open(STDOUT, '>', \$output) or die "Unable to capture output: $!\n";
  is(Run($command, '', 1, 0), $expected, 'Single-quoted arguments remain intact in debug mode');
}
