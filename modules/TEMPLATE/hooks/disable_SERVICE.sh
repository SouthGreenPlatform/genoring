#!/bin/sh

# This hook is a shell script that is called inside the specified docker
# container service called 'SERVICE' (cf. hook file name). It should be adapted
# to the container it supposed to run on. The service could be either a service
# of this module as well as a service of another module.
# The 'disable' container hook is called when an enabled module is disabled,
# to perform the required actions. All the 'disable' hooks of the module
# will be called on the corresponding (enabled) services as well as all
# 'disable' hooks targeting a service of the disabled module.

# Some update tasks to perform on the service...
