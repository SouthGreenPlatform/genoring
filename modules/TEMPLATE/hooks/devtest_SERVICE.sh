#!/bin/sh

# Automatically exit on error.
set -e

# This is not properly a real container hook but it can be used as such for
# testing purposes and called using the command line:
#   perl genoring.pl -verbose containerhooks devtest your_module_name [0 args...]
# Note: before adding arguments, you must start with "0" (ie. the "related"
# parameter that is required but useless for a dev script, so set it to 0).
# See Genoring::ApplyContainerHooks() GenoRing Perl library function.

# To test a menu item:
genoring remove_menuitem /genoring/modules/your_module_name/res/menu.yml
genoring add_menuitem /genoring/modules/your_module_name/res/menu.yml

# To test an integration:
genoring remove_integration /genoring/modules/your_module_name/res/integration.yml
genoring add_integration /genoring/modules/your_module_name/res/integration.yml

# Refresh Drupal cache.
genoring command drush cr
