#!/bin/sh

# Automatically exit on error.
set -e

# This is not properly a real container hook but it can be used as such for
# testing purposes and called using the command line:
#   perl genoring.pl -verbose containerhooks devtest your_module_name [0 args...]
# Note: before adding arguments, you must start with "0" (ie. the "related"
# parameter that is required but useless for a dev script, so set it to 0).
# See Genoring::ApplyContainerHooks() GenoRing Perl library function.

# To test a recipe:
genoring install_recipe modules/YOUR_MODULE_NAME/res/recipes/YOUR_MODULE_NAME_recipe GENORING_HOST GENORING_PORT
genoring uninstall_recipe modules/YOUR_MODULE_NAME/res/recipes/YOUR_MODULE_NAME_recipe
