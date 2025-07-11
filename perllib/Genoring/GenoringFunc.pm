=pod

=head1 NAME

GenoRing - Contains GenoRing Perl Library

=head1 SYNOPSIS

use Genoring;

=head1 REQUIRES

Perl5

=head1 DESCRIPTION

This module contains GenoRing library functions.

=cut

require 5.8.0;
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
use File::Copy;
use File::Path qw( make_path remove_tree );
use File::Spec;
use Time::Piece;




# Script global variables
##########################

=pod

=head1 VARIABLES

B<$g_debug>: (boolean)

When set to true, it enables debug mode. This constant can be set at script
start by command line options.

B<$g_exec_prefix>: (string)

Prefix to add to executed shell commands. It can be usefull to manage the user
running commands or for test or debugging purposes.

B<$g_flags>: (hash ref)

Contains flags set on command line with their values if set or "1" otherwise.

B<$g_instance>: (string)

Contains the global instance name.

B<$_g_modules>: (hash ref)

Cache variable for module lists. See GetModules(). Should not be used directly.

B<$_g_services>: (hash ref)

Cache variable for services lists. See GetServices(). Should not be used directly.

B<$_g_volumes>: (hash ref)

Cache variable for volumes lists. See GetVolumes(). Should not be used directly.

B<$_g_modules_info>: (hash ref)

Cache variable used to store modules' info. Should not be used directly.

=cut

our $g_debug = $Genoring::DEBUG;
our $g_exec_prefix = '';
our $g_flags = {};
our $g_instance = 'genoring';
our $_g_modules = {};
our $_g_services = {};
our $_g_volumes = {};
our $_g_modules_info = {};




# Package subs
###############

=pod

=head1 FUNCTIONAL INTERFACE

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

=item $fatal_error: (bool) (U)

If TRUE, the error is fatal and the script should die. Otherwise, just warn.

=item $interactive: (bool) (O)

If TRUE, the execution output will be displayed to current screen. If FALSE, the
execution output is returned as a string.

=back

B<Return>: (string)

Execution outputs if $interactive is FALSE. An empty string otherwise.

=cut

sub Run {
  my ($command, $error_message, $fatal_error, $interactive) = @_;

  # Get caller.
  my ($package, $filename, $line, $subroutine) = caller(1);
  $subroutine = $subroutine ? $subroutine . ': ' : '';
  $subroutine =~ s/^main:://;

  if (!$command) {
    # Die on logic errors.
    die "ERROR: ${subroutine} Run: No command to run!";
  }
  if ($g_debug) {
    print "COMMAND: $g_exec_prefix $command\n";
  }

  $error_message ||= 'Execution failed!';
  $error_message = ($fatal_error ? 'ERROR: ' : 'WARNING: ')
    . $subroutine
    . $error_message;
  my $output = '';
  if ($interactive) {
    system($g_exec_prefix . $command);
  }
  else {
    if ($g_debug) {
      open(my $pipe, '-|', "$g_exec_prefix $command")
        or die("Can't launch child: $!\n");
      while (defined(my $line = <$pipe>)) {
        $output .= $line;
        print $line;
      }
    }
    else {
      $output = qx($g_exec_prefix $command);
    }
  }

  if ($?) {
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

  return $output;
}


=pod

=head2 CheckGenoringUser

B<Description>: Check if the user running GenoRing is the same as the one used
to setup the current site instance. If they differ, it will ask a user
confirmation to continue or exit.

B<ArgsCount>: 0

=over 4

=item $: (string) (O)

=back

B<Return>: (nothing)

=cut

sub CheckGenoringUser {
  my $genoring_uid = '';
  if (-r 'env/genoring_genoring.env') {
    $genoring_uid = GetEnvVariable('env/genoring_genoring.env', 'GENORING_UID');
  }
  # Test if 'GENORING_UID' is set and different from current effective user.
  # Also make sure the Docker command is not already using sudo to change the
  # user running dockers.
  if (($genoring_uid =~ m/\w/)
      && ($genoring_uid ne $>)
      && ($g_exec_prefix !~ m/^sudo /)
      && !Confirm("You are trying manage current GenoRing instance with a different account than the one used to setup that instance. This may lead to generation of files and directories with incorrect owner and permissions.\nContinue anyway with current user?")
  ) {
    if ((0 == $>)
        && (system('sudo -V >/dev/null 2>&1') == 0)
        && Confirm("You are logged in as root. Do you want to automatically switch to the account used to setup GenoRing?")
    ) {
      $g_exec_prefix = "sudo --user=#$genoring_uid --preserve-env=PWD,COMPOSE_PROJECT_NAME,COMPOSE_PROFILES,GENORING_PORT,GENORING_DIR,GENORING_VOLUMES_DIR,GENORING_NO_EXPOSED_VOLUMES,GENORING_RUNNING ";
    }
    else {
      die "Execution aborted!\n";
    }
  }
}


=pod

=head2 InitGenoringUser

B<Description>: Initializes GenoRing default user and group.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub InitGenoringUser {
  $ENV{'GENORING_UID'} ||= $>;
  $ENV{'GENORING_GID'} ||= $) + 0;
  if (-r 'env/genoring_genoring.env') {
    $ENV{'GENORING_UID'} = GetEnvVariable('env/genoring_genoring.env', 'GENORING_UID') || $>;
    $ENV{'GENORING_GID'} = GetEnvVariable('env/genoring_genoring.env', 'GENORING_GID') || ($) + 0);
  }
}


=pod

=head2 StartGenoring

B<Description>: Starts GenoRing platform in the given mode (default: 'online').

B<ArgsCount>: 0-1

=over 4

=item $mode: (string) (O)

Running mode (ie. online|backend|offline mode). Must be one of:
- online: starts normally (in dev, staging or prod mode, according to config).
- backend: starts but disables CMS (no frontend).
- offline: starts CMS but in "offline" mode (admin can login and access the web
  interface while regular users can only access a maintenance page).
Default: "online".

=back

B<Return>: (nothing)

=cut

sub StartGenoring {
  # Get running mode.
  my ($mode) = @_;
  if ($mode && ($mode !~ m/^(?:online|backend|offline)$/)) {
    die "ERROR: StartGenoring: Invalid starting mode: '$mode'! Valid mode should be one of 'online', 'backend', 'offline'.\n";
  }
  # Set COMPOSE_PROFILES according to the selected environment.
  if (!$mode || ($mode eq 'online')) {
    # Get site environment.
    $mode = 'online';
    $ENV{'COMPOSE_PROFILES'} = GetProfile();
  }
  elsif ($mode eq 'backend') {
    $ENV{'COMPOSE_PROFILES'} = 'backend';
  }
  elsif ($mode eq 'offline') {
    $ENV{'COMPOSE_PROFILES'} = 'offline';
  }
  # Check that genoring docker is not already running.
  my ($id, $state, $name, $image) = IsContainerRunning($ENV{'COMPOSE_PROJECT_NAME'});
  if (!$state || ($state !~ m/running/)) {
    ApplyLocalHooks('start');
    # Not running, start it.
    Run(
      "$Genoring::DOCKER_COMPOSE_COMMAND up -d -y",
      "Failed to start GenoRing ($mode mode)!",
      1,
      $g_debug || $g_flags->{'verbose'}
    );
  }
  # Apply container hooks.
  eval {
    WaitModulesReady();
  };
  if ($@) {
    warn "$@\nWARNING: GenoRing does not seem to have been initialized in allowed time. Applying container hooks may failed...\n";
  }
  if (!$mode || ($mode eq 'online')) {
    ApplyContainerHooks('online');
  }
  elsif ($mode eq 'backend') {
    ApplyContainerHooks('backend');
  }
  elsif ($mode eq 'offline') {
    ApplyContainerHooks('offline');
  }
}


=pod

=head2 StopGenoring

B<Description>: Stops GenoRing platform by calling docker compose down.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub StopGenoring {
  if (-e $Genoring::DOCKER_COMPOSE_FILE) {
    Run(
      "$Genoring::DOCKER_COMPOSE_COMMAND --profile \"*\" down --remove-orphans",
      "Failed to stop GenoRing!",
      1,
      $g_flags->{'verbose'}
    );
  }
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
      "$Genoring::DOCKER_COMPOSE_COMMAND --profile \"*\" logs -f",
      "Failed to get GenoRing logs!",
      undef,
      1
    );
  }
  else {
    Run(
      "$Genoring::DOCKER_COMPOSE_COMMAND logs",
      "Failed to get GenoRing logs!",
      undef,
      1
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
    if ('offline' eq $state) {
      $state = 'running in offline mode';
    }
    elsif ('backend' eq $state) {
      $state = 'running in backend mode';
    }
    print "GenoRing is " . ($state || 'not running') . ".\n";
  }
}


=pod

=head2 GetState

B<Description>: Returns the given GenorRing container state or a global state
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
    $state ||= '';
  }
  else {
    my $states = qx($g_exec_prefix$Genoring::DOCKER_COMPOSE_COMMAND ps --all --format "{{.Names}} {{.State}}");
    $state = $states ? 'running' : '';
    foreach my $line (split(/\n+/, $states)) {
      if ($line !~ m/\srunning$/) {
        ($state) = ($line =~ m/(\S+)\s*$/);
        last;
      }
    }
  }

  # If it is running, check running mode.
  if ('running' eq $state) {
    if ($ENV{'COMPOSE_PROFILES'} =~ m/offline/) {
      $state = 'offline';
    }
    elsif ($ENV{'COMPOSE_PROFILES'} =~ m/backend/) {
      $state = 'backend';
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
    return ();
  }
  my $ps_all = qx($g_exec_prefix$Genoring::DOCKER_COMMAND ps --all --filter name=$container --format "{{.ID}} {{.State}} {{.Names}} {{.Image}} 2>/dev/null");
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
If $progress is set, it will try $Genoring::STATE_MAX_TRIES seconds to check if the module
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
  my $state_hook = File::Spec->catfile($Genoring::MODULES_DIR, $module, 'hooks', 'state.pl');
  if (-e $state_hook) {
    my $tries = $g_flags->{'wait-ready'};
    $state = qx($g_exec_prefix perl $state_hook 2>&1);
    if ($?) {
      die "ERROR: StartGenoring: Failed to get $module module state!\n$!\n(error $?)";
    }
    print "Checking if $module module is ready (see logs below for errors)...\n\n" if $progress;
    my $logs = '';
    # Does not work on Windows.
    my $terminal_width = qx($g_exec_prefix tput cols 2>&1);
    my $fixed_width = 0;
    if ($? || !$terminal_width || ($terminal_width !~ m/^\d+/)) {
      $terminal_width = 0;
      $fixed_width = 80;
    }
    else {
      # For line breaks.
      --$terminal_width;
    }
    while ((--$tries || (Confirm("The process appears to be longer than expected. Continue?") && ($tries = $g_flags->{'wait-ready'})))
      && ($state !~ m/running/i)
    ) {
      if ($progress) {
        # Count number of lines currently displayed.
        my @log_lines = split(/\n/, $logs);
        my $line_count = ($logs =~ tr/\n//);
        if ($terminal_width) {
          foreach my $log_line (@log_lines) {
            # Count long string lines split accross multiple terminal lines.
            if (1 < length($log_line)) {
              $line_count += int((length($log_line) - 1) / $terminal_width);
            }
          }
        }
        # Go back on terminal display to override.
        if ($line_count) {
          print "\r\033[$line_count"."F";
        }
        # Get current logs.
        $logs = '';
        foreach my $service (@{GetModuleServices($module)}) {
          my $service_name = GetContainerName($service);
          if (IsContainerRunning($service_name)) {
            $logs .= "==> $service:\n" . qx($g_exec_prefix $Genoring::DOCKER_COMMAND logs -n 4 $service_name 2>&1) . "\n";
          }
        }
        # Remove non-printable characters (ie. from "space" to "tild", and keep line breaks).
        $logs =~ s/[^ -~\n]+//g;
        if ($logs) {
          @log_lines = split(/\n/, $logs);
          my $new_line_count = ($logs =~ tr/\n//);
          $logs = '';
          if ($terminal_width) {
            foreach my $log_line (@log_lines) {
              # Cut too long lines.
              $log_line =  substr($log_line, 0, ($terminal_width - 1));
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
            my $line_width = ($terminal_width || $fixed_width);
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
      $state = qx($g_exec_prefix perl $state_hook 2>&1);
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
      my $service_name = GetContainerName($service);
      my $service_state = GetState($service_name);
      if ($service_state !~ m/^(?:running|backend|offline)$/) {
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
        my $service_name = GetContainerName($service);
        my $service_state = GetState($service_name);
        if ($service_state && ($service_state !~ m/running/)) {
          $logs .= "==> $service:\n" . qx($g_exec_prefix $Genoring::DOCKER_COMMAND logs -n 10 $service_name 2>&1) . "\n\n";
        }
      }
      die sprintf(
        "LOGS: %s\n\nERROR: WaitModulesReady: Failed to get $module module initialized in less than %d min (state $state)!\n", $logs, $g_flags->{'wait-ready'}/60
      );
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
  print "- Stop GenoRing...\n";
  eval{StopGenoring();};
  if ($@) {
    print "  ...Failed.\n$@\n";
  }
  else {
    print "  ...OK.\n";
  }

  # Cleanup containers.
  print "- Pruning stopped containers...\n";
  Run(
    "$Genoring::DOCKER_COMMAND container prune -f",
    "Failed to prune containers!",
    0,
    $g_flags->{'verbose'}
  );
  print "  ...Done.\n";

  # Remove docker images if needed.
  if (exists($g_flags->{'delete-containers'})) {
    print "- Removing all containers...\n";
    DeleteAllContainers();
    print "  ...Done.\n";
  }

  # Remove all GenoRing volumes.
  print "- Removing all GenoRing volumes...\n";
  my $modules = GetModules();
  foreach my $module (@$modules) {
    my $volumes = GetModuleVolumes($module);
    if (@$volumes) {
      Run(
        "$Genoring::DOCKER_COMMAND volume rm -f " . join(' ', map { GetVolumeName($_) } @$volumes),
        "Failed to remove GenoRing volumes for module '$module'!",
        0,
        $g_flags->{'verbose'}
      );
    }
    # Remove internal volumes if not exposed (ie. not cleaned by "volumes" local
    # directory cleaning).
    if ($g_flags->{'no-exposed-volumes'}) {
      my $module_info = GetModuleInfo($module);
      my @module_volumes;
      foreach my $module_volume (keys(%{$module_info->{'volumes'}})) {
        if (!grep(/$module_volume/, @$volumes)) {
          push(@module_volumes, $module_volume);
        }
      }
      if (@module_volumes) {
        Run(
          "$Genoring::DOCKER_COMMAND volume rm -f " . join(' ', map { GetVolumeName($_) } @module_volumes),
          "Failed to remove GenoRing internal volumes for module '$module'!",
          0,
          $g_flags->{'verbose'}
        );
      }
    }
  }
  print "  ...OK.\n";

  # Uninstall all modules.
  print "- Uninstall all modules...\n";
  foreach my $module (@$modules) {
    ApplyLocalHooks('uninstall', $module);
  }
  unlink $Genoring::MODULE_FILE;
  print "  ...OK.\n";

  # Clear config.
  print "- Clearing config...\n";
  unlink $Genoring::DOCKER_COMPOSE_FILE;
  unlink $Genoring::EXTRA_HOSTS;
  RemoveDependencyFiles();
  print "  ...OK.\n";

  # Clear environment files.
  if (!$g_flags->{'keep-env'}) {
    RemoveEnvFiles();
  }

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
  if (!exists($g_flags->{'hide-compile'})) {
    # Compile missing containers with sources.
    CompileMissingContainers();
  }

  # Process environment variables and ask user for inputs for variables with
  # tags SET and OPT.
  print "- Setup environment...\n";
  SetupGenoringEnvironment(undef, $module);
  print "  ...Environment setup done.\n";

  # Update GenoRing default user.
  InitGenoringUser();

  # Generate docker-compose.yml...
  print "- Generating Docker Compose main file...\n";
  GenerateDockerComposeFile();
  print "  ...Docker Compose file generated.\n";

  # Apply global initialization hooks (modules/*/hooks/init.pl).
  print "- Initialiazing modules...\n";
  ApplyLocalHooks('init', $module);
  print "  ...Modules initialiazed on local system...\n";

  # Start dockers in backend mode.
  print "  - Starting GenoRing backend (in offline mode) for initialization...\n";
  StartGenoring('offline');
  print "    ...OK...\n";

  # Apply docker initialization hooks of each enabled module service for each
  # enabled module service (ie. modules/"svc1"/hooks/init_"svc2".sh).
  print "  - Applying container initialization hooks...\n";
  ApplyContainerHooks('enable', $module, 1);
  print "  ...Modules initialiazed.\n";
}


=pod

=head2 SetupGenoringEnvironment

B<Description>: Ask user to set GenoRing environment variables.

B<ArgsCount>: 0-2

=over 4

=item $reset: (boolean) (U)

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
SETUPGENORINGENVIRONMENT_MODULES:
  foreach my $module (@$modules) {
    $env_vars{$module} = {};
    # List module env files.
    if (!-d "$Genoring::MODULES_DIR/$module/env") {
      next SETUPGENORINGENVIRONMENT_MODULES;
    }
    opendir(my $dh, "$Genoring::MODULES_DIR/$module/env")
      or die "ERROR: SetupGenoringEnvironment: Failed to access '$Genoring::MODULES_DIR/$module/env' directory!\n$!";
    my @env_files = (grep { $_ =~ m/^[^\.].*\.env$/ && -r "$Genoring::MODULES_DIR/$module/env/$_" } readdir($dh));
    closedir($dh);
SETUPGENORINGENVIRONMENT_ENV_FILES:
    foreach my $env_file (@env_files) {
      # Check if environment file already set.
      if (!$reset && (-s "env/${module}_$env_file")) {
        next SETUPGENORINGENVIRONMENT_ENV_FILES;
      }
      # Parse each env file to get parametrable elements.
      my $env_fh;
      if (open($env_fh, '<:utf8', "$Genoring::MODULES_DIR/$module/env/$env_file")) {
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
              my ($name, $value) = ($1, $2);
              # Special case to manage GENORING_UID, GENORING_GID and GENORING_HOST.
              if (('genoring' eq $module) && ('genoring' eq $env_file) && ($value !~ m/\w/)) {
                if ('GENORING_UID' eq $name) {
                  $value = $ENV{'GENORING_UID'};
                }
                elsif ('GENORING_GID' eq $name) {
                  $value = $ENV{'GENORING_GID'};
                }
                elsif ('GENORING_HOST' eq $name) {
                  $value = $ENV{'GENORING_HOST'};
                }
              }
              push(
                @{$env_vars{$module}->{$env_file}},
                {
                  'var' => $name,
                  'name' => $envvar_name,
                  'description' => $envvar_desc,
                  'current' => $value,
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
            # warn "WARNING: Unsupported line in '$Genoring::MODULES_DIR/$module/env/$env_file':\n$line\n";
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
            my @options = ('s', 'h');
            print "* " . ($envvar->{'name'} || $envvar->{'var'}) . "\n";
            if (defined($envvar->{'default'})) {
              print "  Default value: " . $envvar->{'default'} . "\n";
              push(@options, 'd');
            }
            if (defined($envvar->{'current'})) {
              print "  Current value: " . $envvar->{'current'} . "\n";
              push(@options, 'k');
            }
            # Check if optional settings should be skipped.
            if (defined($g_flags->{'minimal'}) && ($envvar->{'is_optional'})) {
              if (!defined($envvar->{'current'})) {
                $envvar->{'current'} = $envvar->{'default'};
              }
              $next_envvar = 1;
            }
            elsif (defined($g_flags->{'auto'})) {
              if (!defined($envvar->{'current'})) {
                $envvar->{'current'} = $envvar->{'default'};
              }
              $next_envvar = 1;
            }
            while (!$next_envvar) {
              print "  Hit 'S' to set a new value, 'K' to keep current value, 'D' to use default value\n  and 'H' to display help and this prompt again (" . join('/', @options) . "): ";
              $user_input = <STDIN>;
              if ($user_input =~ m/s/i)  {
                print "  Enter a new value:\n";
                $user_input = <STDIN>;
                chomp $user_input;
                $envvar->{'current'} = $user_input;
                $next_envvar = 1;
              }
              elsif (defined($envvar->{'current'}) && ($user_input =~ m/k/i))  {
                $next_envvar = 1;
              }
              elsif (defined($envvar->{'default'}) && ($user_input =~ m/d/i))  {
                $envvar->{'current'} = $envvar->{'default'};
                $next_envvar = 1;
              }
              elsif ($user_input =~ m/h/i)  {
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
            if ($g_flags->{'auto'} || Confirm('Validate these settings?')) {
              # Save changes.
              if (open($env_fh, '>:utf8', "env/${module}_$env_file")) {
                foreach my $envvar (@{$env_vars{$module}->{$env_file}}) {
                   print {$env_fh} $envvar->{'previous_content'} . $envvar->{'var'} . "=" . $envvar->{'current'} . "\n";
                   # Special case for host name.
                   if (('genoring' eq $module) && ('genoring.env' eq $env_file) && ($envvar->{'var'} eq 'GENORING_HOST')) {
                     $ENV{'GENORING_HOST'} = $envvar->{'current'};
                   }
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
        die "ERROR: failed to open environment file '$Genoring::MODULES_DIR/$module/env/$env_file':\n$!\n";
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
  # Clear cache.
  ClearCache();

  # Get enabled modules.
  my $modules = GetModules(1);
  my %services;
  my %volumes;
  my $service_dependencies = {};
  my $volume_dependencies = {};
  foreach my $module (@$modules) {
    print "  - Processing $module module\n";

    if (!-d "$Genoring::MODULES_DIR/$module/services") {
      # No service to enable.
      next;
    }
    # Get version.
    my $module_info = GetModuleInfo($module);
    # Work on module services.
    opendir(my $dh, "$Genoring::MODULES_DIR/$module/services")
      or die "ERROR: GenerateDockerComposeFile: Failed to access '$Genoring::MODULES_DIR/$module/services' directory!\n$!";
    my @services = (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$Genoring::MODULES_DIR/$module/services/$_" } readdir($dh));
    closedir($dh);
    foreach my $service_yml (@services) {
      my $svc_fh;
      open($svc_fh, '<:utf8', "$Genoring::MODULES_DIR/$module/services/$service_yml")
        or die "ERROR: GenerateDockerComposeFile: Failed to open module service file '$service_yml'.\n$!";
      # Trim extension.
      my $service = substr($service_yml, 0, -4);
      $services{$service} = {
        'version' => $module_info->{'version'} || '',
        'module' => $module,
        'definition' => '    ' . join('    ', <$svc_fh>),
      };
      # Remove dependencies as they are managed after.
      $services{$service}->{'definition'} =~ s~^    depends_on:\s*\n(?:^      [^\n]*\n)+~~gsm;

      if ($g_flags->{'no-exposed-volumes'}) {
        # Replace all exposed volumes by named volumes instead.
        $services{$service}->{'definition'} =~ m~^    volumes:\s*\n((?:^      [^\n]*\n)+)~gsm;
        my @service_volumes = split(/\n/, $1);
        $services{$service}->{'definition'} =~ s~^    volumes:\s*\n(?:^      [^\n]*\n)+~    volumes:\n~gsm;
        my @new_service_volumes;
        while (@service_volumes) {
          my $service_volume = shift(@service_volumes);
          if ($service_volume =~ m~^      - type:\s*bind~) {
            # For explicit binds, we keep them as they are. Indeed, in case of
            # direct file binding, we can not use named volumes.
            push(@new_service_volumes, $service_volume);
            my $next_bind_line = 1;
            do {
              $service_volume = shift(@service_volumes);
              if (!$service_volume) {
                $next_bind_line = 0;
              }
              elsif ($service_volume =~ m~^      -~) {
                $next_bind_line = 0;
                unshift(@service_volumes, $service_volume);
                $service_volume = undef;
              }
              else {
                # if ($service_volume =~ m~^        source:\s+\$\{VOLUMES_DIR\}/~) {
                #   $service_volume =~ s~^        source:\s+\$\{VOLUMES_DIR\}/~        source: genoring-volume-~;
                #   $service_volume =~ s~[^\w\s:\-]~-~g;
                #   my ($unexposed_volume) = $service_volume =~ m~^        source: (\S+)~;
                #   $volumes{$unexposed_volume} = {
                #     'module' => $module,
                #     # We create (below) and manage non-exposed volumes before
                #     # the use of Docker Compose.
                #     'definition' => "    external: true\n",
                #   };
                # }
                push(@new_service_volumes, $service_volume);
              }
            } while($next_bind_line);
          }
          elsif ($service_volume =~ m~^      - \$\{GENORING_VOLUMES_DIR\}/~) {
            $service_volume =~ s~^      - \$\{GENORING_VOLUMES_DIR\}/~      - genoring-volume-~;
            $service_volume =~ s~/(?=.*:)~-~g;
            my ($unexposed_volume) = $service_volume =~ m~^      - (\S+)\s*:~;
            $volumes{$unexposed_volume} = {
              'module' => $module,
              # We create (below) and manage non-exposed volumes before the use
              # of Docker Compose.
              'definition' => "    external: true\n",
            };
          }
          if ($service_volume) {
            push(@new_service_volumes, $service_volume);
          }
        }
        my $new_service_vol = join("\n", @new_service_volumes);
        $services{$service}->{'definition'} =~ s~^    volumes:\n~    volumes:\n$new_service_vol\n~gsm;
      }
      close($svc_fh);
    }

    # Parse module dependencies to compute service dependencies.
    # @todo Take into account versions.
    foreach my $module_dep (@{$module_info->{'dependencies'}{'services'} || []}) {
      my $dependencies = ParseDependencies($module_dep);
      my @mod_services;
      if (!$dependencies->{'service'}) {
        push(@mod_services, keys(%{$module_info->{'services'} || {}}));
      }
      else {
        push(@mod_services, $dependencies->{'service'});
      }
      my @dep_services;
      foreach my $dependency (@{$dependencies->{'dependencies'} || []}) {
        if ($dependency->{'element'}) {
          push(@dep_services, $dependency->{'element'});
        }
        else {
          # @todo If no element specified, get all dependent module services.
          warn "Module dependency calculation currently does not manage implicit services.\n";
        }
      }
      if (@dep_services && @mod_services) {
        if ('BEFORE' eq $dependencies->{'constraint'}) {
          # The dependency service(s) ('element') must be started after the module
          # service.
          foreach my $dep_service (@dep_services) {
            $service_dependencies->{$dep_service} ||= {};
            if ($dependencies->{'profiles'} && @{$dependencies->{'profiles'}}) {
              foreach my $dep_profile (@{$dependencies->{'profiles'}}) {
                $service_dependencies->{$dep_service}{$dep_profile} ||= [];
                push(@{$service_dependencies->{$dep_service}{$dep_profile}}, @mod_services);
              }
            }
            else {
              $service_dependencies->{$dep_service}{''} ||= [];
              push(@{$service_dependencies->{$dep_service}{''}}, @mod_services);
            }
          }
        }
        elsif ('AFTER' eq $dependencies->{'constraint'}) {
          # The module service must be started after the dependency service(s)
          # ('element').
          foreach my $mod_service (@mod_services) {
            $service_dependencies->{$mod_service} ||= {};
            if ($dependencies->{'profiles'} && @{$dependencies->{'profiles'}}) {
              foreach my $dep_profile (@{$dependencies->{'profiles'}}) {
                if ('online' eq $dep_profile) {
                  foreach $dep_profile ('dev', 'staging', 'prod') {
                    $service_dependencies->{$mod_service}{$dep_profile} ||= [];
                    push(
                      @{$service_dependencies->{$mod_service}{$dep_profile}},
                      @dep_services
                    );
                  }
                }
                else {
                  $service_dependencies->{$mod_service}{$dep_profile} ||= [];
                  push(
                    @{$service_dependencies->{$mod_service}{$dep_profile}},
                    @dep_services
                  );
                }
              }
            }
            else {
              $service_dependencies->{$mod_service}{''} ||= [];
              push(@{$service_dependencies->{$mod_service}{''}}, @dep_services);
            }
          }
        }
      }
    }

    # Work on module volumes.
    opendir($dh, "$Genoring::MODULES_DIR/$module/volumes")
      or next;
    my @volumes = (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$Genoring::MODULES_DIR/$module/volumes/$_" } readdir($dh));
    closedir($dh);
    foreach my $volume_yml (@volumes) {
      my $vl_fh;
      open($vl_fh, '<:utf8', "$Genoring::MODULES_DIR/$module/volumes/$volume_yml")
        or die "ERROR: GenerateDockerComposeFile: Failed to open module volume file '$volume_yml'.\n$!";
      my $volume = substr($volume_yml, 0, -4);
      $volumes{$volume} = {
        'module' => $module,
        'definition' => '    ' . join('    ', <$vl_fh>),
      };
      if ($g_flags->{'no-exposed-volumes'}) {
        $volumes{$volume}->{'definition'} =~ s/^(\s+)driver[^\n]+\n?(?:\g1 [^\n]+\n?)*//gms;
        # We create (below) and manage non-exposed volumes before the use of
        # Docker Compose.
        $volumes{$volume}->{'definition'} .= "    external: true\n";
      }
      close($vl_fh);
    }
    # Check required shared volume are available.
    foreach my $volume_dep (@{$module_info->{'dependencies'}{'volumes'} || []}) {
      my $dependencies = ParseDependencies($volume_dep);
      if ('REQUIRES' eq $dependencies->{'constraint'}) {
        $volume_dependencies->{$module} ||= [];
        push(@{$volume_dependencies->{$module}}, $dependencies->{'dependencies'});
      }
    }
    print "    OK\n";
  }

  # Check volume dependencies.
  foreach my $module (keys(%$volume_dependencies)) {
    foreach my $volume_deps (values(%{$volume_dependencies->{$module}})) {
      my $volume_ok = 0;
      foreach my $volume_dep (@$volume_deps) {
        # Check if the requirement is on a whole module (ie. no volume name).
        if (!$volume_dep->{'element'}) {
          if (grep($volume_dep->{'module'}, @$modules)) {
            $volume_ok = 1;
          }
          # else warn "WARNING: module '$module' requires volumes from module '$module' but that module is not enabled! GenoRing may fail to start.\n";
        }
        elsif ($volume_dep->{'element'}
            && exists($volumes{$volume_dep->{'element'}})
        ) {
          # Check for version constraints.
          if ($volume_dep->{'major_version'}) {
            my $module_info = GetModuleInfo($module);
            my $version_constraint = $volume_dep->{'version_constraint'} || '=';
            # @todo This will not work with minor versions above 10.
            my $dep_version = $volume_dep->{'major_version'} . '.' . ($volume_dep->{'minor_version'} || '');
            if ((('=' eq $version_constraint) && ($module_info->{'version'} == $dep_version))
              || (('<' eq $version_constraint) && ($module_info->{'version'} < $dep_version))
              || (('<=' eq $version_constraint) && ($module_info->{'version'} <= $dep_version))
              || (('>' eq $version_constraint) && ($module_info->{'version'} > $dep_version))
              || (('>=' eq $version_constraint) && ($module_info->{'version'} >= $dep_version))
            ) {
              $volume_ok = 1;
            }
          }
          else {
            # No version constraint and volume is there.
            $volume_ok = 1;
          }
        }
        if ($volume_ok) {
          last;
        }
      }
      if (!$volume_ok) {
        # @todo Display a more informative message.
        warn "WARNING: module '$module' has unmet volume dependencies! GenoRing may fail to start.\n";
      }
    }
  }
  # Done with all modules info.

  # Generate "services" and "volumes" sections from enabled services.
  print "  All modules processed.\n";
  my $dc_fh;
  # If $Genoring::DOCKER_COMPOSE_FILE already exists, remove unused volumes.
  if (open($dc_fh, '<:utf8', $Genoring::DOCKER_COMPOSE_FILE)) {
    my $compose_data = do { local $/; <$dc_fh> };
    close($dc_fh);
    if ($compose_data =~ m/(?:^|.*\n)volumes:/) {
      # Removes what is before "volumes:".
      $compose_data =~ s/(?:^|.*\n)volumes:\s*\n//s;
      # Removes what is after.
      $compose_data =~ s/^\S.*//sm;
      # Get all currently defined volumes.
      my @existing_volumes = $compose_data =~ m/^  ([\w\-]+):/gm;
      # Remove unused volumes.
      foreach my $unused_volume (@existing_volumes) {
        if (!exists($volumes{$unused_volume})) {
          my $unused_volume_name = GetVolumeName($unused_volume);
          Run(
            "$Genoring::DOCKER_COMMAND volume rm -f $unused_volume_name",
            "Failed to remove GenoRing volume '$unused_volume_name'!",
            0,
            $g_flags->{'verbose'}
          );
        }
      }
    }
  }

  # Add other modules to genoring container dependencies (depends_on:).
  if (open($dc_fh, '>:utf8', $Genoring::DOCKER_COMPOSE_FILE)) {
    print {$dc_fh} "# GenoRing docker compose file\n# COMPOSE_PROJECT_NAME=$ENV{'COMPOSE_PROJECT_NAME'}\n# WARNING: This file is auto-generated by genoring.sh script. Any direct\n# modification may be lost when genoring.pl will need to regenerate it.\n";
    # For each enabled service, add the section name, the indented definition,
    # and the 'container_name:' field.
    print {$dc_fh} "\nservices:\n";
    foreach my $service (sort keys(%services)) {
      my $service_name = GetContainerName($service);
      print {$dc_fh} "\n  $service:\n";
      print {$dc_fh} $services{$service}->{'definition'};
      if ($services{$service}->{'definition'} !~ m/\n$/s) {
        print {$dc_fh} "\n";
      }
      print {$dc_fh} "    container_name: $service_name\n";
      # Add dependencies between services.
      if (exists($service_dependencies->{$service})
        && (my $profile_count = scalar(keys(%{$service_dependencies->{$service}})))
      ) {
        # Filter service dependencies to only keep used services.
        if ((1 < $profile_count) || !exists($service_dependencies->{$service}->{''})) {
          # Profile-specific.
          foreach my $dep_profile ('dev', 'staging', 'prod', 'backend', 'offline') {
            my %higher_services = map
              { $_ => 1 }
              grep
                {exists($services{$_})}
                (
                  @{$service_dependencies->{$service}->{$dep_profile} || []},
                  @{$service_dependencies->{$service}->{''} || []}
                );
            my @higher_services = sort keys(%higher_services);
            my $ds_fh;
            # Create "dependencies" directory if missing.
            mkdir('dependencies') unless (-d 'dependencies');
            if (open($ds_fh, '>:utf8', "dependencies/$service.$dep_profile.yml")) {
              print {$ds_fh} "services:\n  $service:\n";
              if (@higher_services) {
                print {$ds_fh}
                  "    depends_on:\n      - "
                  . join("\n      - ", @higher_services)
                  . "\n";
              }
              close($ds_fh);
            }
          }
          print {$dc_fh} "    extends:\n      file: \${PWD}/dependencies/$service.\${COMPOSE_PROFILES}.yml\n      service: $service\n";
        }
        else {
          # All profiles.
          my %higher_services = map { $_ => 1 } grep {exists($services{$_})} @{$service_dependencies->{$service}->{''}};
          my @higher_services = sort keys(%higher_services);
          print {$dc_fh} "    depends_on:\n      - " . join("\n      - ", @higher_services) . "\n";
        }
      }
    }
    # For volumes, add the section name, the indented definition and the
    # 'name:' field. Section names and volume names are prefixed with
    # 'genoring-'.
    print {$dc_fh} "\nvolumes:\n";
    foreach my $volume (sort keys(%volumes)) {
      my $volume_name = GetVolumeName($volume);
      print {$dc_fh} "  $volume:\n";
      print {$dc_fh} $volumes{$volume}->{'definition'};
      print {$dc_fh} "    name: \"$volume_name\"\n";
      # Manage non-exposed volumes.
      if ($g_flags->{'no-exposed-volumes'}) {
        Run(
          "$Genoring::DOCKER_COMMAND volume create $volume_name",
          "Failed to create volume '$volume_name'.",
          0,
          $g_flags->{'verbose'}
        );
      }
    }

    # Check for extra hosts to add.
    if (-e $Genoring::EXTRA_HOSTS) {
      my $extra_fh;
      if (open($extra_fh, '<:utf8', $Genoring::EXTRA_HOSTS)) {
        my $extra_hosts = do { local $/; <$extra_fh> };
        close($extra_fh);
        # Trim.
        $extra_hosts =~ s/^\s+|[ \t\f]+$//gm;
        $extra_hosts =~ s/^\n+//gsm;
        if ($extra_hosts) {
          if ($extra_hosts !~ m/^(\w+: "\[?[\d.:]+\]?"\n)+$/s) {
            warn "WARNING: It seems that the extra hosts file '$Genoring::EXTRA_HOSTS' has been corrupted. GenoRing may not be able to run without manual adjustments in '$Genoring::DOCKER_COMPOSE_FILE' in the 'extra_hosts:' section.\n";
          }
          # Indent.
          $extra_hosts =~ s/^/  /gm;
          print {$dc_fh} "extra_hosts:\n$extra_hosts";
        }
      }
      else {
        warn "WARNING: failed to open extra hosts file '$Genoring::EXTRA_HOSTS'.\n$!\n";
      }
    }

    close($dc_fh);
  }
  else {
    die "ERROR: GenerateDockerComposeFile: Failed to open Docker Compose file '$Genoring::DOCKER_COMPOSE_FILE':\n$!\n";
  }
}


=pod

=head2 PrepareOperations

B<Description>: Prepares GenoRing platform for operations (update, install,
uninstall, etc.).

B<ArgsCount>: 0

B<Return>: (hash ref)

An operation context hash.

=cut

sub PrepareOperations {
  my $context = {};

  # Clear caches.
  ClearCache();

  # Check if GenoRing is running or not.
  $context->{'current_mode'} = GetState();
  $context->{'operation_mode'} = 'offline';
  if (('running' eq $context->{'current_mode'})
    || ('backend' eq $context->{'current_mode'})
  ) {
    $context->{'operation_mode'} = 'backend';
  }

  # Stop if running.
  print "- Stopping GenoRing...\n";
  eval {StopGenoring();};
  if ($@) {
    die "ERROR: Failed to stop GenoRing!\n$@\n";
  }
  print "  ...OK.\n";

  # Make a backup.
  if (!$g_flags->{'no-backup'}) {
    Backup('operation', undef, 1);
  }

  return $context;
}


=pod

=head2 PerformLocalOperations

B<Description>: Performs local operations and return new context.

B<ArgsCount>: 1

=over 4

=item $context: (hash ref) (R)

The operation context.

=back

B<Return>: (nothing)

=cut

sub PerformLocalOperations {

  my ($context) = @_;
  return if $context->{'failed'};

  my ($mode, $current_mode, $local_hooks, $module) = (
    $context->{'operation_mode'},
    $context->{'current_mode'},
    $context->{'local_hooks'},
    $context->{'module'},
  );

  eval {
    # Make sure GenoRing is stopped.
    StopGenoring();

    # Apply local hooks (modules/*/hooks/${hook}.pl).
    print "- Applying local hooks...\n";
    my @local_hooks = sort {
        my $ao = $local_hooks->{$a}->{'order'} || 0;
        my $bo = $local_hooks->{$b}->{'order'} || 0;
        return $ao <=> $bo;
      }
      keys(%$local_hooks);
    foreach my $local_hook (@local_hooks) {
      my $args = $context->{'local_hooks'}->{$local_hook}->{'args'};
      ApplyLocalHooks($local_hook, $module, $args);
      $context->{'local_hooks'}->{$local_hook}->{'ok'} = 1;
    }
    print "  ...OK.\n";
  };

  # Check for errors.
  if ($@) {
    $context->{'failed'} = $@;
  }
}


=pod

=head2 PerformContainerOperations

B<Description>: Performs an operation and restore GenoRing system after a
successfull or unsuccessfull operation.

B<ArgsCount>: 1

=over 4

=item $context: (hash ref) (R)

The operation context.

=back

B<Return>: (nothing)

=cut

sub PerformContainerOperations {

  my ($context) = @_;
  return if $context->{'failed'};

  my ($mode, $current_mode, $container_hooks, $module) = (
    $context->{'operation_mode'},
    $context->{'current_mode'},
    $context->{'container_hooks'},
    $context->{'module'},
  );

  eval {
    # Start containers in backend mode.
    print "- Starting GenoRing backend...\n";
    StartGenoring($mode);
    print "  ...OK.\n";

    # Apply docker hooks of each enabled module service for each
    # enabled module service (ie. modules/"svc1"/hooks/${hook}_"svc2".sh).
    print "  - Applying service hooks" . ($module ? " ($module)" : '') . "...\n";
    my @container_hooks = sort {
        my $ao = $container_hooks->{$a}->{'order'} || 0;
        my $bo = $container_hooks->{$b}->{'order'} || 0;
        return $ao <=> $bo;
      }
      keys(%$container_hooks);

    foreach my $container_hook (@container_hooks) {
      my $related = $context->{'container_hooks'}->{$container_hook}->{'related'};
      my $args = $context->{'container_hooks'}->{$container_hook}->{'args'};
      ApplyContainerHooks($container_hook, $module, $related, $args);
      $context->{'container_hooks'}->{$container_hook}->{'ok'} = 1;
    }
    print "  ...OK.\n";
  };

  # Check for errors.
  if ($@) {
    $context->{'failed'} = $@;
  }
}


=pod

=head2 CleanupOperations

B<Description>: Cleanup GenoRing system and revert changes in case of operation
failure.

B<ArgsCount>: 1

=over 4

=item $context: (hash ref) (R)

The operation context.

=back

B<Return>: (nothing)

=cut

sub CleanupOperations {

  my ($context) = @_;

  my ($mode, $current_mode, $local_hooks, $container_hooks, $module) = (
    $context->{'operation_mode'},
    $context->{'current_mode'},
    $context->{'local_hooks'},
    $context->{'container_hooks'},
    $context->{'module'},
  );

  if ($context->{'failed'}) {
    warn "ERROR: Failed!\n" . $context->{'failed'} . "\n";

    # Revert container hooks.
    print "  - Reverting service hooks...\n";
    my $failed = 0;
    foreach my $container_hook (keys(%$container_hooks)) {
      my $revert_hook = $context->{'container_hooks'}->{$container_hook}->{'revert'};
      if ($revert_hook) {
        my $related = $context->{'container_hooks'}->{$container_hook}->{'related'};
        my $args = $context->{'container_hooks'}->{$container_hook}->{'args'};
        eval {
          ApplyContainerHooks($revert_hook, $module, $related, $args);
          $context->{'container_hooks'}->{$container_hook}->{'reverted'} = 1;
        };
        if ($@) {
          $failed = 1;
        }
      }
    }
    print "  ..." . ($failed ? 'Failed' : 'OK') . ".\n";

    # Revert local hooks.
    StopGenoring();
    print "- Reverting local hooks...\n";
    $failed = 0;
    foreach my $local_hook (keys(%$local_hooks)) {
      my $revert_hook = $context->{'local_hooks'}->{$local_hook}->{'revert'};
      if ($revert_hook) {
        my $args = $context->{'local_hooks'}->{$local_hook}->{'args'};
        eval {
          ApplyLocalHooks($local_hook, $module, $args);
          $context->{'local_hooks'}->{$local_hook}->{'reverted'} = 1;
        };
        if ($@) {
          $failed = 1;
        }
      }
    }
    print "  ..." . ($failed ? 'Failed' : 'OK') . ".\n";

    # Restore backups.
    if (!$g_flags->{'no-backup'}) {
      Restore('operation');
    }
  }
}


=pod

=head2 EndOperations

B<Description>: Restore GenoRing system after a successfull or unsuccessfull
operation.

B<ArgsCount>: 1

=over 4

=item $context: (hash ref) (R)

The operation context.

=back

B<Return>: (nothing)

=cut

sub EndOperations {

  my ($context) = @_;

  my ($mode, $current_mode, $local_hooks, $container_hooks, $module) = (
    $context->{'operation_mode'},
    $context->{'current_mode'},
    $context->{'local_hooks'},
    $context->{'container_hooks'},
    $context->{'module'},
  );

  # Restart as needed.
  if ('running' eq $current_mode) {
    print "- Restarting GenoRing...\n";
    StartGenoring('online');
    print "  ...OK.\n";
  }
  elsif (('backend' ne $current_mode) && ('offline' ne $current_mode)) {
    # Stop containers.
    print "- Stopping Genoring...\n";
    StopGenoring();
    print "  ...OK.\n";
  }
  print "Operation done.\n";
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

  my $context = PrepareOperations();
  $context->{'module'} = $module;
  $context->{'local_hooks'} = {
    'update' => {},
  };
  $context->{'container_hooks'} = {
    'update' => {},
  };

  PerformLocalOperations($context);
  PerformContainerOperations($context);
  CleanupOperations($context);
  EndOperations($context);
}


=pod

=head2 Upgrade

B<Description>: Upgrades the GenoRing system or the specified module.

B<ArgsCount>: 0-1

=over 4

=item $module: (string) (O)

The module name is only this module should be upgraded.

=back

B<Return>: (nothing)

=cut

sub Upgrade {

  my ($module) = @_;
  if ($module) {
    print "Upgrading GenoRing module '$module'...\n";
  }
  else {
    print "Upgrading GenoRing...\n";
  }
  # @todo Implement.
  die "EROR: Not implemented yet!\n";
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

  if (! -d "$Genoring::MODULES_DIR/$module") {
    die "ERROR: InstallModule: Module '$module' not found!\n";
  }

  my $module_info = GetModuleInfo($module);
  # Check requirements.
  if (!$module_info
      || !$module_info->{'genoring_script_version'}
      || ($module_info->{'genoring_script_version'} > $Genoring::GENORING_VERSION)
  ) {
    die "ERROR: InstallModule: Module '$module' not supported by current GenoRing script version!\nRequired version: " . ($module_info->{'genoring_script_version'} || 'n/a') . ", current script version: $Genoring::GENORING_VERSION.\n";
  }

  my %enabled_modules = map { $_ => $_ } @{GetModules(1)};
  if (exists($enabled_modules{$module})) {
    warn "WARNING: InstallModule: Module '$module' already installed!\n";
    return;
  }

  # Check module requirements.
  my $errors = ApplyLocalHooks('requirements', $module);
  if (scalar(values(%$errors))) {
    die
      "ERROR: Could not install module '$module': some requirements were not met.\n"
      . $errors->{$module};
  }
  # Check module dependencies.
  # @todo Dependencies are not checked properly:
  #   - no version check.
  #   - no service check.
  #   - no conflict check.
  foreach my $service_dep (@{$module_info->{'dependencies'}->{'services'}}) {
    my $constraint = ParseDependencies($service_dep);
    next if !%$constraint;
    # Only look for requirements or conflicts.
    if ('REQUIRES' eq $constraint->{'constraint'}) {
      # Check if one of the required modules is installed.
      my $dependency_ok = 0;
      foreach my $dependency (@{$constraint->{'dependencies'}}) {
        if (exists($enabled_modules{$dependency->{'module'}})) {
          # @todo Check version.
          # my $dep_service = $dependency->{'element'}
          # $dependency->{'version_constraint'}
          # $dependency->{'major_version'}
          # $dependency->{'minor_version'}
          $dependency_ok = 1;
          last;
        }
      }
      if (!$dependency_ok) {
        die
          "ERROR: Could not install module '$module': some required modules are not enabled:\n- "
          . join("\n- ", map { $_->{'module'}; } @{$constraint->{'dependencies'}});
      }
    }
    elsif ('CONFLICTS' eq $constraint->{'constraint'}) {
      # @todo To implement...
    }
  }
  my $context = PrepareOperations();
  $context->{'module'} = $module;
  $context->{'local_hooks'} = {
    'init' => {
      'revert' => 'uninstall',
    },
  };
  $context->{'container_hooks'} = {
    'enable' => {
      'revert' => 'disable',
    },
  };

  # Setup environment files.
  eval {
    # Enable module.
    SetModuleConf(
      $module,
      {
        'status' => 'enabled',
        'version' => $module_info->{'version'},
      }
    );

    # Setup new environment variables.
    SetupGenoringEnvironment(undef, $module);

    if (!exists($g_flags->{'hide-compile'})) {
      # Compile missing containers with sources.
      CompileMissingContainers();
    }

    PerformLocalOperations($context);

    # Update Docker Compose config.
    GenerateDockerComposeFile();

    PerformContainerOperations($context);
  };
  # Check if an intermediate operation failed.
  if ($@) {
    $context->{'failed'} = $@;
  }

  CleanupOperations($context);

  if ($context->{'failed'}) {
    eval {
      # Remove module from modules.yml if installation failed.
      RemoveModuleConf($module);
    };
    warn "WARNING: $@\n" if $@;
    eval {
      # Update Docker Compose config.
      GenerateDockerComposeFile();
    };
    warn "WARNING: $@\n" if $@;
  }

  EndOperations($context);
}


=pod

=head2 EnableModule

B<Description>: Installs and enables the given module.

B<ArgsCount>: 1

=over 4

=item $module: (string) (R)

The module name.

=back

B<Return>: (nothing)

=cut

sub EnableModule {
  my ($module) = @_;
  if (!$module) {
    die "ERROR: EnableModule: Missing module name!\n";
  }

  if (! -d "$Genoring::MODULES_DIR/$module") {
    die "ERROR: EnableModule: Module '$module' not found!\n";
  }

  # @todo Check module dependencies.

  my %enabled_modules = map { $_ => $_ } @{GetModules(1)};
  if (exists($enabled_modules{$module})) {
    die "ERROR: EnableModule: Module '$module' already enabled!\n";
  }
  my %disabled_modules = map { $_ => $_ } @{GetModules(0)};
  if (!exists($disabled_modules{$module})) {
    die "ERROR: EnableModule: Module '$module' not installed!\n";
  }

  my $context = PrepareOperations();
  $context->{'module'} = $module;
  $context->{'local_hooks'} = {
    'enable' => {
      'revert' => 'disable',
    },
  };
  $context->{'container_hooks'} = {
    'enable' => {
      'revert' => 'disable',
    },
  };

  # Setup environment files.
  eval {
    # Enable module.
    my $module_config = GetModuleConf($module);
    $module_config->{'status'} = 'enabled';
    SetModuleConf($module, $module_config);

    PerformLocalOperations($context);

    # Update Docker Compose config.
    GenerateDockerComposeFile();

    PerformContainerOperations($context);
  };
  # Check if an intermediate operation failed.
  if ($@) {
    $context->{'failed'} = $@;
  }

  CleanupOperations($context);

  if ($context->{'failed'}) {
    eval {
      # Disable module if failed.
      my $module_config = GetModuleConf($module);
      $module_config->{'status'} = 'disabled';
      SetModuleConf($module, $module_config);
    };
    warn "WARNING: $@\n" if $@;
    eval {
      # Update Docker Compose config.
      GenerateDockerComposeFile();
    };
    warn "WARNING: $@\n" if $@;
  }

  EndOperations($context);
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

  if (! -d "$Genoring::MODULES_DIR/$module") {
    warn "WARNING: DisableModule: Module '$module' not found!\n";
  }

  # @todo Check other module dependencies (to this module).

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

  my $context = PrepareOperations();
  $context->{'module'} = $module;
  $context->{'local_hooks'} = {
    'disable' => {
      'revert' => 'enable',
      'order' => 1,
    },
  };
  $context->{'container_hooks'} = {
    'disable' => {
      'revert' => 'enable',
      'related' => 1,
      'order' => 1,
    },
  };
  if ($uninstall) {
    $context->{'local_hooks'}->{'uninstall'} = {'order' => 2,};
    $context->{'container_hooks'}->{'uninstall'} = {'related' => 1, 'order' => 2,};
  }

  eval {
    # Disable or uninstall module.
    if ($uninstall) {
      RemoveModuleConf($module);
    }
    else {
      # @todo Get current module config and just change its status.
      my $module_config = GetModuleConf($module);
      $module_config->{'status'} = 'disabled';
      SetModuleConf($module, $module_config);
    }
    # Update Docker Compose config.
    GenerateDockerComposeFile();

    # Set maintenance mode to apply disabling hooks.
    PerformContainerOperations($context);

    # Perform local hooks if needed.
    PerformLocalOperations($context);

    if ($uninstall && !$g_flags->{'keep-env'}) {
      # Remove module environment files.
      RemoveEnvFiles($module);
    }
  };
  if ($@) {
    $context->{'failed'} = $@;
  }
  CleanupOperations($context);
  EndOperations($context);
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

  if (! -d "$Genoring::MODULES_DIR/$module") {
    warn "WARNING: UninstallModule: Module '$module' not found!\n";
  }

  # @todo Check other module dependencies (to this module).

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

=head2 ListAlternatives

B<Description>: Lists module alternatives.

B<ArgsCount>: 1

=over 4

=item $module: (string) (R)

The module of interest.

=back

B<Return>: (nothing)

=cut

sub ListAlternatives {
  my ($module) = @_;

  if (!$module) {
    # Die on logic error.
    die "ERROR: ListAlternatives: Missing module name!\n";
  }

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


=pod

=head2 EnableAlternative

B<Description>: Enables a module alternative.

B<ArgsCount>: 2

=over 4

=item $module: (string) (R)

The module of interest.

=item $alternative_name: (string) (R)

The alternative to enable.

=back

B<Return>: (nothing)

=cut

sub EnableAlternative {
  my ($module, $alternative_name) = @_;

  if (!$module) {
    # Die on logic error.
    die "ERROR: EnableAlternative: Missing module name!\n";
  }
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
    if (!-w "$Genoring::MODULES_DIR/$module/services") {
      die "ERROR: Cannot enable alternative '$alternative_name' on module '$module': the service directory ($Genoring::MODULES_DIR/$module/services) is write-protected.\n";
    }

    # Make sure services have not been already altered.
    my $alternative = $alternatives->{$alternative_name};
    my (@missing_services, @disabled_services);
    foreach my $old_service (keys(%{$alternative->{'substitue'} || {}}), keys(%{$alternative->{'remove'} || {}})) {
      if (-e "$Genoring::MODULES_DIR/$module/services/$old_service.yml.dis") {
        push(@disabled_services, $old_service);
      }
      if (!-e "$Genoring::MODULES_DIR/$module/services/alt/$old_service.yml") {
        push(@missing_services, $old_service);
      }
    }
    if (@disabled_services) {
      die "ERROR: Cannot enable alternative '$alternative_name' on module '$module': some impacted services have already been changed by another alteration (services: " . join(', ', @disabled_services) . ").\n";
    }
    my @added_services;
    foreach my $new_service (keys(%{$alternative->{'add'} || {}})) {
      if (-e "$Genoring::MODULES_DIR/$module/services/$new_service.yml") {
        push(@added_services, $new_service);
      }
      if (!-e "$Genoring::MODULES_DIR/$module/services/alt/$new_service.yml") {
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
        if (!rename("$Genoring::MODULES_DIR/$module/services/$to_rename.yml", "$Genoring::MODULES_DIR/$module/services/$to_rename.yml.dis")) {
          die "ERROR: Cannot enable alternative '$alternative_name' on module '$module': service '$to_rename' could not be replaced/removed.\n$!";
        }
        push(@renamed, $to_rename);
      }
      foreach my $to_add (keys(%{$alternative->{'substitue'} || {}}), keys(%{$alternative->{'add'} || {}})) {
        if (!copy("$Genoring::MODULES_DIR/$module/services/alt/$to_add.yml", "$Genoring::MODULES_DIR/$module/services/$to_add.yml")) {
          die "ERROR: Cannot enable alternative '$alternative_name' on module '$module': service '$to_add' could not be added/replaced.\n$!";
        }
        push(@copied, $to_add);
      }
    };
    if ($@) {
      # Undo changes.
      foreach my $to_remove (@copied) {
        # Remove added files.
        unlink("$Genoring::MODULES_DIR/$module/services/$to_remove.yml");
      }
      foreach my $to_restore (@renamed) {
        # Revert renaming.
        rename("$Genoring::MODULES_DIR/$module/services/$to_restore.yml.dis", "$Genoring::MODULES_DIR/$module/services/$to_restore.yml");
      }
      die $@;
    }
  }
  else {
    die "ERROR: alternative '$alternative_name' not found for module '$module'.\n";
  }

}


=pod

=head2 DisableAlternative

B<Description>: Disables a module alternative.

B<ArgsCount>: 2

=over 4

=item $module: (string) (R)

The module of interest.

=item $alternative_name: (string) (R)

The alternative to disable.

=back

B<Return>: (nothing)

=cut

sub DisableAlternative {
  my ($module, $alternative_name) = @_;
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
    if (!-w "$Genoring::MODULES_DIR/$module/services") {
      die "ERROR: Cannot disable alternative '$alternative_name' on module '$module': the service directory ($Genoring::MODULES_DIR/$module/services) is write-protected.\n";
    }

    # Make sure services have already been altered.
    my $alternative = $alternatives->{$alternative_name};
    my @missing_services;
    foreach my $old_service (keys(%{$alternative->{'substitue'} || {}}), keys(%{$alternative->{'remove'} || {}})) {
      if (!-e "$Genoring::MODULES_DIR/$module/services/alt/$old_service.yml.dis") {
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
        if (-e "$Genoring::MODULES_DIR/$module/services/$to_remove.yml"
          && !unlink("$Genoring::MODULES_DIR/$module/services/$to_remove.yml")
        ) {
          die "ERROR: Cannot disable alternative '$alternative_name' on module '$module': altered service '$to_remove' could not be removed.\n$!";
        }
      }
      foreach my $to_rename (keys(%{$alternative->{'substitue'} || {}}), keys(%{$alternative->{'remove'} || {}})) {
        if (!rename("$Genoring::MODULES_DIR/$module/services/$to_rename.yml.dis", "$Genoring::MODULES_DIR/$module/services/$to_rename.yml")) {
          die "ERROR: Cannot disable alternative '$alternative_name' on module '$module': service '$to_rename' could not be put back.\n$!";
        }
        push(@renamed, $to_rename);
      }
    };
    if ($@) {
      # Undo changes.
      foreach my $to_restore (@renamed) {
        # Revert renaming.
        rename("$Genoring::MODULES_DIR/$module/services/$to_restore.yml", "$Genoring::MODULES_DIR/$module/services/$to_restore.yml.dis");
      }
      die $@;
    }
  }
  else {
    die "ERROR: alternative '$alternative_name' not found for module '$module'.\n";
  }
}


=pod

=head2 ToLocalService

B<Description>: Turns a docker service into a local service.

B<ArgsCount>: 2

=over 4

=item $service: (string) (R)

The service name.

=item $ip: (string) (R)

The IP running the service.

=back

B<Return>: (nothing)

=cut

sub ToLocalService {
  my ($service, $ip) = @_;
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
  if (-e "$Genoring::MODULES_DIR/$module/services/alt/$service.yml.dis") {
    # Using an alternative, remove it.
    if (!unlink("$Genoring::MODULES_DIR/$module/services/$service.yml")) {
      die "ERROR: Cannot disable module '$module' service '$service'.\n$!";
    }
  }
  else {
    if (!rename("$Genoring::MODULES_DIR/$module/services/$service.yml", "$Genoring::MODULES_DIR/$module/services/$service.yml.dis")) {
      die "ERROR: Cannot disable module '$module' service '$service'.\n$!";
    }
  }
  # Append replacing host to "extra_hosts".
  my $extra_fh;
  if (open($extra_fh, '>>:utf8', $Genoring::EXTRA_HOSTS)) {
    print {$extra_fh} "$service: \"$ip\"\n";
    close($extra_fh);
  }
  else {
    die "ERROR: failed to open extra hosts file '$Genoring::EXTRA_HOSTS' to add replacing host ($service: \"$ip\")\n$!\n";
  }
  GenerateDockerComposeFile();
}


=pod

=head2 ToDockerService

B<Description>: Turns back a local service into a docker service.

B<ArgsCount>: 1-2

=over 4

=item $service: (string) (R)

The service name.

=item $alternative_name: (string) (O)

The service alternative to enable if needed.

=back

B<Return>: (nothing)

=cut

sub ToDockerService {
  my ($service, $alternative_name) = @_;
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


=pod

=head2 Backup

B<Description>: Performs a general backup of the GenoRing system into an archive
file or a backup of the given module data and config.

B<ArgsCount>: 0-3

=over 4

=item $backup_name: (string) (U)

The backup name. If not set, a default one is provided. Backup names must only
contain letters, numbers, dots, underscores and dashes and must begin with a
letter.

=item $module: (string) (U)

Module machine name if only one module should be backuped.

=item $no_confirm: (bool) (U)

If set to a TRUE value, existing backup would be overwritten without
confirmation.

=back

B<Return>: (nothing)

=cut

sub Backup {
  my ($backup_name, $module, $no_confirm) = @_;
  if (!$backup_name) {
    # No name provided, use a default one.
    $backup_name = localtime->strftime('backup_%Y%d%mT%H%M');
  }
  elsif ($backup_name !~ m/^[a-z][\w._\-]*$/i) {
    die "ERROR: Backup: Invalid back name '$backup_name'. Only letters, numbers, dots, underscores and dashes are allowed and the name must begin with a letter.\n";
  }

  my $backupdir = "$Genoring::VOLUMES_DIR/backups/$backup_name";
  if (-d $backupdir) {
    # Check if directory is not empty.
    opendir(my $dh, $backupdir)
      or die "ERROR: Backup: Failed to open backup directory '$backupdir'.";
    if (scalar(grep { $_ ne "." && $_ ne ".." } readdir($dh)) != 0) {
      if (!$no_confirm && !Confirm("WARNING: The backup directory '$backupdir' is not empty! Overwrite existing backups?")) {
        die "ERROR: Backup: Backup directory '$backupdir' is not empty. Aborting.";
      }
    }
  }
  else {
    if (!mkdir $backupdir) {
      die "ERROR: Backup: Failed to create backup directory '$backupdir'.\n";
    }
  }

  print "Backuping GenoRing...\n";
  # Backup GenoRing config.
  if (!$module) {
    print "- Backuping GenoRing config...\n";
    if (!-d "$backupdir/config" && !mkdir "$backupdir/config") {
      warn "WARNING: Backup: Failed to create config backup directory '$backupdir/config'.\n";
    }
    if (-e $Genoring::DOCKER_COMPOSE_FILE
      && !copy($Genoring::DOCKER_COMPOSE_FILE, "$backupdir/config/$Genoring::DOCKER_COMPOSE_FILE")
    ) {
      warn "WARNING: Failed to backup $Genoring::DOCKER_COMPOSE_FILE.\n$!";
    }
    if (-e $Genoring::MODULE_FILE
      && !copy($Genoring::MODULE_FILE, "$backupdir/config/$Genoring::MODULE_FILE")
    ) {
      warn "WARNING: Failed to backup $Genoring::MODULE_FILE.\n$!";
    }
    if (-e $Genoring::EXTRA_HOSTS
      && !copy($Genoring::EXTRA_HOSTS, "$backupdir/config/$Genoring::EXTRA_HOSTS")
    ) {
      warn "WARNING: Failed to backup $Genoring::EXTRA_HOSTS.\n$!";
    }
    if (-d './env'
      && !DirCopy('env', "$backupdir/config/env")
    ) {
      warn "WARNING: Failed to backup 'env' directory.\n$!";
    }
    print "  ...OK.\n";
  }

  # Check if GenoRing is running or not.
  my $current_mode = GetState();
  my $mode = 'offline';
  if (('running' eq $current_mode)
    || ('backend' eq $current_mode)
  ) {
    $mode = 'backend';
  }

  eval {
    # Stop if running.
    print "- Stopping GenoRing...\n";
    StopGenoring();
    print "  ...OK.\n";

    # Launch backup hooks (modules/*/hooks/backup.pl).
    print "- Backuping modules data...\n";
    ApplyLocalHooks('backup', $module, $backup_name);
    print "  ...Modules backuped on local system, backuping services data...\n";

    # Start containers in backend mode.
    print "  - Starting GenoRing backend for backup...\n";
    StartGenoring($mode);
    print "    ...OK.\n";

    # Apply docker backup hooks of each enabled module service for each
    # enabled module service (ie. modules/"svc1"/hooks/backup_"svc2".sh).
    print "  - Calling service backup hooks...\n";
    ApplyContainerHooks('backup', $module, 1, $backup_name);
    print "  ...Services backuped.\n";

    # Restart as needed.
    if ('running' eq $current_mode) {
      print "- Restarting GenoRing...\n";
      StartGenoring('online');
      print "  ...OK.\n";
    }
    elsif (('backend' ne $current_mode) && ('offline' ne $current_mode)) {
      # Stop containers.
      print "- Stopping Genoring...\n";
      StopGenoring();
      print "  ...OK.\n";
    }

    print "Backup done. Backup created in 'backups/$backup_name/'.\n";
  };

  if ($@) {
    print "ERROR: Backup failed!\n$@\n";
  }
}


=pod

=head2 Restore

B<Description>: Restores GenoRing from a given backup.

B<ArgsCount>: 1-2

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
  # Restore GenoRing config.
  my $backupdir = "$Genoring::VOLUMES_DIR/backups/$backup_name";
  if (!$module) {
    print "- Restoring GenoRing config...\n";
    if (-e "$backupdir/config/$Genoring::DOCKER_COMPOSE_FILE"
      && !copy("$backupdir/config/$Genoring::DOCKER_COMPOSE_FILE", $Genoring::DOCKER_COMPOSE_FILE)
    ) {
      warn "WARNING: Failed to restore $Genoring::DOCKER_COMPOSE_FILE.\n$!";
    }
    if (-e "$backupdir/config/$Genoring::MODULE_FILE"
      && !copy("$backupdir/config/$Genoring::MODULE_FILE", $Genoring::MODULE_FILE)
    ) {
      warn "WARNING: Failed to restore $Genoring::MODULE_FILE.\n$!";
    }
    if (-e "$backupdir/config/$Genoring::EXTRA_HOSTS"
      && !copy("$backupdir/config/$Genoring::EXTRA_HOSTS", $Genoring::EXTRA_HOSTS)
    ) {
      warn "WARNING: Failed to restore $Genoring::EXTRA_HOSTS.\n$!";
    }
    if (-d "$backupdir/config/env"
      && !DirCopy("$backupdir/config/env", 'env')
    ) {
      warn "WARNING: Failed to restore 'env' directory.\n$!";
    }
    print "  ...OK.\n";
  }

  # Check if GenoRing is running or not.
  my $current_mode = GetState();
  my $mode = 'offline';
  if (('running' eq $current_mode)
    || ('backend' eq $current_mode)
  ) {
    $mode = 'backend';
  }

  eval {
    # Stop if running.
    print "- Stopping GenoRing...\n";
    StopGenoring();
    print "  ...OK.\n";

    # Launch restore hooks (modules/*/hooks/restore.pl).
    print "- Restoring modules data...\n";
    ApplyLocalHooks('restore', $module, $backup_name);
    print "  ...Modules restored on local system, restoring services data...\n";

    # Start containers in backend mode.
    print "  - Starting GenoRing backend for backup restoration...\n";
    StartGenoring($mode);
    print "    ...OK.\n";

    # Apply docker restore hooks of each enabled module service for each
    # enabled module service (ie. modules/"svc1"/hooks/restore_"svc2".sh).
    print "  - Calling service restore hooks...\n";
    ApplyContainerHooks('restore', $module, 1, $backup_name);
    print "  ...Services restored.\n";

    # Restart as needed.
    if ('running' eq $current_mode) {
      print "- Restarting GenoRing...\n";
      StartGenoring('online');
      print "  ...OK.\n";
    }
    elsif (('backend' ne $current_mode) && ('offline' ne $current_mode)) {
      # Stop containers.
      print "- Stopping Genoring...\n";
      StopGenoring();
      print "  ...OK.\n";
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
- requirements: called before a module is installed to check for its local
  requirements.
- init: called just before a module is enabled, in order to setup the file
  system (ie. create local data directories, generate, download or copy files,
  etc.).
- disable: perform actions on file system to disable the module.
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

B<Return>: (hash ref)
A reference to a hash which keys are module name and values are error messages
of each hook execution if a failure occurred. The hash is empty if no error
occurred.

=cut

sub ApplyLocalHooks {
  my ($hook_name, $module, $args) = @_;
  $args ||= '';
  my $errors = {};

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

  foreach $module (@$modules) {
    if (-e "$Genoring::MODULES_DIR/$module/hooks/$hook_name.pl") {
      if ($g_debug) {
        print "DEBUG: Applying '$module' local hook '$Genoring::MODULES_DIR/$module/hooks/$hook_name.pl'...\n";
      }
      print "  Processing $module module hook $hook_name...";
      my $hook_script = File::Spec->catfile($Genoring::MODULES_DIR, $module, 'hooks', "$hook_name.pl");
      # @todo Add environment variables.
      eval {
        Run(
          # "export \$(cat env/*.env | grep '^\w'| xargs -d '\\n') && perl $hook_script $args",
          # cat env/*.env | grep '^\w' | while IFS='=' read -r name value; do export "$name=$value"; done
          # Issue: the above don't work with values containing spaces or with ending comments.
          "perl $hook_script $args",
          "Failed to process $module module hook $hook_name!",
          1,
          $g_flags->{'verbose'}
        );
      };
      if ($@) {
        $errors->{$module} = $@;
        print "  Failed.\n";
      }
      else {
        print "  OK.\n";
      }
    }
  }
  if (scalar(values(%$errors))) {
    warn "ERROR: ApplyLocalHooks:\n" . join("\n", values(%$errors)) . "\n";
  }
  return $errors;
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
- offline: called for GenoRing is set offline.
- online: called for is set online.
- update: called for a module on services when one of them is updated.
- backup: called for a module on services when one of them must perform backups
  with the backup name as first argument.
- restore: called for a module on services when one of them must restore files,
  content and config using the backup name provided as first argument.

B<ArgsCount>: 1-4

=over 4

=item $hook_name: (string) (R)

The hook name.

=item $spec_module: (string) (U)

Restrict hooks to the specified module and its services. When set to a valid
module name, only its hooks will be processed first and then only other module
hooks related to this module will be run as well if $related is set to 1.

=item $related: (bool) (O)

Will also run hook scripts of other modules targeting one service of
$spec_module.

=item $args: (string) (O)

Additional arguments to transmit to the hook script in command line.

=back

B<Return>: (nothing)

=cut

sub ApplyContainerHooks {
  my ($hook_name, $spec_module, $related, $args) = @_;
  $args ||= '';

  if (!$hook_name) {
    die "ERROR: ApplyContainerHooks: Missing hook name!\n";
  }

  # Get enabled modules.
  my $modules;
  if (!$spec_module || $related) {
    $modules = GetModules(1);
    if ($spec_module && !grep(/^$spec_module$/, @$modules)) {
      # Add module being disabled/uninstalled.
      push(@$modules, $spec_module);
    }
  }
  else {
    $modules = [$spec_module];
  }

  # Get enabled services.
  my $services = GetServices();

  # Process enabled modules.
  my %initialized_containers;
APPLYCONTAINERHOOKS_MODULES:
  foreach my $module (@$modules) {
    if ($g_debug) {
      print "DEBUG: Processing '$module' container '$hook_name' hooks...\n";
    }
    if (-d "$Genoring::MODULES_DIR/$module/hooks/") {
      # Read directory and filter on services.
      opendir(my $dh, "$Genoring::MODULES_DIR/$module/hooks")
        or die "ERROR: ApplyContainerHooks: Failed to list '$Genoring::MODULES_DIR/$module/hooks' directory!\n$!";
      my @hooks = (grep { $_ =~ m/^${hook_name}_.+\.sh$/ && -r "$Genoring::MODULES_DIR/$module/hooks/$_" } readdir($dh));
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
          if ($spec_module && ($spec_module ne $module) && ($services->{$service} ne $spec_module)) {
            if ($g_debug) {
              print "DEBUG: non-matching container hook '$Genoring::MODULES_DIR/$module/hooks/$hook' for '$service' container.\n";
            }
            # Skip non-matching hooks.
            next APPLYCONTAINERHOOKS_HOOKS;
          }
          if ($g_debug) {
            print "DEBUG: Applying container hook '$Genoring::MODULES_DIR/$module/hooks/$hook' in '$service' container.\n";
          }
          else {
            print "  Processing $module module hook $hook_name in '$service' container...";
          }
          # Check if container is running.
          my $service_name = GetContainerName($service);
          my ($id, $state, $name, $image) = IsContainerRunning($service_name);
          if ($state && ($state !~ m/running/)) {
            $state ||= 'not running';
            warn "WARNING: Failed to run $module module hook in $service (hook $hook): $service_name is $state.";
            next APPLYCONTAINERHOOKS_HOOKS;
          }
          # Provide module files to container if not done already.
          if (!exists($initialized_containers{$service})) {
            # Copy GenoRing module files as root.
            Run(
              "$Genoring::DOCKER_COMMAND exec " . ($g_flags->{'platform'} ? '--platform ' . $g_flags->{'platform'} . ' ' : '') . "-u 0 -it $service_name sh -c \"mkdir -p /genoring && rm -rf /genoring/modules\"",
              "Failed to prepare module file copy in $service_name ($module $hook hook)",
              0,
              $g_flags->{'verbose'}
            );
            Run(
              "$Genoring::DOCKER_COMMAND cp $Genoring::MODULES_DIR/ $service_name:/genoring/modules",
              "Failed to copy module files in $service_name ($module $hook hook)",
              0,
              $g_flags->{'verbose'}
            );
            $initialized_containers{$service} = 1;
          }
          # Make sure script is executable and run as root.
          # Note: we trust hook scripts are they are stored outside GenoRing
          # Docker containers.
          my $env_data = join(' --env-file ', GetEnvironmentFiles($services->{$service}), GetEnvironmentFiles($module));
          if ($env_data) {
            $env_data = ' --env-file ' . $env_data;
          }
          $env_data .= ' -e GENORING_HOST=' . $ENV{'GENORING_HOST'} . ' -e GENORING_PORT=' . $ENV{'GENORING_PORT'} . ' ';
          my $output = Run(
            "$Genoring::DOCKER_COMMAND exec " . $env_data . ($g_flags->{'platform'} ? '--platform ' . $g_flags->{'platform'} . ' ' : '') . "-u 0 -it $service_name sh -c \"chmod uog+x /genoring/modules/$module/hooks/$hook && /genoring/modules/$module/hooks/$hook $args\"",
            "Failed to run hook of $module in $service_name (hook $hook)",
            0,
            $g_flags->{'verbose'}
          );
          if ($?) {
            print "  Failed.\n$output\n";
          }
          else {
            print "  OK.\n";
          }
        }
      }
    }
    if ($g_debug) {
      print "DEBUG: ...OK.\n";
    }
  }
}


=pod

=head2 Compile

B<Description>: Compiles a given container. Two arguments are always passed to
the builder: GENORING_UID and GENORING_GID that correspond to their respective
environment variables set by GenoRing.

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
  elsif (!-d "$Genoring::MODULES_DIR/$module") {
    die "ERROR: Compile: The given module ($module) was not found in the module directory!";
  }
  elsif (!-d "$Genoring::MODULES_DIR/$module/src") {
    die "ERROR: Compile: The given module ($module) does not have sources!";
  }

  if (!$service) {
    # Try to get default service.
    opendir(my $dh, "$Genoring::MODULES_DIR/$module/src")
      or die "ERROR: Compile: Failed to access '$Genoring::MODULES_DIR/$module/src' directory!";
    my @services = (grep { $_ ne '.' && $_ ne '..' && -d "$Genoring::MODULES_DIR/$module/src/$_" } readdir($dh));
    if (1 == scalar(@services)) {
      $service = shift(@services);
    }
    else {
      die "ERROR: Compile: Missing service name!";
    }
  }

  # Check if "buildx" is enabled.
  my $disable_buildx = 0;
  if (!$g_flags->{'bypass'}) {
    my $output = qx($Genoring::DOCKER_COMMAND buildx ls 2>&1);
    if ($?) {
      warn "WARNING: '$Genoring::DOCKER_COMMAND buildx' command not available!\n";
      $disable_buildx = 1;
    }
    elsif ($? == 0 && $output =~ /\buse\b/) {
      if (Confirm("WARNING: Docker buildx (BuildKit plugin) is not enabled. It may be a problem if running ARM architectures. Do you want to enable it?")) {
        $output = qx($Genoring::DOCKER_COMMAND buildx create --use 2>&1);
        if ($?) {
          warn "WARNING: Failed to enable Docker buildx:\n$output\n";
          $disable_buildx = 1;
        }
      }
      else {
        $disable_buildx = 1;
      }
    }
    if ($disable_buildx) {
      $Genoring::DOCKER_BUILD_COMMAND =~ s/ buildx//;
    }
  }

  # Get service sub-directory for sources (take into account ARM support).
  if (!-d "$Genoring::MODULES_DIR/$module/src/$service") {
    die "ERROR: Compile: The given service (${module}[$service]) does not have sources!";
  }
  elsif ((!-r "$Genoring::MODULES_DIR/$module/src/$service/Dockerfile")
    && (!-r "$Genoring::MODULES_DIR/$module/src/$service/Dockerfile.default")
  ) {
    die "ERROR: Compile: Unable to access the Dockerfile of the given service (${module}[$service])!";
  }

  # Other platform support.
  if ($g_flags->{'platform'} && ($g_flags->{'platform'} !~ m~^$Genoring::DEFAULT_ARCHITECTURE$~)) {
    my $platform_arch = $g_flags->{'platform'};

    # Make sure we got a linux/amd64 version.
    if (!-e "$Genoring::MODULES_DIR/$module/src/$service/Dockerfile.default") {
      # No linux/amd64 version, assume current one is.
      if (!rename("$Genoring::MODULES_DIR/$module/src/$service/Dockerfile", "$Genoring::MODULES_DIR/$module/src/$service/Dockerfile.default")) {
        die "ERROR: Cannot rename '$Genoring::MODULES_DIR/$module/src/$service/Dockerfile'.\n$!";
      }
    }
    # Here we got a 'Dockerfile.default'.

    # Now generate a new platform version.
    if (-e "$Genoring::MODULES_DIR/$module/src/$service/Dockerfile") {
      # Remove current 'Dockerfile'.
      unlink("$Genoring::MODULES_DIR/$module/src/$service/Dockerfile");
    }
    # Replace "FROM xxx:yyy" by "FROM --platform=*** xxx:yyy".
    my $dockerfile_fh;
    if (open($dockerfile_fh, '<:utf8', "$Genoring::MODULES_DIR/$module/src/$service/Dockerfile.default")) {
      my $docker_source = do { local $/; <$dockerfile_fh> };
      close($dockerfile_fh);
      $docker_source =~ s~^FROM\s+(?:--platform=\S+\s+)?([a-z0-9][a-z0-9\._-]*)((?:[:@][a-z0-9][a-z0-9\._-]*)?)(\s|$)~FROM --platform=$platform_arch $1$2$3~mg;
      if (open($dockerfile_fh, '>:utf8', "$Genoring::MODULES_DIR/$module/src/$service/Dockerfile")) {
        print {$dockerfile_fh} $docker_source;
        close($dockerfile_fh);
      }
    }
  }
  elsif (-e "$Genoring::MODULES_DIR/$module/src/$service/Dockerfile.default"
    || !-e "$Genoring::MODULES_DIR/$module/src/$service/Dockerfile"
  ) {
    # Compiling for linux/amd64, make sure we got a 'Dockerfile' in linux/amd64
    # version.
    # Note: only get here if either we got a 'Dockerfile.default' which means a
    # '-arm' or '--platform' compile flag were used before and may have changed
    # the 'Dockerfile' or because we don't have any 'Dockerfile' at all but we
    # got a 'Dockerfile.default'.
    if (-e "$Genoring::MODULES_DIR/$module/src/$service/Dockerfile") {
      # Remove current 'Dockerfile'.
      unlink("$Genoring::MODULES_DIR/$module/src/$service/Dockerfile");
    }
    # Copy linux/amd64 Dockerfile.
    if (!copy("$Genoring::MODULES_DIR/$module/src/$service/Dockerfile.default", "$Genoring::MODULES_DIR/$module/src/$service/Dockerfile")) {
      die "ERROR: Cannot copy '$Genoring::MODULES_DIR/$module/src/$service/Dockerfile.default'.\n$!";
    }
  }
  print "Compiling service ${module}[$service]...\n";

  # Check if container is running and stop it unless it is not running the same
  # image.
  # @todo The following code does not take into account non-genoring project
  # names (ie. my $service_name = GetContainerName($service)). Since multiple
  # projects may run with the same image, each should be checked.
  my ($id, $state, $name, $image) = IsContainerRunning($service);
  if ($id) {
    if ($image && ($image ne $service)) {
      die "ERROR: Compile: A container with the same name ($service) but a different image ($image) is currently running. Please stop it before compiling.";
    }
    Run(
      "$Genoring::DOCKER_COMMAND stop $id",
      "Failed to stop container '$service' (image $image)!",
      0,
      $g_flags->{'verbose'}
    );
    Run(
      "$Genoring::DOCKER_COMMAND container prune -f",
      "Failed to prune containers!",
      0,
      $g_flags->{'verbose'}
    );
  }

  Run(
    "$Genoring::DOCKER_COMMAND image rm -f $service",
    "Failed to remove previous image (service ${module}[$service])!",
    1,
    $g_flags->{'verbose'}
  );
  my $service_src_path = File::Spec->catfile($Genoring::MODULES_DIR, $module, 'src' , $service);
  my $no_cache = '';
  if ($g_flags->{'no-cache'}) {
    $no_cache = '--no-cache';
  }
  Run(
    "$Genoring::DOCKER_BUILD_COMMAND $no_cache --build-arg GENORING_UID=\${GENORING_UID} --build-arg GENORING_GID=\${GENORING_GID} -t $service $service_src_path",
    "Failed to compile container (service ${module}[$service])",
    1,
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
    my $image_id = qx($g_exec_prefix $Genoring::DOCKER_COMMAND images -q $service:latest 2>&1);
    if (!$image_id) {
      # Check if we got sources
      my $module = $services->{$service};
      if (-d "$Genoring::MODULES_DIR/$module/src/$service") {
        # Got sources, compile.
        print "Compile missing service $module:$service.\n";
        Compile($module, $service);
      }
    }
  }
}


=pod

=head2 DeleteAllContainers

B<Description>: Remove all containers to recompile or reload them.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub DeleteAllContainers {

  # Get module services.
  my %services;
  my $modules = GetModules();
  foreach my $module (@$modules) {
    foreach my $service (@{GetModuleServices($module)}) {
      $services{$service} = $module;
    }
  }


  # Check missing containers.
  foreach my $service (keys(%services)) {
    my $image_id = qx($g_exec_prefix $Genoring::DOCKER_COMMAND images -q $service:latest 2>&1);
    if ($image_id) {
      print "  - Removing container '$service'...\n";
      # Check if container is running and stop it unless it is not running the
      # same image.
      # @todo The following code does not take into account non-genoring project
      # names (ie. my $service_name = GetContainerName($service)). Since multiple
      # projects may run with the same image, each should be checked.
      my ($id, $state, $name, $image) = IsContainerRunning($service);
      if ($id) {
        if ($image && ($image ne $service)) {
          die "ERROR: DeleteAllContainers: A container with the same name ($service) but a different image ($image) is currently running. Please stop it manually.";
        }
        Run(
          "$Genoring::DOCKER_COMMAND stop $id",
          "Failed to stop container '$service' (image $image)!",
          0,
          $g_flags->{'verbose'}
        );
        Run(
          "$Genoring::DOCKER_COMMAND container prune -f",
          "Failed to prune containers!",
          0,
          $g_flags->{'verbose'}
        );
      }
      my $module = $services{$service};
      Run(
        "$Genoring::DOCKER_COMMAND image rm -f $service",
        "Failed to remove image (service ${module}[$service])!",
        1,
        $g_flags->{'verbose'}
      );
      print "    ...OK.\n";
    }
  }
}


=pod

=head2 GetModulesConfig

B<Description>: Returns GenoRing module config.

B<ArgsCount>: 0

B<Return>: (hash ref)

The modules config. Keys are module names and values are module config hashes.

=cut

sub GetModulesConfig {
  my $module_fh;
  # Get module config.
  if (!$_g_modules->{'config'}) {
    if (open($module_fh, '<:utf8', $Genoring::MODULE_FILE)) {
      my $yaml_text = do { local $/; <$module_fh> };
      close($module_fh);
      my $yaml = CPAN::Meta::YAML->read_string($yaml_text)
        or die
          "ERROR: failed to read module file '$Genoring::MODULE_FILE':\n"
          . CPAN::Meta::YAML->errstr;
      $_g_modules->{'config'} = $yaml->[0];
    }
    else {
      # warn "WARNING: failed to open module file '$Genoring::MODULE_FILE':\n$!\n";
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

  if (defined($module_mode) && ($module_mode !~ m/^\d+$/)) {
    if ($module_mode eq 'enabled') {
      $module_mode = 1;
    }
    elsif ($module_mode eq 'disabled') {
      $module_mode = 0;
    }
    else {
      $module_mode = undef;
    }
  }

  if (!defined($module_mode)) {
    if (!exists($_g_modules->{'all'})) {
      # Get all available modules.
      opendir(my $dh, "$Genoring::MODULES_DIR")
        or die "ERROR: GetModules: Failed to list '$Genoring::MODULES_DIR' directory!\n$!";
      $_g_modules->{'all'} = [ sort grep { $_ =~ m/^$Genoring::MODULE_NAME_REGEX$/ && -d "$Genoring::MODULES_DIR/$_" } readdir($dh) ];
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
    GetModulesConfig();

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

=head2 GetContainerName

B<Description>: Returns the container service name of a given service.

B<ArgsCount>: 1

=over 4

=item $service: (string) (R)

Service name.

=back

B<Return>: (string)

The container service name.

=cut

sub GetContainerName {
  my ($service) = @_;

  if (!defined($service)) {
    die "ERROR: GetContainerName: No service provided!";
  }

  my $service_name = $service;
  $service_name =~ s/^genoring/$ENV{'COMPOSE_PROJECT_NAME'}/;
  return $service_name;
}


=pod

=head2 GetVolumeName

B<Description>: Returns the Docker volume name of a given volume.

B<ArgsCount>: 1

=over 4

=item $volume: (string) (R)

Volume name.

=back

B<Return>: (string)

The Docker volume name.

=cut

sub GetVolumeName {
  my ($volume) = @_;

  if (!defined($volume)) {
    die "ERROR: GetVolumeName: No volume provided!";
  }

  my $volume_name = $volume;
  $volume_name =~ s/^genoring-/$ENV{'COMPOSE_PROJECT_NAME'}-/;
  return $volume_name;
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
  if (-d "$Genoring::MODULES_DIR/$module/services") {
    if (opendir(my $dh, "$Genoring::MODULES_DIR/$module/services")) {
      if (!$include || ('enabled' eq $include) || ('all' eq $include)) {
        push(@services, map { s/\.yml$//; $_ } (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$Genoring::MODULES_DIR/$module/services/$_" } readdir($dh)));
      }
      if ($include) {
         if (('disabled' eq $include) || ('all' eq $include)) {
          push(@services, map { s/\.yml\.dis$//; $_ } (grep { $_ =~ m/^[^\.].*\.yml\.dis$/ && -r "$Genoring::MODULES_DIR/$module/services/$_" } readdir($dh)));
        }
        if (('alt' eq $include) || ('all' eq $include)) {
          push(@services,  map { s/\.yml$//; $_ } (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$Genoring::MODULES_DIR/$module/services/alt/$_" } readdir($dh)));
        }
      }
      my %seen = map {$_ => $_} @services;
      @services = sort values(%seen);
    }
    else {
      warn "WARNING: GetModuleServices: Failed to list '$Genoring::MODULES_DIR/$module/services' directory!\n$!";
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
  my $info = GetModuleInfo($module);
  if (exists($info->{'alternatives'})) {
    $alternatives = $info->{'alternatives'};
  }

  return $alternatives;
}


=pod

=head2 GetModuleInfo

B<Description>: Returns details of a given available module.
WARNNG: The version may be different from what is installed if the module has
not been upgraded.

B<ArgsCount>: 1

=over 4

=item $module: (string) (R)

The module name.

=back

B<Return>: (hash ref)

The module details or an empty hash if the module is not available.
Ex.:
  {
    'name' => 'Gigwa',
    'version' => '1.0',
    'volumes' => {
      'genoring-volume-gigwa-config' => {
        'mapping' => 'volumes/gigwa/config',
        'type' => 'exposed',
        'name' => 'Gigwa config files',
        'description' => 'Contains Gigwa Tomcat config files.',
      },
    },
    'dependencies' => {
      'volumes' => [
        'requires genoring genoring-data-volume',
        'requires genoring genoring-backups-volume',
      ],
      'services' => [
        'genoring-gigwa BEFORE genoring genoring-proxy',
        'genoring-gigwa AFTER gigwa genoring-mongodb',
      ],
    },
    'description' => 'A tool to explore large amounts of genotyping data by filtering it.',
    'genoring_script_version' => '1.0',
    'services' => {
      'genoring-gigwa' => {
        'name' => 'Gigwa Tomcat',
        'description' => 'The Gigwa web application part.',
        'version' => '1.0',
      },
    },
  };

=cut

sub GetModuleInfo {
  my ($module) = @_;

  if (!defined($module)) {
    die "ERROR: GetModuleInfo: No module name provided!";
  }

  if (!$_g_modules_info->{$module}) {
    $_g_modules_info->{$module} = {};
    if (-f "$Genoring::MODULES_DIR/$module/$module.yml") {
      if (open(my $alt_fh, '<:utf8', "$Genoring::MODULES_DIR/$module/$module.yml")) {
        my $yaml_text = do { local $/; <$alt_fh> };
        close($alt_fh);
        my $yaml = CPAN::Meta::YAML->read_string($yaml_text)
          or die
            "ERROR: failed to parse module info file '$Genoring::MODULES_DIR/$module/$module.yml':\n"
            . CPAN::Meta::YAML->errstr;
        $_g_modules_info->{$module} = $yaml->[0];
      }
      else {
        warn "WARNING: GetModuleInfo: Failed to open module info file '$Genoring::MODULES_DIR/$module/$module.yml'!\n$!";
      }
    }
  }
  return $_g_modules_info->{$module};
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
      # @todo We currently don't have modules using shared volumes.
      foreach my $volume (@{GetModuleVolumes($module, 'all')}) {
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

B<Description>: Returns a list of shared volumes defined by the given module.

B<ArgsCount>: 1-2

=over 4

=item $module: (string) (R)

Module name.

=item $type: (string) (O)

Type of volume. One of 'defined', 'shared', 'exposed', 'used', 'all'.
Default to 'defined'.
Note: 'defined' and 'shared' should return the same list: 'defined' gets shared
volumes from their definitions in the module "volumes" directory while 'shared'
gets its volume list from the "volumes" key in the module info YAML.

=back

B<Return>: (array ref)

The list of volumes.

=cut

sub GetModuleVolumes {
  my ($module, $type) = @_;

  if (!defined($module)) {
    die "ERROR: GetModuleVolumes: No module name provided!";
  }
  my @volumes;
  if (!$type || ('defined' eq $type)) {
    # Get all defined volumes.
    if (-d "$Genoring::MODULES_DIR/$module/volumes") {
      if (opendir(my $dh, "$Genoring::MODULES_DIR/$module/volumes")) {
        @volumes = sort map { s/\.yml$//; $_ } (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$Genoring::MODULES_DIR/$module/volumes/$_" } readdir($dh));
      }
      else {
        warn "WARNING: GetModuleVolumes: Failed to list '$Genoring::MODULES_DIR/$module/volumes' directory!\n$!";
      }
    }
  }
  else {
    # Other cases.
    my $module_info = GetModuleInfo($module);
    if (('used' eq $type) || ('all' eq $type)) {
      foreach my $volume_dep (@{$module_info->{'dependencies'}{'volumes'}}) {
        my $dependencies = ParseDependencies($volume_dep);
        foreach my $dependency (@{$dependencies->{'dependencies'}}) {
          if ($dependency->{'element'}) {
            push(@volumes, $dependency->{'element'});
          }
          else {
            my $dep_module_info = GetModuleInfo($dependency->{'module'});
            foreach my $dep_volume (keys(%{$dep_module_info->{'volumes'} || {}})) {
              if ('shared' eq $dep_module_info->{'volumes'}{$dep_volume}{'type'}) {
                push(@volumes, $dep_volume);
              }
            }
          }
        }
      }
    }
    if (('shared' eq $type) || ('exposed' eq $type) || ('all' eq $type)) {
      foreach my $volume (keys(%{$module_info->{'volumes'}})) {
        if (('all' eq $type)
            || ($type eq $module_info->{'volumes'}{$volume}->{'type'})
        ) {
          push(@volumes, $volume);
        }
      }
    }
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
    die "ERROR: SetEnvVariable: No environment file provided!";
  }
  if (! -r $env_file) {
    die "ERROR: SetEnvVariable: Cannot access environment file '$env_file'!";
  }
  if (! $variable) {
    die "ERROR: SetEnvVariable: No environment variable name provided!";
  }

  $value ||= '';

  my $env_fh;
  my $new_content = '';
  my $got_value = 0;
  if (open($env_fh, '<:utf8', $env_file)) {
    while (my $line = <$env_fh>) {
      if ($line =~ m/^\s*$variable\s*[=:]/) {
        if ($got_value) {
          # Remove duplicates.
          $line = '';
        }
        else {
          $line = "$variable=$value\n";
          $got_value = 1;
        }
      }
      $new_content .= $line;
    }
    close($env_fh);
    if (!$got_value) {
      # Add new value.
      $new_content .= "\n$variable=$value\n";
    }
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

=head2 RemoveDependencyFiles

B<Description>: Remove all dependency files from the given service or from all
services.

B<ArgsCount>: 0-1

=over 4

=item $service: (string) (O)

A specific service.

=back


B<Return>: (nothing)

=cut

sub RemoveDependencyFiles {
  my ($service) = @_;
  if (-d 'dependencies') {
    # Remove all dependency files.
    if (opendir(my $dh, 'dependencies')) {
      my @dependency_files = (grep { $_ =~ m/^[\w\-\_]+\.\w+.*\.yml$/ && -r "dependencies/$_" } readdir($dh));
      closedir($dh);
      foreach my $dependency_file (@dependency_files) {
        if (!$service) {
          unlink "dependencies/$dependency_file";
        }
        elsif ($dependency_file =~ m/^$service\.\w+\.yml$/) {
          unlink "dependencies/$dependency_file";
        }
      }
    }
    else {
      warn "WARNING: Failed to access 'dependencies' directory!\n$!";
    }
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
    if (-d "$Genoring::MODULES_DIR/$module/env") {
      # List module env files.
      if (opendir(my $dh, "$Genoring::MODULES_DIR/$module/env")) {
        my @env_files = (grep { $_ =~ m/^[^\.].*\.env$/ && -r "$Genoring::MODULES_DIR/$module/env/$_" } readdir($dh));
        closedir($dh);
        foreach my $env_file (@env_files) {
          # Check if environment file exist.
          if (-e "env/${module}_$env_file") {
            unlink "env/${module}_$env_file";
          }
        }
      }
      else {
        warn "WARNING: Failed to access '$Genoring::MODULES_DIR/$module/env' directory!\n$!";
      }
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

=head2 GetEnvironmentFiles

B<Description>: Returns the list of environment files configured for a given
module or all modules.

B<ArgsCount>: 0-1

=over 4

=item $module: (string) (O)

A specific module.

=back

B<Return>: (list)

A list of environment file paths for a given module if specified or for all
modules if not.

=cut

sub GetEnvironmentFiles {
  my @env_files;
  my ($module) = @_;
  if ($module) {
    if (-d "$Genoring::MODULES_DIR/$module/env") {
      # List module env files.
      if (opendir(my $dh, "$Genoring::MODULES_DIR/$module/env")) {
        my @module_env_files = (grep { $_ =~ m/^[^\.].*\.env$/ && -r "$Genoring::MODULES_DIR/$module/env/$_" } readdir($dh));
        closedir($dh);
        foreach my $env_file (@module_env_files) {
          # Check if environment file exist.
          if (-r "./env/${module}_$env_file") {
            push(@env_files, "./env/${module}_$env_file");
          }
        }
      }
      else {
        warn "WARNING: Failed to access '$Genoring::MODULES_DIR/$module/env' directory!\n$!";
      }
    }
  }
  elsif (-d 'env') {
    # Get all environment files.
    if (opendir(my $dh, 'env')) {
      @env_files = map { './env/' . $_ } (grep { $_ =~ m/^[^\.].*\.env$/ && -r "./env/$_" } readdir($dh));
      closedir($dh);
    }
    else {
      warn "WARNING: Failed to access 'env' directory!\n$!";
    }
  }
  return @env_files;
}


=pod

=head2 GetProjectName

B<Description>: Returns current project name.

B<Return>: (string)

The project name.

=cut

sub GetProjectName {
  my $project_name = 'genoring';
  my $dc_fh;
  if (open($dc_fh, '<:utf8', $Genoring::DOCKER_COMPOSE_FILE)) {
    # Get project name from docker compose file if available.
    while (my $line = <$dc_fh>) {
      if ($line =~ /#\s*COMPOSE_PROJECT_NAME=(\S+)/) {
        $project_name = $1;
        last;
      }
    }
  }
  elsif (exists($ENV{'COMPOSE_PROJECT_NAME'})
      && ($ENV{'COMPOSE_PROJECT_NAME'} =~ m/\w/)
  ) {
    # Otherwise, try to get it form environment variable.
    $project_name = $ENV{'COMPOSE_PROJECT_NAME'};
  }

  return $project_name;
}


=pod

=head2 GetProfile

B<Description>: Returns current site environment type (dev/staging/prod).

B<Return>: (string)

The site environment type. Must be one of 'dev', 'staging', 'prod' or 'backend'.

=cut

sub GetProfile {
  my $site_env = 'dev';
  if (-r "$Genoring::MODULES_DIR/env/genoring_genoring.env") {
    $site_env =
      GetEnvVariable("$Genoring::MODULES_DIR/genoring/env/genoring.env", 'GENORING_ENVIRONMENT')
      || 'dev';
  }
  if ($site_env !~ m/^(?:dev|staging|prod|backend)$/) {
    die "ERROR: GetProfile: Invalid site environment : '$site_env' in '$Genoring::MODULES_DIR/genoring/env/genoring.env'! Valid profile should be one of 'dev', 'staging', 'prod' or 'backend'.\n";
  }
  return $site_env;
}


=pod

=head2 GetModuleConf

B<Description>: Retrieves a module config from the modules config file.

B<ArgsCount>: 1

=over 4

=item $module: (string) (R)

The module name.

=back

B<Return>: (hash)

A module config hash or an empty hash if the module is not installed.

=cut

sub GetModuleConf {
  my ($module) = @_;
  GetModulesConfig();
  my $module_config = $_g_modules->{'config'}->{$module} || {};
  return $module_config;
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
  GetModulesConfig();
  $_g_modules->{'config'}->{$module} ||= {};

  my $module_info = GetModuleInfo($module);
  $module_conf ||= {
    'status' => 'enabled',
    'version' => $module_info->{'version'} || '',
  };
  $_g_modules->{'config'}->{$module} = $module_conf;
  my $yaml = CPAN::Meta::YAML->new($_g_modules->{'config'});
  my $yaml_text = $yaml->write_string()
    or die "ERROR: failed to generate module config!\n"
    . CPAN::Meta::YAML->errstr;
  my $module_fh;
  if (open($module_fh, '>:utf8', $Genoring::MODULE_FILE)) {
    print {$module_fh} $yaml_text;
    close($module_fh);
  }
  else {
    die "ERROR: failed to write module file '$Genoring::MODULE_FILE':\n$!\n";
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
  GetModulesConfig();
  $_g_modules->{'config'}->{$module} ||= {};

  if ($_g_modules->{'config'}->{$module}) {
    delete($_g_modules->{'config'}->{$module});
    my $yaml = CPAN::Meta::YAML->new($_g_modules->{'config'});
    my $yaml_text = $yaml->write_string()
      or die "ERROR: failed to generate module config!\n"
      . CPAN::Meta::YAML->errstr;
    my $module_fh;
    if (open($module_fh, '>:utf8', $Genoring::MODULE_FILE)) {
      print {$module_fh} $yaml_text;
      close($module_fh);
    }
    else {
      die "ERROR: failed to write module file '$Genoring::MODULE_FILE':\n$!\n";
    }
  }
}


=pod

=head2 ParseDependencies

B<Description>: Parses a dependency line to extract dependencies. See
$Genoring::CONSTRAINT_TYPE_REGEX and $Genoring::DEPENDENCY_REGEX.

B<ArgsCount>: 1

=over 4

=item $dependencies: (string) (R)

A dependency string of the following format:
  [PROFILE:][SERVICE] <"REQUIRES"|"CONFLICTS"|"BEFORE"|"AFTER"> CONSTRAINT [or CONSTRAINT] ...
Ex.:
  # Volume examples:
  'REQUIRES genoring >= 1.0 genoring-backups-volume'
  'REQUIRES genoring genoring-backups-volume'
  # Service examples:
  'genoring-gigwa BEFORE genoring genoring-proxy'

=back

B<Return>: (hash ref)

A dependency hash of the form:
  {
    'constraint' => <constraint>,
    'dependencies' => [
      {
        'module' => <module_name>,
        'version_constraint' => <version_constraint>,
        'major_version' => <string>,
        'minor_version' => <string>,
        'element' => <service_or_volume_name>,
      },
      {
        'module' => <module_name>,
        'version_constraint' => <version_constraint>,
        'major_version' => <string>,
        'minor_version' => <string>,
        'element' => <service_or_volume_name>,
      },
      ...
    ],
  }

=cut

sub ParseDependencies {
  my ($dependencies) = @_;

  my ($profiles, $service, $constraint) = $dependencies =~ m/^$Genoring::PROFILE_CONSTRAINT_REGEX\s*$Genoring::SERVICE_CONSTRAINT_REGEX\s*$Genoring::CONSTRAINT_TYPE_REGEX/;
  if (!$constraint) {
    return {};
  }
  # Remove what has been matched already.
  $dependencies =~ s/^$Genoring::PROFILE_CONSTRAINT_REGEX\s*$Genoring::SERVICE_CONSTRAINT_REGEX\s*$Genoring::CONSTRAINT_TYPE_REGEX\s+//;
  my @module_dependencies;
  my @module_dependencies_to_parse = split(/\s+[oO][rR]\s+/, $dependencies);
  my $dep;
  while (($dep = shift(@module_dependencies_to_parse))
    && ($dep =~ m/$Genoring::DEPENDENCY_REGEX/g)
  ) {
    push(
      @module_dependencies,
      {
        'module' => $1,
        'version_constraint' => $2 || '=',
        'major_version' => $3,
        'minor_version' => $4,
        'stability' => $5,
        'element' => $6,
      }
    );
  }
  if (@module_dependencies_to_parse) {
    die "ERROR: Failed to parse module dependency line:\n  $dependencies\n";
  }
  return {
    'profiles' => [split(/\s*,\s*/, $profiles || '')],
    'service' => $service,
    'constraint' => $constraint,
    'dependencies' => \@module_dependencies,
  };
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
    $_g_modules_info = {};
  }
  elsif ($category eq 'modules') {
    $_g_modules = {};
    $_g_modules_info = {};
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

  if ($g_flags->{'yes'}) {
    return 1;
  }
  elsif ($g_flags->{'no'}) {
    return 0;
  }

  print "$message (y/n) ";
  my $user_input = <STDIN>;
  if ($user_input !~ m/^y/i) {
    return 0;
  }
  return 1;
}


=pod

=head2 GetOs

B<Description>: Returns the OS architecture.

B<ArgsCount>: 0

B<Return>: (string)

The OS architecture. One of: 'Unix', 'Win32' or 'unsup'.
See %Genoring::OS.

=cut

sub GetOs {
  return $Genoring::OS{$^O} || $Genoring::OS{''};
}


=pod

=head2 HandleShellExecutionError

B<Description>: Displays an error message if the last shell command failed. It
will adapt the message according to the error type. If no error occurred,
nothing is displayed. This function should be called after each shell command.

B<ArgsCount>: 0

B<Return>: (nothing)

B<Example>:

    HandleShellExecutionError();

=cut

sub HandleShellExecutionError
{
  if ($?) {
    my $error_message = "ERROR\n";
    if ($? == -1) {
      $error_message = "ERROR $?:\n$!\n";
    }
    elsif ($? & 127) {
      $error_message = sprintf(
        "ERROR: Child died with signal %d, %s coredump\n",
        ($? & 127), ($? & 128) ? 'with' : 'without'
      );
    }
    else {
      $error_message = sprintf("ERROR %d\n", $? >> 8);
    }
    warn($error_message);
  }
}


=pod

=head2 Dircopy

B<Description>: Copy a directory content into another recursively.

B<ArgsCount>: 2

=over 4

=item $source: (string) (R)

The source directory.

=item $target: (string) (R)

The target directory.

=back

B<Return>: (bool)

1 if all was copied without errors.

=cut

sub DirCopy {
  my ($source, $target) = @_;
  my $success = 1;
  if (opendir(my $dh, $source)) {
    if (!-e $target) {
      if (!mkdir $target) {
        warn "WARNING: Failed to create '$target' directory!\n$!";
        $success = 0;
      }
    }
    elsif (!-d $target) {
      warn "WARNING: Target '$target' is not a directory!\n$!";
      $success = 0;
    }
    foreach my $item (readdir($dh)) {
      # Skip "." and "..".
      if ($item =~ m/^\.\.?$/) {
        next;
      }
      if (-d "$source/$item") {
        # Sub-directory.
        if (!-e "$target/$item") {
          if (!mkdir "$target/$item") {
            warn "WARNING: Failed to create '$target/$item' directory!\n$!";
            $success = 0;
          }
        }
        if (!DirCopy("$source/$item", "$target/$item")) {
          $success = 0;
        }
      }
      else {
        # File.
        if (!copy("$source/$item", "$target/$item")) {
          $success = 0;
        }
      }
    }
    closedir($dh);
  }
  else {
    warn "WARNING: Failed to access '$source' directory!\n$!";
    $success = 0;
  }
  return $success;
}


=pod

=head2 CreateVolumeDirectory

B<Description>: Recursive function to create directories in Genoring "volumes".

B<ArgsCount>: 1

=over 4

=item $subpath: (string) (R)

The sub-path in the GenoRing "volumes" directory with or without a trailing
slash.

=back

B<Return>: (nothing)

B<Example>:

    my $subpath = 'proxy/nginx';
    CreateVolumeDirectory($subpath);

=cut

sub CreateVolumeDirectory {
  my ($subpath) = @_;
  return if (!$subpath);

  # Trim leading and trailing slashes.
  $subpath =~ s~[\\/:]+$~~g;
  make_path("$ENV{'GENORING_VOLUMES_DIR'}/$subpath");

  # Code left in case we want ot make extra checks.
  # my @subpaths = split(m~[\\/:]+~, $subpath);
  # my $current_path = $ENV{'GENORING_VOLUMES_DIR'};
  # while (@subpaths) {
  #   $subpath = shift(@subpaths);
  #   $subpath =~ s~^\s+|\s+$~~;
  #   if ($subpath && ($subpath !~ m/^\.+$/)) {
  #     if (!-e "$current_path/$subpath") {
  #       if (!mkdir "$current_path/$subpath") {
  #         warn "WARNING: Failed to create directory '$current_path/$subpath'!\n$!\n";
  #         return;
  #       }
  #       $current_path = "$current_path/$subpath";
  #     }
  #   }
  # }
}


=pod

=head2 CopyDirectory

B<Description>: Recursive function to copy directories. The target directory may
not exist and will be created, however the target parent directory structure
must exist.
A warning will be issued for each files or sub-directories that could not be
copied.

B<ArgsCount>: 2

=over 4

=item $source: (string) (R)

The source directory path.

=item $target: (string) (R)

The target directory path.

=back

B<Return>: (nothing)

B<Example>:

    CopyDirectory($source, $target);

=cut

sub CopyDirectory {
  my ($source, $target) = @_;
  if (opendir(my $dh, $source)) {
    if (!-d $target) {
      if (!mkdir $target) {
        die "ERROR: Failed to create target directory '$target'!\n$!\n";
      }
    }
    foreach my $item (readdir($dh)) {
      # Skip "." and "..".
      if ($item =~ m/^\.\.?$/) {
        next;
      }
      if (-d "$source/$item") {
        # Sub-directory.
        if (!-e "$target/$item") {
          if (!mkdir "$target/$item") {
            warn "WARNING: Failed to create directory '$target/$item'!\n$!\n";
          }
        }
        CopyDirectory("$source/$item", "$target/$item");
      }
      else {
        # File.
        if (!copy("$source/$item", "$target/$item")) {
          warn "WARNING: Failed to copy '$source/$item'.\n$!\n";
        }
      }
    }
    closedir($dh);
  }
  else {
    warn "WARNING: Failed to access '$source' directory!\n$!";
  }
}


=pod

=head2 CopyFiles

B<Description>: Copy a file from the between directories.

B<ArgsCount>: 2-5

=over 4

=item $source_file_subpath: (string) (R)

Sub-path to the file to copy without leading slash.

=item $target_file_subpath: (string) (R)

Sub-path to the file to add without leading slash.

=item $source_base: (string) (U)

Base source path without leading or trailing slashes.

=item $target_base: (string) (U)

Base target path without leading or trailing slashes.

=item $replace_existing: (bool) (O)

If TRUE, replace existing target file(s). Default: FALSE.

=back

B<Return>: (nothing)

B<Example>:

    $source = $Genoring::MODULES_DIR . '/brapimapper/res/nginx/brapimapper.conf';
    $target = $Genoring::VOLUMES_DIR . '/proxy/nginx/includes/brapimapper.conf';
    CopyFiles($source, $target);

=cut

sub CopyFiles
{
  my ($files, $single_target, $source_base, $target_base, $replace_existing) = @_;
  return if (!$files);
  $source_base ||= '';
  $target_base ||= '';
  $source_base =~ s~[\s\\/:]+$~~g;
  $target_base =~ s~[\s\\/:]+$~~g;
  if ($source_base) {
    $source_base = $source_base . '/';
  }
  if ($target_base) {
    $target_base = $target_base . '/';
  }
  if (!ref($files)) {
    # Single file.
    $files =~ s~^\s+|\s+$~~g;
    $single_target ||= '';
    $single_target =~ s~^\s+|\s+$~~g;
    if (!$single_target) {
      warn "WARNING: Invalid parameters for Genoring::CopyFiles()! Missing target.\n";
      return;
    }
    if (($files =~ m~\.\.~) || ($single_target =~ m~\.\.~)) {
      warn "WARNING: Invalid parameters for Genoring::CopyFiles()! Relative paths are not allowed ($files => $single_target).\n";
      return;
    }
    if (!-r $source_base . $files) {
      warn "WARNING: Genoring::CopyFiles(): Missing source file '$source_base$files'.\n";
    }
    elsif ((!-e $target_base . $single_target) || $replace_existing) {
      copy($source_base .$files, $target_base . $single_target);
    }
  }
  elsif ('HASH' eq ref($files)) {
    # Multiple files.
    if ($single_target) {
      warn "WARNING: Invalid parameters for Genoring::CopyFiles()! Multiple targets are specified as hash values. The target parameter should not be set.\n";
      return;
    }
    keys %$files; # Reset the internal iterator.
    while (my ($source, $target) = each(%$files)) {
      $source =~ s~^\s+|\s+$~~g;
      $target =~ s~^\s+|\s+$~~g;
      if (($source =~ m~\.\.~) || ($target =~ m~\.\.~)) {
        warn "WARNING: Invalid parameters for Genoring::CopyFiles(%)! Relative paths are not allowed ($source => $target).\n";
        next;
      }
      if (!-r $source_base . $source) {
        warn "WARNING: Genoring::CopyFiles(%): Missing source file '$source_base$source'.\n";
        next;
      }
      elsif ((!-e $target_base . $target) || $replace_existing) {
        copy($source_base . $source, $target_base . $target);
      }
    }
  }
  else {
    warn "WARNING: Invalid parameters (" . ref($files) . ") for Genoring::CopyFiles()!\n";
    return;
  }
}


=pod

=head2 CopyVolumeFiles

B<Description>: Copy a file from the GenoRing "modules" directory to the
"volumes" directory.

B<ArgsCount>: 1-3

=over 4

=item $files: (string | hash ref) (R)

Sub-path to the file to copy from the GenoRing "volumes" without leading slash.
If $files is a hash ref, then each hash key is a sub-path to a file to copy
from the GenoRing "volumes" and each corresponding key is a sub-path to the
corresponding file to add to the GenoRing "volumes". In that case,
$single_target parameter should not be set.

=item $single_target: (string) (U)

Sub-path to the file to add to the GenoRing "volumes" without leading slash.
This parameter is only used for single file copy.

=item $replace_existing: (bool) (O)

If TRUE, replace existing target file(s). Default: FALSE.

=back

B<Return>: (nothing)

B<Example>:

    $source = 'proxy/nginx/includes/brapimapper.conf';
    $target = 'proxy/nginx/includes/other_service.conf';
    CopyVolumeFiles($source, $target);

=cut

sub CopyVolumeFiles
{
  my ($files, $single_target, $replace_existing) = @_;
  CopyFiles($files, $single_target, $Genoring::VOLUMES_DIR, $Genoring::VOLUMES_DIR, $replace_existing);
}


=pod

=head2 CopyModuleFiles

B<Description>: Copy one or more files from the GenoRing "modules" directory to
the "volumes" directory.

B<ArgsCount>: 1-3

=over 4

=item $files: (string | hash ref) (R)

Sub-path to the file to copy from the GenoRing "modules" without leading slash.
If $files is a hash ref, then each hash key is a sub-path to a file to copy
from the GenoRing "modules" and each corresponding key is a sub-path to the
corresponding file to add to the GenoRing "volumes". In that case,
$single_target parameter should not be set.

=item $single_target: (string) (U)

Sub-path to the file to add to the GenoRing "volumes" without leading slash.
This parameter is only used for single file copy.

=item $replace_existing: (bool) (O)

If TRUE, replace existing target file(s). Default: FALSE.

=back

B<Return>: (nothing)

B<Example>:

    $source = 'brapimapper/res/nginx/brapimapper.conf';
    $target = 'proxy/nginx/includes/brapimapper.conf';
    CopyModuleFiles($source, $target);

=cut

sub CopyModuleFiles
{
  my ($files, $single_target, $replace_existing) = @_;
  CopyFiles($files, $single_target, $Genoring::MODULES_DIR, $Genoring::VOLUMES_DIR, $replace_existing);
}


=pod

=head2 RemoveVolumeDirectories

B<Description>: Remove directory (recursively) from the GenoRing "volumes"
directory.

B<ArgsCount>: 1

=over 4

=item $subpaths: (string|array ref) (R)

Sub-path to the directories to remove in the GenoRing "volumes" without leading
slash. A list of directory should be passed as an array ref while a single
directory can be passed as a string.

=back

B<Return>: (nothing)

B<Example>:

    $subpath = 'jbrowse';
    RemoveVolumeDirectories($subpath);

=cut

sub RemoveVolumeDirectories
{
  my ($subpaths) = @_;
  return if (!$subpaths);
  if ('ARRAY' ne ref($subpaths)) {
    $subpaths = [$subpaths];
  }
  foreach my $subpath (@$subpaths) {
    if (-d $ENV{'GENORING_VOLUMES_DIR'} . "/$subpath") {
      remove_tree($ENV{'GENORING_VOLUMES_DIR'} . "/$subpath");
    }
  }
}


=pod

=head2 RemoveVolumeFiles

B<Description>: Remove files from the GenoRing "volumes" directory.

B<ArgsCount>: 1

=over 4

=item $file_subpaths: (string|array ref) (R)

Sub-path to the files to remove in the GenoRing "volumes" without leading slash.
A list of files should be passed as an array ref while a single file can be
passed as a string.

=back

B<Return>: (nothing)

B<Example>:

    $file_subpath = 'proxy/nginx/includes/brapimapper.conf';
    RemoveVolumeFiles($file_subpath);

=cut

sub RemoveVolumeFiles
{
  my ($file_subpaths) = @_;
  return if (!$file_subpaths);
  if ('ARRAY' ne ref($file_subpaths)) {
    $file_subpaths = [$file_subpaths];
  }
  foreach my $file_subpath (@$file_subpaths) {
    if (-e $ENV{'GENORING_VOLUMES_DIR'} . "/$file_subpath") {
      unlink $ENV{'GENORING_VOLUMES_DIR'} . "/$file_subpath";
    }
  }
}


=pod

=head2 CheckFreeSpace

B<Description>: Check if there is currently enough disk space to run GenoRing.
If there is less than 100M or 2% free space, it will ask to continue or stop.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub CheckFreeSpace
{
  my $df_output = '';
  if ('Unix' eq GetOs()) {
    $df_output = qx(df . -BM 2>/dev/null);
  }
  if (($? == 0)
      && ($df_output =~ m/(\d+)M\s+(\d+)M\s+(\d+)M\s+(\d+)%\s+/)
  ) {
    my ($total, $used, $available, $percent_used) = ($1, $2, $3, $4);
    # Less than 100M.
    if ((($available < 100) || ($percent_used < 2))
      && (!Confirm('The disk space is very low! GenoRing may not work properly. Do you want to continue anyway?'))
    ) {
      die "Execution aborted!\n";
    }
  }
}




=pod

=head1 AUTHORS

Valentin GUIGNON (The Alliance Bioversity - CIAT), v.guignon@cgiar.org

=head1 VERSION

Version 1.0.0

Date 13/02/25

=head1 SEE ALSO

GenoRing documentation.

=cut

return 1; # package return
