#!/bin/sh

# Automatically exit on error.
set -e

if [ -z $GIGWA_DIRECT_ACCESS ] || [ $GIGWA_DIRECT_ACCESS -eq 0 ]; then
  genoring install_recipe modules/gigwa/res/recipes/gigwa_embeded_recipe
fi

genoring install_recipe modules/gigwa/res/recipes/gigwa_recipe
