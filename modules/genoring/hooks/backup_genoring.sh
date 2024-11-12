#!/bin/sh

# $1 is supposed to contain the base name of the backup.
mkdir -p /backups/$1/genoring/
./vendor/drush/drush/drush sset system.maintenance_mode 1
./vendor/drush/drush/drush -y archive:dump --destination=/backups/$1/genoring/ --overwrite --exclude-code-paths=web/sites/default/db_settings.php
./vendor/drush/drush/drush sset system.maintenance_mode 0
