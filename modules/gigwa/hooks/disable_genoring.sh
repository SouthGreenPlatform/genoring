#!/bin/sh

# Automatically exit on error.
set -e

genoring uninstall_recipe modules/gigwa/res/recipes/gigwa_recipe
genoring uninstall_recipe modules/gigwa/res/recipes/gigwa_embeded_recipe
# We uninstall gigwa module as it is not supported by uninstall_recipe.
# genoring command drush -y pm-uninstall gigwa
# genoring command composer --no-interaction remove drupal/gigwa
