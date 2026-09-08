#!/usr/bin/env perl

# This hook is a PERL script that is called on the local server running the
# GenoRing system (and the dockers) when a module needs to upgrade itself to its
# latest version.
# It is run from GenoRing base directory.
# It is normally called when all GenoRing dockers are down before any update is
# performed by container update hooks.
# Parameters are: current version string, and new version string.

use strict;
use warnings;
use lib "$ENV{'GENORING_DIR'}/perllib";
use Genoring;

++$|; #no buffering

# Perform the module's upgrade tasks on the local file system.


# @todo Implement upgrade for genoring-db from 1.0 to 1.1.

# Manual procedure:
# sudo mv volumes/db/pgdata/pgdata volumes/data/pgdata.16
# sudo chown 999 volumes/db/pgdata
# sudo mv volumes/db/pgdata volumes/db/data
# export GENORING_VOLUMES_DIR=$PWD/volumes
# docker run --rm --name pg_upgrade_temp --env-file env/genoring_db.env -v ${GENORING_VOLUMES_DIR}/data:/data -v ${GENORING_VOLUMES_DIR}/data/pgdata.16:/var/lib/postgresql/data/pgdata -d postgis/postgis:16-3.5
# docker exec -t  pg_upgrade_temp  bash -c 'pg_dumpall -U postgres > /data/v16.sql'
# docker stop pg_upgrade_temp
# # Build new genoring-db image.
# ./genoring.pl build genoring genoring-db --no-cache
# docker run --rm --name pg_upgrade_temp --env-file env/genoring_db.env -v ${GENORING_VOLUMES_DIR}/data:/data -v ${GENORING_VOLUMES_DIR}/db/data:/var/lib/postgresql -d genoring-db
# docker exec -t  pg_upgrade_temp  bash -c 'psql -U postgres -f /data/v16.sql'
# docker stop pg_upgrade_temp

# # Now we need to make sure pg_hba.conf contains or ends with the appropriate
# # stuff. Maybe, copy previous version (in case of orther modifications)?
# ----------
# host all all all scram-sha-256
# ----------

# Returns 1 when called by "require".
1;
