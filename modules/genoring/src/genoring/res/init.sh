#!/bin/sh

cd /opt/drupal/

modules="tripal token geofield leaflet dbxschema external_entities xnttexif-xnttexif xnttjson xnttmanager xnttstrjp xntttsv xnttxml xnttyaml chadol gbif2 eu_cookie_compliance bibcite honeypot"
enabled_modules="token dbxschema_pgsql dbxschema_mysql chadol xnttjson xntttsv xnttxml xnttmanager layout_builder"

# Check if Drupal should be installed.
if [ ! -e ./web/index.php ]; then
  printf "Drupal downloads...\n"
  printf "* Downloading Drupal $DRUPAL_VERSION core...\n"
  composer create-project --no-interaction "drupal/recommended-project:$DRUPAL_VERSION" .
  mkdir private config
  chown -R www-data:www-data web/sites web/modules web/themes private config
  rm -rf /var/www/html && ln -sf /opt/drupal/web /var/www/html
  printf "   OK\n"

  printf "* Downloading Drupal extensions...\n"
  # Install Drupal extensions.
  composer config minimum-stability dev && composer -n require drush/drush
  # Disabled: "gigwa rdf_entity".
  composer -n require drupal/$(printf "$modules" | sed "s/ / drupal\//g")
  printf "   OK\n"
  # Setup cron.
  printf "* Setup Drupal cron...\n"
  printf "*/5 * * * * root /opt/drupal/vendor/bin/drush cron >> /var/log/cron.log 2>&1\n" > /etc/cron.d/drush-cron
  printf "   OK\n"
  printf "...Drupal downloads done.\n"
else
  printf "Drupal already downloaded.\n"
fi

# Check if the database is already initialized.
# Wait for database ready (3 minutes max).
printf "Waiting for database server to be ready...\n"
if [ ! -z "$POSTGRES_PASSWORD" ]; then
  # Update credential in case of change.
  printf "$POSTGRES_HOST:$POSTGRES_PORT:*:$POSTGRES_USER:$POSTGRES_PASSWORD\n" >~/.pgpass && chmod go-rwx ~/.pgpass
fi
loop_count=0
while ! pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" && [ "$loop_count" -lt 180 ]; do
  printf "."
  loop_count=$((loop_count + 1))
  sleep 1
done
if [ "$loop_count" -ge 180 ]; then
  >&2 printf "ERROR: Failed to wait for PostgreSQL database. Stopping here.\n"
  exit 1
fi
printf "...Database server seems ready.\n"
test_drupal_db=$( psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -XtAc "SELECT 1 FROM pg_database WHERE datname='$POSTGRES_DRUPAL_DB';" )
test_drupal_db_error=$?
if [ '1' = "$test_drupal_db" ]; then
  # Database already initialized.
  printf "Database already initialized.\n"
else
  if [ "$test_drupal_db_error" -ne 0 ]; then
    >&2 printf "ERROR: Failed to connect to PostgreSQL database. Stopping here.\n"
    exit 1
  fi
  # Initialize database...
  printf "Setup database...\n"
  # Setup PostgreSQL.
  psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" --command="CREATE DATABASE $POSTGRES_DRUPAL_DB WITH OWNER $POSTGRES_USER;"
  psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" "$POSTGRES_DRUPAL_DB" --command="CREATE EXTENSION pg_trgm;CREATE EXTENSION fuzzystrmatch;"
  printf "...database setup done.\n"

  printf "Setup Drupal...\n"
  if [ ! -s ./web/sites/default/settings.php ]; then
    printf "* settings.php\n"
    cp ./web/sites/default/default.settings.php ./web/sites/default/settings.php
    # Append some settings.
    printf "\n\$settings['config_sync_directory'] = '../config/sync';\n\$settings['file_private_path'] = '/opt/drupal/private/';\n\n" >>./web/sites/default/settings.php
    printf "\n\$settings['trusted_host_patterns'] = [\n" >>./web/sites/default/settings.php
    # We must not use "printf" for $DRUPAL_TRUSTED_HOST because it complicates
    # escaping in env file, especially for "\E".
    echo "$DRUPAL_TRUSTED_HOST" >>./web/sites/default/settings.php
    printf "];\n\n" >>./web/sites/default/settings.php
    # Append auto-include for external databases settings in "external_databases.php".
    printf "\n\nif (file_exists(\$app_root . '/' . \$site_path . '/external_databases.php')) {\n  include \$app_root . '/' . \$site_path . '/external_databases.php';\n}\n\n" >>./web/sites/default/settings.php
    printf "   OK\n"
  fi
  # Allow setting update by Drupal installation process.
  # Permissions will be automatically reset after installation.
  chmod uog+w ./web/sites/default/settings.php

  if [ ! -s ./web/sites/default/services.yml ]; then
    printf "* services.yml\n"
    cp ./web/sites/default/default.services.yml ./web/sites/default/services.yml
    # Enable and configure Drupal CORS to allow REST and token authentication...
    # - enabled: true
    perl -pi -e 'BEGIN{undef $/;} s/^(  cors.config:\s*\n(?:    [^\n]+\n|\s*\n|\s*#[^\n]*\n)*)    enabled:\s*false/$1    enabled: true/smig' ./web/sites/default/services.yml
    # - allowedHeaders: ['authorization','content-type','accept','origin','access-control-allow-origin','x-allowed-header']
    perl -pi -e 'BEGIN{undef $/;} s/^(  cors.config:\s*\n(?:\s*\n|    [^\n]+\n|    #[^\n]*\n)*)    allowedHeaders:[^\n]*/$1    allowedHeaders: ['"'"'authorization'"'"','"'"'content-type'"'"','"'"'accept'"'"','"'"'origin'"'"','"'"'access-control-allow-origin'"'"','"'"'x-allowed-header'"'"']/smig' ./web/sites/default/services.yml
    # - allowedMethods: ['*']
    perl -pi -e 'BEGIN{undef $/;} s/^(  cors.config:\s*\n(?:    [^\n]+\n|\s*\n|\s*#[^\n]*\n)*)    allowedMethods:[^\n]*/$1    allowedMethods: ['"'"'*'"'"']/smig' ./web/sites/default/services.yml
    printf "   OK\n"
  fi

  if [ ! -e ./web/sites/default/external_databases.php ]; then
    printf "* external_databases.php\n"
    cp /opt/genoring/external_databases.template.php ./web/sites/default/external_databases.php
    printf "   OK\n"
  fi

  # Install Drupal.
  printf "* initializing Drupal\n"
  ./vendor/drush/drush/drush -y site-install standard \
    --db-url=pgsql://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DRUPAL_DB \
    --account-mail="$DRUPAL_USER_MAIL" \
    --account-name="$DRUPAL_USER" \
    --account-pass="$DRUPAL_PASSWORD" \
    --site-mail="$DRUPAL_SITE_MAIL" \
    --site-name="$DRUPAL_SITE_NAME"
  printf "   OK\n"

  # Other config stuff.
  chown -R www-data:www-data ./web/sites/default/files
  chmod -R uog+w ./private ./config ./web/sites/default/files

  printf "...Drupal setup done.\n"

  printf "Setup Drupal extensions...\n"
  # Enable modules.
  for module in $enabled_modules; do
    ./vendor/drush/drush/drush -y pm-enable "$module"
  done
  printf "...Drupal extensions setup done.\n"

  printf "Setup GenoRing site...\n"
  cp /opt/genoring/logo-genoring.png /opt/drupal/web/sites/default/files/
  # ./vendor/drush/drush/drush config-import --partial --source=/opt/genoring/config/
  ./vendor/drush/drush/drush -y php:script /opt/genoring/init_site.php
  printf "...GenoRing site setup done.\n"

fi

printf "Process extensions scrips...\n"
if [ -d /opt/genoring/init/ ] && [ -z "$( find /opt/genoring/init/ -maxdepth 0 -type f -not -empty -name '*.sh' )" ]; then
  /opt/genoring/init/*.sh
fi
printf "..processing extensions scrips done.\n"

printf "Synchronizing host config...\n"
# Synchronize PHP config.
if [ ! -e ./php ] || [ ! -e ./php/php.ini ]; then
  # First time, copy PHP settings on a mountable volume.
  mkdir -p ./php
  cp "$PHP_INI_DIR/php.ini" ./php/php.ini
else
  # If (volume) Drupal php.ini exists, replace the system one with it.
  cp ./php/php.ini "$PHP_INI_DIR/php.ini"
fi
printf "... done synchronizing host.\n"

# Update Drupal and modules.
if [ "$DRUPAL_UPDATE" -gt 0 ]; then
  printf "Updating Drupal...\n"
  # Check if updates could run well.
  # @todo Maybe check free disk space as well?
  if composer update --with-all-dependencies --dry-run; then
    # Set Drupal offline.
    ./vendor/drush/drush/drush sset system.maintenance_mode TRUE
    # Backup DB.
    printf "...backup Drupal...\n"
    ./vendor/drush/drush/drush -y archive:dump --destination=/backups/preupdate_backup.tgz --overwrite
    printf "...backup done...\n"
    if [ $? -ne 0 ]; then
      printf "...FAILED to backup, aborting update.\n"
      exit 1
    fi
    if composer update --with-all-dependencies && ./vendor/drush/drush/drush -y updb; then
      printf "...Drupal update done.\n"
    else
      # Restore DB backup.
      printf "...Drupal update failed. Restoring...\n"
        ./vendor/drush/drush/drush -y archive:restore /backups/preupdate_backup.tgz
        rm -rf ./vendor
        composer update
      printf "...done restoring.\n"
    fi
    # Set Drupal back online.
    ./vendor/drush/drush/drush sset system.maintenance_mode FALSE
  fi
  if [ $DRUPAL_UPDATE -eq 2 ]; then
    # Update and stop.
    exit 0
  fi
fi

printf "Running PHP-fpm...\n"
# Launch PHP-fpm
php-fpm
printf "Stopping.\n"
