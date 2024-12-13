#!/bin/sh

# Automatically exit on error.
set -e

# Set maintenance mode.
genoring offline

# Remove offline file.
if test -f /opt/drupal/web/offline.html; then
  printf "Remove offline file.\n"
  rm /opt/drupal/web/offline.html
fi
