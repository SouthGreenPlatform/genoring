#!/bin/sh

# Automatically exit on error.
set -e

# $1 is supposed to contain the base name of the backup.
# Set maintenance mode.
genoring offline

# Restore.
genoring restore $1

# We need to rebuild the cache.
genoring command drush cr

# Done. Remove maintenance mode.
genoring online
