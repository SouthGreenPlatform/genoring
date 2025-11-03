#!/bin/sh

genoring uninstall_recipe modules/brapimapper/res/recipes/brapimapper_recipe
# We uninstall BrAPI module as it is not supported by uninstall_recipe.
genoring command drush -y pm-uninstall brapi
genoring command composer --no-interaction remove drupal/brapi
