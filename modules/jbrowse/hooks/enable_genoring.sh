#!/bin/sh

# Automatically exit on error.
set -e

# Add integration.
genoring add_integration /genoring/modules/jbrowse/res/integration.yml

# Add JBrowse menu item.
genoring add_menuitem /genoring/modules/jbrowse/res/menu.yml

# Add JBrowse module.
genoring install_module genoring_jbrowse

genoring command drush cr
