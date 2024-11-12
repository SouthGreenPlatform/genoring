#!/bin/sh

# $1 is supposed to contain the base name of the backup.
# Set maintenance mode.
drush sset system.maintenance_mode 1
# First we extract backuped source code of Drupal in a different directory to
# avoid removing libraries used by Drush for this opeation.
drush -y archive:restore --code --overwrite --destination-path /opt/drupal_res /backups/$1/genoring/archive.tar.gz
# Then we copy restored files to current Drupal and remove restore temp dir.
cp -R /opt/drupal_res/* /opt/drupal
rm -rf /opt/drupal_res
# We update the composer libraries.
composer update
# Now we restore the rest (database and files).
drush -y archive:restore  --db --files --overwrite /backups/$1/genoring/archive.tar.gz
# We need to rebuild the cache.
drush cr
# Done. Remove maintenance mode.
drush sset system.maintenance_mode 0
