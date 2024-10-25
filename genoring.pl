#!/usr/bin/env perl

=pod

=head1 NAME

genoring.pl - Manages GenoRing platform.

=head1 SYNOPSIS

    ./genoring.pl start

=head1 REQUIRES

Perl5

=head1 DESCRIPTION

Manages GenoRing platform. This script can be used to start, update, stop,
reinstall GenoRing, get informations on current GenoRing instance and compile
GenoRing module containers.

=cut

use strict;
use warnings;
use utf8;

# Note: we use CPAN YAML parser because it is a core PERL module. We could have
# used YAML::Tiny but it would have required either a user-side installation
# (while we want to minimize the requirements!) or it should have been
# distributed with the GenoRing package which is not possible due to
# incompatible license (MIT licensed projects -GenoRing- can not include GPL or
# artistic licensed projects while the opposit is possible, ie. GenoRing can
# be more easily integrated into other projects).
# For our uses here, the CPAN YAML parser should be enough.
use CPAN::Meta::YAML;
use Env;
use File::Basename;
use File::Copy;
use Pod::Usage;
use Time::Piece;

++$|; #no buffering




# Script global constants
##########################

=pod

=head1 CONSTANTS

B<$GENORING_VERSION>: (string)

Current script version.

B<$BASEDIR>: (string)

Installation directory of GenoRing.

B<$DOCKER_COMPOSE_FILE>: (string)

Name of the Docker Compose file.

B<$MODULE_FILE>: (string)

Name of the module config file.

B<$MODULE_DIR>: (string)

Name of the module directory.

B<$EXTRA_HOSTS>: (string)

Name of the extra hosts config file that contains service names replaced by
local hosts (IPs).

B<$STATE_MAX_TRIES>: (integer)

Maximum number of seconds to wait for a service to be ready (running).

=cut

our $GENORING_VERSION = '1.0';
our $BASEDIR = dirname(__FILE__);
our $DOCKER_COMPOSE_FILE = 'docker-compose.yml';
our $MODULE_FILE = 'modules.yml';
our $MODULE_DIR = 'modules';
our $EXTRA_HOSTS = 'extra_hosts.yml';
our $STATE_MAX_TRIES = 120;




# Script global variables
##########################

=pod

=head1 VARIABLES

B<$g_debug>: (boolean)

When set to true, it enables debug mode. This constant can be set at script
start by command line options.

B<$g_flags>: (hash ref)

Contains flags set on command line with their values if set or "1" otherwise.

B<$_g_modules>: (hash ref)

Cache variable for module lists. See GetModules(). Should not be used directly.

B<$_g_services>: (hash ref)

Cache variable for services lists. See GetServices(). Should not be used directly.

B<$_g_volumes>: (hash ref)

Cache variable for volumes lists. See GetVolumes(). Should not be used directly.

=cut

our $g_debug = 0;
our $g_flags = {};
our $_g_modules = {};
our $_g_services = {};
our $_g_volumes = {};




# Script global functions
##########################

=pod

=head1 FUNCTIONS

=head2 Run

B<Description>: Runs a shell command and displays a message in case of error. If
$fatal_error is TRUE, calls die() and use warn() otherwise.

B<ArgsCount>: 3

=over 4

=item $command: (string) (R)

The command line to execute.

=item $error_message: (string) (U)

The error message to display in case of error. Do not prefix it with 'ERROR' or
'WARNING' as it will be automatically managed in this routine.

=item $fatal_error: (string) (O)

If TRUE, the error is fatal and the script should die. Otherwise, just warn.

=back

B<Return>: (nothing)

=cut

sub Run {
  my ($command, $error_message, $fatal_error) = @_;

  # Get caller.
  my ($package, $filename, $line, $subroutine) = caller(1);
  $subroutine = $subroutine ? $subroutine . ': ' : '';
  $subroutine =~ s/^main:://;

  if (!$command) {
    # Die on logic errors.
    die "ERROR: ${subroutine} Run: No command to run!";
  }
  if ($g_debug) {
    print "COMMAND: $command\n";
  }

  $error_message ||= 'Execution failed!';
  $error_message = ($fatal_error ? 'ERROR: ' : 'WARNING: ')
    . $subroutine
    . $error_message;

  my $failed = system($command);

  if ($failed) {
    if ($? == -1) {
      $error_message = "$error_message (error $?)\n$!";
    }
    elsif ($? & 127) {
      $error_message = "$error_message\n"
        . sprintf(
          "Child died with signal %d, %s coredump\n",
          ($? & 127), ($? & 128) ? 'with' : 'without'
        );
    }
    else {
      $error_message = "$error_message " . sprintf("(error %d)", $? >> 8);
    }

    if ($fatal_error) {
      die($error_message);
    }
    else {
      warn($error_message);
    }
  }
}

=pod

=head2 StartGenoring

B<Description>: Starts GenoRing platform in the given mode (default: 'normal').

B<ArgsCount>: 0-1

=over 4

=item $mode: (string) (O)

Running mode. Must be one of:
- normal: starts normally (ie. dev|staging|prod|backend mode).
- backend: only starts "backend".
- offline: only starts "offline" service.
- backoff: starts in "backend" mode with "offline" service as frontend.
Default: "normal".

=back

B<Return>: (nothing)

=cut

sub StartGenoring {
  # Get running mode.
  my ($mode) = @_;
  if ($mode && ($mode !~ m/^(?:normal|backend|offline|backoff)$/)) {
    die "ERROR: StartGenoring: Invalid starting mode: '$mode'! Valid mode should be one of 'normal', 'backend', 'offline' or 'backoff'.\n";
  }
  # Set COMPOSE_PROFILES according to the selected environment.
  if (!$mode || ($mode eq 'normal')) {
    # Get site environment.
    $mode = 'normal';
    $ENV{'COMPOSE_PROFILES'} = GetProfile();
  }
  elsif ($mode eq 'backend') {
    $ENV{'COMPOSE_PROFILES'} = 'backend';
  }
  elsif ($mode eq 'offline') {
    $ENV{'COMPOSE_PROFILES'} = 'offline';
  }
  elsif ($mode eq 'backoff') {
    $ENV{'COMPOSE_PROFILES'} = 'backend,offline';
  }
  # Check that genoring docker is not already running.
  my ($id, $state, $name, $image) = IsContainerRunning('genoring');
  if (!$state || ($state !~ m/running/)) {
    ApplyLocalHooks('start');
    # Not running, start it.
    Run(
      "docker compose up -d" . (exists($g_flags->{'arm'}) ? ' --platform linux/amd64 2>&1' : ''),
      "Failed to start GenoRing ($mode mode)!",
      1
    );
  }
}

=pod

=head2 StopGenoring

B<Description>: Stops GenoRing platform by calling docker compose down.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub StopGenoring {
  Run(
    "docker compose --profile '*' down --remove-orphans",
    "Failed to stop GenoRing!",
    1
  );
  ApplyLocalHooks('stop');
}

=pod

=head2 GetLogs

B<Description>: Displays GenoRing logs. If the "-f" flag is used, follows logs.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub GetLogs {
  if (exists($g_flags->{'f'})) {
    Run(
      "docker compose --profile '*' logs -f",
      "Failed to GenoRing logs!",
    );
  }
  else {
    Run(
      "docker compose logs",
      "Failed to GenoRing logs!",
    );
  }
}

=pod

=head2 GetStatus

B<Description>: Displays GenorRing or a given module status.

B<ArgsCount>: 0-1

=over 4

=item $module: (string) (O)

An optional module name.

=back

B<Return>: (nothing)

=cut

sub GetStatus {
  my ($module) = @_;
  if ($module) {
    my $module_state = GetModuleRealState($module);
    if ($module_state && ($module_state !~ m/running/)) {
      print "$module is not running.\n";
      return;
    }
    else {
      print "$module is running.\n";
    }
  }
  else {
    my $state = GetState();
    if ('running' eq $state) {
      if ($ENV{'COMPOSE_PROFILES'} =~ m/offline/) {
        $state .= ' in offline mode';
        if ($ENV{'COMPOSE_PROFILES'} =~ m/backend/) {
          $state .= ' with backend';
        }
      }
      elsif ($ENV{'COMPOSE_PROFILES'} =~ m/backend/) {
        $state .= ' in backend mode';
      }
    }
    print "GenoRing is " . ($state || 'not running') . ".\n";
  }
}

=pod

=head2 GetState

B<Description>: Displays the given GenorRing container state or a global state
for all GenoRing containers (ie. 'running' only if all a running, otherwise the
first non-running state).

B<ArgsCount>: 0-1

=over 4

=item $container: (string) (O)

Container name.

=back

B<Return>: (string)
  The GenoRing or container state.

=cut

sub GetState {
  my ($container) = @_;
  my $state = '';
  if ($container) {
    (undef, $state) = IsContainerRunning($container);
  }
  else {
    my $states = `docker compose ps --all --format '{{.Names}} {{.State}}'`;
    $state = $states ? 'running' : '';
    foreach my $line (split(/\n+/, $states)) {
      if ($line !~ m/\srunning$/) {
        ($state) = ($line =~ m/(\S+)\s*$/);
        last;
      }
    }
  }

  return $state;
}

=pod

=head2 IsContainerRunning

B<Description>: Tells if the given container name is currently running.

B<ArgsCount>: 1

=over 4

=item $container: (string) (R)

The container name.

=back

B<Return>: (list)

The container identifier, the state string, the container name and the image
name of the running container or an empty list otherwise.
The state string should be one of "created", "running", "restarting", "paused",
"dead" or "exited".

=cut

sub IsContainerRunning {
  my ($container) = @_;

  if (!$container) {
    warn "WARNING: IsContainerRunning: Missing container name!";
    return '';
  }
  my $ps_all = `docker ps --all --filter name=$container --format '{{.ID}} {{.State}} {{.Names}} {{.Image}}'`;
  my @ps = split(/\n+/, $ps_all);
  foreach my $ps (@ps) {
    my @status = split(/\s+/, $ps);
    # Name filter does not do an exact match so we do it here.
    if ($status[2] eq $container) {
      return (@status);
    }
  }
  return ();
}

=pod

=head2 GetModuleRealState

B<Description>: Returns the given module real state (can be different from the
state returned by Docker). It calls the module state hook (hooks/state.pl).
If $progress is set, it will try $STATE_MAX_TRIES seconds to check if the module
is not running and displays logs.
If the state is not available (ex. modules with no own services), an empty
string is returned and can not be considered as a running or a
non-running state: it is just not available and the module might be running or
not, depending on the existing services it relies on.

B<ArgsCount>: 0-1

=over 4

=item $module: (string) (O)

Module name.

=back

B<Return>: (string)

The module state. Should be one of "created", "running", "restarting", "paused",
"dead", "exited" or an empty string if not available.

=cut

sub GetModuleRealState {
  my ($module, $progress) = @_;

  if (!$module) {
    die "ERROR: GetModuleRealState: Missing module name!";
  }

  my $state = '';
  if (-e "$MODULE_DIR/$module/hooks/state.pl") {
    my $tries = $STATE_MAX_TRIES;
    $state = `perl $MODULE_DIR/$module/hooks/state.pl`;
    if ($?) {
      die "ERROR: StartGenoring: Failed to get $module module state!\n$!\n(error $?)";
    }
    print "Checking if $module module is ready (see logs below for errors)...\n" if $progress;
    my $logs = '';
    # Does not work on Windows.
    my $terminal_width = `tput cols`;
    my $fixed_width = 0;
    if ($? || !$terminal_width || ($terminal_width !~ m/^\d+/)) {
      $terminal_width = 0;
      $fixed_width = 80;
    }
    else {
      # For line breaks.
      --$terminal_width;
    }
    while (--$tries && ($state !~ m/running/i)) {
      if ($progress) {
        my @log_lines = split(/\n/, $logs);
        my $line_count = scalar(@log_lines);
        if ($terminal_width) {
          foreach my $log_line (@log_lines) {
            $line_count += int(length($log_line) / ($terminal_width+1));
          }
        }
        if ($line_count) {
          print "\r" . ("\033[F" x $line_count);
        }
        $logs = '';
        foreach my $service (@{GetModuleServices($module)}) {
          if (IsContainerRunning($service)) {
            $logs .= "==> $service:\n" . `docker logs -n 4 $service 2>&1` . "\n";
          }
        }
        # Remove non-printable characters (but keep line breaks).
        $logs =~ s/[^ -~\n]+//g;
        if ($logs) {
          @log_lines = split(/\n/, $logs);
          $logs = '';
          my $new_line_count = scalar(@log_lines);
          if ($terminal_width) {
            foreach my $log_line (@log_lines) {
              # Cut too long lines.
              $log_line =  substr($log_line, 0, $terminal_width);
              $logs .= $log_line . (' ' x ($terminal_width - length($log_line) % ($terminal_width))) . "\n";
            }
          }
          elsif ($fixed_width) {
            foreach my $log_line (@log_lines) {
              if (length($log_line) >= $fixed_width) {
                # # Other approach: split long lines in multiple lines.
                # # Problem: very long lines could take a lot of split lines and
                # # are hidding previous log lines.
                # my @sub_lines = ($log_line =~ m/(.{0,$fixed_width})/gs);
                # $log_line =  join("\n", @sub_lines) . (' ' x ($fixed_width - length($log_line) % $fixed_width)) . "\n";
                # $new_line_count += scalar(@sub_lines) - 1;
                # Cut too long lines.
                $log_line =  substr($log_line, 0, $fixed_width) . "\n";
              }
              else {
                $log_line .=  (' ' x ($fixed_width - length($log_line) % $fixed_width)) . "\n"
              }
              $logs .= $log_line;
            }
          }
          # Clear previous log lines that where not overwritten.
          if ($new_line_count < $line_count) {
            my $line_width = $terminal_width || $fixed_width;
            my $line_diff = $line_count - $new_line_count;
            print(((' ' x  $line_width) . "\n") x $line_diff);
          }
          print $logs;
        }
        else {
          print '.';
        }
      }
      sleep(1);
      $state = `perl $MODULE_DIR/$module/hooks/state.pl`;
      if ($?) {
        die "ERROR: StartGenoring: Failed to get $module module state!\n$!\n(error $?)";
      }
    }
  }
  else {
    # Check if module containers are running.
    # Get module services.
    foreach my $service (@{GetModuleServices($module)}) {
      # Check service is running.
      my $service_state = GetState($service);
      if ($service_state !~ m/running/) {
        return $service_state;
      }
    }
  }
  return $state;
}

=pod

=head2 WaitModulesReady

B<Description>: Wait until all enabled modules are ready.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub WaitModulesReady {
  my $modules = [@_];
  if (!scalar(@$modules)) {
    $modules = GetModules(1);
  }
  foreach my $module (@$modules) {
    my $state = GetModuleRealState($module, 1);
    if ($state && ($state !~ m/running/i)) {
      my $logs = '';
      foreach my $service (@{GetModuleServices($module)}) {
        my $service_state = GetState($service);
        if ($service_state && ($service_state !~ m/running/)) {
          $logs .= "==> $service:\n" . `docker logs -n 10 $service 2>&1` . "\n\n";
        }
      }
      die sprintf("\nERROR: WaitModulesReady: Failed to get $module module initialized in less than %d min (state $state)!\n", $STATE_MAX_TRIES/60)
        . "LOGS: $logs";
    }
  }
}

=pod

=head2 Reinitialize

B<Description>: Remove all configs, and volume data. Remove GenoRing persitant
docker elements to allow a new reinstallation from scratch. Ask confirmation
before performing destructives tasks.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub Reinitialize {
  if (!exists($g_flags->{'f'})) {
    #  Warn and ask for confirmation.
    if (!Confirm("WARNING: This will stop all GenoRing containers, REMOVE their local data ('volumes' directory contant) and reset GenoRing config! This operation can not be undone so make backups before as needed. Are you sure you want to continue?")) {
      print "Operation canceled!\n";
      exit(0);
    }
  }

  # Stop genoring.
  print "Stop GenoRing...\n";
  eval{StopGenoring();};
  if ($@) {
    print "  Failed.\n$@\n";
  }
  else {
    print "  OK.\n";
  }

  # Cleanup containers.
  print "Pruning stopped containers...\n";
  Run(
    "docker container prune -f",
    "Failed to prune containers!"
  );
  print "  Done.\n";

  # Remove all GenoRing volumes.
  print "Removing all GenoRing volumes...\n";
  my $modules = GetModules();
  foreach my $module (@$modules) {
    my $volumes = GetModuleVolumes($module);
    if (@$volumes) {
      Run(
        "docker volume rm -f " . join(' ', @$volumes),
        "Failed to remove GenoRing volumes for module '$module'!"
      );
    }
  }
  print "  OK.\n";

  # Uninstall all modules.
  print "Uninstall all modules...\n";
  foreach my $module (@$modules) {
    ApplyLocalHooks('uninstall', $module);
  }
  unlink $MODULE_FILE;
  print "  OK.\n";

  # Clear config.
  print "Clearing config...\n";
  unlink $DOCKER_COMPOSE_FILE;
  unlink $EXTRA_HOSTS;
  print "  OK.\n";

  # Clear environment files.
  RemoveEnvFiles();

  print "Reinitialization done!\n";
}

=pod

=head2 SetupGenoring

B<Description>: Initializes GenoRing system with user inputs.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub SetupGenoring {
  my ($module) = @_;

  # Make sure we have the core module enabled at least.
  if (!$module) {
    my $modules = GetModules(1);
    if (!@$modules) {
      SetModuleConf('genoring');
      $modules = GetModules(1);
    }
  }

  # Process environment variables and ask user for inputs for variables with
  # tags SET and OPT.
  print "- Setup environment...\n";
  SetupGenoringEnvironment($module);
  print "  ...Environment setup done.\n";

  # Generate docker-compose.yml...
  print "- Generating Docker Compose main file...\n";
  GenerateDockerComposeFile();
  print "  ...Docker Compose file generated.\n";

  # Apply global initialization hooks (modules/*/hooks/init.pl).
  print "- Initialiazing modules...\n";
  ApplyLocalHooks('init', $module);
  print "  Modules initialiazed on local system, initializing services...\n";

  # Start dockers in backend mode.
  print "  - Starting GenoRing backend for initialization...\n";
  StartGenoring('backend');
  print "    OK\n";

  # Check dockers are ready.
  print "  - Waiting for all services to be operational...\n";
  WaitModulesReady();
  print "    OK\n";

  # Apply docker initialization hooks of each enabled module service for each
  # enabled module service (ie. modules/"svc1"/hooks/init_"svc2".sh).
  print "  - Applying container initialization hooks...\n";
  ApplyContainerHooks('enable', $module, 1);
  print "  ...Modules initialiazed.\n";

  # Stop containers.
  print "- Stopping backend.\n";
  StopGenoring();
}

=pod

=head2 SetupGenoringEnvironment

B<Description>: Ask user to set GenoRing environment variables.

B<ArgsCount>: 0-2

=over 4

=item $reset: (boolean) (R)

Force environment file re-generation.

=item $module: (string) (O)

A specific module name.

=back

B<Return>: (nothing)

=cut

sub SetupGenoringEnvironment {
  my ($reset, $setup_module) = @_;
  my $user_input;

  # Create environment directory.
  mkdir('env') unless (-d 'env');

  # @todo Only display if there are new environment files to setup.
  print <<"___SETUPGENORINGENVIRONMENT_INSTALL_TEXT___";
To continue, you will be asked to provide values for some setting variables for
each module.
___SETUPGENORINGENVIRONMENT_INSTALL_TEXT___

  # Get enabled modules or specified module.
  my $modules;
  if ($setup_module) {
    $modules = [$setup_module];
  }
  else {
    $modules = GetModules(1);
  }
  my %env_vars;
  foreach my $module (@$modules) {
    $env_vars{$module} = {};
    # List module env files.
    opendir(my $dh, "$MODULE_DIR/$module/env")
      or die "ERROR: SetupGenoringEnvironment: Failed to access '$MODULE_DIR/$module/env' directory!\n$!";
    my @env_files = (grep { $_ =~ m/^[^\.].*\.env$/ && -r "$MODULE_DIR/$module/env/$_" } readdir($dh));
    closedir($dh);
    foreach my $env_file (@env_files) {
      # Check if environment file already set.
      if (!$reset && (-s "env/${module}_$env_file")) {
        next;
      }
      # Parse each env file to get parametrable elements.
      my $env_fh;
      if (open($env_fh, '<:utf8', "$MODULE_DIR/$module/env/$env_file")) {
        my ($envvar_name, $envvar_desc, $envvar_default, $is_setting, $is_optional, $previous_content) = ('', '', '', 0, 0, '');
        $env_vars{$module}->{$env_file} = [];
        while (my $line = <$env_fh>) {
          if ($line =~ m/^\s*$/) {
            # Clear if empty line.
            ($envvar_name, $envvar_desc, $envvar_default, $is_setting, $is_optional) = ('', '', '', 0, 0);
          }
          elsif ($line =~ m/^#\s+\@default\s+(.*)/) {
            $envvar_default = $1;
          }
          elsif ($line =~ m/^#\s+\@tags\s+(.*)/) {
            my $tags = $1;
            if ($tags =~ m/SET/) {
              $is_setting = 1;
            }
            else {
              $is_setting = 0;
            }
            if ($tags =~ m/OPT/) {
              $is_optional = 1;
            }
            else {
              $is_optional = 0;
            }
          }
          elsif (!$envvar_name && ($line =~ m/^#\s+(\w.+)/)) {
            # Env var name.
            $envvar_name = $1;
          }
          elsif ($envvar_name && ($line =~ m/^#/)) {
            # Env var description.
            # Skip first empty line.
            if ($envvar_desc || ($line =~ m/\w/)) {
              $envvar_desc .= substr($line, 2) . "\n";
            }
          }
          elsif ($line =~ m/^\s*(\w+)\s*[=:]\s*(.*)$/) {
            if ($is_setting || $is_optional) {
              push(
                @{$env_vars{$module}->{$env_file}},
                {
                  'var' => $1,
                  'name' => $envvar_name,
                  'description' => $envvar_desc,
                  'current' => $2,
                  'default' => $envvar_default,
                  'is_setting' => $is_setting,
                  'is_optional' => $is_optional,
                  'module' => $module,
                  'env_file' => $env_file,
                  'previous_content' => $previous_content,
                }
              );
              # Clear line to exclude it from previous content.
              $line = '';
              # Reset previous content.
              $previous_content = '';
            }
            # Reset for next env var.
            ($envvar_name, $envvar_desc, $envvar_default, $is_setting, $is_optional) = ('', '', '', 0, 0);
          }
          else {
            # Unsupported line.
            # warn "WARNING: Unsupported line in '$MODULE_DIR/$module/env/$env_file':\n$line\n";
            ($envvar_name, $envvar_desc, $envvar_default, $is_setting, $is_optional) = ('', '', '', 0, 0);
          }
          $previous_content .= $line;
        }
        close($env_fh);

        my $next_envfile = 0;
        while (!$next_envfile) {
          # Now get user input to fill env file.
          if (scalar(@{$env_vars{$module}->{$env_file}})) {
            print "Settings for \"$env_file\"\n";
          }
          foreach my $envvar (@{$env_vars{$module}->{$env_file}}) {
            my $next_envvar = 0;
            print "* " . ($envvar->{'name'} || $envvar->{'var'}) . "\n";
            if (defined($envvar->{'default'})) {
              print "  Default value: " . $envvar->{'default'} . "\n";
            }
            if (defined($envvar->{'current'})) {
              print "  Current value: " . $envvar->{'current'} . "\n";
            }
            while (!$next_envvar) {
              print "  Hit 'S' to set a new value, 'K' to keep current value, 'D' to use default value\n  and 'H' to display help and this prompt again (S/K/D/H): ";
              $user_input = <STDIN>;
              if ($user_input =~ m/S/i)  {
                print "  Enter a new value:\n";
                $user_input = <STDIN>;
                chomp $user_input;
                $envvar->{'current'} = $user_input;
                $next_envvar = 1;
              }
              elsif ($user_input =~ m/K/i)  {
                $next_envvar = 1;
              }
              elsif ($user_input =~ m/D/i)  {
                $envvar->{'current'} = $envvar->{'default'};
                $next_envvar = 1;
              }
              elsif ($user_input =~ m/H/i)  {
                if ($envvar->{'description'}) {
                  print
                    "\nDESCRIPTION:\n============\n"
                    . ($envvar->{'name'} || $envvar->{'var'}) . "\n\n"
                    . $envvar->{'description'} . "\n";
                }
                else {
                  print "Sorry, no description available.\n";
                }
              }
            }
          }
          if (scalar(@{$env_vars{$module}->{$env_file}})) {
            print "\nNew settings ($env_file):\n";
            foreach my $envvar (@{$env_vars{$module}->{$env_file}}) {
               print "* " . ($envvar->{'name'} || $envvar->{'var'}) . ": " . $envvar->{'current'} . "\n";
            }
            print "Validate these settings? (y/n)";
            $user_input = <STDIN>;
            if ($user_input =~ m/y/) {
              # Save changes.
              if (open($env_fh, '>:utf8', "env/${module}_$env_file")) {
                foreach my $envvar (@{$env_vars{$module}->{$env_file}}) {
                   print {$env_fh} $envvar->{'previous_content'} . $envvar->{'var'} . "=" . $envvar->{'current'} . "\n";
                }
                print {$env_fh} $previous_content;
                close($env_fh);
              }
              else {
                die "ERROR: failed to save environment file 'env/${module}_$env_file':\n$!\n";
              }
              $next_envfile = 1;
            }
          }
          else {
            # Nothing to change, copy file.
            if (open($env_fh, '>:utf8', "env/${module}_$env_file")) {
              print {$env_fh} $previous_content;
              close($env_fh);
            }
            else {
              die "ERROR: failed to save environment file 'env/${module}_$env_file':\n$!\n";
            }
            $next_envfile = 1;
          }
        }
      }
      else {
        die "ERROR: failed to open environment file '$MODULE_DIR/$module/env/$env_file':\n$!\n";
      }
    }
  }
}

=pod

=head2 GenerateDockerComposeFile

B<Description>: Generates Docker Compose file.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub GenerateDockerComposeFile {
  # Get enabled modules.
  my $modules = GetModules(1);

  my %services;
  my %volumes;
  my @proxy_dependencies;
  foreach my $module (@$modules) {
    print "  - Processing $module module\n";

    if (!-d "$MODULE_DIR/$module/services") {
      # No service to enable.
      next;
    }
    # Work on module services.
    opendir(my $dh, "$MODULE_DIR/$module/services")
      or die "ERROR: GenerateDockerComposeFile: Failed to access '$MODULE_DIR/$module/services' directory!\n$!";
    my @services = (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$MODULE_DIR/$module/services/$_" } readdir($dh));
    closedir($dh);
    foreach my $service_yml (@services) {
      my $svc_fh;
      open($svc_fh, '<:utf8', "$MODULE_DIR/$module/services/$service_yml")
        or die "ERROR: GenerateDockerComposeFile: Failed to open module service file '$service_yml'.\n$!";
      # Trim extension.
      my $service = substr($service_yml, 0, -4);
      if (($module ne 'genoring') || ($service eq 'genoring')) {
        push(@proxy_dependencies, $service);
      }
      my $svc_version = <$svc_fh>;
      if ($svc_version !~ m/^# v?(\d+)\.(\d+)/i) {
        die "ERROR: GenerateDockerComposeFile: Invalid $module module service file '$service_yml': missing version!";
      }
      $services{$service} = {
        'version' => $1,
        'subversion' => $2,
        'module' => $module,
        'definition' => '    ' . join('    ', <$svc_fh>),
      };
      close($svc_fh);
    }

    # Work on module volumes.
    opendir($dh, "$MODULE_DIR/$module/volumes")
      or next;
    my @volumes = (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$MODULE_DIR/$module/volumes/$_" } readdir($dh));
    closedir($dh);
    foreach my $volume_yml (@volumes) {
      my $vl_fh;
      open($vl_fh, '<:utf8', "$MODULE_DIR/$module/volumes/$volume_yml")
        or die "ERROR: GenerateDockerComposeFile: Failed to open module volume file '$volume_yml'.\n$!";
      my $volume = substr($volume_yml, 0, -4);
      my $vol_version = <$vl_fh>;
      if ($vol_version !~ m/^# v?(\d+)\.(\d+)/i) {
        die "ERROR: GenerateDockerComposeFile: Invalid $module module volume file '$volume_yml': missing version!";
      }
      if (exists($volumes{$volume})) {
        # Compare versions.
        if ($volumes{$volume}->{'version'} != $1) {
          die "ERROR: GenerateDockerComposeFile: Incompatible $module module volume file '$volume_yml': major version differs from corresponding " . $volumes{$volume}->{'module'} . " module definition!";
        }
        # Keep latest or most recent definition.
        if ($volumes{$volume}->{'subversion'} >= $2) {
          $volumes{$volume} = {
            'version' => $1,
            'subversion' => $2,
            'module' => $module,
            'definition' => '    ' . join('    ', <$vl_fh>),
          };
        }
      }
      else {
        $volumes{$volume} = {
          'version' => $1,
          'subversion' => $2,
          'module' => $module,
          'definition' => '    ' . join('    ', <$vl_fh>),
        };
      }
      close($vl_fh);
    }
    print "    OK\n";
  }
  # Done with all modules, add proxy dependencies.
  if (exists($services{'genoring-proxy'})) {
    $services{'genoring-proxy'}->{'dependencies'} = [@proxy_dependencies];
  }

  # Generate "services" and "volumes" sections from enabled services.
  print "  All modules processed.\n";
  # Add other modules to genoring container dependencies (depends_on:).
  my $dc_fh;
  if (open($dc_fh, '>:utf8', $DOCKER_COMPOSE_FILE)) {
    print {$dc_fh} "# GenoRing docker compose file\n# WARNING: This file is auto-generated by genoring.sh script. Any direct\n# modification may be lost when genoring.sh will need to regenerate it.\n";
    # For each enabled service, add the section name, the indented definition,
    # and the 'container_name:' field.
    print {$dc_fh} "\nservices:\n";
    foreach my $service (sort keys(%services)) {
      print {$dc_fh} "\n  $service:\n";
      print {$dc_fh} $services{$service}->{'definition'};
      print {$dc_fh} "    container_name: $service\n";
      # For proxy, add dependencies of all other services.
      if (exists($services{$service}->{'dependencies'})
        && scalar(@{$services{$service}->{'dependencies'}})
      ) {
        print {$dc_fh} "    depends_on:\n      - " . join("\n      - ", @{$services{$service}->{'dependencies'}}) . "\n";
      }
    }
    # For volumes, add the section name, the indented definition and the
    # 'name:' field. Section names and volume names are prefixed with
    # 'genoring-'.
    print {$dc_fh} "\nvolumes:\n";
    foreach my $volume (sort keys(%volumes)) {
      print {$dc_fh} "  $volume:\n    # v" . $volumes{$volume}->{'version'} . '.' . $volumes{$volume}->{'subversion'} . "\n";
      print {$dc_fh} $volumes{$volume}->{'definition'};
      print {$dc_fh} "    name: \"$volume\"\n";
    }
    
    # Check for extra hosts to add.
    if (-e $EXTRA_HOSTS) {
      my $extra_fh;
      if (open($extra_fh, '<:utf8', $EXTRA_HOSTS)) {
        my $extra_hosts = do { local $/; <$extra_fh> };
        close($extra_fh);
        # Trim.
        $extra_hosts =~ s/^\s+|[ \t\f]+$//gm;
        $extra_hosts =~ s/^\n+//gsm;
        if ($extra_hosts) {
          if ($extra_hosts !~ m/^(\w+: "\[?[\d.:]+\]?"\n)+$/s) {
            warn "WARNING: It seems that the extra hosts file '$EXTRA_HOSTS' has been corrupted. GenoRing may not be able to run without manual adjustments in '$DOCKER_COMPOSE_FILE' in the 'extra_hosts:' section.\n";
          }
          # Indent.
          $extra_hosts =~ s/^/  /gm;
          print {$dc_fh} "extra_hosts:\n$extra_hosts";
        }
      }
      else {
        warn "WARNING: failed to open extra hosts file '$EXTRA_HOSTS'.\n$!\n";
      }
    }
    
    close($dc_fh);
  }
  else {
    die "ERROR: GenerateDockerComposeFile: Failed to open Docker Compose file '$DOCKER_COMPOSE_FILE':\n$!\n";
  }
}

=pod

=head2 Update

B<Description>: Updates the GenoRing system or the specified module.

B<ArgsCount>: 0-1

=over 4

=item $module: (string) (O)

The module name is only this module should be updated.

=back

B<Return>: (nothing)

=cut

sub Update {

  my ($module) = @_;
  if ($module) {
    print "Updating GenoRing module '$module'...\n";
  }
  else {
    print "Updating GenoRing...\n";
  }

  my $mode = 'backend';
  # Check if genoring is running and if so, we need to set "offline" mode
  # and restart it properly after the update.
  if ('running' eq GetState()) {
    $mode = 'backoff';
  }

  # Stop if running.
  print "- Make sure GenoRing is stopped\n";
  StopGenoring();

  # @todo Make an update backup.
  eval {
    # Apply global update hooks (modules/*/hooks/update.pl).
    print "- Updating modules...\n";
    ApplyLocalHooks('update', $module);
    print "  Modules updated on local system, updating services...\n";

    # Start containers in backend mode.
    print "- Starting GenoRing backend for update...\n";
    StartGenoring($mode);
    print "  OK.\n";

    # Check modules are ready.
    print "- Waiting for all services to be operational...\n";
    WaitModulesReady();
    print "  OK.\n";

    # Apply docker update hooks of each enabled module service for each
    # enabled module service (ie. modules/"svc1"/hooks/update_"svc2".sh).
    print "  - Applying service update hooks...\n";
    ApplyContainerHooks('update', $module);
    print "  ...Services updated.\n";

    # Stop containers.
    print "- Stopping backend.\n";
    StopGenoring();

    # Restart if needed.
    if ('backoff' eq $mode) {
      print "- Restart GenoRing...\n";
      StartGenoring('normal');
      print "  OK.\n";
      # Check modules are ready.
      print "- Waiting for all services to be operational...\n";
      WaitModulesReady();
      print "  OK.\n";
    }

    print "Update done.\n";
  };

  if ($@) {
    print "ERROR: Update failed!\n$@\n";
    # @todo If failed, restore backup.
  }
}

=pod

=head2 InstallModule

B<Description>: Installs and enables the given module.

B<ArgsCount>: 1

=over 4

=item $module: (string) (R)

The module name.

=back

B<Return>: (nothing)

=cut

sub InstallModule {
  my ($module) = @_;
  if (!$module) {
    die "ERROR: InstallModule: Missing module name!\n";
  }

  if (! -d "$MODULE_DIR/$module") {
    die "ERROR: InstallModule: Module '$module' not found!\n";
  }

  my %enabled_volumes = map { $_ => $_ } @{GetModules(1)};
  if (exists($enabled_volumes{$module})) {
    warn "WARNING: InstallModule: Module '$module' already installed!\n";
    return;
  }
  # Clear caches.
  ClearCache();

  # Check if the system is running and stop it.
  my $mode = 'backend';
  # Check if genoring is running and if so, we need to set "offline" mode
  # and restart it properly after the update.
  if ('running' eq GetState()) {
    $mode = 'backoff';
  }

  # Stop if running.
  StopGenoring();

  # Enable module.
  SetModuleConf($module, {'status' => 'enabled'});
  $enabled_volumes{$module} = $module;
  my ($init_ok, $enable_ok);
  eval {
    # Setup environment files.
    SetupGenoringEnvironment();

    # Apply module init hook.
    ApplyLocalHooks('init', $module);
    $init_ok = 1;

    # Update Docker Compose config.
    GenerateDockerComposeFile();

    # Set maintenance mode.
    StartGenoring($mode);
    WaitModulesReady();
    ApplyContainerHooks('enable', $module, 1);
    $enable_ok = 1;
    StopGenoring();
  };
  # If installation failed, cleanup things.
  if ($@) {
    warn "ERROR: Failed to install module '$module'.\n$@\n";
    eval {
      ApplyLocalHooks('uninstall', $module);
    } if ($init_ok);
    # Remove module from modules.yml if installation fails.
    RemoveModuleConf($module);
    # Update Docker Compose config.
    GenerateDockerComposeFile();
    StopGenoring();
  }

  # Restart if needed.
  if ('backoff' eq $mode) {
    StartGenoring('normal');
    WaitModulesReady();
  }
}

=pod

=head2 DisableModule

B<Description>: Disables the given module.

B<ArgsCount>: 1

=over 4

=item $module: (string) (R)

The module name.

=back

B<Return>: (nothing)

=cut

sub DisableModule {
  my ($module, $non_interactive, $uninstall) = @_;

  if (!$module) {
    # Die on logic error.
    die "ERROR: DisableModule: Missing module name!\n";
  }

  if (! -d "$MODULE_DIR/$module") {
    warn "WARNING: DisableModule: Module '$module' not found!\n";
  }

  my %enabled_modules = map { $_ => $_ } @{GetModules(1)};
  if (!exists($enabled_modules{$module})) {
    warn "WARNING: DisableModule: Module '$module' already disabled! Will retry to disable it.\n";
  }
  elsif (!$non_interactive) {
    if (!Confirm("Are you sure you want to disable module '$module'?")) {
      print "Operation canceled!\n";
      exit(0);
    }
  }
  # Clear caches.
  ClearCache();

  # Check if the system is running and stop it.
  my $mode = 'backend';
  # Check if genoring is running and if so, we need to set "offline" mode
  # and restart it properly after the changes.
  if ('running' eq GetState()) {
    $mode = 'backoff';
  }

  # Stop if running.
  eval {StopGenoring();};
  if ($@) {
    die "ERROR: Failed to stop GenoRing. Unable to uninstall module '$module'.\n$@\n";
  }

  # Disable or uninstall module.
  if ($uninstall) {
    RemoveModuleConf($module);
  }
  else {
    SetModuleConf($module, {'status' => 'disabled'});
  }

  # Update Docker Compose config.
  eval {GenerateDockerComposeFile();};
  if ($@) {
    warn $@;
  }

  # Set maintenance mode to apply disabling hooks.
  my $disable_hook_ok;
  eval {
    StartGenoring($mode);
    WaitModulesReady();
    ApplyContainerHooks('disable', $module, 1);
    $disable_hook_ok = 1;
    StopGenoring();
  };
  if ($@) {
    warn "WARNING: Failed to apply disable hooks!\n$@\n";
  }

  if ($uninstall) {
    # Apply module uninstall hook.
    eval {ApplyLocalHooks('uninstall', $module);};
    if ($@) {
      warn "WARNING: Failed to apply uninstall hooks!\n$@\n";
    }

    # Remove module environment files.
    RemoveEnvFiles($module);
  }

  # Restart if needed.
  if ('backoff' eq $mode) {
    StartGenoring('normal');
    WaitModulesReady();
  }

}

=pod

=head2 UninstallModule

B<Description>: Disables and uninstalls the given GenoRing module.

B<ArgsCount>: 1-2

=over 4

=item $module: (string) (R)

The module to disable and uninstall.

=item $non_interactive: (boolean) (O)

If 1 (TRUE), no confirmation is asked before uninstalling.

=back

B<Return>: (nothing)

=cut

sub UninstallModule {
  my ($module, $non_interactive) = @_;

  if (!$module) {
    # Die on logic error.
    die "ERROR: UninstallModule: Missing module name!\n";
  }

  if (! -d "$MODULE_DIR/$module") {
    warn "WARNING: UninstallModule: Module '$module' not found!\n";
  }

  my %enabled_modules = map { $_ => $_ } @{GetModules(1)};
  if (!exists($enabled_modules{$module})) {
    warn "WARNING: UninstallModule: Module '$module' already uninstalled! Will retry to uninstall it.\n";
  }
  elsif (!$non_interactive) {
    if (!Confirm("This action will also remove data files used or generated by the module. Are you sure you want to UNINSTALL module '$module'?")) {
      print "Operation canceled!\n";
      exit(0);
    }
  }
  DisableModule($module, 1, 1);
}

=pod

=head2 Backup

B<Description>: Performs a general backup of the GenoRing system into an archive
file or a backup of the given module data and config.

B<ArgsCount>: 0-2

=over 4

=item $backup_name: (string) (U)

The backup name. If not set, a default one is provided. Default backups can be
overriden without check while named backups can not.

=item $module: (string) (O)

Module machine name if only one module should be backuped.

=back

B<Return>: (nothing)

=cut

sub Backup {
  my ($backup_name, $module) = @_;
  if (!$backup_name) {
    # No name provided, use a default one.
    $backup_name = localtime->strftime('backup_%Y%d%mT%H%M');
    my $backupdir = "volumes/backups/$backup_name";
    # In the case of automatic names, we allow backup override.
    if (!-d $backupdir) {
      mkdir $backupdir;
      if ($!) {
        die "ERROR: Backup: Failed to create backup directory '$backupdir'.\n";
      }
    }
  }
  else {
    my $backupdir = "volumes/backups/$backup_name";
    if ($module) {
      $backupdir .= "/$module";
    }
    if (-d $backupdir) {
      # Check if directory is not empty as we don't allow backup override in
      # case of named backups.
      opendir(my $dh, $backupdir) or die "ERROR: Backup: Failed to open backup directory '$backupdir'.";
      if (scalar(grep { $_ ne "." && $_ ne ".." } readdir($dh)) != 0) {
        die "ERROR: Backup: Backup directory '$backupdir' is not empty. Aborting.";
      }
    }
  }

  # @todo Backup GenoRing config as well (docker-compose.yml, module.conf, env/).
  print "Backuping GenoRing...\n";

  my $mode = 'backend';
  # Check if genoring is running and if so, we need to set "offline" mode
  # and restart it properly after the update.
  if ('running' eq GetState()) {
    $mode = 'backoff';
  }

  # Stop if running.
  print "- Make sure GenoRing is stopped\n";
  StopGenoring();

  eval {
    # Launch backup hooks (modules/*/hooks/backup.pl).
    print "- Backuping modules data...\n";
    ApplyLocalHooks('backup', $module, $backup_name);
    print "  Modules backuped on local system, backuping services data...\n";

    # Start containers in backend mode.
    print "- Starting GenoRing backend for backup...\n";
    StartGenoring($mode);
    print "  OK.\n";

    # Check modules are ready.
    print "- Waiting for all services to be operational...\n";
    WaitModulesReady();
    print "  OK.\n";

    # Apply docker backup hooks of each enabled module service for each
    # enabled module service (ie. modules/"svc1"/hooks/backup_"svc2".sh).
    print "  - Call service backup hooks...\n";
    ApplyContainerHooks('backup', $module, 1, $backup_name);
    print "  ...Services backuped.\n";

    # Stop containers.
    print "- Stopping backend.\n";
    StopGenoring();

    # Restart if needed.
    if ('backoff' eq $mode) {
      print "- Restart GenoRing...\n";
      StartGenoring('normal');
      print "  OK.\n";
      # Check modules are ready.
      print "- Waiting for all services to be operational...\n";
      WaitModulesReady();
      print "  OK.\n";
    }

    print "Backup done.\n";
  };

  if ($@) {
    print "ERROR: Backup failed!\n$@\n";
  }
}

=pod

=head2 Restore

B<Description>: Restores GenoRing from a given backup.

B<ArgsCount>: 0-2

=over 4

=item $backup_name: (string) (R)

The backup name.

=item $module: (string) (O)

Module machine name if only one module should be restored.

=back

B<Return>: (nothing)

=cut

sub Restore {
  my ($backup_name, $module) = @_;
  if (!$backup_name) {
    die "ERROR: no backup name provided! Nothing to restore.";
  }

  print "Restore GenoRing...\n";
  # @todo Also restore GenoRing config files.

  my $mode = 'backend';
  # Check if genoring is running and if so, we need to set "offline" mode
  # and restart it properly after the update.
  if ('running' eq GetState()) {
    $mode = 'backoff';
  }

  # Stop if running.
  print "- Make sure GenoRing is stopped\n";
  StopGenoring();

  eval {
    # Launch backup hooks (modules/*/hooks/backup.pl).
    print "- Restoring modules data...\n";
    ApplyLocalHooks('restore', $module, $backup_name);
    print "  Modules restored on local system, restoring services data...\n";

    # Start containers in backend mode.
    print "- Starting GenoRing backend for backup...\n";
    StartGenoring($mode);
    print "  OK.\n";

    # Check modules are ready.
    print "- Waiting for all services to be operational...\n";
    WaitModulesReady();
    print "  OK.\n";

    # Apply docker restore hooks of each enabled module service for each
    # enabled module service (ie. modules/"svc1"/hooks/restore_"svc2".sh).
    print "  - Call service restore hooks...\n";
    ApplyContainerHooks('restore', $module, 1, $backup_name);
    print "  ...Services restored.\n";

    # Stop containers.
    print "- Stopping backend.\n";
    StopGenoring();

    # Restart if needed.
    if ('backoff' eq $mode) {
      print "- Restart GenoRing...\n";
      StartGenoring('normal');
      print "  OK.\n";
      # Check modules are ready.
      print "- Waiting for all services to be operational...\n";
      WaitModulesReady();
      print "  OK.\n";
    }

    print "Restore done.\n";
  };

  if ($@) {
    print "ERROR: Restore failed!\n$@\n";
  }
}

=pod

=head2 ApplyLocalHooks

B<Description>: Find and run the given local hook scripts.

Local hook scripts are PERL scripts runned on the current server running
"genoring.pl" and dockers. They can be called for a given module or for all
modules implementing the hook. The return code can be used to raise errors. They
are called when dockers are stopped except for the "state" hook.

Hook file name sructure: "<hook_name>.pl"

List of supported local hooks:
- init: called just before a module is enabled, in order to setup the file
  system (ie. create local data directories, generate, download or copy files,
  etc.).
- uninstall: cleanup local file system and remove data files and directories
  generated by the module.
- update: update local file system for the given module.
- backup: backup local files for the given module with the backup name as first
  argument.
- restore: restore local files for the given module with the backup name as first
  argument.
- start: called just before GenoRing dockers are started.
- stop: called just after GenoRing dockers are stopped.
- state: output the state of a module (ie. "created", "running", "restarting",
  "paused", "dead", "exited").

B<ArgsCount>: 1-3

=over 4

=item $hook_name: (string) (R)

The hook name.

=item $module: (string) (U)

Restrict hooks to this module.

=item $args: (string) (O)

Additional arguments to transmit to the hook script in command line.

=back

B<Return>: (nothing)

=cut

sub ApplyLocalHooks {
  my ($hook_name, $module, $args) = @_;
  $args ||= '';

  if (!$hook_name) {
    die "ERROR: ApplyLocalHooks: Missing hook name!\n";
  }

  my $modules;
  if ($module) {
    # Only work on specified module.
    $modules = [$module];
  }
  else {
    # Get all enabled modules.
    $modules = GetModules(1);
  }

  my @errors;
  foreach $module (@$modules) {
    if (-e "$MODULE_DIR/$module/hooks/$hook_name.pl") {
      print "  Processing $module module hook $hook_name...";
      eval {
        Run(
          "perl $MODULE_DIR/$module/hooks/$hook_name.pl $args",
          "Failed to process $module module hook $hook_name!",
          1
        );
      };
      if ($@) {
        push(@errors, $@);
        print "  Failed.\n";
      }
      else {
        print "  OK.\n";
      }
    }
  }
  if (@errors) {
    warn "ERROR: ApplyLocalHooks:\n" . join("\n", @errors) . "\n";
  }
}

=pod

=head2 ApplyContainerHooks

B<Description>: Find and run the given container hook scripts into related
containers.
IMPORTANT: Hooks will only be processed in *running* containers. Warnings will
be issued for enabled services that are not running.

Container hooks are shell scripts run into a genoring container corresponding to
a given service which appears in the hook script name. Hook script name
structure: "<hook_name>_<service_name>.sh"

Note: the "service_name" is a docker name.

Example: "enable_toto.sh" will run the "enable_toto.sh" on the
"toto" container when either the module holding that hook is enabled or the
"toto" service is enabled (while the module holding that hook is already
enabled).

To run scripts in the container, the "modules/" directory is copied into the
container directory "/genoring". In previous example, if "enable_toto.sh" is a
hook of the "mymodule" module, when the "mymodule" module is enabled, all the
directory "./modules/" is copied in the "toto" docker in the "/genoring/"
directory and the hook script is started from
"/genoring/modules/mymodule/hooks/enable_toto.sh". Since the developer of the
hook script knows the container that will run the script, the script should be
adapted to that container (ie. choose between "#!/bin/bash" or "#!/bin/sh" for
instance).

List of supported container hooks:
- enable: called for a module on services when one of them is enabled.
- disable: called for a module on services when one of them is disabled.
- update: called for a module on services when one of them is updated.
- backup: called for a module on services when one of them must perform backups
  with the backup name as first argument.
- restore: called for a module on services when one of them must restore files,
  content and config using the backup name provided as first argument.

B<ArgsCount>: 1-4

=over 4

=item $hook_name: (string) (R)

The hook name.

=item $en_module: (string) (U)

Restrict hooks to the given module and its services. When set to a valid module
name, only its hooks will be processed first and then only other module hooks
related to this module will be run as well if $related is set to 1.

=item $related: (bool) (O)

Will also run hook scripts of other modules targetting one service of
$en_module.

=item $args: (string) (O)

Additional arguments to transmit to the hook script in command line.

=back

B<Return>: (nothing)

=cut

sub ApplyContainerHooks {
  my ($hook_name, $en_module, $related, $args) = @_;
  $args ||= '';

  if (!$hook_name) {
    die "ERROR: ApplyContainerHooks: Missing hook name!\n";
  }

  # Get enabled modules.
  my $modules;
  if (!$en_module || $related) {
    $modules = GetModules(1);
  }
  else {
    $modules = [$en_module];
  }

  # Get enabled services.
  my $services = GetServices();

  # Process enabled modules.
  my %initialized_containers;
APPLYCONTAINERHOOKS_MODULES:
  foreach my $module (@$modules) {
    if (-d "$MODULE_DIR/$module/hooks/") {
      # Read directory and filter on services.
      opendir(my $dh, "$MODULE_DIR/$module/hooks")
        or die "ERROR: ApplyContainerHooks: Failed to list '$MODULE_DIR/$module/hooks' directory!\n$!";
      my @hooks = (grep { $_ =~ m/^${hook_name}_.+\.sh$/ && -r "$MODULE_DIR/$module/hooks/$_" } readdir($dh));
      # Process all module hooks that can be run.
APPLYCONTAINERHOOKS_HOOKS:
      foreach my $hook (@hooks) {
        if (($hook =~ m/^${hook_name}_(.+)\.sh$/) && exists($services->{$1})) {
          my $service = $1;
          # Check if a module has been specified and only process its hooks.
          # ie. process any hook of current module or any hook of another module
          # that targets a service of the specified module, and skip others.
          # Note: other modules hooks are not processed if $related was not TRUE
          # as $modules would only contain the given module.
          if ($en_module && ($en_module ne $module) && ($services->{$service} ne $en_module)) {
            # Skip non-matching hooks.
            next APPLYCONTAINERHOOKS_HOOKS;
          }
          # Check if container is running.
          my ($id, $state, $name, $image) = IsContainerRunning($service);
          if ($state && ($state !~ m/running/)) {
            $state ||= 'not running';
            warn "WARNING: Failed to run $module module hook in $service (hook $hook): $service is $state.";
            next APPLYCONTAINERHOOKS_HOOKS;
          }
          # Provide module files to container if not done already.
          if (!exists($initialized_containers{$service})) {
            Run(
              "docker exec " . (exists($g_flags->{'arm'}) ? '--platform linux/amd64 ' : '') . "-it $service mkdir -p /genoring",
              "Failed to prepare module file copy in $service ($module $hook hook)"
            );
            Run(
              "docker cp \$(pwd)/$MODULE_DIR/ $service:/genoring/$MODULE_DIR/",
              "Failed to copy module files in $service ($module $hook hook)"
            );
            $initialized_containers{$service} = 1;
          }
          Run(
            "docker exec " . (exists($g_flags->{'arm'}) ? '--platform linux/amd64 ' : '') . "-it $service /genoring/$MODULE_DIR/$module/hooks/$hook $args",
            "Failed to run hook of $module in $service (hook $hook)"
          );
        }
      }
    }
  }
}

=pod

=head2 Compile

B<Description>: Compiles a given container.

B<ArgsCount>: 2

=over 4

=item $module: (string) (R)

Module machine name.

=item $container: (string) (O)

Container name.

=back

B<Return>: (nothing)

=cut

sub Compile {
  my ($module, $service) = @_;

  if (!$module) {
    die "ERROR: Compile: Missing module name!";
  }
  elsif (!-d "$MODULE_DIR/$module") {
    die "ERROR: Compile: The given module ($module) was not found in the module directory!";
  }
  elsif (!-d "$MODULE_DIR/$module/src") {
    die "ERROR: Compile: The given module ($module) does not have sources!";
  }

  if (!$service) {
    # Try to get default service.
    opendir(my $dh, "$MODULE_DIR/$module/src")
      or die "ERROR: Compile: Failed to access '$MODULE_DIR/$module/src' directory!";
    my @services = (grep { $_ ne '.' && $_ ne '..' && -d "$MODULE_DIR/$module/src/$_" } readdir($dh));
    if (1 == scalar(@services)) {
      $service = shift(@services);
    }
    else {
      die "ERROR: Compile: Missing service name!";
    }
  }

  # Get service sub-directory for sources (take into account ARM support).
  my $service_subdir = $service . (exists($g_flags->{'arm'}) ? '-arm' : '');

  if (!-d "$MODULE_DIR/$module/src/$service_subdir") {
    die "ERROR: Compile: The given service (${module}[$service]) does not have sources!";
  }
  elsif (!-r "$MODULE_DIR/$module/src/$service_subdir/Dockerfile") {
    die "ERROR: Compile: Unable to access the Dockerfile of the given service (${module}[$service])!";
  }

  print "Compiling service ${module}[$service]...\n";

  # Check if container is running and stop it unless it is not running the same
  # image.
  my ($id, $state, $name, $image) = IsContainerRunning($service);
  if ($id) {
    if ($image && ($image ne $service)) {
      die "ERROR: Compile: A container with the same name ($service) but a different image ($image) is currently running. Please stop it before compiling.";
    }
    Run(
      "docker stop $id",
      "Failed to stop container '$service' (image $image)!"
    );
    Run(
      "docker container prune -f",
      "Failed to prune containers!"
    );
  }

  Run(
    "docker image rm -f $service",
    "Failed to remove previous image (service ${module}[$service])!",
    1
  );
  Run(
    "docker build -t $service $MODULE_DIR/$module/src/$service_subdir/",
    "Failed to compile container (service ${module}[$service])",
    1
  );
}

=pod

=head2 CompileMissingContainers

B<Description>: Compiles all missing containers from which sources are
available.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub CompileMissingContainers {

  # Get module services.
  my $services = GetServices();

  # Check missing containers.
  foreach my $service (keys(%$services)) {
    my $image_id = `docker images -q $service:latest`;
    if (!$image_id) {
      # Check if we got sources
      my $module = $services->{$service};
      if (-d "$MODULE_DIR/$module/src/$service") {
        # Got sources, compile.
        print "Compile missing service $module:$service.\n";
        Compile($module, $service);
      }
    }
  }
}

=pod

=head2 GetModuleConfig

B<Description>: Returns GenoRing module config.

B<ArgsCount>: 0

B<Return>: (hash ref)

The modules config. Keys are module names and values are module config hashes.

=cut

sub GetModuleConfig {
  my $module_fh;
  # Get module config.
  if (!$_g_modules->{'config'}) {
    if (open($module_fh, '<:utf8', $MODULE_FILE)) {
      my $yaml_text = do { local $/; <$module_fh> };
      close($module_fh);
      my $yaml = CPAN::Meta::YAML->read_string($yaml_text)
        or die
          "ERROR: failed to read module file '$MODULE_FILE':\n"
          . CPAN::Meta::YAML->errstr;
      $_g_modules->{'config'} = $yaml->[0];
    }
    else {
      # warn "WARNING: failed to open module file '$MODULE_FILE':\n$!\n";
      $_g_modules->{'config'} = {};
    }
  }
  return $_g_modules->{'config'};
}

=pod

=head2 GetModules

B<Description>: Returns a list of GenoRing modules.

B<ArgsCount>: 0-1

=over 4

=item $module_mode: (integer) (O)

If 1, only returns enabled modules, if 0 only returns disabled available modules
and if not set, returns all available modules.

=back

B<Return>: (array ref)

The list of modules.

=cut

sub GetModules {
  my ($module_mode) = @_;
  my $modules;
  if (!defined($module_mode)) {
    if (!exists($_g_modules->{'all'})) {
      # Get all available modules.
      opendir(my $dh, "$MODULE_DIR")
        or die "ERROR: GetModules: Failed to list '$MODULE_DIR' directory!\n$!";
      $_g_modules->{'all'} = [ sort grep { $_ !~ m/^\./ && -d "$MODULE_DIR/$_" } readdir($dh) ];
    }
    $modules = $_g_modules->{'all'};
  }
  elsif ((0 == $module_mode) && exists($_g_modules->{'disabled'})) {
    $modules = $_g_modules->{'disabled'};
  }
  elsif ((1 == $module_mode) && exists($_g_modules->{'enabled'})) {
    $modules = $_g_modules->{'enabled'};
  }
  else {
    # No cache.
    my %modules;
    # Get module config.
    GetModuleConfig();

    if (0 == $module_mode) {
      if ($_g_modules->{'config'}) {
        foreach my $module (keys(%{$_g_modules->{'config'}})) {
          if ('enabled' ne $_g_modules->{'config'}->{$module}->{'status'}) {
            $modules{$module} = $module;
          }
        }
        $_g_modules->{'disabled'} = [ sort values(%modules) ];
      }
      $modules = $_g_modules->{'disabled'} || [];
    }
    elsif (1 == $module_mode) {
      if ($_g_modules->{'config'}) {
        foreach my $module (keys(%{$_g_modules->{'config'}})) {
          if ('enabled' eq $_g_modules->{'config'}->{$module}->{'status'}) {
            $modules{$module} = $module;
          }
        }
        $_g_modules->{'enabled'} = [ sort values(%modules) ];
      }
      $modules = $_g_modules->{'enabled'} || [];
    }
  }
  
  # Filter ALL CAPS example modules. Valid names only contain alpha-numeric
  # characters and underscores, don't start by a number and must contain at
  # least one lower case letter.
  $modules = [grep(m/^(?:[a-z]\w*|[A-Z]\w*[a-z]\w*)$/, @$modules)];
  return $modules;
}

=pod

=head2 GetServices

B<Description>: Returns the list of GenoRing services (of enabled modules).

B<Return>: (hash ref)

The list of services. Keys are service names and values are modules they belong
to.

=cut

sub GetServices {
  if (!defined($_g_services) || !scalar(%$_g_services)) {
    my %services;
    my $modules = GetModules(1);
    foreach my $module (@$modules) {
      foreach my $service (@{GetModuleServices($module)}) {
        $services{$service} = $module;
      }
    }
    $_g_services = \%services;
  }

  return $_g_services;
}

=pod

=head2 GetModuleServices

B<Description>: Returns a list of services provided by the given module.

B<ArgsCount>: 1-2

=over 4

=item $module: (string) (R)

Module name.

=item $include: (string) (O)

If left empty or set to 'enabled', only includes enabled services. If set to
'disabled', only provide 'disabled' services, if set to 'alt', provides
alternative services (enabled or not) and if set to all, provides all the above.

=back

B<Return>: (array ref)

The list of services.

=cut

sub GetModuleServices {
  my ($module, $include) = @_;

  if (!defined($module)) {
    die "ERROR: GetModuleServices: No module name provided!";
  }

  # Get all available services.
  my @services;
  if (-d "$MODULE_DIR/$module/services") {
    if (opendir(my $dh, "$MODULE_DIR/$module/services")) {
      if (!$include || ('enabled' eq $include) || ('all' eq $include)) {
        push(@services, map { s/\.yml$//; $_ } (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$MODULE_DIR/$module/services/$_" } readdir($dh)));
      }
      if ($include) {
         if (('disabled' eq $include) || ('all' eq $include)) {
          push(@services, map { s/\.yml\.dis$//; $_ } (grep { $_ =~ m/^[^\.].*\.yml\.dis$/ && -r "$MODULE_DIR/$module/services/$_" } readdir($dh)));
        }
        if (('alt' eq $include) || ('all' eq $include)) {
          push(@services,  map { s/\.yml$//; $_ } (grep { $_ =~ m/^[^\.].*\.yml$/ && ($_ ne 'alt.yml') && -r "$MODULE_DIR/$module/services/alt/$_" } readdir($dh)));
        }
      }
      my %seen = map {$_ => $_} @services;
      @services = sort values(%seen);
    }
    else {
      warn "WARNING: GetModuleServices: Failed to list '$MODULE_DIR/$module/services' directory!\n$!";
    }
  }

  return \@services;
}

=pod

=head2 GetModuleAlternatives

B<Description>: Returns a list of available alternatives for a module.

B<ArgsCount>: 1

=over 4

=item $module: (string) (R)

The module name.

=back

B<Return>: (hash ref)

The list of alternatives keyed by names.

=cut

sub GetModuleAlternatives {
  my ($module) = @_;

  if (!defined($module)) {
    die "ERROR: GetModuleAlternatives: No module name provided!";
  }

  # Get all available alternatives.
  my $alternatives = {};
  if (-f "$MODULE_DIR/$module/services/alt/alt.yml") {
    if (open(my $alt_fh, '<:utf8', "$MODULE_DIR/$module/services/alt/alt.yml")) {
      my $yaml_text = do { local $/; <$alt_fh> };
      close($alt_fh);
      my $yaml = CPAN::Meta::YAML->read_string($yaml_text)
        or die
          "ERROR: failed to alternative config file '$MODULE_DIR/$module/services/alt/alt.yml':\n"
          . CPAN::Meta::YAML->errstr;
      $alternatives = $yaml->[0];
    }
    else {
      warn "WARNING: GetModuleAlternatives: Failed to open alternative config file '$MODULE_DIR/$module/services/alt/alt.yml'!\n$!";
    }
  }

  return $alternatives;

}

=pod

=head2 GetVolumes

B<Description>: Returns the list of GenoRing volumes (of enabled modules).

B<Return>: (hash ref)

The list of volumes. Keys are volume names and values are array of modules using
them.

=cut

sub GetVolumes {
  if (!defined($_g_volumes) || !scalar(%$_g_volumes)) {
    my %volumes;
    my $modules = GetModules(1);
    foreach my $module (@$modules) {
      foreach my $volume (@{GetModuleVolumes($module)}) {
        $volumes{$volume} ||= [];
        push(@{$volumes{$volume}}, $module);
      }
    }
    $_g_volumes = \%volumes;
  }

  return $_g_volumes;
}

=pod

=head2 GetModuleVolumes

B<Description>: Returns a list of shared volumes used by the given module.

B<ArgsCount>: 1

=over 4

=item $module: (string) (R)

Module name.

=back

B<Return>: (array ref)

The list of volumes.

=cut

sub GetModuleVolumes {
  my ($module) = @_;

  if (!defined($module)) {
    die "ERROR: GetModuleVolumes: No module name provided!";
  }

  # Get all available volumes.
  my @volumes;
  if (opendir(my $dh, "$MODULE_DIR/$module/volumes")) {
    @volumes = sort map { s/\.yml$//; $_ } (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$MODULE_DIR/$module/volumes/$_" } readdir($dh));
  }
  else {
    warn "WARNING: GetModuleVolumes: Failed to list '$MODULE_DIR/$module/volumes' directory!\n$!";
  }

  return \@volumes;
}

=pod

=head2 GetEnvVariable

B<Description>: Gets the value of an environment variable in a given env file.

B<ArgsCount>: 2

=over 4

=item $env_file: (string) (R)

The environment file path.

=item $variable: (string) (R)

The setting variable name.

=back

B<Return>: (string)

The variable value if found or undef otherwise.

=cut

sub GetEnvVariable {
  my ($env_file, $variable) = @_;
  my $value;
  if (! $env_file) {
    die "ERROR: GetEnvVariable: No environment file provided!";
  }
  if (! -r $env_file) {
    die "ERROR: GetEnvVariable: Cannot access environment file '$env_file'!";
  }

  if (! $variable) {
    die "ERROR: GetEnvVariable: No environment variable name provided!";
  }

  my $env_fh;
  if (open($env_fh, '<:utf8', $env_file)) {
    while (my $line = <$env_fh>) {
      if ($line =~ m/^\s*$variable\s*[=:]\s*(.*)$/) {
        $value = $1;
      }
    }
    close($env_fh);
  }
  else {
    die "ERROR: failed to open environment file '$env_file':\n$!\n";
  }

  return $value;
}

=pod

=head2 SetEnvVariable

B<Description>: Sets the value of an environment variable in a given env file.

B<ArgsCount>: 3

=over 4

=item $env_file: (string) (R)

The environment file path.

=item $variable: (string) (R)

The setting variable name.

=item $value: (string) (R)

The new setting variable value.

=back

B<Return>: (nothing)

=cut

sub SetEnvVariable {
  my ($env_file, $variable, $value) = @_;

  if (! $env_file) {
    die "ERROR: GetEnvVariable: No environment file provided!";
  }
  if (! -r $env_file) {
    die "ERROR: GetEnvVariable: Cannot access environment file '$env_file'!";
  }

  if (! $variable) {
    die "ERROR: GetEnvVariable: No environment variable name provided!";
  }

  $value ||= '';

  my $env_fh;
  my $new_content = '';
  my $got_value = 0;
  if (open($env_fh, '<:utf8', $env_file)) {
    while (my $line = <$env_fh>) {
      if ($line =~ m/^\s*$variable\s*[=:]$/) {
        if ($got_value) {
          $line = '';
        }
        else {
          $line = "$variable=$value\n";
          $got_value = 1
        }
      }
      $new_content .= $line;
    }
    close($env_fh);
    if (open($env_fh, '>:utf8', $env_file)) {
      print {$env_fh} $new_content;
      close($env_fh);
    }
    else {
      die "ERROR: Failed to update environment file '$env_file':\n$!\n";
    }
  }
  else {
    die "ERROR: Failed to open environment file '$env_file':\n$!\n";
  }
}

=pod

=head2 RemoveEnvFiles

B<Description>: Remove all environment files from the given module or from all
modules.

B<ArgsCount>: 0-1

=over 4

=item $module: (string) (O)

A specific module.

=back


B<Return>: (nothing)

=cut

sub RemoveEnvFiles {
  my ($module) = @_;
  if ($module) {
    # Remove module environment files.
    # List module env files.
    if (opendir(my $dh, "$MODULE_DIR/$module/env")) {
      my @env_files = (grep { $_ =~ m/^[^\.].*\.env$/ && -r "$MODULE_DIR/$module/env/$_" } readdir($dh));
      closedir($dh);
      foreach my $env_file (@env_files) {
        # Check if environment file exist.
        if (-e "env/${module}_$env_file") {
          unlink "env/${module}_$env_file";
        }
      }
    }
    else {
      warn "WARNING: Failed to access '$MODULE_DIR/$module/env' directory!\n$!";
    }
  }
  elsif (-d 'env') {
    # Remove all environment files.
    if (opendir(my $dh, 'env')) {
      my @env_files = (grep { $_ =~ m/^[^\.].*\.env$/ && -r "env/$_" } readdir($dh));
      closedir($dh);
      foreach my $env_file (@env_files) {
        unlink "env/$env_file";
      }
    }
    else {
      warn "WARNING: Failed to access 'env' directory!\n$!";
    }
  }
}

=pod

=head2 GetProfile

B<Description>: Returns current site environment type (dev/staging/prod).

B<Return>: (string)

The site environment type. Must be one of 'dev', 'staging', 'prod' or 'backend'.

=cut

sub GetProfile {
  my $site_env =
    GetEnvVariable("$MODULE_DIR/genoring/env/genoring.env", 'GENORING_ENVIRONMENT')
    || 'dev';
  if ($site_env !~ m/^(?:dev|staging|prod|backend)$/) {
    die "ERROR: GetProfile: Invalid site environment : '$site_env' in '$MODULE_DIR/genoring/env/genoring.env'! Valid profile should be one of 'dev', 'staging', 'prod' or 'backend'.\n";
  }
  return $site_env;
}

=pod

=head2 SetModuleConf

B<Description>: Adds a module to module config file.

B<ArgsCount>: 1-2

=over 4

=item $module: (string) (R)

The module name.

=item $module_conf: (hash ref) (O)

The module configuration.

=back

B<Return>: (nothing)

=cut

sub SetModuleConf {
  my ($module, $module_conf) = @_;
  GetModuleConfig();
  $_g_modules->{'config'}->{$module} ||= {};

  $module_conf ||= {
    'status' => 'enabled',
  };
  $_g_modules->{'config'}->{$module} = $module_conf;
  my $yaml = CPAN::Meta::YAML->new($_g_modules->{'config'});
  my $yaml_text = $yaml->write_string()
    or die "ERROR: failed to generate module config!\n"
    . CPAN::Meta::YAML->errstr;
  my $module_fh;
  if (open($module_fh, '>:utf8', $MODULE_FILE)) {
    print {$module_fh} $yaml_text;
    close($module_fh);
  }
  else {
    die "ERROR: failed to write module file '$MODULE_FILE':\n$!\n";
  }
  # Clear cache.
  delete($_g_modules->{'disabled'});
  delete($_g_modules->{'enabled'});
  delete($_g_modules->{'all'});
}

=pod

=head2 RemoveModuleConf

B<Description>: Removes a module from module config file.

B<ArgsCount>: 1

=over 4

=item $module: (string) (R)

The module name.

=back

B<Return>: (nothing)

=cut

sub RemoveModuleConf {
  my ($module) = @_;
  GetModuleConfig();
  $_g_modules->{'config'}->{$module} ||= {};

  if ($_g_modules->{'config'}->{$module}) {
    delete($_g_modules->{'config'}->{$module});
    my $yaml_text = $_g_modules->{'config'}->write_string()
      or die "ERROR: failed to generate module config!\n"
      . CPAN::Meta::YAML->errstr;
    my $module_fh;
    if (open($module_fh, '>:utf8', $MODULE_FILE)) {
      print {$module_fh} $yaml_text;
      close($module_fh);
    }
    else {
      die "ERROR: failed to write module file '$MODULE_FILE':\n$!\n";
    }
  }
}

=pod

=head2 ClearCache

B<Description>: Clears cache data.

B<ArgsCount>: 0-1

=over 4

=item $category: (string) (O)

Only clear the given category of cache. Could be one of: 'modules',
'services' or 'volumes'.

=back

B<Return>: (nothing)

=cut

sub ClearCache {
  my ($category) = @_;
  if (!$category) {
    $_g_modules = {};
    $_g_services = {};
    $_g_volumes = {};
  }
  elsif ($category eq 'modules') {
    $_g_modules = {};
  }
  elsif ($category eq 'services') {
    $_g_services = {};
  }
  elsif ($category eq 'volumes') {
    $_g_volumes = {};
  }
  else {
    print "WARNING: Unknown cache category: '$category'\n";
  }
}

=pod

=head2 Confirm

B<Description>: Ask a question and get user confirmation.

B<ArgsCount>: 1

=over 4

=item $message: (string) (R)

Confirmation message. The message does not need to have "(y/n)" in the end as it
is automatically added.

=back

B<Return>: (bool)

1 if confirmed (yes) and 0 otherwise.

=cut

sub Confirm {
  my ($message) = @_;
  print "$message (y/n) ";
  my $user_input = <STDIN>;
  if ($user_input !~ m/^y/i) {
    return 0;
  }
  return 1;
}

# Script options
#################

=pod

=head1 OPTIONS

genoring.pl [help | man | start | stop | logs | status | reset | update | enable | disable | uninstall | setup | modules | services | volumes | backup | restore | compile | tolocal | todocker] [-debug] [-arm]

=over 4

=item B<help>:

Display help and exits.

=item B<man>:

Prints the manual page and exits.

=item B<-debug>:

Enables debug mode.

=item B<-arm>:

Use ARM versions for Docker compilation when available or run on ARM
architectures.

=back

=cut


# CODE START
#############

# Change working directory to where the script is to later use relative paths.
chdir $BASEDIR;
$ENV{'COMPOSE_PROJECT_NAME'} = 'genoring';

# Set COMPOSE_PROFILES to an empty string to prevent warning 'The
# "COMPOSE_PROFILES" variable is not set. Defaulting to a blank string.'.
if (!defined($ENV{'COMPOSE_PROFILES'})) {
  $ENV{'COMPOSE_PROFILES'} = '';
}

# Options processing.
my ($man, $help) = (0, 0);

my $command = shift(@ARGV);
if (!$command || ($command =~ m/^-?-?help$|^[-\/]-?\?$/i)) {
  $help = shift(@ARGV) || 1;
}
elsif ($command =~ m/^-?-?man$/i) {
  $man = 1;
}

my (@arguments);
my $arg = shift(@ARGV);
while (defined($arg)) {
  if ($arg =~ m/^--?([\w\-]+)(?:=(.*))?$/i) {
    $g_flags->{$1} = defined($2) ? $2 : 1;
  }
  else {
    push(@arguments, $arg);
  }
  $arg = shift(@ARGV);
}

if (exists($g_flags->{'help'})) {
  $help = $g_flags->{'help'} || 1;
}

if ($help) {
  if (1 == $help) {
    # Display main help.
    pod2usage('-verbose' => 1, '-exitval' => 0);
  }
  else {
    # @todo Display command-specific help.
    # @see https://perldoc.perl.org/Pod::Usage
    pod2usage('-verbose' => 1, '-exitval' => 0);
  }
}
if ($man) {pod2usage('-verbose' => 2, '-exitval' => 0);}

# Change debug mode if requested/forced.
$g_debug ||= exists($g_flags->{'debug'}) ? $g_flags->{'debug'} : 0;

if ($command =~ m/^start$/i) {
  # Compile missing containers with sources.
  CompileMissingContainers();

  # Check if setup needs to be run first.
  if (!-e $DOCKER_COMPOSE_FILE) {
    # Needs first-time initialization.
    print "GenoRing needs to be setup...\n";
    SetupGenoring();
  }

  print "Starting GenoRing...\n";
  StartGenoring(@arguments);
  print "...GenoRing started.\n";

  print "Ensuring services are ready...\n";
  # Get enabled modules.
  my $modules = GetModules(1);
  WaitModulesReady(@$modules);
  print "...GenoRing is ready to accept client connections.\n";
}
elsif ($command =~ m/^stop$/i) {
  # Check if installed.
  if (!-e $DOCKER_COMPOSE_FILE) {
    warn "GenoRing needs to be setup first.\n";
    exit(1);
  }
  print "Stopping GenoRing...\n";
  StopGenoring(@arguments);
  print "...GenoRing stopped.\n";
}
elsif ($command =~ m/^logs$/i) {
  GetLogs(@arguments);
}
elsif ($command =~ m/^status$/i) {
  GetStatus(@arguments);
}
elsif ($command =~ m/^reset|reinit(?:ialize)?$/i) {
  Reinitialize(@arguments);
}
elsif ($command =~ m/^update$/i) {
  # Check if installed.
  if (!-e $DOCKER_COMPOSE_FILE) {
    warn "GenoRing needs to be setup first.\n";
    exit(1);
  }
  Update(@arguments);
}
elsif ($command =~ m/^setup$/i) {
  # (Re)run environment setup and docker-compose.yml generation.
  SetupGenoringEnvironment($g_flags->{'f'}, @arguments);
  GenerateDockerComposeFile();
}
elsif ($command =~ m/^enable$/i) {
  # Check if installed.
  if (!-e $DOCKER_COMPOSE_FILE) {
    warn "GenoRing needs to be setup first.\n";
    exit(1);
  }
  InstallModule(@arguments);
}
elsif ($command =~ m/^disable$/i) {
  # Check if installed.
  if (!-e $DOCKER_COMPOSE_FILE) {
    warn "GenoRing needs to be setup first.\n";
    exit(1);
  }
  DisableModule(@arguments);
}
elsif ($command =~ m/^uninstall$/i) {
  # Check if installed.
  if (!-e $DOCKER_COMPOSE_FILE) {
    warn "GenoRing needs to be setup first.\n";
    exit(1);
  }
  UninstallModule(@arguments);
}
elsif ($command =~ m/^backup$/i) {
  Backup(@arguments);
}
elsif ($command =~ m/^restore$/i) {
  Restore(@arguments);
}
elsif ($command =~ m/^compile$/i) {
  Compile(@arguments);
}
elsif ($command =~ m/^modules$/i) {
  print join(', ', @{GetModules(@arguments)}) . "\n";
}
elsif ($command =~ m/^services$/i) {
  my $services = GetServices(@arguments);
  foreach my $service (sort keys(%$services)) {
    print "$service (" . $services->{$service} . ")\n";
  }
}
elsif ($command =~ m/^alt(?:ernatives?)?$/i) {
  my ($module) = (@arguments);
  my $alternatives = GetModuleAlternatives($module);
  if (%$alternatives) {
    print "Alternatives for module '$module':\n";
    foreach my $alternative_name (sort keys(%$alternatives)) {
      my $alternative = $alternatives->{$alternative_name};
      print "- $alternative_name:\n";
      if ($alternative->{'substitue'}) {
        foreach my $substitued (keys(%{$alternative->{'substitue'}})) {
          print "    - service '$substitued' is replaced by service '" . $alternative->{'substitue'}->{$substitued} . "'\n";
        }
      }
      if ($alternative->{'add'}) {
        foreach my $added (@{$alternative->{'add'}}) {
          print "    - new service '$added' is added\n";
        }
      }
      if ($alternative->{'remove'}) {
        foreach my $removed (@{$alternative->{'remove'}}) {
          print "    - service '$removed' is removed\n";
        }
      }
    }
  }
  else {
    print "No alternatives for module '$module'.\n";
  }
}
elsif ($command =~ m/^enalt$/i) {
  my ($module, $alternative_name) = (@arguments);
  my $alternatives = GetModuleAlternatives($module);
  if (!defined($alternative_name)) {
    die "ERROR: No alternative name provided for module '$module'. You must provide the name of the alternative to enable.\n";
  }
  elsif (%$alternatives && $alternatives->{$alternative_name}) {
    # Make sure the module has not been installed yet.
    my %enabled_modules = map { $_ => $_ } @{GetModules(1)};
    if (exists($enabled_modules{$module})) {
      die "ERROR: Cannot enable an alternative on an already installed module ($module). You must uninstall the module first.\n";
    }

    # Ensure directory permissions.
    if (!-w "$MODULE_DIR/$module/services") {
      die "ERROR: Cannot enable alternative '$alternative_name' on module '$module': the service directory ($MODULE_DIR/$module/services) is write-protected.\n";
    }

    # Make sure services have not been already altered.
    my $alternative = $alternatives->{$alternative_name};
    my (@missing_services, @disabled_services);
    foreach my $old_service (keys(%{$alternative->{'substitue'} || {}}), keys(%{$alternative->{'remove'} || {}})) {
      if (-e "$MODULE_DIR/$module/services/$old_service.yml.dis") {
        push(@disabled_services, $old_service);
      }
      if (!-e "$MODULE_DIR/$module/services/alt/$old_service.yml") {
        push(@missing_services, $old_service);
      }
    }
    if (@disabled_services) {
      die "ERROR: Cannot enable alternative '$alternative_name' on module '$module': some impacted services have already been changed by another alteration (services: " . join(', ', @disabled_services) . ").\n";
    }
    my @added_services;
    foreach my $new_service (keys(%{$alternative->{'add'} || {}})) {
      if (-e "$MODULE_DIR/$module/services/$new_service.yml") {
        push(@added_services, $new_service);
      }
      if (!-e "$MODULE_DIR/$module/services/alt/$new_service.yml") {
        push(@missing_services, $new_service);
      }
    }
    if (@added_services) {
      die "ERROR: Cannot enable alternative '$alternative_name' on module '$module': some new services have already been added by another alteration (services: " . join(', ', @added_services) . ").\n";
    }
    if (@missing_services) {
      die "ERROR: Cannot enable alternative '$alternative_name' on module '$module': some new service definitions are missing (services: " . join(', ', @missing_services) . ").\n";
    }

    # Change service files and keep track of change made.
    my (@renamed, @copied);
    eval {
      foreach my $to_rename (keys(%{$alternative->{'substitue'} || {}}), keys(%{$alternative->{'remove'} || {}})) {
        if (!rename("$MODULE_DIR/$module/services/$to_rename.yml", "$MODULE_DIR/$module/services/$to_rename.yml.dis")) {
          die "ERROR: Cannot enable alternative '$alternative_name' on module '$module': service '$to_rename' could not be replaced/removed.\n$!";
        }
        push(@renamed, $to_rename);
      }
      foreach my $to_add (keys(%{$alternative->{'substitue'} || {}}), keys(%{$alternative->{'add'} || {}})) {
        if (!copy("$MODULE_DIR/$module/services/alt/$to_add.yml", "$MODULE_DIR/$module/services/$to_add.yml")) {
          die "ERROR: Cannot enable alternative '$alternative_name' on module '$module': service '$to_add' could not be added/replaced.\n$!";
        }
        push(@copied, $to_add);
      }
    };
    if ($@) {
      # Undo changes.
      foreach my $to_remove (@copied) {
        # Remove added files.
        unlink("$MODULE_DIR/$module/services/$to_remove.yml");
      }
      foreach my $to_restore (@renamed) {
        # Revert renaming.
        rename("$MODULE_DIR/$module/services/$to_restore.yml.dis", "$MODULE_DIR/$module/services/$to_restore.yml");
      }
      die $@;
    }
  }
  else {
    die "ERROR: alternative '$alternative_name' not found for module '$module'.\n";
  }
}
elsif ($command =~ m/^disalt$/i) {
  my ($module, $alternative_name) = (@arguments);
  my $alternatives = GetModuleAlternatives($module);
  if (!defined($alternative_name)) {
    die "ERROR: No alternative name provided for module '$module'. You must provide the name of the alternative to disable.\n";
  }
  elsif (%$alternatives && $alternatives->{$alternative_name}) {
    # Make sure the module is not installed.
    my %enabled_modules = map { $_ => $_ } @{GetModules(1)};
    if (exists($enabled_modules{$module})) {
      die "ERROR: Cannot disable an alternative on an already installed module ($module). You must uninstall the module first.\n";
    }

    # Ensure directory permissions.
    if (!-w "$MODULE_DIR/$module/services") {
      die "ERROR: Cannot disable alternative '$alternative_name' on module '$module': the service directory ($MODULE_DIR/$module/services) is write-protected.\n";
    }

    # Make sure services have already been altered.
    my $alternative = $alternatives->{$alternative_name};
    my @missing_services;
    foreach my $old_service (keys(%{$alternative->{'substitue'} || {}}), keys(%{$alternative->{'remove'} || {}})) {
      if (!-e "$MODULE_DIR/$module/services/alt/$old_service.yml.dis") {
        push(@missing_services, $old_service);
      }
    }
    if (@missing_services) {
      die "ERROR: Cannot disable alternative '$alternative_name' on module '$module': some previous service definitions are missing (services: " . join(', ', @missing_services) . ").\n";
    }

    # Change service files and keep track of change made.
    my (@renamed);
    eval {
      foreach my $to_remove (keys(%{$alternative->{'substitue'} || {}}), keys(%{$alternative->{'add'} || {}})) {
        if (-e "$MODULE_DIR/$module/services/$to_remove.yml"
          && !unlink("$MODULE_DIR/$module/services/$to_remove.yml")
        ) {
          die "ERROR: Cannot disable alternative '$alternative_name' on module '$module': altered service '$to_remove' could not be removed.\n$!";
        }
      }
      foreach my $to_rename (keys(%{$alternative->{'substitue'} || {}}), keys(%{$alternative->{'remove'} || {}})) {
        if (!rename("$MODULE_DIR/$module/services/$to_rename.yml.dis", "$MODULE_DIR/$module/services/$to_rename.yml")) {
          die "ERROR: Cannot disable alternative '$alternative_name' on module '$module': service '$to_rename' could not be put back.\n$!";
        }
        push(@renamed, $to_rename);
      }
    };
    if ($@) {
      # Undo changes.
      foreach my $to_restore (@renamed) {
        # Revert renaming.
        rename("$MODULE_DIR/$module/services/$to_restore.yml", "$MODULE_DIR/$module/services/$to_restore.yml.dis");
      }
      die $@;
    }
  }
  else {
    die "ERROR: alternative '$alternative_name' not found for module '$module'.\n";
  }
}
elsif ($command =~ m/^tolocal$/i) {
  my ($service, $ip) = @arguments;
  if (!$service) {
    die "ERROR: Turn docker service into local service: no service name provided!\n";
  }
  if (!$ip
    || ($ip !~ m/
      (
        # IP v4.
        (^(?:(?:[0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}(?:[0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$)
        # IP v6.
        | (^
            (?:
              # One of those syntaxes:
              (?:(?:[0-9a-f]{1,4}:){7}(?:[0-9a-f]{1,4}|:))
              | (?:(?:[0-9a-f]{1,4}:){6}(?::[0-9a-f]{1,4}|(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))
              | (?:(?:[0-9a-f]{1,4}:){5}(?:(?:(?::[0-9a-f]{1,4}){1,2})|:(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))
              | (?:(?:[0-9a-f]{1,4}:){4}(?:(?:(?::[0-9a-f]{1,4}){1,3})|(?:(?::[0-9a-f]{1,4})?:(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))
              | (?:(?:[0-9a-f]{1,4}:){3}(?:(?:(?::[0-9a-f]{1,4}){1,4})|(?:(?::[0-9a-f]{1,4}){0,2}:(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))
              | (?:(?:[0-9a-f]{1,4}:){2}(?:(?:(?::[0-9a-f]{1,4}){1,5})|(?:(?::[0-9a-f]{1,4}){0,3}:(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))
              | (?:(?:[0-9a-f]{1,4}:){1}(?:(?:(?::[0-9a-f]{1,4}){1,6})|(?:(?::[0-9a-f]{1,4}){0,4}:(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))
              | (?::(?:(?:(?::[0-9a-f]{1,4}){1,7})|(?:(?::[0-9a-f]{1,4}){0,5}:(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))
            )
            # Optional zone index.
            (?:%.+)?
          $)
      )
    /ix)
  ) {
    die "ERROR: Turn docker service into local service: no valid replacing IP provided!\n";
  }
  my $services = GetServices();
  if (!$services->{$service}) {
    die "ERROR: Turn docker service into local service: the given service does not exist or is not enabled!\n";
  }
  my $module = $services->{$service};
  # Disable the service.
  if (-e "$MODULE_DIR/$module/services/alt/$service.yml.dis") {
    # Using an alternative, remove it.
    if (!unlink("$MODULE_DIR/$module/services/$service.yml")) {
      die "ERROR: Cannot disable module '$module' service '$service'.\n$!";
    }
  }
  else {
    if (!rename("$MODULE_DIR/$module/services/$service.yml", "$MODULE_DIR/$module/services/$service.yml.dis")) {
      die "ERROR: Cannot disable module '$module' service '$service'.\n$!";
    }
  }
  # Append replacing host to "extra_hosts".
  my $extra_fh;
  if (open($extra_fh, '>>:utf8', $EXTRA_HOSTS)) {
    print {$extra_fh} "$service: \"$ip\"\n";
    close($extra_fh);
  }
  else {
    die "ERROR: failed to open extra hosts file '$EXTRA_HOSTS' to add replacing host ($service: \"$ip\")\n$!\n";
  }
  GenerateDockerComposeFile();
}
elsif ($command =~ m/^todocker$/i) {
  my ($service, $alternative_name) = @arguments;
  if (!$service) {
    die "ERROR: Turn back local service into docker service: no service name provided!\n";
  }
  my $services = GetServices();
  if ($services->{$service}) {
    die "ERROR: Turn local service into docker service: the given service already exist as a docker service!\n";
  }
  
  my $module = $services->{$service};

  die "ERROR: Turn back local service into docker service: not implemented yet!\n";
  # @todo Check if an alternative service should be used.
  
  if ($alternative_name) {
    my $alternatives = GetModuleAlternatives($module);
    
  }

  # Rename service to its original name or copy alt service.
  # Remove service from extra_hosts.
  # GenerateDockerComposeFile();
}
elsif ($command =~ m/^shell$/i) {
  Run(
    "docker exec -it genoring bash",
    "Failed to open a GenoRing shell!",
    1
  );
}
elsif ($command =~ m/^volumes$/i) {
  my $volumes = GetVolumes(@arguments);
  foreach my $volume (sort keys(%$volumes)) {
    print "$volume (" . join(', ', @{$volumes->{$volume}}) . ")\n";
  }
}
else {
  pod2usage('-verbose' => 1, '-exitval' => 1);
}

exit(0);

__END__
# CODE END
###########

=pod

=head1 AUTHORS

Valentin GUIGNON (Bioversity), v.guignon@cgiar.org

=head1 VERSION

Version 1.0

Date 23/10/2024

=head1 SEE ALSO

GenoRing documentation (README.md).

=cut
