# GenoRing module hooks

## Description

This directory contains hook scripts called by GenoRing when a given event
occurs. Some scripts are local, some others are for containers. The given
scripts are provided as example and can be altered. Remove all hook scripts that
are not used by your module.

All scripts should be fault-tolerant and output meaningfull messages for logs.

Local hooks are the one ending by ".pl" and run on the local server running
Genoring.

Container hooks are the one ending by "SERVICE.sh" and run inside containers.
Their file names should be adapted to the GenoRing services they are targeting.

For a detailed list of supported hooks, see genoring.pl script documentation for
functions ApplyLocalHooks and ApplyContainerHooks.

## Local hooks
Local hooks are perl scripts with the following recommandations:
- do not use non-PERL core modules (https://perldoc.perl.org/modules).
  This is required to avoid extra-requirements. Otherwise, you should document
  that your module has extra-dependencies and handle the case when those
  dependencies are not met.
- avoid the use of shell commands (ie. system(), qx(), and such) unless you are
  the command used are available on all OS (including Windows and Mac
  platforms).
- when using file path, make sure function used support automatic path
  conversion, otherwise, use File::Spec->catfile() for compatibility with
  Windows.

## Container hooks

The "SERVICE" part of the name of a container hook should be replaced by the
name of a service (ie. Docker container name). The given container hook will be
executed in that container, using the container specificities (ie. if it is a
Linux image with bash, the script could start with "#!/bin/bash", but if it's an
alpine image, using "#!/bin/ash" would be more appropriate).

To allow the use of external materials (ie. files) in the target service, the
GenoRing "modules" directory is automatically mounted in the container as
"/genoring/modules". Therefore, the hook can call additional scripts or use
resource files for its operations.
