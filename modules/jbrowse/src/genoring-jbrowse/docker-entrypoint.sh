#!/bin/sh
if [ -d "/data/" ]; then
  for f in /data/*.sh;
  do
    [ -f "$f" ] && . "$f"
  done
fi

mkdir -p $JBROWSE_DATA/json/

exec nginx -g "daemon off;"
