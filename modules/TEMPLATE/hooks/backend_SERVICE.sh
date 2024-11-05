#!/bin/sh

# This hook is a shell script that is called inside the specified docker
# container service called 'SERVICE' (cf. hook file name). It should be adapted
# to the container it supposed to run on. The service could be either a service
# of this module as well as a service of another module.
# The 'backend' container hook is called when GenoRing is set to 'backend' mode,
# to perform the required actions. All the 'backend' hooks of the module
# will be called on the corresponding (enabled) services as well as all
# 'backend' hooks targeting a service of this module.
# If your module needs to perform a task on a service of another module when
# GenoRing is set backend, it is possible by creating a hook targeting that
# service.

# Some tasks to perform on the service...
