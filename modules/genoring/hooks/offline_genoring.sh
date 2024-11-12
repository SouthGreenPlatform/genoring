#!/bin/sh

# Automatically exit on error.
set -e

# Set offline mode by copying offline file.
mkdir -p /opt/drupal/web/
if test -f /opt/offline/offline.html; then
  printf 'Set site offline.\n'
  cp /opt/offline/offline.html /opt/drupal/web/offline.html
else
  printf 'Offline file not found, using an empty one.\n'
  # Create a default empty file.
  printf '<!DOCTYPE html>\n<html>\n<head>\n<title>GenoRing - Site under maintenance</title>\n</head>\n<body>\n<h1>GenoRing - Site under maintenance</h1>\n</body>\n</html>\n' > /opt/drupal/web/offline.html
fi
