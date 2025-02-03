#!/bin/sh

# Automatically exit on error.
set -e

# Add JBrowse menu item.
genoring add_menuitem /genoring/modules/jbrowse/res/menu.yml

genoring command drush cr
