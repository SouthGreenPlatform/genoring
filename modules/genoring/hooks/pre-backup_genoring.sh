#!/bin/sh

# Automatically exit on error.
set -e

# Clear cache files.
drush cr
drush cc css-js
drush cron
rm -rf /opt/drupal/web/sites/default/files/css /opt/drupal/web/sites/default/files/js /opt/drupal/web/sites/default/files/styles /opt/drupal/web/sites/default/files/simpletest /opt/drupal/web/sites/default/files/php
