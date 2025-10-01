#!/usr/bin/env perl

=pod

=head1 NAME

genoring.pl - Manages GenoRing platform.

=head1 SYNOPSIS

  ./genoring.pl start
  ./genoring.pl stop

Multi-instances:
  COMPOSE_PROJECT_NAME=instance_name ./genoring.pl start

Syntax:

  perl genoring.pl [help | man | start | stop | online | offline | backend
  | logs [-f] | status
  | modules | services | volumes | alternatives <MODULE> | moduleinfo <MODULE>
  | setup [-auto | -minimal] [-reset]
  | reset [-f] [-delete-containers] [-keep-env]
  | enable <MODULE> | disable <MODULE> | uninstall <MODULE> [-keep-env]
  | enalt <MODULE> <SERVICE> | disalt <MODULE> <SERVICE>
  | tolocal <SERVICE> <IP> | todocker <SERVICE [ALTERNATIVE]>
  | update [MODULE] | upgrade [MODULE]
  | backup [BKNAME] | restore [BKNAME] | compile <MODULE> <SERVICE> [-no-cache]
  | shell [SERVICE] [-cmd=<COMMAND>] ] [-debug] [-no-exposed-volumes] [-no-backup]
  [-port=<HTTP_PORT>] [-arm[=ARCH] | -platform=<ARCH>] [-wait-ready[=DELAYSEC]]
  [-yes|-no] [-verbose] [-hide-compile]

=head1 REQUIRES

Perl5

=head1 DESCRIPTION

Manages GenoRing platform. This script can be used to start, update, stop,
reinstall GenoRing, get informations on current GenoRing instance and compile
GenoRing module containers.

=cut

require 5.8.0;
use strict;
use warnings;
use utf8;

use Cwd qw();
use File::Basename;
use File::Spec;
use FindBin;
use Pod::Usage;
use Time::Piece;
# Local libraries.
$ENV{'GENORING_RUNNING'} = 1;
use lib "$FindBin::Bin/perllib";
use Genoring;

++$|; #no buffering




# Script global constants
##########################

=pod

=head1 CONSTANTS

B<$Genoring::GENORING_DIR>: (string)

Installation directory of GenoRing. This "constant" from the GenoRing package is
ajusted to reflect current script path.

B<$Genoring::MODULES_DIR>: (string)

Name of the module directory. This "constant" from the GenoRing package is
ajusted to reflect current script path.

=cut

$Genoring::GENORING_DIR = dirname(__FILE__);
$Genoring::GENORING_DIR = Cwd::cwd() if ('.' eq $Genoring::GENORING_DIR);
$Genoring::MODULES_DIR = File::Spec->catfile($Genoring::GENORING_DIR, 'modules');




# Script options
#################

=pod

=head1 OPTIONS

* Commands:

=over 4

=item B<help>:

Display help and exits.

=item B<man>:
->
Prints the manual page and exits.

=item B<start>:

Starts GenoRing. For the first start, GenoRing is installed and initialized.

=item B<stop>:

Stops GenoRing.

=item B<online>:

Alias for "start". Starts GenoRing in "online" mode.

=item B<offline>:

Starts GenoRing in "offline" mode, meaning that the web site displays a
maintenance message and returns a 503 HTTP status code. The administration
interface is not accessible and no web services are available.

=item B<backend>:

Starts GenoRing in "backend" mode, meaning that the site is accessible but
displays a maintenance page and no services are available. The admin users can
still login and access the administration interface.

=item B<logs [-f]>:

Display container logs. If the "-f" flag is used, logs are displayed in "follow"
mode (updated live until the GenoRing script is stopped).

=item B<status>:

Display current GenoRing status (ie. "running", "not running", "offline mode",
...).

=item B<modules [0|1]>:

Displays all available modules by default. If 0 is used, only disabled modules
are listed and if 1 is used, only enabled modules are listed.

=item B<services>:

Displays the list of GenoRing services with their corresponding (enabled)
modules.

=item B<volumes>:

Displays the list of GenoRing volumes with their corresponding (enabled)
modules.

=item B<alternatives MODULE>:

Displays the list of service alternatives for a given module.

=item B<moduleinfo MODULE>:

Displays information on the given module.

=item B<setup [-auto | -minimal] [-reset]>:

Setups GenoRing environment and regenerates Docker Compose file.
If '-auto' flag is used, all current or default settings are used. If '-minimal'
flag is used, only non-optional environment values will be asked. If '-reset'
flag is used, current environment files are removed and need to be fully
regenerated.

=item B<reset [-f] [-delete-containers] [-keep-env]>:

Reinitializes GenoRing system and removes everything (except backups) to restart
GenoRing from scratch. If the '-f' flag is used, no confirmation is asked. If
the '-delete-containers' flag is used, compiled containers are also removed.
If '-keep-env' is used, current environment files are kept.

=item B<enable MODULE>:

Installs and enables the given GenoRing module.

=item B<disable MODULE>:

Disables the given GenoRing module.

=item B<uninstall MODULE [-keep-env]>:

Uninstalls the given GenoRing module. If -keep-env flag is used, settings are
not removed.

=item B<enalt MODULE SERVICE>:

Enables the given GenoRing module service alternative.

=item B<disalt MODULE SERVICE>:

Disables the given GenoRing module service alternative and put back the default
service.

=item B<tolocal SERVICE IP>:

Turns a Docker service SERVICE into a local service provided by the given IP.

=item B<todocker SERVICE [ALTERNATIVE]>:

Puts back the given Docker service that was replaced by a local service. If
ALTERNATIVE is specified, the given service alternative will be used.

=item B<backup [BACKUP_NAME [MODULE]]>:

Performs a general backup of the GenoRing system into a backup directory
(volumes/backups/[BACKUP_NAME]/) or a backup of the given module data and config
(in volumes/backups/[BACKUP_NAME]/[MODULE]/).

=item B<restore [BACKUP_NAME [MODULE]]>:

Restores a general backup of the GenoRing system from the backup directory
(volumes/backups/[BACKUP_NAME]/) or from a backup of the given module
(in volumes/backups/[BACKUP_NAME]/[MODULE]/).

=item B<update>:

Updates GenoRing or a given GenoRing module. "Update" will update the software
and the data managed by GenoRing or the given module. "update" deals with what
is managed by the GenoRing module itself while "upgrade" deals with the version
of the GenoRing module: for instance, "updating" GenoRing core will update
Drupal modules while upgrading will change the version of GenoRing used which
may bring new features or a different behavior of the GenoRing platform.

=item B<upgrade>:

Upgrade GenoRing or a given GenoRing module. "Upgrade" will upgrade
GenoRing core and its modules or the given GenoRing module to a newer version.
Upgrading will also update the software and the data. "update" deals with what
is managed by the GenoRing module itself while "upgrade" deals with the version
of the GenoRing module: for instance, "updating" GenoRing core will update
Drupal modules while upgrading will change the version of GenoRing used which
may bring new features or a different behavior of the GenoRing platform.

=item B<compile MODULE SERVICE [-arm[=ARCH]] [-no-cache]>:

Compiles the Docker container corresponding to the given module service if
sources are available. For ARM systems, you must use the "-arm" flag. It is also
possible to provide a specific ARM architecture (ARCH). If a source
"Dockerfile.arm" is provided, it will be used (regardless the specified ARCH
parameter) and if not, it will be generated (either using the ARCH architecture
or the default 'linux/arm64' architecture).

=item B<shell [SERVICE] [-cmd=COMMAND]>:

Launches a bash shell in the main GenoRing container (the CMS container). If
SERVICE is specified, the corresponding service container will be used instead.
If COMMAND is specified, that command will be used instead of "bash".

=back

* Global flags:

=over 4

=item B<-port=HTTP_PORT>:

Specifies the HTTP port to use. Default: 8080.

=item B<-arm[=ARCH]>:

Use ARM versions for Docker compilation when available or run on ARM
architectures. You may specify an architecture, for example: "-arm=linux/arm64".
Default architecture is "linux/arm64". Using this flag excludes the "-platform"
flag.

=item B<-platform=ARCH>:

Use the given architecture for Docker compilation and execution. This flag can
not be used in conjunction with the "-arm" flag.

=item B<-wait-ready=DELAYSEC>:

Maximum waiting time in seconds to wait for system to be ready. If the system is
not ready during this time, genoring.pl script will just stop and let know the
system might be still loading, which is ok. Default to 300 (seconds = 5minutes).
Some systems may require more than 5 minutes to be started, especially when
installing or enabling modules or during updates, so that delay may need to be
increased according to the machine running GenoRing. It can be set high but
sometimes, some docker services are never ready because of an error and the
given delay ensure GenoRing ends gracefully and gives back the hand to the admin
in such cases in reasonable time.

=item B<-no-exposed-volumes>:

Disables Docker exposed named (shared) volumes. Must be used at installation
time and each time the Docker Compose file is regenerated (module/service
changes).

=item B<-no-backup>:

Disables the use of automatic backups when performing site operations such as
modifying modules.

=item B<-yes | -no>:

Automatically answers confirmations with the selected answer (ie. 'yes' or
'no').

=item B<-hide-compile>:

Use this flag to hide missing container compilation details.

=item B<-debug>:

Enables debug mode.

=back

=cut

# Get configuration.
my $config = GetConfig();

print "GenoRing script v$Genoring::GENORING_VERSION (project instance: " . GetProjectName() . ")\n";

# Test license agreement.
if (!-e "$Genoring::GENORING_DIR/agreed.txt") {
  my $message = "License Agreement\n=================\nGenoRing is under *MIT License*. It is free and open-source software that will *always remain free to use*. Please read the provided LICENSE file for details.\nDo you agree with those conditions?";
  if (Confirm($message)) {
    my $agreed_fh;
    if (open($agreed_fh, '>:utf8', "$Genoring::GENORING_DIR/agreed.txt")) {
      print {$agreed_fh} "License agreed on the " . localtime->strftime('%Y-%m-%d') . "\n";
      close($agreed_fh);
    }
    else {
      print "WARNING: Unable to create 'agreed.txt' file.\n$!\n";
    }
    print "\n";
  }
  else {
    die "You must agree to the MIT License conditions to use GenoRing.\n";
  }
}

# Options processing.
my ($man, $help) = (0, 0);

my @argv = @ARGV;
my $command = shift(@argv);
if (!$command || ($command =~ m/^-?-?help$|^[-\/]-?\?$/i)) {
  $help = shift(@argv) || 1;
}
elsif ($command =~ m/^-?-?man$/i) {
  $man = 1;
}

my (@arguments);
my $arg = shift(@argv);
while (defined($arg)) {
  if ($arg =~ m/^--?([\w\-]+)(?:=(.*))?$/i) {
    my $flag = $1;
    $g_flags->{$flag} = defined($2) ? $2 : 1;
    if (!defined($2)
      && ($flag =~ m/arm|cmd|platform|port|wait-ready/i)
    ) {
      if (scalar(@argv) && ($argv[0] !~ m/^--?[a-z]/i)) {
        $g_flags->{$flag} = shift(@argv);
      }
      elsif ($flag =~ m/cmd|platform|port/i) {
        warn "ERROR: Invalid flag syntax for flag '$flag'.\n\n";
        pod2usage('-verbose' => 0, '-exitval' => 1);
      }
    }
  }
  else {
    push(@arguments, $arg);
  }
  $arg = shift(@argv);
}

if (exists($g_flags->{'help'})) {
  $help = $g_flags->{'help'} || 1;
}

if (exists($g_flags->{'verbose'})) {
  $g_flags->{'verbose'} = 1;
}

if ($help) {
  if (1 == $help) {
    # Display main help.
    pod2usage('-verbose' => 0, '-exitval' => 0);
  }
  else {
    # @todo Display command-specific help.
    # @see https://perldoc.perl.org/Pod::Usage
    pod2usage('-verbose' => 1, '-exitval' => 0);
  }
}
if ($man) {pod2usage('-verbose' => 1, '-exitval' => 0);}

# Change debug mode if requested/forced.
$g_debug ||= exists($g_flags->{'debug'}) ? $g_flags->{'debug'} : 0;

# Allow alternative syntax for no-backups without "s".
if ($g_flags->{'no-backups'}) {
  $g_flags->{'no-backup'} = $g_flags->{'no-backups'};
}

# Check Docker requirements.
if (!$g_flags->{'bypass'}) {
  # Docker command availability.
  my $output = qx($Genoring::DOCKER_COMMAND 2>&1) || '';
  if ($?) {
    die "ERROR: '$Genoring::DOCKER_COMMAND' command not found!\n$output\n";
  }
  # Docker version.
  my $docker_compose_version = qx($Genoring::DOCKER_COMPOSE_COMMAND version 2>&1);
  if ($?) {
    die "ERROR: '$Genoring::DOCKER_COMMAND compose' command not available!\n";
  }
  elsif ($docker_compose_version !~ m/\sv?(?:[2-9]|\d{2,})\./) {
    $docker_compose_version =~ m/\sv?([\d\.]+)/;
    die "ERROR: '$Genoring::DOCKER_COMMAND compose' does not meet minimal version requirement (" . ($1 || 'unknown version') . " < v2)!\n";
  }
  # Docker command permission.
  $output = qx($Genoring::DOCKER_COMMAND ps 2>&1);
  if ($?) {
    die "ERROR: Current user not allowed to manage containers with '$Genoring::DOCKER_COMMAND' command!\n$output\n";
  }
  # @todo: check buildx.
}

# Init host name.
my ($hostname, $port);
if (-r "env/genoring_genoring.env") {
  $hostname = GetEnvVariable('env/genoring_genoring.env', 'GENORING_HOST');
  $port = GetEnvVariable('env/genoring_genoring.env', 'GENORING_PORT');
}
if ($hostname) {
  $ENV{'GENORING_HOST'} = $hostname;
}

# Check for HTTP port.
if ($g_flags->{'port'} && ($g_flags->{'port'} =~ m/^\d{2,}$/)) {
  # Port forced in parameters, ignore environment.
  $ENV{'GENORING_PORT'} = $g_flags->{'port'};
  if ((-r "env/genoring_genoring.env")
      && (!$port || ($g_flags->{'port'} != $port))
  ) {
    SetEnvVariable('env/genoring_genoring.env', 'GENORING_PORT', $g_flags->{'port'});
  }
}
elsif ($port) {
  # Port set in environment config, ignore global environment.
  $ENV{'GENORING_PORT'} = $port;
}
elsif ((-r "env/genoring_genoring.env") && $ENV{'GENORING_PORT'}) {
  # Port not set in environment config, use global environment.
  SetEnvVariable('env/genoring_genoring.env', 'GENORING_PORT', $ENV{'GENORING_PORT'});
}

# Check for a specific platform architecture.
if (exists($g_flags->{'arm'})) {
  # Use a default ARM platform if needed.
  if ((!$g_flags->{'arm'}) || (1 == $g_flags->{'arm'})) {
    $g_flags->{'arm'} = $Genoring::DEFAULT_ARM_ARCHITECTURE;
  }
  # Set platform to ARM.
  $g_flags->{'platform'} = $g_flags->{'arm'};
}
elsif ($g_flags->{'platform'} && ('1' ne $g_flags->{'platform'})) {
  # If the platform flag is used without specifying a platform, clear it.
  delete($g_flags->{'platform'});
}
# Only set default platform if needed.
# Disabled as it does not work as expected.
# if ($g_flags->{'platform'}) {
#   $ENV{'DOCKER_DEFAULT_PLATFORM'} = $g_flags->{'platform'};
# }

# Check for exposed file system.
if ($config->{'no-exposed-volumes'}) {
  $g_flags->{'no-exposed-volumes'} = $config->{'no-exposed-volumes'};
}
# For Windows FS, we can't use exposed shared FS as it crashes so we force set
# the appropriate flag.
if (('Win32' eq GetOs()) && (!$g_flags->{'no-exposed-volumes'})) {
  print "NOTE: Exposed named (shared) volumes are disabled in Windows system to avoid issues.\n";
  $g_flags->{'no-exposed-volumes'} = 1;
}
# Synchronize variables.
$g_flags->{'no-exposed-volumes'} =
$ENV{'GENORING_NO_EXPOSED_VOLUMES'} =
  ($g_flags->{'no-exposed-volumes'} || $ENV{'GENORING_NO_EXPOSED_VOLUMES'});

# Make sure there is enough disk space.
CheckFreeSpace();

# Set default GenoRing user and group.
InitGenoringUser();
CheckGenoringUser();

# Set waiting time.
if (!$g_flags->{'wait-ready'} || ($g_flags->{'wait-ready'} !~ m/^\d+/)) {
  $g_flags->{'wait-ready'} = $Genoring::STATE_MAX_TRIES;
}

if ($command =~ m/^(?:start|online|offline|backend)$/i) {
  if (!-d $Genoring::VOLUMES_DIR) {
    if (Confirm("GenoRing was not started in that directory before. Do you want to initialize current directory (" . $ENV{'PWD'} . ") as a GenoRing instance directory?")) {
      mkdir($Genoring::VOLUMES_DIR);
    }
    else {
      die("No \"volumes\" directory. Stopping here.");
    }
  }

  if (!exists($g_flags->{'hide-compile'})) {
    # Compile missing containers with sources.
    CompileMissingContainers();
  }

  # Check if setup needs to be run first.
  if (!-e $Genoring::DOCKER_COMPOSE_FILE) {
    # Needs first-time initialization.
    print "GenoRing needs to be setup...\n";
    SetupGenoring();
  }
  # Add requested mode.
  if ($command !~ m/^start$/i) {
    unshift(@arguments, lc($command));
  }
  print "Starting GenoRing...\n";
  StartGenoring(@arguments);
  print "...GenoRing started.\n";

  print "Ensuring services are ready...\n";
  # Get enabled modules.
  my $modules = GetModules(1);
  eval {
    WaitModulesReady(@$modules);
  };
  if ($@) {
    die $@ . "\nIt might be possible GenoRing needs more time to get ready. You may check GenoRing logs using 'perl genoring.pl logs -f' to watch for errors.";
  }
  print "...GenoRing is ready to accept client connections.\n";
  print "\n  --> http://" . $ENV{'GENORING_HOST'} . ":" . $ENV{'GENORING_PORT'} . "/\n";
}
elsif ($command =~ m/^stop$/i) {
  # Check if installed.
  if (!-e $Genoring::DOCKER_COMPOSE_FILE) {
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
  if (!-e $Genoring::DOCKER_COMPOSE_FILE) {
    warn "GenoRing needs to be setup first.\n";
    exit(1);
  }
  Update(@arguments);
}
elsif ($command =~ m/^upgrade$/i) {
  # Check if installed.
  if (!-e $Genoring::DOCKER_COMPOSE_FILE) {
    warn "GenoRing needs to be setup first.\n";
    exit(1);
  }
  Upgrade(@arguments);
}
elsif ($command =~ m/^setup$/i) {
  # (Re)run environment setup and docker-compose.yml generation.
  SetupGenoringEnvironment($g_flags->{'reset'}, @arguments);
  GenerateDockerComposeFile();
}
elsif ($command =~ m/^enable$/i) {
  # Check if installed.
  if (!-e $Genoring::DOCKER_COMPOSE_FILE) {
    warn "GenoRing needs to be setup first.\n";
    exit(1);
  }
  InstallModule(@arguments);
}
elsif ($command =~ m/^disable$/i) {
  # Check if installed.
  if (!-e $Genoring::DOCKER_COMPOSE_FILE) {
    warn "GenoRing needs to be setup first.\n";
    exit(1);
  }
  DisableModule(@arguments);
}
elsif ($command =~ m/^uninstall$/i) {
  # Check if installed.
  if (!-e $Genoring::DOCKER_COMPOSE_FILE) {
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
elsif ($command =~ m/^moduleinfo$/i) {
  my ($module) = @arguments;
  if (!$module) {
    die "ERROR: ModuleInfo: Missing module name!\n";
  }
  my $module_info = GetModuleInfo($module);
  print "Module: " . ($module_info->{'name'} || '!NAME MISSING!') . "\n";
  print "Machine name: $module\n";
  my $description = $module_info->{'description'} || '';
  # @todo Also split too long lines according to terminal line length.
  $description =~ s/\n/\n    /g;
  print "Description: " . $description . "\n";
  print "Version: " . ($module_info->{'version'} || 'n/a') . "\n";
  print "Services: " . join(', ', keys(%{$module_info->{'services'}})) . "\n";
  print "Volumes: " . join(', ', keys(%{$module_info->{'volumes'}})) . "\n";
  # @todo Add alternatives and dependencies.
}
elsif ($command =~ m/^volumes$/i) {
  my $volumes = GetVolumes(@arguments);
  foreach my $volume (sort keys(%$volumes)) {
    print "$volume (" . join(', ', @{$volumes->{$volume}}) . ")\n";
  }
}
elsif ($command =~ m/^services$/i) {
  my $services = GetServices(@arguments);
  foreach my $service (sort keys(%$services)) {
    print "$service (" . $services->{$service} . ")\n";
  }
}
elsif ($command =~ m/^alt(?:ernatives?)?$/i) {
  ListAlternatives(@arguments);
}
elsif ($command =~ m/^enalt$/i) {
  EnableAlternative(@arguments);
}
elsif ($command =~ m/^disalt$/i) {
  DisableAlternative(@arguments);
}
elsif ($command =~ m/^tolocal$/i) {
  ToLocalService(@arguments);
}
elsif ($command =~ m/^todocker$/i) {
  ToDockerService(@arguments);
}
elsif ($command =~ m/^shell$/i) {
  RunShell(@arguments);
}
elsif ($command =~ m/^diag$/i) {
  GetDiagosticLogs(@arguments);
}
elsif ($command =~ m/^localhooks$/i) {
  ApplyLocalHooks(@arguments);
}
elsif ($command =~ m/^containerhooks$/i) {
  ApplyContainerHooks(@arguments);
}
else {
  warn "ERROR: Invalid command '$command'.\n\n" if $command;
  pod2usage('-verbose' => 0, '-exitval' => 1);
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

Date 01/10/2025

=head1 SEE ALSO

GenoRing documentation (README.md).

=cut
