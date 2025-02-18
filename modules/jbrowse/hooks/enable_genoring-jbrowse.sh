#!/bin/sh

# Automatically exit on error.
set -e

mkdir -p /data/jbrowse
if [ -d /usr/local/www/.jbrowse-disabled ]; then
  mv /usr/local/www/.jbrowse-disabled  /usr/local/www/jbrowse
elif [ ! -d /usr/local/www/jbrowse ]; then
  mkdir -p /usr/local/www
  cp -r /opt/jbrowse  /usr/local/www/jbrowse
fi

