#!/bin/bash

# This hook is a bash (-or shell by changing the header-) script that is called
# inside the specified docker container service called 'SERVICE' (cf. hook file
# name). It should be adapted to the container it supposed to run on. The
# service could be either a service of this module as well as a service of
# another module.
# The 'enable' container hook is called when a (not already enabled) module is
# enabled, to perform the required actions. All the 'enable' hooks of the module
# will be called on the corresponding (enabled) services as well as all 'enable'
# hooks targetting a service of this module.
# If your module needs to perform a task on a service of another module when
# that module is enabled, it is possible by creating a hook targeting that
# service. Such a hook will not be run when your module is enabled as the other
# module service is not available but once it is (enabled), your hook will be
# run.

# Automatically exit on error.
set -e

# Some tasks to perform on the service...
