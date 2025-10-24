#!/bin/sh

# Remove SSL config.
rm -f /etc/nginx/genoring/ssl.conf

# Remove certificates.
rm -f /etc/ssl/private/${GENORING_HOST}.key
rm -f /etc/ssl/certs/${GENORING_HOST}.crt
