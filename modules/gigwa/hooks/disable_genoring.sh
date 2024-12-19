#!/bin/sh

# Automatically exit on error.
set -e

# Enable Gigwa module.
# genoring uninstall_module gigwa

# Remove Gigwa menu item.
genoring remove_menuitem /genoring/modules/gigwa/res/menu.yml

# Remove integration.
genoring remove_integration /genoring/modules/gigwa/res/integration.yml

genoring command drush cr
