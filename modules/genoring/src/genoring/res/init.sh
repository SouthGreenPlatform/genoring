#!/bin/bash

# Automatically exit on error.
set -e

cd /opt/drupal/

modules=(
  "tripal"
  "brapi"
  "token"
  "geofield"
  "leaflet"
  "dbxschema"
  "imagecache_external"
  "external_entities"
  "xnttdb"
  "xnttbrapi"
  "xnttfiles"
  "xnttexif-xnttexif"
  "xnttjson"
  "xnttmanager"
  "xnttmulti"
  "xnttstrjp"
  "xntttsv"
  "xnttxml"
  "xnttyaml"
  "chadol"
  "gbif2"
  "xnttviews"
  "eu_cookie_compliance"
  "bibcite"
)
enabled_modules=(
  "token"
  "imagecache_external"
  "dbxschema_pgsql"
  "dbxschema_mysql"
  "xnttdb"
  "chadol"
  "xnttjson"
  "xntttsv"
  "xnttxml"
  "xnttmanager"
  "xnttmulti"
  "xnttbrapi"
  "brapi"
  "layout_builder"
)

# Check if Drupal should be installed.
if [ ! -e ./web/index.php ]; then
  echo "Drupal downloads..."
  echo "* Downloading Drupal $DRUPAL_VERSION core..."
	composer create-project --no-interaction "drupal/recommended-project:$DRUPAL_VERSION" .
  mkdir private config
	chown -R www-data:www-data web/sites web/modules web/themes private config
	rmdir /var/www/html
	ln -sf /opt/drupal/web /var/www/html
  echo "   OK"

  echo "* Downloading Drupal extensions..."
  # Install Drupal extensions.
  composer config minimum-stability dev && composer -n require drush/drush
  # Disabled: "gigwa rdf_entity".
  composer -n require $(printf "drupal/%s " "${modules[@]}")
  echo "   OK"
  # Setup cron.
  echo "* Setup Drupal cron..."
  echo "*/5 * * * * root /opt/drupal/vendor/bin/drush cron >> /var/log/cron.log 2>&1" > /etc/cron.d/drush-cron
  echo "   OK"
  echo "...Drupal downloads done."
else
  echo "Drupal already downloaded."
fi

# Check if the database is already initialized.
# Wait for database ready (3 minutes max).
echo "Waiting for database server to be ready..."
loop_count=0
while ! pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER && [[ "$loop_count" -lt 180 ]]; do
  echo -n "."
  loop_count=$((loop_count+1))
  sleep 1
done
if [[ "$loop_count" -ge 180 ]]; then
  >&2 echo "ERROR: Failed to wait for PostgreSQL database. Stopping here."
  exit 1
fi
echo "...Database server seems ready."

if [ "$( psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -XtAc "SELECT 1 FROM pg_database WHERE datname='$POSTGRES_DRUPAL_DB';" )" = '1' ]; then
  # Database already initialized.
  echo "Database already initialized."
else
  # Initialize database...
  echo "Setup database..."
  # Setup PostgreSQL.
  psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER --command="CREATE DATABASE $POSTGRES_DRUPAL_DB WITH OWNER $POSTGRES_USER;"
  psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_DRUPAL_DB --command="CREATE EXTENSION pg_trgm;CREATE EXTENSION fuzzystrmatch;"
  echo "...database setup done."

  echo "Setup Drupal..."
  if [ ! -s ./web/sites/default/settings.php ]; then
    echo "* settings.php"
    cp ./web/sites/default/default.settings.php ./web/sites/default/settings.php
    # Append some settings.
    echo -e "\n\$settings['config_sync_directory'] = '../config/sync';\n\$settings['file_private_path'] = '/opt/drupal/private/';\n" >>./web/sites/default/settings.php
    echo -e "\n\$settings['trusted_host_patterns'] = [$DRUPAL_TRUSTED_HOST];\n" >>./web/sites/default/settings.php
    # Append auto-include for external databases settings in "external_databases.php".
    echo -e "\n\nif (file_exists(\$app_root . '/' . \$site_path . '/external_databases.php')) {\n  include \$app_root . '/' . \$site_path . '/external_databases.php';\n}\n" >>./web/sites/default/settings.php
    echo "   OK"
  fi
  # Allow setting update by Drupal installation process.
  # Permissions will be automatically reset after installation.
  chmod uog+w ./web/sites/default/settings.php

  if [ ! -s ./web/sites/default/services.yml ]; then
    echo "* services.yml"
    cp ./web/sites/default/default.services.yml ./web/sites/default/services.yml
    # Enable and configure Drupal CORS to allow REST and token authentication...
    # - enabled: true
    perl -pi -e 'BEGIN{undef $/;} s/^(  cors.config:\s*\n(?:    [^\n]+\n|\s*\n|\s*#[^\n]*\n)*)    enabled:\s*false/$1    enabled: true/smig' ./web/sites/default/services.yml
    # - allowedHeaders: ['authorization','content-type','accept','origin','access-control-allow-origin','x-allowed-header']
    perl -pi -e 'BEGIN{undef $/;} s/^(  cors.config:\s*\n(?:\s*\n|    [^\n]+\n|    #[^\n]*\n)*)    allowedHeaders:[^\n]*/$1    allowedHeaders: ['"'"'authorization'"'"','"'"'content-type'"'"','"'"'accept'"'"','"'"'origin'"'"','"'"'access-control-allow-origin'"'"','"'"'x-allowed-header'"'"']/smig' ./web/sites/default/services.yml
    # - allowedMethods: ['*']
    perl -pi -e 'BEGIN{undef $/;} s/^(  cors.config:\s*\n(?:    [^\n]+\n|\s*\n|\s*#[^\n]*\n)*)    allowedMethods:[^\n]*/$1    allowedMethods: ['"'"'*'"'"']/smig' ./web/sites/default/services.yml
    echo "   OK"
  fi

  if [ ! -e ./web/sites/default/external_databases.php ]; then
    echo "* external_databases.php"
    cp /opt/resources/external_databases.template.php ./web/sites/default/external_databases.php
    echo "   OK"
  fi

  # Install Drupal.
  echo "* initializing Drupal"
  ./vendor/drush/drush/drush -y site-install standard \
    --db-url=pgsql://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DRUPAL_DB \
    --account-mail="$DRUPAL_USER_MAIL" \
    --account-name="$DRUPAL_USER" \
    --account-pass="$DRUPAL_PASSWORD" \
    --site-mail="$DRUPAL_SITE_MAIL" \
    --site-name="$DRUPAL_SITE_NAME"
  echo "   OK"

  # Other config stuff.
  chown -R www-data:www-data ./web/sites/default/files
  chmod -R uog+w ./private ./config ./web/sites/default/files

  echo "...Drupal setup done."

  echo "Setup Drupal extensions..."
  # Enable modules.
  ./vendor/drush/drush/drush -y pm-enable "${enabled_modules[@]}"
  echo "...Drupal extensions setup done."

  echo "Setup GenoRing site..."
  ./vendor/drush/drush/drush -y php:script /opt/resources/init_site.php
  echo "...GenoRing site setup done."

fi

echo "Process extensions scrips..."
if [ -d /opt/genoring/init/ && -z "$( find /opt/genoring/init/ -maxdepth 0 -type f -not -empty -name '*.sh' )" ]; then
  /opt/genoring/init/*.sh
fi
echo "..processing extensions scrips done."

echo "Synchronizing host config..."
# Synchronize PHP config.
if [[ ! -e ./php ]] || [[ ! -e ./php/php.ini ]]; then
  # First time, copy PHP settings on a mountable volume.
  mkdir -p ./php
  cp "$PHP_INI_DIR/php.ini" ./php/php.ini
else
  # If (volume) Drupal php.ini exists, replace the system one with it.
  cp ./php/php.ini "$PHP_INI_DIR/php.ini"
fi
echo "... done synchronizing host."

# Update Drupal and modules.
if [ $DRUPAL_UPDATE -gt 0 ]; then
  echo "Updating Drupal..."
  # @todo Set Drupal offline.
  # @todo Backup DB and restore if errors.
  composer update --with-all-dependencies
  ./vendor/drush/drush/drush -y updb
  # @todo Set Drupal online.
  echo "...Drupal update done."
  if [ $DRUPAL_UPDATE -eq 2 ]; then
    # Update and stop.
    exit 0;
  fi
fi

echo "Running PHP-fpm..."
# Launch PHP-fpm
php-fpm
echo "Stopping."
