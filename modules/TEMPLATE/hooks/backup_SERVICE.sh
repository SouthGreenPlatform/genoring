#!/bin/sh

# This hook is a shell script that is called inside the specified docker
# container service called 'SERVICE' (cf. hook file name). It should be adapted
# to the container it supposed to run on with a backup (machine) name as first
# argument. The service could be either a service of this module as well as a
# service of another module.
# The 'backup' container hook is called when backup operation is needed.
# The task of the hook script is to copy, dump or export the data to backup in
# a given file/directory which name is based on the first parameter given to
# that script.

# Automatically exit on error.
set -e

# $1 is supposed to contain the base name of the backup.
mkdir -p /backups/my_module/$1
cd /data/my_module/
tar zcvf /backups/my_module/$1.tgz .
