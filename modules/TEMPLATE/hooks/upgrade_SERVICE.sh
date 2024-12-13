#!/bin/sh

# This hook is a shell script that is called inside the specified docker
# container service called 'SERVICE' (cf. hook file name). It should be adapted
# to the container it supposed to run on. The service could be either a service
# of this module as well as a service of another module.
# The 'upgrade' container hook is called when a module needs to be upgraded to
# its latest version, to perform the required changes in the related services.
# All the 'upgrade' hooks of the module will be called on the corresponding
# services.

# Automatically exit on error.
set -e

# Some upgrade tasks to perform...
