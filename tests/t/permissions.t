#!/usr/bin/env perl

=pod

=head1 NAME

permissions.t - Tests the restriction of instance sensitive file permissions.

=head1 DESCRIPTION

Verifies that SecureInstanceFiles() restricts the access to the "env" directory
and its files, to the GenoRing backup directory and to the generated Docker
Compose file, that it leaves already restricted permissions unchanged, that it
does nothing on Windows and that it warns when the file system ignores Unix
permissions.

=cut

use strict;
use warnings;

use Cwd qw(getcwd);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin;
use Test::More;

# Allows to simulate a file system that ignores Unix permissions.
our $g_ignore_chmod = 0;
BEGIN {
  *CORE::GLOBAL::chmod = sub {
    return $main::g_ignore_chmod ? scalar(@_) - 1 : CORE::chmod($_[0], @_[1..$#_]);
  };
}

use lib "$FindBin::Bin/../../perllib";
use Genoring;

if ('Win32' eq GetOs()) {
  plan skip_all => 'Unix permissions are not supported on Windows.';
}
plan tests => 14;

sub write_file {
  my ($path, $mode) = @_;
  open(my $fh, '>', $path) or die "Cannot create '$path': $!";
  print {$fh} "SECRET=value\n";
  close($fh);
  chmod($mode, $path) or die "Cannot set '$path' permissions: $!";
}

sub get_mode {
  my ($path) = @_;
  return (stat($path))[2] & 07777;
}

# Creates an instance with sensitive files readable by everybody.
sub create_instance {
  my $instance_dir = tempdir(CLEANUP => 1);
  make_path("$instance_dir/env", "$instance_dir/$Genoring::SYSBACKUPS_DIR");
  chmod(0755, "$instance_dir/env", "$instance_dir/$Genoring::SYSBACKUPS_DIR");
  write_file("$instance_dir/env/genoring_genoring.env", 0644);
  write_file("$instance_dir/env/ssl_ssl.env", 0400);
  write_file("$instance_dir/$Genoring::DOCKER_COMPOSE_FILE", 0664);
  return $instance_dir;
}

my $original_dir = getcwd();
local $g_exec_prefix = '';

# Unix permissions are restricted when needed.
{
  my $instance_dir = create_instance();
  chdir($instance_dir) or die "Cannot change to '$instance_dir': $!";
  my @warnings;
  local $SIG{__WARN__} = sub { push(@warnings, @_); };
  ok(SecureInstanceFiles(), 'Sensitive files are restricted');
  is(sprintf('%04o', get_mode('env')), '0700', 'env directory is restricted');
  is(sprintf('%04o', get_mode('env/genoring_genoring.env')), '0600', 'Environment file is restricted');
  is(sprintf('%04o', get_mode('env/ssl_ssl.env')), '0400', 'Already restricted permissions are kept');
  is(sprintf('%04o', get_mode($Genoring::SYSBACKUPS_DIR)), '0700', 'Backup directory is restricted');
  is(sprintf('%04o', get_mode($Genoring::DOCKER_COMPOSE_FILE)), '0600', 'Docker Compose file is restricted');
  is(scalar(@warnings), 0, 'No warning');
  chdir($original_dir);
}

# Missing paths are ignored.
{
  my $instance_dir = tempdir(CLEANUP => 1);
  chdir($instance_dir) or die "Cannot change to '$instance_dir': $!";
  ok(SecureInstanceFiles(), 'Missing paths are ignored');
  ok(!-e 'env' && !-e $Genoring::SYSBACKUPS_DIR, 'Missing paths are not created');
  chdir($original_dir);
}

# Nothing is done on Windows.
{
  my $instance_dir = create_instance();
  chdir($instance_dir) or die "Cannot change to '$instance_dir': $!";
  no warnings 'redefine';
  local *Genoring::GetOs = sub { return 'Win32'; };
  ok(SecureInstanceFiles(), 'Windows permissions are not managed');
  is(sprintf('%04o', get_mode('env/genoring_genoring.env')), '0644', 'Permissions are not changed on Windows');
  chdir($original_dir);
}

# File systems ignoring Unix permissions raise a warning.
{
  my $instance_dir = create_instance();
  chdir($instance_dir) or die "Cannot change to '$instance_dir': $!";
  my @warnings;
  local $SIG{__WARN__} = sub { push(@warnings, @_); };
  local $g_ignore_chmod = 1;
  ok(!SecureInstanceFiles(), 'Unsupported permissions are reported');
  is(scalar(@warnings), 1, 'A single warning is issued');
  like(
    $warnings[0] // '',
    qr/could not be restricted.*\n  env\n  env\/genoring_genoring\.env\n  \Q$Genoring::SYSBACKUPS_DIR\E\n  \Q$Genoring::DOCKER_COMPOSE_FILE\E\n/s,
    'The warning lists unrestricted paths'
  );
  chdir($original_dir);
}
