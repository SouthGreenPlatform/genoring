#!/bin/sh
mkdir -p $JBROWSE_DATA/json/

# Start fastcgi wrap.
rm -f /var/run/fcgiwrap.socket
nohup fcgiwrap -s unix:/var/run/fcgiwrap.socket &
while ! [ -S /var/run/fcgiwrap.socket ]; do sleep .2; done
chown nginx:www-data /var/run/fcgiwrap.socket
test -f nohup.out && rm ./nohup.out

exec nginx -g "daemon off;"
