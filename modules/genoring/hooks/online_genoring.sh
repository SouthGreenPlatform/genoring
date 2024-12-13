#!/bin/sh

# Automatically exit on error.
set -e

# Remove maintenance mode.
genoring online

# Remove offline file.
if test -f /opt/drupal/web/offline.html; then
  echo "Remove offline file."
  rm /opt/drupal/web/offline.html
fi
