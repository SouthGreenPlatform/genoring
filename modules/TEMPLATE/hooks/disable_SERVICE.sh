#!/bin/sh

# This hook is a shell script that is called inside the specified docker
# container service called 'SERVICE' (cf. hook file name). It should be adapted
# to the container it supposed to run on. The service must be a service of
# another module (see below).
# The 'disable' container hook is called when an enabled module is disabled,
# to perform the required actions on services that remain enabled (ie. remove
# CMS menu items the module added in the "genoring" service). It is NOT run on
# the services of the disabled module as they are not available anymore: their
# cleanup must be performed by the 'disable.pl' local hook instead (a warning is
# issued if such a container hook is provided). For the same reason, 'disable'
# hooks of other modules targeting a service of the disabled module are not run.

# Some update tasks to perform on the service...
