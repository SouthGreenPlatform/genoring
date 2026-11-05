#!/bin/sh

# HTTPS host (the port is only specified when it is not the default HTTPS one).
# Note: SSL_PORT is provided by the ssl module environment file.
SSL_PORT="${SSL_PORT:-443}"
if [ "$SSL_PORT" = "443" ]; then
  GENORING_SSL_HOST="$GENORING_HOST"
else
  GENORING_SSL_HOST="$GENORING_HOST:$SSL_PORT"
fi
export GENORING_SSL_HOST

# Expand GenoRing host environment variables in recipe and install recipe.
genoring install_recipe modules/cas_server/res/recipes/genoring_cas_server_recipe GENORING_HOST,GENORING_PORT,GENORING_SSL_HOST
