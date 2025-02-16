=pod

=head1 NAME

GenoRingConst - Contains GenoRing Perl constants.

=head1 SYNOPSIS

use GenoringConst;

=head1 REQUIRES

Perl5

=head1 DESCRIPTION

This module contains GenoRing global constants.

=cut

require 5.8.0;
use strict;
use warnings;
use utf8;
use Cwd qw();
use File::Basename;
use File::Spec;




# Package constants
####################

=pod

=head1 CONSTANTS

B<$CONSTRAINT_TYPE_REGEX>: (string)

Regular expression used to match a dependency constraint. One of "REQUIRES",
"CONFLICTS", "BEFORE" and "AFTER".

B<$DEBUG>: (boolean)

Enables/disables local debug mode.

B<$DEFAULT_ARCHITECTURE>: (string)

Default architecture to use.

B<$DEFAULT_ARM_ARCHITECTURE>: (string)

Default ARM architecture to use.

B<$DEPENDENCY_REGEX>: (string)

Regular expression used to match a dependency. Match order:
$1: module name
$2: optional version constraint (=, <, <=, >, >=)
$3: optional major version (always set if $3 is set)
$4: optional minor version
$5: optional stability
$6: optional service or volume name

B<$DOCKER_COMMAND>: (string)

Docker command (executable name with or without path).

B<$DOCKER_COMPOSE_FILE>: (string)

Name of the Docker Compose file.

B<$EXTRA_HOSTS>: (string)

Name of the extra hosts config file that contains service names replaced by
local hosts (IPs).

B<$GENORING_DEFAULT_PORT>: (integer)

Default HTTP port of GenoRing.

B<$GENORING_DIR>: (string)

Installation directory of GenoRing.

B<$GENORING_VERSION>: (string)

Current GenoRing script version.

B<$IS_CGI>: (boolean)

Tells if GenoRing is currently running from CGI (true) or command line (false).

B<$IS_MOD_PERL>: (boolean)

Tells if GenoRing is currently running as Apache Perl mod (true).

B<$MODULE_DIR>: (string)

Name of the module directory.

B<$MODULE_FILE>: (string)

Name of the module config file.

B<$MODULE_NAME_REGEX>: (string)

Regular expression used to match valid module names.

B<%OS>: (hash)

Hash associating an OS name ($^O) to a normalized OS architecture.

B<$PROFILE_CONSTRAINT_REGEX>: (string)

Regular expression used to match Docker execution profiles supported by
GenoRing.

B<$SERVICE_CONSTRAINT_REGEX>: (string)

Regular expression used to match service constraints in module config files.

B<$SERVICE_NAME_REGEX>: (string)

Regular expression used to match valid service names.

B<$STATE_MAX_TRIES>: (integer)

Maximum number of seconds to wait for a service to be ready (running).

B<$VOLUME_DIR>: (string)

Name of the shared docker volume directory.

B<$VOLUME_NAME_REGEX>: (string)

Regular expression used to match valid volume names.

=cut

our $CONSTRAINT_TYPE_REGEX = '(REQUIRES|CONFLICTS|BEFORE|AFTER)';
our $DEBUG = 0;
our $DEFAULT_ARCHITECTURE = 'linux/amd64';
our $DEFAULT_ARM_ARCHITECTURE = 'linux/arm64';
our $DOCKER_COMMAND = 'docker';
our $DOCKER_COMPOSE_FILE = 'docker-compose.yml';
our $EXTRA_HOSTS = 'extra_hosts.yml';
our $GENORING_DEFAULT_PORT = 8080;
our $GENORING_DIR = $ENV{'GENORING_DIR'} || '.';
our $GENORING_VERSION = '1.0';
our $IS_MOD_PERL = exists($ENV{'MOD_PERL'});
our $MODULE_FILE = 'modules.yml';
our $MODULE_NAME_REGEX = '[a-z][a-z0-9_]*';
our %OS = (
  ''        => 'Unix',
  'MSWin32' => 'Win32',
  'os2'     => 'Win32',
  'VMS'     => 'unsup',
  'NetWare' => 'Win32',
  'symbian' => 'Win32',
  'dos'     => 'Win32',
  'cygwin'  => 'Unix',
  'amigaos' => 'unsup',
);
our $PROFILE_CONSTRAINT_REGEX = '(?:((?:dev|staging|prod|backend|offline)(?:\s*,\s*(?:dev|staging|prod|backend|offline))*):)?';
our $SERVICE_CONSTRAINT_REGEX = '([a-z0-9\-\_]+)?';
our $SERVICE_NAME_REGEX = '[a-z][a-z0-9\-]*';
our $STATE_MAX_TRIES = 300;
our $VOLUME_DIR = $ENV{'GENORING_VOLUMES_DIR'} || File::Spec->catfile(Cwd::cwd(), 'volumes');
our $VOLUME_NAME_REGEX = '[a-z][a-z0-9\-]*';
# Constants that depends on others.
our $DEPENDENCY_REGEX = "(?:\\s+[oO][rR]\\s+)?($MODULE_NAME_REGEX)(?:\\s+(?:([<>]?=?)\\s*)(\\d+)(?:\\.(\\d+))?(alpha|beta|dev)?)?(?:\\s+($SERVICE_NAME_REGEX|$VOLUME_NAME_REGEX))?";
our $IS_CGI = $IS_MOD_PERL || (exists($ENV{'GATEWAY_INTERFACE'}) && $ENV{'GATEWAY_INTERFACE'});
our $MODULE_DIR = File::Spec->catfile($GENORING_DIR, 'modules');




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
