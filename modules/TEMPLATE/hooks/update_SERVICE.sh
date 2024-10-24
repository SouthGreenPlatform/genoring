#!/bin/bash

# This hook is a bash (-or shell by changing the header-) script that is called
# inside the specified docker container service called 'SERVICE' (cf. hook file
# name). It should be adapted to the container it supposed to run on. The
# service could be either a service of this module as well as a service of
# another module.
# The 'update' container hook is called when a module needs to be updated, to
# perform the required updates. All the 'update' hooks of the module will be
# called on the corresponding services.

# Automatically exit on error.
set -e

# Some update tasks to perform...
