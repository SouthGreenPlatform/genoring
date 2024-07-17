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

use Pod::Usage;
use File::Basename;
use Env;

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

B<$STATE_MAX_TRIES>: (integer)

Maximum number of seconds to wait for a service to be ready (running).

=cut

our $GENORING_VERSION = '1.0';
our $BASEDIR = dirname(__FILE__);
our $DOCKER_COMPOSE_FILE = 'docker-compose.yml';
our $MODULE_FILE = 'modules.conf';
our $MODULE_DIR = 'modules';
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
    die "ERROR: ${subroutine}Run: No command to run!";
  }

  $error_message ||= 'Execution failed!';
  $error_message = ($fatal_error ? 'ERROR: ' : 'WARNING: ')
    . $subroutine
    . $error_message;

  my $failed = system($command);

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
  
  if ($failed) {
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
  Run(
    "docker compose up -d",
    "Failed to start GenoRing ($mode mode)!",
    1
  );
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
  my $state = GetState(@_);
  if (@_) {
    # @todo Get given module state: convert module name to container name.
    print $_[0] . " is " . ($state || 'not running') . ".\n";
  }
  else {
    if ('running' eq $state) {
      # @todo Check if offline or backend.
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

=head2 GetModuleRealState

B<Description>: Returns the given module real state (can be different from the
state returned by Docker).

B<ArgsCount>: 0-1

=over 4

=item $container: (string) (O)

Container name.

=back

B<Return>: (string)

The module state. Should be one of "created", "running", "restarting", "paused",
"dead", "exited" or an empty string if not available (not running).

=cut

sub GetModuleRealState {
  my ($module, $progress) = @_;
  my $state = '';
  if (-e "$MODULE_DIR/$module/hooks/state.pl") {
    my $tries = $STATE_MAX_TRIES;
    $state = `perl $MODULE_DIR/$module/hooks/state.pl`;
    if ($?) {
      die "ERROR: StartGenoring: Failed to get $module module state!\n$!\n(error $?)";
    }
    print "Checking if $module module is ready...\n" if $progress;
    while (--$tries && ($state !~ m/running/i)) {
      print '.' if $progress;
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
      if ($service_state && ($service_state !~ m/running/)) {
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
      # @todo Show 4 last lines of logs during progress in GetModuleRealState().
      my $logs = '';
      foreach my $service (@{GetModuleServices($module)}) {
        my $service_state = GetState($service);
        if ($service_state && ($service_state !~ m/running/)) {
          $logs .= "$service:\n" . `docker logs $service 2>&1` . "\n\n";
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
    print "WARNING: This will stop all GenoRing containers, REMOVE their local data ('volumes' directory contant) and reset GenoRing config! This operation can not be undone so make backups before as needed. Are you sure you want to continue? (y|n) ";
    my $userword = <STDIN>;
    chomp $userword;
    if (!$userword || $userword !~ m/^y(?:es)?/i) {
      print "Operation canceled!\n";
      exit(0);
    }
  }

  # @todo Check if only a sub-part should be managed.
  # @todo Add an option to remove ALL and not just Drupal and its db.

  # Stop genoring.
  print "Stop GenoRing...\n";
  StopGenoring();
  print "  OK.\n";

  # Cleanup containers.
  print "Pruning stopped containers...\n";
  Run(
    "docker container prune -f",
    "Failed to prune containers!"
  );
  print "  OK.\n";

  # Remove GenoRing volumes.
  print "Removing GenoRing volumes...\n";
  Run(
    "docker volume rm -f genoring-drupal genoring-data",
    "Failed to remove GenoRing volumes!"
  );
  # @todo Remove module's shared volumes as well.

  # Remove Drupal and database content.
  # @todo use genoring module uninstall hook instead.
  Run(
    "docker run --rm -v $BASEDIR/volumes:/genoring -w / alpine rm -rf /genoring/drupal /genoring/db /genoring/proxy /genoring/offline /genoring/data",
    "Failed clear local volume content!"
  );
  # @todo Clear data of enabled modules.
  print "  OK.\n";

  # Uninstall enabled modules.
  print "Uninstall all modules...\n";
  unlink $MODULE_FILE;
  print "  OK.\n";

  # Clear config.
  print "Clearing config...\n";
  unlink $DOCKER_COMPOSE_FILE;
  print "  OK.\n";

  print "Reinitialization done!\n";
}

=pod

=head2 SetupGenoring

B<Description>: Initializes GenoRing system with user inputs.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub SetupGenoring {

  # Process environment variables and ask user for inputs for variables with
  # tags SET et OPT.
  print "- Setup environment...\n";
  SetupGenoringEnvironment();
  print "  ...Environment setup done.\n";

  # Generate docker-compose.yml...
  print "- Generating Docker Compose main file...\n";
  GenerateDockerComposeFile();
  print "  ...Docker Compose file generated.\n";

  # Apply global initialization hooks (modules/*/hooks/init.pl).
  print "- Initialiazing modules...\n";
  ApplyLocalHooks('init');
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
  ApplyContainerHooks('enable');
  print "  ...Modules initialiazed.\n";

  # Stop containers.
  print "- Stopping backend.\n";
  StopGenoring();

  # # @todo Check for modules to enable.
  # # docker exec -v ./modules/profile/path/to/:/path/to/ -it genoring /path/to/script.sh
  # # @toto Ask to start genoring.
}

=pod

=head2 SetupGenoringEnvironment

B<Description>: Ask user to set GenoRing environment variables.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub SetupGenoringEnvironment {

  # Get enabled modules.
  my $modules = GetModules(1);

  foreach my $module (@$modules) {
    # @todo Manage environment file generation.
    print "Here, you will soon be able to customize settings (environment variables) before site installation... Hit enter to continue. ";
    my $userword = <STDIN>;
    chomp $userword;
    # # Ask for ...
    # while [ -z "$value" ]; do
    #   read -p "Enter a value: " value
    # done
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

    # Work on module services.
    opendir(my $dh, "$MODULE_DIR/$module/services")
      or die "ERROR: GenerateDockerComposeFile: Failed to access '$MODULE_DIR/$module/services' directory!\n$!";
    my @services = (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$MODULE_DIR/$module/services/$_" } readdir($dh));
    closedir($dh);
    foreach my $service_yml (@services) {
      my $svc_fh;
      open($svc_fh, "$MODULE_DIR/$module/services/$service_yml")
        or die "ERROR: GenerateDockerComposeFile: Failed to open module service file '$service_yml'.\n$!";
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
    # Remove eventual 'genoring-' prefix as it will be added later when
    # needed.
    @volumes = map { $_ =~ s/^genoring-//; $_ } @volumes;
    closedir($dh);
    foreach my $volume_yml (@volumes) {
      my $vl_fh;
      open($vl_fh, "$MODULE_DIR/$module/volumes/$volume_yml")
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
  if (open($dc_fh, ">$DOCKER_COMPOSE_FILE")) {
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
      my $volume_name = "genoring-$volume";
      print {$dc_fh} "  $volume_name:\n    # v" . $volumes{$volume}->{'version'} . '.' . $volumes{$volume}->{'subversion'} . "\n";
      print {$dc_fh} $volumes{$volume}->{'definition'};
      print {$dc_fh} "    name: \"$volume_name\"\n";
    }
    close($dc_fh);
  }
  else {
    die "ERROR: GenerateDockerComposeFile: Failed to open Docker Compose file '$DOCKER_COMPOSE_FILE':\n$!\n";
  }
}

##
# Updates the GenoRing system or the specified module.
#
# Arguments:
#  service (optional): the service/module to update. If not set, all is
#    updated.
#
sub Update {

  print "Updating GenoRing...\n";

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
    ApplyLocalHooks('update');
    print "  Modules updated on local system, updating services...\n";

    # Start containers in backend mode.
    print "- Starting GenoRing backend for update...\n";
    StartGenoring($mode);
    print "  OK\n";

    # Check modules are ready.
    print "- Waiting for all services to be operational...\n";
    WaitModulesReady();
    print "  OK\n";

    # @todo Check if only some parts should be updated or update all.
    Run(
     "docker compose run -e DRUPAL_UPDATE=2 genoring",
     "ERROR: Update: Failed to run update on GenoRing container!",
     1
    );

    # Apply docker initialization hooks of each enabled module service for each
    # enabled module service (ie. modules/"svc1"/hooks/init_"svc2".sh).
    print "  - Applying container update hooks...\n";
    ApplyContainerHooks('update');
    print "    OK\n";
    print "  ...Modules updated.\n";

    # Stop containers.
    print "- Stopping backend.\n";
    StopGenoring();

    # Restart if needed.
    if ('backoff' eq $mode) {
      print "- Restart GenoRing...\n";
      StartGenoring('normal');
      print "  OK\n";
      # Check modules are ready.
      print "- Waiting for all services to be operational...\n";
      WaitModulesReady();
      print "  OK\n";
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
  # @todo: remove module from modules.conf if installation fails.
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
  my $module_fh;
  if (open($module_fh, ">>$MODULE_FILE")) {
    print {$module_fh} "$module\n";
    close($module_fh);
    $enabled_volumes{$module} = $module;
  }
  else {
    die "ERROR: failed to open module file '$MODULE_FILE':\n$!\n";
  }
  
  # Apply module init hook.
  ApplyLocalHooks('init', $module);
  
  # Update Docker Compose config.
  GenerateDockerComposeFile();

  # Set maintenance mode.
  StartGenoring($mode);
  WaitModulesReady();
  ApplyContainerHooks('enable', $module);
  StopGenoring();

  # Restart if needed.
  if ('backoff' eq $mode) {
    StartGenoring('normal');
    WaitModulesReady();
  }
}

##
#
sub DisableModule {
}

##
# Disables and uninstalls the given GenoRing module.
#
# Arguments:
#  module: the module to disable and uninstall.
# @todo Maybe see if uninstall could be optional.
#
sub UninstallModule {
  # assert_root
  # # @todo Warn and ask for confirmation.
  # if [ -z $1 ]; then
  #   >&2 echo "ERROR: genoring_disable: No module name provided!"
  #   exit 1
  # fi
  # # Get module status.
  # get_module_status $1
  # if [ -z "$module_status" ]; then
  #   >&2 echo "ERROR: genoring_disable: module not found ($1)!"
  #   exit 1
  # elif [ "1" == "$module_status" ]; then
  #   # Disable specified modules.
  #   # Remove module from the enabled module file.
  #   perl -p -i -e "s/^\\s*\\Q$1\\E\\s*\$//g" ./enabled_modules.txt
  #   # Remove nginx config.
  #   if [ -e "./proxy/modules/$1.conf" ]; then
  #     rm ./proxy/modules/$1.conf 
  #   fi
  #   # Call uninstall scripts.
  #   echo "Uninstalling..."
  #   if [ -x "./modules/$1/hooks/uninstall.sh" ]; then
  #     echo "- $1"
  #     ./modules/$1/hooks/uninstall.sh
  #   fi
  #   if [ -d "./modules/$1/hooks" ]; then
  #     # Loop on docker uninstallation scripts.
  #     for scriptname in ./modules/$1/hooks/uninstall_*.sh; do
  #       # When no files found, continue.
  #       [ -e "$scriptname" ] || continue
  #       container_name=$(echo $scriptname | perl -p -e "s#modules/$1/hooks/uninstall_(.+)\.sh#\$1#g")
  #       # Check if the corresponding container is running.
  #       container_is_running $container_name
  #       if [ ! -z "$container_is_running" ]; then
  #         echo "- $container_name"
  #         docker exec -v ./modules/$1/hooks/uninstall_$container_name.sh:/usr/init/uninstall_$container_name.sh -it $container_name /user/init/uninstall_$container_name.sh
  #       fi
  #     done
  #   fi
  #   echo "...uninstallation done."
  # elif [ "0" == "$module_status" ]; then
  #   echo "WARNING: genoring_disable: module already disabled ($1)."
  # fi
}

##
# Performs a general backup of the GenoRing system into an archive file.
#
sub Backup {
  # @todo Backup config and data to an archive.
}

##
# Restores GenoRing from a given backup archive.
sub Restore {
  # @todo Restore a given backup archive.
}

=pod

=head2 ApplyLocalHooks

B<Description>: Find and run the given local hook scripts.

B<ArgsCount>: 1-2

=over 4

=item $hook_name: (string) (R)

The hook name.

=item $module: (string) (O)

Restrict hooks to this module.

=back

B<Return>: (nothing)

=cut

sub ApplyLocalHooks {
  my ($hook_name, $module) = @_;
  
  if (!$hook_name) {
    die "ERROR: ApplyLocalHooks: Missing hook name!\n";
  }

  my $modules;
  if ($module) {
    # Only work on specified module.
    $modules = [$module];
  }
  else {
    # Get enabled modules.
    $modules = GetModules(1);
  }

  foreach $module (@$modules) {
    if (-e "$MODULE_DIR/$module/hooks/$hook_name.pl") {
      print "  Processing $module module hook $hook_name...";
      Run(
        "perl $MODULE_DIR/$module/hooks/$hook_name.pl",
        "Failed to process $module module hook $hook_name!",
        1
      );
      print "  OK\n";
    }
  }
}

=pod

=head2 ApplyContainerHooks

B<Description>: Find and run the given container hook scripts into related
containers.
IMPORTANT: Hooks will only be processed in *running* containers. Warnings will
be issued for enabled services that are not running.

B<ArgsCount>: 1-2

=over 4

=item $hook_name: (string) (R)

The hook name.

=item $en_module: (string) (O)

Restrict hooks to the given module and its services. When set to a valid module
name, only its hooks will be processed first and then only other module hooks
related to this module will be run as well.

=back

B<Return>: (nothing)

=cut

sub ApplyContainerHooks {
  my ($hook_name, $en_module) = @_;

  if (!$hook_name) {
    die "ERROR: ApplyContainerHooks: Missing hook name!\n";
  }

  # Get enabled modules.
  my $modules = GetModules(1);

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
          if ($en_module && ($en_module ne $module) && ($services->{$service} ne $module)) {
            # Skip non-matching hooks.
            next APPLYCONTAINERHOOKS_HOOKS;
          }
          # Check if container is running.
          my ($id, $state, $name, $image) = IsContainerRunning($service);
          if (!$state || ($state !~ m/running/)) {
            $state ||= 'not running';
            warn "WARNING: Failed to run $module module hook in $service (hook $hook): $service is $state.";
            next APPLYCONTAINERHOOKS_HOOKS;
          }
          # Provide module files to container if not done already.
          if (!exists($initialized_containers{$service})) {
            Run(
              "docker exec -it $service mkdir -p /genoring",
              "Failed to prepare module file copy in $service ($module $hook hook)"
            );
            Run(
              "docker cp \$(pwd)/$MODULE_DIR/ $service:/genoring/$MODULE_DIR/",
              "Failed to copy module files in $service ($module $hook hook)"
            );
            $initialized_containers{$service} = 1;
          }
          Run(
            "docker exec -it $service /genoring/$MODULE_DIR/$module/hooks/$hook",
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

  if (!-d "$MODULE_DIR/$module/src/$service") {
    die "ERROR: Compile: The given service (${module}[$service]) does not have sources!";
  }
  elsif (!-r "$MODULE_DIR/$module/src/$service/Dockerfile") {
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
    "docker build -t $service $MODULE_DIR/$module/src/$service/",
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
  if (!defined($module_mode)) {
    if (!exists($_g_modules->{'all'})) {
      # Get all available modules.
      opendir(my $dh, "$MODULE_DIR")
        or die "ERROR: GetModules: Failed to list '$MODULE_DIR' directory!\n$!";
      $_g_modules->{'all'} = [ sort grep { $_ !~ m/^\./ && -d "$MODULE_DIR/$_" } readdir($dh) ];
    }
    return $_g_modules->{'all'};
  }
  elsif (0 == $module_mode) {
    if (!exists($_g_modules->{'disabled'})) {
      # Get disabled modules.
      my $all_modules = GetModules();
      my $enabled_modules = { map { $_ => $_ } GetModules(1) };
      $_g_modules->{'disabled'} = [ sort grep { !exists($enabled_modules->{$_}) } @$all_modules ];
    }
    return $_g_modules->{'disabled'};
  }
  elsif (1 == $module_mode) {
    if (!exists($_g_modules->{'enabled'})) {
      my %modules;
      # Get enabled modules.
      if (!-e $MODULE_FILE) {
        my $module_fh;
        if (open($module_fh, ">$MODULE_FILE")) {
          print {$module_fh} "genoring\n";
          close($module_fh);
          $modules{'genoring'} = 'genoring';
        }
        else {
          die "ERROR: failed to open module file '$MODULE_FILE':\n$!\n";
        }
      }
      else {
        # Get enabled modules.
        my $module_fh;
        if (open($module_fh, $MODULE_FILE)) {
          while (<$module_fh>) {
            $_ =~ s/^\s+|\s+$//g;
            $modules{$_} = $_;
          }
          close($module_fh);
        }
        else {
          die "ERROR: failed to open module file '$MODULE_FILE':\n$!\n";
        }
      }
      $_g_modules->{'enabled'} = [ sort keys(%modules) ];
    }
    return $_g_modules->{'enabled'};
  }
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

B<ArgsCount>: 1

=over 4

=item $module: (string) (R)

Module name.

=back

B<Return>: (array ref)

The list of services.

=cut

sub GetModuleServices {
  my ($module) = @_;

  if (!defined($module)) {
    die "ERROR: GetModuleServices: No module name provided!";
  }

  # Get all available services.
  # @todo Manage alternatives and disabled services in modules.conf.
  my @services;
  if (opendir(my $dh, "$MODULE_DIR/$module/services")) {
    @services = sort map { s/\.yml$//; $_ } (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$MODULE_DIR/$module/services/$_" } readdir($dh));
  }
  else {
    warn "WARNING: GetModuleServices: Failed to list '$MODULE_DIR/$module/services' directory!\n$!";
  }

  return \@services;
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
  opendir(my $dh, "$MODULE_DIR/$module/volumes")
    or die "ERROR: GetModuleVolumes: Failed to list '$MODULE_DIR/$module/volumes' directory!\n$!";
  my @volumes = sort map { s/\.yml$//; $_ } (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$MODULE_DIR/$module/volumes/$_" } readdir($dh));

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
  if (open($env_fh, $env_file)) {
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
  if (open($env_fh, $env_file)) {
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
    if (open($env_fh, ">$env_file")) {
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

# Script options
#################

=pod

=head1 OPTIONS

genoring.pl [help | man | start | stop | logs | status | reset | update | enable | disable | uninstall | modules | services | volumes | backup | restore | compile] -debug

=over 4

=item B<help>:

Display help and exits.

=item B<man>:

Prints the manual page and exits.

=item B<-debug>:

Enables debug mode.

=back

=cut


# CODE START
#############

# Change working directory to where the script is to later use relative paths.
chdir $BASEDIR;
$ENV{'COMPOSE_PROJECT_NAME'} = 'genoring';

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
while (my $arg = shift(@ARGV)) {
  if ($arg =~ m/^--?([\w\-]+)(?:=(.*))?$/i) {
    $g_flags->{$1} = defined($2) ? $2 : 1;
  }
  else {
    push(@arguments, $arg);
  }
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

Date 12/07/2024

=head1 SEE ALSO

GenoRing documentation (README.md).

=cut
