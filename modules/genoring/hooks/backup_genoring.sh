#!/bin/sh

# Automatically exit on error.
set -e

# $1 is supposed to contain the base name of the backup.
# Set maintenance mode.
genoring offline

# Perform backup.
genoring backup $1

# Done. Remove maintenance mode.
genoring online
