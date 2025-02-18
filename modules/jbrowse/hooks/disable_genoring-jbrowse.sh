#!/bin/sh

# Automatically exit on error.
set -e

if [ -d /usr/local/www/.jbrowse-disabled ]; then
  rm -rf /usr/local/www/jbrowse
elif [ -d /usr/local/www/jbrowse ]; then
  mv /usr/local/www/jbrowse  /usr/local/www/.jbrowse-disabled
fi
