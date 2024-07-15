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

=cut

our $g_debug = 0;
my $g_flags = {};




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

B<Description>: Starts GenoRing platform by calling docker compose up -d. If the
system has not been installed yet, the installation process will be
automatically started first.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub StartGenoring {
  print "Starting GenoRing...\n";

  # Get enabled modules.
  my $modules = GetModules(1);
  
  # @todo Compile missing containers with sources.

  # Check if setup needs to be run first.
  if (!-e $DOCKER_COMPOSE_FILE) {
    SetupGenoring();
  }

  print "- Starting GenoRing...\n";
  # set COMPOSE_PROFILES according to genoring.env
  $ENV{'COMPOSE_PROFILES'} = 'dev';
  Run(
    "docker compose up -d",
    "Failed to start GenoRing!",
    1
  );
  print "  GenoRing started.\n";
  WaitModulesReady(@$modules);
  print "  GenoRing is ready to accept client connections.\n";
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

B<Description>: Displays GenoRing logs.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub GetLogs {
  Run(
    "docker compose logs -f",
    "Failed to GenoRing logs!",
  );
}

=pod

=head2 GetStatus

B<Description>: Displays GenorRing status.

B<ArgsCount>: 0-1

=over 4

=item $container: (string) (O)

Container name.

=back

B<Return>: (nothing)

=cut

sub GetStatus {
   print GetState(@_) . "\n";
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
      if ($service_state && ($service_state != m/running/)) {
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
  my @modules = @_;
  foreach my $module (@modules) {
    my $state = GetModuleRealState($module, 1);
    if ($state !~ m/running|ready/i) {
      # @todo Show 4 last lines of logs during progress in GetModuleRealState().
      my $logs = '';
      foreach my $service (@{GetModuleServices($module)}) {
        my $service_state = GetState($service);
        if ($service_state && ($service_state != m/running/)) {
          $logs = `docker logs $service 2>&1`;
        }
      }
      die sprintf("\nERROR: StartGenoring: Failed to get $module module initialized in less than %d min!\n", $STATE_MAX_TRIES/60)
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
  #  Warn and ask for confirmation.
  print "WARNING: This will stop all GenoRing containers, REMOVE their local data ('volumes' directory contant) and reset GenoRing config! This operation can not be undone so make backups before as needed. Are you sure you want to continue? (y|n) ";
  my $userword = <STDIN>;
  chomp $userword;
  if (!$userword || $userword !~ m/^y(?:es)?/i) {
    print "Operation canceled!\n";
    exit(0);
  }

  # @todo Check if only a sub-part should be managed.
  # @todo Add an option to remove ALL and not just Drupal and its db.

  # Stop genoring.
  StopGenoring();

  # Cleanup containers.
  print "Pruning stopped containers...\n";
  Run(
    "docker container prune -f",
    "Failed to prune containers!"
  );

  # Remove GenoRing volumes.
  print "Removing GenoRing volumes...\n";
  Run(
    "docker volume rm -f genoring-drupal genoring-data",
    "Failed to remove GenoRing volumes!"
  );
  # @todo Remove module's shared volumes as well.

  # Remove Drupal and database content.
  Run(
    "docker run --rm -v $BASEDIR/volumes:/genoring -w / alpine rm -rf /genoring/drupal /genoring/db /genoring/data",
    "Failed clear local volume content!"
  );
  # @todo Clear enabled modules.

  # Clear config.
  print "Clearing config...\n";
  unlink $DOCKER_COMPOSE_FILE;

  print "Reinitialization done!\n";
}

=pod

=head2 SetupGenoring

B<Description>: Initializes GenoRing system with user inputs.

B<ArgsCount>: 0

B<Return>: (nothing)

=cut

sub SetupGenoring {

  # Get enabled modules.
  my $modules = GetModules(1);

  # Needs first-time initialization.
  print "- GenoRing needs to be setup\n";
  # @todo
  # Process environment variables and ask user for inputs for variables with
  # tags SET et OPT.
  print "- Setup environment...\n";
  print "  ...Environment setup done.\n";

  # Generate docker-compose.yml...
  print "- Generating Docker Compose main file...\n";
  my %services;
  my %volumes;
  my @proxy_dependencies;
  foreach my $module (@$modules) {
    print "  - Processing $module module\n";

    # Work on module services.
    opendir(my $dh, "$MODULE_DIR/$module/services")
      or die "ERROR: StartGenoring: Failed to access '$MODULE_DIR/$module/services' directory!\n$!";
    my @services = (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$MODULE_DIR/$module/services/$_" } readdir($dh));
    closedir($dh);
    foreach my $service_yml (@services) {
      my $svc_fh;
      open($svc_fh, "$MODULE_DIR/$module/services/$service_yml")
        or die "ERROR: StartGenoring: Failed to open module service file '$service_yml'.\n$!";
      my $service = substr($service_yml, 0, -4);
      if (($module ne 'genoring') || ($service eq 'genoring')) {
        push(@proxy_dependencies, $service);
      }
      my $svc_version = <$svc_fh>;
      if ($svc_version !~ m/^# v?(\d+)\.(\d+)/i) {
        die "ERROR: StartGenoring: Invalid $module module service file '$service_yml': missing version!";
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
        or die "ERROR: StartGenoring: Failed to open module volume file '$volume_yml'.\n$!";
      my $volume = substr($volume_yml, 0, -4);
      my $vol_version = <$vl_fh>;
      if ($vol_version !~ m/^# v?(\d+)\.(\d+)/i) {
        die "ERROR: StartGenoring: Invalid $module module volume file '$volume_yml': missing version!";
      }
      if (exists($volumes{$volume})) {
        # Compare versions.
        if ($volumes{$volume}->{'version'} != $1) {
          die "ERROR: StartGenoring: Incompatible $module module volume file '$volume_yml': major version differs from corresponding " . $volumes{$volume}->{'module'} . " module definition!";
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
    die "ERROR: failed to open Docker Compose file '$DOCKER_COMPOSE_FILE':\n$!\n";
  }
  print "  ...Docker Compose file generated.\n";

  # Apply global initialization hooks (modules/*/hooks/init.pl).
  print "- Initialiazing modules...\n";
  foreach my $module (@$modules) {
    if (-e "$MODULE_DIR/$module/hooks/init.pl") {
      print "  Initialiazing $module module...";
      Run(
        "perl $MODULE_DIR/$module/hooks/init.pl",
        "Failed to initialize $module module!",
        1
      );
      print "OK\n";
    }
  }
  print "  Modules initialiazed on local system, initializing services...\n";

  # Start dockers in backend mode.
  print "  - Starting GenoRing backend for initialization...\n";
  $ENV{'COMPOSE_PROFILES'} = 'backend';
  Run(
    "docker compose up -d",
    "Failed to start GenoRing backend!",
    1
  );
  print "    OK\n";

  # Check dockers are ready.
  print "  - Waiting for all services to be operational...\n";
  WaitModulesReady(@$modules);
  print "    OK\n";

  # Apply docker initialization hooks of each enabled module service for each
  # enabled module service (ie. modules/"svc1"/hooks/init_"svc2".sh).
  print "  - Applying container initialization hooks...\n";
  foreach my $module (@$modules) {
    if (-d "$MODULE_DIR/$module/hooks/") {
      # readdir and filter on services.
      opendir(my $dh, "$MODULE_DIR/$module/hooks")
        or die "ERROR: StartGenoring: Failed to list '$MODULE_DIR/$module/hooks' directory!\n$!";
      my @hooks = (grep { $_ =~ m/^enable_.+\.sh$/ && -r "$MODULE_DIR/$module/hooks/$_" } readdir($dh));
      foreach my $hook (@hooks) {
        if (($hook =~ m/^enable_(.+)\.sh$/) && exists($services{$1})) {
          Run(
            "docker exec -v $(pwd)/$MODULE_DIR/$module/hooks/:/genoring/ -it $1 /genoring/$hook",
            "Failed to initialize $module in $1 (hook $hook)"
          );
        }
      }
    }
  }
  print "    OK\n";
  print "  ...Modules initialiazed.\n";

  # Stop containers.
  print "- Stopping backend.\n";
  StopGenoring();

  # mkdir -p volumes/drupal
  # mkdir -p volumes/data
  # # @toto Manage environment file generation.
  # # Ask for ...
  # while [ -z "$value" ]; do
  #   read -p "Enter a value: " value
  # done
  # 
  # # @todo Check for modules to enable.
  # # docker exec -v ./modules/profile/path/to/:/path/to/ -it genoring /path/to/script.sh
  # # @toto Ask to start genoring.
  # start_genoring
}

##
# Updates the GenoRing system or the specified module.
#
# Arguments:
#  service (optional): the service/module to update. If not set, all is
#    updated.
#
sub Update {

  # Get enabled modules.
  my $modules = GetModules(1);
  my %services; # @todo

  # @todo Check if running.
  StopGenoring();

  # @todo Check if only some parts should be updated or update all.
  # docker compose run -e DRUPAL_UPDATE=2 genoring

  # Start dockers in backend mode.
  print "  - Starting GenoRing backend for initialization...\n";
  $ENV{'COMPOSE_PROFILES'} = 'backend';
  Run(
    "docker compose up -d",
    "Failed to start GenoRing backend!",
    1
  );
  print "    OK\n";

  # Check dockers are ready.
  print "  - Waiting for all services to be operational...\n";
  WaitModulesReady(@$modules);
  print "    OK\n";

  # Apply docker initialization hooks of each enabled module service for each
  # enabled module service (ie. modules/"svc1"/hooks/init_"svc2".sh).
  print "  - Applying container initialization hooks...\n";
  foreach my $module (@$modules) {
    if (-d "$MODULE_DIR/$module/hooks/") {
      # readdir and filter on services.
      opendir(my $dh, "$MODULE_DIR/$module/hooks")
        or die "ERROR: StartGenoring: Failed to list '$MODULE_DIR/$module/hooks' directory!\n$!";
      my @hooks = (grep { $_ =~ m/^enable_.+\.sh$/ && -r "$MODULE_DIR/$module/hooks/$_" } readdir($dh));
      foreach my $hook (@hooks) {
        if (($hook =~ m/^enable_(.+)\.sh$/) && exists($services{$1})) {
          Run(
            "docker exec -v $(pwd)/$MODULE_DIR/$module/hooks/:/genoring/ -it $1 /genoring/$hook",
            "Failed to initialize $module in $1 (hook $hook)"
          );
        }
      }
    }
  }
  print "    OK\n";
  print "  ...Modules initialiazed.\n";

  # Stop containers.
  print "- Stopping backend.\n";
  StopGenoring();

}

##
# Enables the given GenoRing module.
#
# Arguments:
#  module: the module to enable and setup.
#
sub InstallModule {
  # Check if the system is running and stop it.
  # Set maintenance mode.
  # Perform install.
  # Start the system.
  # Perform container installations.
  # Stop the system if it was not started.
  
  # if [ -z $1 ]; then
  #   >&2 echo "ERROR: genoring_enable: No module name provided!"
  #   exit 1
  # fi
  # # Get module status.
  # get_module_status $1
  # if [ -z "$module_status" ]; then
  #   >&2 echo "ERROR: genoring_enable: module not found ($1)!"
  #   exit 1
  # elif [ "0" == "$module_status" ]; then
  #   # Enable specified modules.
  #   # Add module to the enabled module file.
  #   echo "$1" >> ./enabled_modules.txt
  #   # Copy nginx config.
  #   if [ -e "./modules/$1/nginx/$1.conf" ]; then
  #     # Do not overwrite existing.
  #     cp -n "./modules/$1/nginx/$1.conf" ./proxy/modules/
  #   fi
  #   # Call init scripts.
  #   echo "Initializing..."
  #   if [ -x "./modules/$1/hooks/init.sh" ]; then
  #     echo "- $1"
  #     ./modules/$1/hooks/init.sh
  #   fi
  #   if [ -d "./modules/$1/hooks" ]; then
  #     # Loop on docker initialization scripts.
  #     for scriptname in modules/$1/hooks/init_*.sh; do
  #       # When no files found, continue.
  #       [ -e "$scriptname" ] || continue
  #       container_name=$(echo $scriptname | perl -p -e "s#modules/$1/hooks/init_(.+)\.sh#\$1#g")
  #       # Check if the corresponding container is running.
  #       container_is_running $container_name
  #       if [ ! -z "$container_is_running" ]; then
  #         echo "- $container_name"
  #         docker exec -v ./modules/$1/hooks/init_$container_name.sh:/usr/init/init_$container_name.sh -it $container_name /user/init/init_$container_name.sh
  #       fi
  #     done
  #   fi
  #   echo "...initialization done."
  # elif [ "1" == "$module_status" ]; then
  #   echo "WARNING: genoring_enable: module already enabled ($1)."
  # fi
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
  my ($module, $service) = (@_);
  
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
  my @modules;
  if (!defined($module_mode)) {
    # Get all available modules.
    opendir(my $dh, "$MODULE_DIR")
      or die "ERROR: GetModules: Failed to list '$MODULE_DIR' directory!\n$!";
    my @modules = (grep { $_ !~ m/^\.$/ && -d "$MODULE_DIR/$_" } readdir($dh));
  }
  elsif (0 == $module_mode) {
    # Get disabled modules.
    my $all_modules = GetModules();
    my $enabled_modules = { map { $_ => $_ } GetModules(1) };
    my @modules = (grep { !exists($enabled_modules->{$_}) } @$all_modules);
  }
  elsif (1 == $module_mode) {
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
    @modules = keys(%modules);
  }

  return \@modules;
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
  opendir(my $dh, "$MODULE_DIR/$module/services")
    or die "ERROR: GetModuleServices: Failed to list '$MODULE_DIR/$module/services' directory!\n$!";
  my @services = (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$MODULE_DIR/$module/services/$_" } readdir($dh));

  return \@services;
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
  my @volumes = (grep { $_ =~ m/^[^\.].*\.yml$/ && -r "$MODULE_DIR/$module/volumes/$_" } readdir($dh));

  return \@volumes;
}

##
# Returns the value of an environment variable in an env file.
#
# Arguments:
#   $1: environment file path.
#   $2: setting variable name.
#
# Return: 
#   Sets the variable 'env_value'.
#
sub GetEnvVariable {
  # env_value=
  # if [ -z $1 ]; then
  #   >&2 echo "ERROR: get_env_setting: Environment file not provided!"
  #   exit 1
  # elif [ ! -f $1 ]; then
  #   >&2 echo "ERROR: get_env_setting: Environment file not found ($1)!"
  #   exit 1
  # elif [ -z $2 ]; then
  #   >&2 echo "ERROR: get_env_setting: No setting variable requested!"
  #   exit 1
  # fi
  # env_value=$(grep -P "^\s*$2\s*[=:]" $1 | sed -r "s/\s*$2\s*[=:]\s*//" | sed -r "s/^'(.*)'\\s*\$|^\"(.*)\"\\s*\$/\1\2/" | tail -n 1)
}

##
# Sets the value of an environment variable in a given env file.
#
# Arguments:
#   $1: environment file path.
#   $2: setting variable name.
#   $3: new setting variable value.
#
sub SetEnvVariable {
  # if [ -z $1 ]; then
  #   >&2 echo "ERROR: set_env_setting: Environment file not provided!"
  #   exit 1
  # elif [ ! -f $1 ]; then
  #   >&2 echo "ERROR: set_env_setting: Environment file not found ($1)!"
  #   exit 1
  # elif [ -z $2 ]; then
  #   >&2 echo "ERROR: set_env_setting: No setting variable requested!"
  #   exit 1
  # fi
  # # Check if setting is there.
  # if [ -z "$(grep -P "\s*$2\s*[=:]" $1)" ]; then
  #   echo "\n$2=$3" >> $1
  # else
  #   perl -p -i -e "s/\s*\Q$2\E\s*[=:].*/$2=$3/g" $1
  # fi
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


# Script options
#################

=pod

=head1 OPTIONS

genoring.pl [help | man | start | stop | compile] -debug

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
  StartGenoring(@arguments);
}
elsif ($command =~ m/^stop$/i) {
  StopGenoring(@arguments);
}
elsif ($command =~ m/^logs$/i) {
  GetLogs(@arguments);
}
elsif ($command =~ m/^status$/i) {
  GetStatus(@arguments);
}
elsif ($command =~ m/^reinit(?:ialize)?$/i) {
  Reinitialize(@arguments);
}
elsif ($command =~ m/^update$/i) {
  Update(@arguments);
}
elsif ($command =~ m/^enable$/i) {
  InstallModule(@arguments);
}
elsif ($command =~ m/^uninstall$/i) {
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
  print join(', ', @{GetModuleServices(@arguments)}) . "\n";
}
elsif ($command =~ m/^volumes$/i) {
  print join(', ', @{GetModuleVolumes(@arguments)}) . "\n";
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
