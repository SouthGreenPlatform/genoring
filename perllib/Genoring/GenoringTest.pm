=pod

=head1 NAME

GenoRing - Contains GenoRing Perl Test Library

=head1 SYNOPSIS

use Genoring::GenoringTest;

=head1 REQUIRES

Perl5

=head1 DESCRIPTION

This module contains GenoRing test library functions.

=cut

package Genoring::GenoringTest;

require 5.8.0;
use strict;
use warnings;
use utf8;
use Cwd qw(abs_path);
use Data::Dumper;
use Fcntl qw(O_CREAT O_EXCL O_WRONLY);
use File::Basename qw(basename dirname);
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Spec;
use IO::Handle;
use IO::Select;
use IO::Socket::INET;
use IPC::Open3 qw(open3);
use POSIX qw(strftime WNOHANG);
use Time::HiRes qw(sleep time);
use lib "..";
use Genoring;

use base qw(Exporter);
our @EXPORT = qw(
  GetNewInstance InitializeInstance ListInstances RemoveInstances
  RemoveInstanceLogs RunGenoring
);




# Package constants
####################

=pod

=head1 CONSTANTS

B<$TEST_DIR>: (string)

Name of the test directory root.

B<$TEMP_TEST_DIR>: (string)

Name of the test directory containing GenoRing temporary test instances.

B<$RANDOM_PART_LENGTH>: (integer)

Length of the random part in instance names.

B<$BASE_PORT>: (integer)

Base HTTP port to use for proxy. It may be changed automatically if not
available on host.

B<$DEFAULT_MAX_EXECUTION_TIME>: (integer)

Default maximum external script execution time in seconds.

=cut

our $GENORING_DIR = abs_path(File::Spec->catdir(dirname(__FILE__), '..', '..'));
our $TEST_DIR = File::Spec->catdir($GENORING_DIR, 'tests');
our $TEMP_TEST_DIR = 'temptests';
# Make sure $TEMP_TEST_DIR is available as expected.
if (!-d $TEMP_TEST_DIR) {
  die "ERROR: Test directory '$TEMP_TEST_DIR' not found in current directory.\n";
}
elsif (!-r $TEMP_TEST_DIR) {
  die "ERROR: Test directory '$TEMP_TEST_DIR' is not readable.\n";
}
elsif (!-w $TEMP_TEST_DIR) {
  die "ERROR: Test directory '$TEMP_TEST_DIR' is not writable.\n";
}
our $RANDOM_PART_LENGTH = 8;
our $BASE_PORT = 8180;
our $DEFAULT_MAX_EXECUTION_TIME = 180;




# Package subs
###############

=pod

=head1 FUNCTIONAL INTERFACE

=head2 GetNewInstance

B<Description>: Returns the name of a new test instance and creates its
directory.

B<ArgsCount>: 0

B<Return>: (string)

The new test instance name.

=cut

sub GetNewInstance {
  my $test_name;
  my $instance_dir;
  my @alphabet = ('a' .. 'z', 0 .. 9);
  do {
    my $suffix = join('', map { $alphabet[rand(@alphabet)] } 1 .. $RANDOM_PART_LENGTH);
    $test_name = 'test' . $suffix;
    $instance_dir = File::Spec->catdir($TEMP_TEST_DIR, $test_name);

  } while (-e $instance_dir);
  if (!mkdir $instance_dir) {
    die "ERROR: Failed to create test directory '$instance_dir'.\n$!";
  }
  return $test_name;
}


=pod

=head2 InitializeInstance

B<Description>: Runs Genoring to initialize a test instance with the given
configuration.

B<ArgsCount>: 1-2

=over 4

=item $instance_name: (string) (R)

Instance name.

=item $config: (hash) (U)

A pre-configuration for the instance.

=back

B<Return>: (boolean)

1 (true) if an error occurred, 0 (false) otherwise.

=cut

sub InitializeInstance {
  my ($instance_name, $config) = @_;

  # Create default env files.
  my $instance_dir = File::Spec->catdir($TEMP_TEST_DIR, $instance_name);
  my $default_env_dir = File::Spec->catdir($TEST_DIR, 'data', 'default_env');
  my $instance_env_dir = File::Spec->catdir($instance_dir, 'env');
  make_path($instance_env_dir)
    unless -d $instance_env_dir;
  CopyDirectory($default_env_dir, $instance_env_dir);

  SetAvailablePort($instance_env_dir);
  SetEnvironmentVariables($instance_env_dir, $config->{env}) if $config && $config->{env};

  my $io = {
    'GenoRing was not started in that directory before.' => "y\n",
  };

  return RunGenoring($instance_name, ['start'], $io);
}


=pod

=head2 SetAvailablePort

B<Description>: Finds the next available port on the host to expose tests
instance HTTP port, and sets it in the environment file.

B<ArgsCount>: 1

=over 4

=item $instance_env_dir: (string) (R)

Name of the test instance environment directory.

=back

B<Return>: (nothing)

=cut

sub SetAvailablePort {
  my ($instance_env_dir) = @_;

  my $port = $BASE_PORT;
  $port++ until IsPortAvailable($port);

  SetEnvironmentVariables(
    $instance_env_dir,
    {
      'genoring_genoring' => {
        GENORING_PORT => $port,
      },
    }
  );
}


=pod

=head2 SetEnvironmentVariables

B<Description>: Sets values for a given set of environment variables of a set of
environment files.

B<ArgsCount>: 2

=over 4

=item $instance_env_dir: (string) (R)

Name of the test instance environment directory.

=item $environment: (hashref) (R)

First level keys are environment categories (ie. environment file names wiythout
".env" extension), and second level keys are environment variable names with
their associated values.

=back

B<Return>: (nothing)

=cut

sub SetEnvironmentVariables {
  my ($instance_env_dir, $environment) = @_;
  return unless $environment && 'HASH' eq ref($environment);

  for my $env_category (keys %$environment) {
    my $env_file = File::Spec->catfile($instance_env_dir, "$env_category.env");
    open(my $input, '<', $env_file)
      or die "ERROR: Unable to read '$env_file': $!\n";
    local $/;
    my $content = <$input>;
    close($input);

    my $variables = $environment->{$env_category};
    die "ERROR: Environment variables for '$env_category' must be a hashref.\n"
      unless 'HASH' eq ref($variables);
    for my $variable (keys %$variables) {
      my $value = $variables->{$variable};
      $value = '' unless defined $value;
      my $replaced = $content =~ s/^(\Q$variable\E\s*=).*\R/$1$value\n/m;
      die "ERROR: $variable not found in '$env_file'.\n" unless $replaced;
    }

    open(my $output, '>', $env_file)
      or die "ERROR: Unable to write '$env_file': $!\n";
    print {$output} $content
      or die "ERROR: Unable to write '$env_file': $!\n";
    close($output)
      or die "ERROR: Unable to close '$env_file': $!\n";
  }
}


=pod

=head2 IsPortAvailable

B<Description>: Tells if the given port is free (avaible) on current host.

B<ArgsCount>: 1

=over 4

=item $port: (string) (R)

The port number to test.

=back

B<Return>: (boolean)

True (1) if the port is available, false (0) otherwise.

=cut

sub IsPortAvailable {
  my ($port) = @_;
  my $socket = IO::Socket::INET->new(
    LocalAddr => '0.0.0.0',
    LocalPort => $port,
    Proto     => 'tcp',
    ReuseAddr => 0,
  );
  return 0 unless $socket;
  close($socket);
  return 1;
}


=pod

=head2 ListInstances

B<Description>: Lists all the existing instances.

B<Return>: (list)

The list of existing test instances.

=cut

sub ListInstances {
  my @instance_names;
  opendir(my $handle, $TEMP_TEST_DIR)
    or die "Unable to read test directory '$TEMP_TEST_DIR: $!\n";
  while (my $element = readdir($handle)) {
    if (($element =~ /^test[A-Za-z0-9]{$RANDOM_PART_LENGTH}$/)
      && (-d File::Spec->catdir($TEMP_TEST_DIR, $element))
    ) {
      push(@instance_names, $element);
    }
  }
  return @instance_names;
}


=pod

=head2 RemoveInstances

B<Description>: Remove the given test instances or all the existing instances.

B<ArgsCount>: 1

=over 4

=item $instance_names: (array) (O)

List of instance names to remove. If not provided, all existing instances will
be removed.

=back

B<Return>: (boolean)

1 (true) if an error occurred, 0 (false) otherwise.

=cut

sub RemoveInstances {
  my @instance_names = @_;
  my %all_instances_hash = map { $_ => 1 } ListInstances();
  if (!@instance_names) {
    @instance_names = keys(%all_instances_hash);
  }
  @instance_names = grep { exists $all_instances_hash{$_} } @instance_names;
  return print "No test directories to remove.\n" unless @instance_names;
  for my $instance_name (@instance_names) {
    my $directory = abs_path(File::Spec->catdir($TEMP_TEST_DIR, $instance_name));
    die "Unable to resolve test directory '$instance_name'.\n"
      unless defined($directory);
    my $parent_directory = dirname($directory);
    my $directory_name = basename($directory);

    my @command = (
      'docker', 'run', '--rm', '--user', '0:0',
      '--mount', "type=bind,source=$parent_directory,destination=/tests",
      'alpine:latest', 'rm', '-rf', "/tests/$directory_name",
    );
    print "Removing $directory using Docker.\n";
    my $status = system(@command);
    if ($status == -1 || ($status >> 8)) {
      my $exit_code = $status == -1 ? 'unavailable' : ($status >> 8);
      die "Unable to remove $directory using Docker (exit code: $exit_code).\n";
    }
    print "Removed $directory\n";
  }
  return 0;
}


=pod

=head2 RemoveInstanceLogs

B<Description>: Removes logs for the given test instances or all test instance
logs.

B<ArgsCount>: 1

=over 4

=item $instance_names: (array) (O)

List of instance names whose logs should be removed. If not provided, all log
files are removed.

=back

B<Return>: (boolean)

1 (true) if an error occurred, 0 (false) otherwise.

=cut

sub RemoveInstanceLogs {
  my @instance_names = @_;
  my $logs_dir = File::Spec->catdir($TEST_DIR, $TEMP_TEST_DIR, 'logs');
  return 0 unless -d $logs_dir;

  opendir(my $handle, $logs_dir)
    or die "Unable to read log directory '$logs_dir': $!\n";
  my @log_files = grep { /\.log\z/ && -f File::Spec->catfile($logs_dir, $_) }
    readdir($handle);
  closedir($handle);

  if (@instance_names) {
    @log_files = grep {
      my $log_file = $_;
      grep { $log_file =~ /^\Q$_\E.*\.log\z/ } @instance_names;
    } @log_files;
  }

  for my $log_file (@log_files) {
    my $path = File::Spec->catfile($logs_dir, $log_file);
    unlink($path)
      or die "Unable to remove log file '$path': $!\n";
  }
  return 0;
}


=pod

=head2 RunGenoring

B<Description>: Runs Genoring with the given arguments for the given instance.

B<ArgsCount>: 2

=over 4

=item $instance_name: (string) (R)

Instance name.

=item $args: (string) (R)

GenoRing command arguments.

=back

B<Return>: (boolean).

1 (true) if an error occurred, 0 (false) otherwise.

=cut

sub RunGenoring {
  my ($instance_name, $args, $io, $max_execution_time) = @_;
  $args ||= [];
  if ('ARRAY' ne ref($args)) {
    $args = [$args];
  }
  $io ||= {};
  $max_execution_time ||= $DEFAULT_MAX_EXECUTION_TIME;

  my $instance_dir = abs_path(File::Spec->catfile($TEMP_TEST_DIR, $instance_name));
  my $genoring_script = File::Spec->catfile($GENORING_DIR, 'genoring.pl');
  # Run into instance directory.
  chdir($instance_dir) or die "ERROR: Unable to enter instance directory: $!";
  # Prepare environment variables for the instance.
  local $ENV{'PWD'} = $instance_dir;
  local $ENV{'COMPOSE_FILE'} = undef;
  local $ENV{'COMPOSE_PROJECT_NAME'} = $instance_name;
  local $ENV{'COMPOSE_PROFILES'} = undef;
  local $ENV{'GENORING_HOST'} = undef;
  local $ENV{'GENORING_PORT'} = undef;
  local $ENV{'GENORING_VOLUMES_DIR'} = undef;
  local $ENV{'GENORING_NO_EXPOSED_VOLUMES'} = undef;

  my @command = ($^X, $genoring_script, @$args);
  my ($stdout, $stderr) = ('', '');
  my $logs_dir = File::Spec->catdir($TEST_DIR, $TEMP_TEST_DIR, 'logs');
  make_path($logs_dir) unless -d $logs_dir;
  my $log_basename = $instance_name . '_' . strftime('%Y%m%d-%H%M%S', localtime);
  my $log_file = File::Spec->catfile($logs_dir, $log_basename . '.log');
  for my $suffix_index (0 .. 26) {
    my $candidate = File::Spec->catfile(
      $logs_dir,
      $log_basename . ($suffix_index ? chr(ord('a') + $suffix_index - 1) : '') . '.log',
    );
    if (sysopen(my $candidate_fh, $candidate, O_WRONLY | O_CREAT | O_EXCL)) {
      close($candidate_fh);
      $log_file = $candidate;
      last;
    }
    die "ERROR: Unable to create log file '$candidate': $!\n"
      unless $!{EEXIST};
    die "ERROR: Too many log files for '$log_basename'.\n"
      if $suffix_index == 26;
  }

  open(my $log_fh, '>>', $log_file)
    or die "ERROR: Unable to open log file '$log_file': $!\n";
  $log_fh->autoflush(1);
  my %log_buffers;
  my $log_lines = sub {
    my ($prefix, $text) = @_;
    $log_buffers{$prefix} .= $text;
    while ($log_buffers{$prefix} =~ s/^(.*?\n)//) {
      print {$log_fh} $prefix . $1;
    }
  };
  my $flush_log = sub {
    for my $prefix (keys %log_buffers) {
      if (length($log_buffers{$prefix})) {
        print {$log_fh} $prefix . $log_buffers{$prefix} . "\n";
        $log_buffers{$prefix} = '';
      }
    }
  };
  $log_lines->('COMMAND: ', join(' ', @command) . "\n");

  my ($child_stdin, $child_stdout, $child_stderr);
  my $pid = open3(
    $child_stdin,
    $child_stdout,
    $child_stderr,
    @command,
  );
  $child_stdin->autoflush(1);

  my $selector = IO::Select->new($child_stdout, $child_stderr);
  my $stdout_buffer = '';
  my $stderr_buffer = '';
  my $deadline = time + $max_execution_time;
  my $timed_out = 0;
  my $child_reaped = 0;
  my $child_status;
  while (1) {
    my $remaining = $deadline - time;
    if ($remaining <= 0) {
      $timed_out = 1;
      print "ERROR: genoring.pl exceeded the $max_execution_time-second timeout.\n";
      kill 'KILL', $pid;
      last;
    }

    unless ($child_reaped) {
      my $waited_pid = waitpid($pid, WNOHANG);
      if ($waited_pid == $pid) {
        $child_reaped = 1;
        $child_status = $?;
      }
    }
    last if !$selector->count && $child_reaped;
    if (!$selector->count) {
      sleep($remaining < 0.1 ? $remaining : 0.1);
      next;
    }

    my @ready = $selector->can_read($remaining);
    if (!@ready) {
      $timed_out = 1;
      print "ERROR: genoring.pl exceeded the $max_execution_time-second timeout.\n";
      kill 'KILL', $pid;
      last;
    }
    foreach my $handle (@ready) {
      my $buffer = fileno($handle) == fileno($child_stdout)
        ? \$stdout_buffer
        : \$stderr_buffer;
      my $bytes = sysread($handle, my $chunk, 4096);
      die "ERROR: Unable to read genoring.pl output: $!\n"
        unless defined($bytes);
      if (!$bytes) {
        $selector->remove($handle);
        close($handle);
        next;
      }

      $$buffer .= $chunk;
      if (fileno($handle) == fileno($child_stdout)) {
        $stdout .= $chunk;
        $log_lines->('STDOUT: ', $chunk);
        print "Output: $chunk";
        if (exists($io->{$chunk})) {
          $flush_log->();
          print {$child_stdin} $io->{$chunk};
          $child_stdin->flush;
          $log_lines->('STDIN : ', $io->{$chunk});
        }
        else {
          foreach my $question (keys %$io) {
            if (index($chunk, $question) >= 0) {
              $flush_log->();
              print {$child_stdin} $io->{$question};
              $child_stdin->flush;
              $log_lines->('STDIN : ', $io->{$question});
            }
          }
        }

      }
      else {
        $stderr .= $chunk;
        $log_lines->('STDERR: ', $chunk);
        print "Error: $chunk";
      }
    }
  }
  close($child_stdin);
  unless ($child_reaped) {
    waitpid($pid, 0);
    $child_status = $?;
  }
  my $exit_status = $child_status >> 8;
  $exit_status = 1 if $child_status == -1 || ($child_status & 127);
  $exit_status = 124 if $timed_out;
  $flush_log->();
  $log_lines->('CODE: ', $exit_status);
  close($log_fh);

  my $interrupted = 0;
  foreach my $line (split(/\n/, $stdout)) {
    unless (grep { $line =~ /\Q$_\E/ } keys %$io) {
      if ($line =~ /\?\s*$/) { # Détecte une question (se termine par "?")
        print "ERROR: Unexpected question: $line\n";
        $interrupted = 1;
        last;
      }
    }
  }

  # Go back to test directory root.
  chdir($Genoring::GenoringTest::TEST_DIR) or die "ERROR: Unable to go back to test directory: $!";

  return $interrupted || $exit_status;
}




=pod

=head1 AUTHORS

Valentin GUIGNON (The Alliance Bioversity - CIAT), v.guignon@cgiar.org

=head1 VERSION

Version 1.0

Date 03/09/2026

=head1 SEE ALSO

GenoRing documentation.

=cut

return 1; # package return
