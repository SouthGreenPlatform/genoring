#!/bin/sh

set -e

genoring uninstall_recipe modules/cas_server/res/recipes/genoring_cas_server_recipe
# We uninstall cas_server module as it is not supported by uninstall_recipe.
genoring command drush -y pm-uninstall cas_server
genoring command composer --no-interaction remove drupal/cas_server
