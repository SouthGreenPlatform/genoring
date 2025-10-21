=pod

=head1 NAME

GenoRingEnv - Contains GenoRing Perl environment variable initialization.

=head1 SYNOPSIS

use GenoringEnv;

=head1 REQUIRES

Perl5

=head1 DESCRIPTION

This module contains GenoRing shell environment variable initialization. Those
environment variable are passed to any script (hooks) run by GenoRing.

=cut

require 5.8.0;
use strict;
use warnings;
use utf8;
use Cwd qw();
use Sys::Hostname;
use Genoring::GenoringFunc;




# Package environment variables
################################

=pod

=head1 ENVIRONMENT VARIABLES

B<PWD>: (string)

Path of current working directory. This environment variable is always set if
missing, especially on Windows architecture.

B<COMPOSE_PROJECT_NAME>: (string)

GenoRing instance name also known as Docker project name. Default: 'genoring'.

B<COMPOSE_PROFILES>: (string)

GenoRing running (environment) mode. The default value is set in GenoRing
environment file (genoring_genoring.env) variable 'GENORING_ENVIRONMENT'. It can
be one of 'dev', 'staging', 'prod', 'backend' and 'offline'.

B<GENORING_HOST>: (string)

GenoRing user interface web server name or IP.

B<GENORING_PORT>: (integer)

GenoRing user interface web port (clear HTTP, not secured).

B<GENORING_DIR>: (string)

Path to the GenoRing directory containing the main Perl script. It does not
include a trailing slash.

B<GENORING_VOLUMES_DIR>: (string)

Path to the GenoRing volume directory. It does not include a trailing slash.

B<GENORING_NO_EXPOSED_VOLUMES>: (boolean)

If set to a TRUE value (ie. '1'), GenoRing will not use Docker exposed volumes
but only internal (hidden) volumes.

B<GENORING_RUNNING>: (boolean)

Set by genoring.pl to 1 (TRUE) when running the script.

=cut

# Prepare environment variables...

# For Windows env, add PWD.
if (!defined($ENV{'PWD'})) {
  $ENV{'PWD'} = Cwd::cwd();
}
$ENV{'PWD'} ||= '.';

# Initializes current project name (ie. instance name).
if (!exists($ENV{'COMPOSE_PROJECT_NAME'})
    || ($ENV{'COMPOSE_PROJECT_NAME'} !~ m/\w/)
) {
  # If COMPOSE_PROJECT_NAME is not set, try to use the one from docker compose
  # file or use default.
  $ENV{'COMPOSE_PROJECT_NAME'} = Genoring::GetProjectName();
}
elsif ((Genoring::GetProjectName() ne $ENV{'COMPOSE_PROJECT_NAME'})
  && (-e $Genoring::DOCKER_COMPOSE_FILE)
) {
  # Make sure we use the correct project name.
  if (!Genoring::Confirm("WARNING: You are trying to run an already configured GenoRing instance with a different COMPOSE_PROJECT_NAME (configured: '" . Genoring::GetProjectName() . "', requested: '" . $ENV{'COMPOSE_PROJECT_NAME'} . "'). This may not work as expected. Do you want to continue anyway?")) {
    die "Stopped due to incorrect COMPOSE_PROJECT_NAME value.\n";
  }
}

# Set COMPOSE_PROFILES to an empty string to prevent warning 'The
# "COMPOSE_PROFILES" variable is not set. Defaulting to a blank string.'.
if (!defined($ENV{'COMPOSE_PROFILES'})) {
  if ('Win32' eq Genoring::GetOs()) {
    # Windows does not detect COMPOSE_PROFILES if set to an empty string.
    $ENV{'COMPOSE_PROFILES'} = ' ';
  }
  else {
    $ENV{'COMPOSE_PROFILES'} = '';
  }
}

# Set default port (can be modified by "-port" flag later).
if (!defined($ENV{'GENORING_HOST'})) {
  $ENV{'GENORING_HOST'} = hostname() || 'localhost';
}

# Set default port (can be modified by "-port" flag later).
if (!defined($ENV{'GENORING_PORT'})) {
  $ENV{'GENORING_PORT'} = $Genoring::GENORING_DEFAULT_PORT;
}

# Set/update GENORING_DIR environment variable.
$ENV{'GENORING_DIR'} = $Genoring::GENORING_DIR;

# Adjust GENORING_VOLUMES_DIR environment variable and $Genoring::VOLUMES_DIR.
if (!defined($ENV{'GENORING_VOLUMES_DIR'})) {
  $ENV{'GENORING_VOLUMES_DIR'} = $Genoring::VOLUMES_DIR;
}
else {
  $Genoring::VOLUMES_DIR = $ENV{'GENORING_VOLUMES_DIR'};
}

$ENV{'GENORING_NO_EXPOSED_VOLUMES'} ||= '';

# Use current user and group identifiers by default if not set.
$ENV{'GENORING_UID'} ||= $>;
$ENV{'GENORING_GID'} ||= $) + 0;




=pod

=head1 AUTHORS

Valentin GUIGNON (The Alliance Bioversity - CIAT), v.guignon@cgiar.org

=head1 VERSION

Version 1.0

Date 13/10/2025

=head1 SEE ALSO

GenoRing documentation.

=cut

return 1; # package return
