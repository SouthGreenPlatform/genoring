#!/bin/sh

# Expand GENORING_HOST environment variable in recipe and install recipe.
genoring install_recipe modules/cas_server/res/recipes/genoring_cas_server_recipe GENORING_HOST,GENORING_PORT
