#!/bin/bash

# Automatically exit on error.
set -e

# Install and enable Gigwa Drupal module.
composer -n require drupal/gigwa

# Add Gigwa menu item.
drush -y scr /genoring/modules/gigwa/res/init_site.php
