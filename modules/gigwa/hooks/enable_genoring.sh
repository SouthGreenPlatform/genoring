#!/bin/sh

# Automatically exit on error.
set -e

# Enable Gigwa module.
# genoring install_module gigwa

# Add integration.
if [ -z $GIGWA_DIRECT_ACCESS ] || [ $GIGWA_DIRECT_ACCESS -eq 0 ]; then
  genoring add_integration /genoring/modules/gigwa/res/integration.yml
fi

# Add Gigwa menu item.
genoring add_menuitem /genoring/modules/gigwa/res/menu.yml

genoring command drush cr
