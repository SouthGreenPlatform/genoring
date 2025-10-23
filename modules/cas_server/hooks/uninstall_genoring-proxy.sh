#!/bin/sh

# Remove certificates.
rm -f /etc/nginx/genoring/ssl/${GENORING_HOST}.key
rm -f /etc/nginx/genoring/ssl/${GENORING_HOST}.crt
rmdir /etc/nginx/genoring/ssl

# Remove SSL config.
rm -f /etc/nginx/genoring/cas_server.conf
