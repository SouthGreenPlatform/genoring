#!/bin/sh

# Automatically exit on error.
set -e


genoring uninstall_recipe modules/jbrowse/res/recipes/genoring_jbrowse_recipe
# We uninstall genoring_jbrowse module has it is not supported by uninstall_recipe.
genoring command drush -y pm-uninstall genoring_jbrowse
