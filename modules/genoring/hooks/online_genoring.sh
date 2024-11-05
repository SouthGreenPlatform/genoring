#!/bin/sh

# Automatically exit on error.
set -e

# Remove maintenance mode.
./vendor/drush/drush/drush -y sset system.maintenance_mode 0

# Remove offline file.
if test -f /opt/drupal/web/offline.html; then
  echo "Remove offline file."
  rm /opt/drupal/web/offline.html
fi
