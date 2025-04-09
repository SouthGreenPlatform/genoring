#!/bin/sh

# Automatically exit on error.
set -e

mkdir -p /data/jbrowse
chown -R genoring:genoring /data/jbrowse
if [ -d /usr/local/www/.jbrowse-disabled ]; then
  mv /usr/local/www/.jbrowse-disabled  /usr/local/www/jbrowse
elif [ ! -d /usr/local/www/jbrowse ]; then
  mkdir -p /usr/local/www
  cp -r /opt/jbrowse  /usr/local/www/jbrowse
  chown -R genoring:genoring /usr/local/www/jbrowse
  ln -nfs /data/jbrowse /usr/local/www/jbrowse/data
fi

