This directory is the best place to hold NGINX configs for a given GenoRing
module.

You may store configs that should be included in genoring proxy as part of the
genoring server instructions; such configs should be copied by the init.pl and
enable.pl hooks (and removed by disable.pl hook) into the
"$ENV{'GENORING_VOLUMES_DIR'}/proxy/nginx/genoring/" directory.

You may also store config for separate HTTP services with "server" instructions;
such configs should be copied by the init.pl and enable.pl hooks (and removed by
disable.pl hook) into the "$ENV{'GENORING_VOLUMES_DIR'}/proxy/nginx/includes/"
directory.

If you need to use environment variables in your NGINX config, you will need to
generate the final config files using the "envsubst" tool. See "brapimapper"
module for an example.
