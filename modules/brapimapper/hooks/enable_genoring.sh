#!/bin/sh

composer -n require drupal/brapi
drush -y pm-enable brapi
