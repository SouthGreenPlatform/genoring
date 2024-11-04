#!/bin/bash

# Automatically exit on error.
set -e

# Set maintenance mode.
./vendor/drush/drush/drush -y sset system.maintenance_mode 1
./vendor/drush/drush/drush cr

# Remove offline file.
if test -f /opt/drupal/web/offline.html; then
  echo "Remove offline file."
  rm /opt/drupal/web/offline.html
fi
