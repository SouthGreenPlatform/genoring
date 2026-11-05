#!/bin/sh

# Automatically exit on error.
set -e

# Rebuild cache files.
genoring command drush cr
