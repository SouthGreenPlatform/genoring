#!/bin/sh

# Automatically exit on error.
set -e

# Add JBrowse menu item.
genoring remove_menuitem /genoring/modules/jbrowse/res/menu.yml

# Remove integration.
genoring remove_integration /genoring/modules/jbrowse/res/integration.yml

genoring command drush cr
