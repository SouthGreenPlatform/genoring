#!/bin/sh

mkdir -p /etc/nginx/genoring/ssl
chmod 750 /etc/nginx/genoring/ssl
# Generate certificates if missing or expired.
CERT_FILE="/etc/nginx/genoring/ssl/${NGINX_HOST}.crt"
if [ ! -f "$CERT_FILE" ] || [ ! openssl x509 -checkend 0 -noout -in "$CERT_FILE" 2>/dev/null ]; then
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/genoring/ssl/${NGINX_HOST}.key \
    -out "$CERT_FILE" \
    -subj "/CN=${NGINX_HOST}"
  chmod 644 /etc/nginx/genoring/ssl/${NGINX_HOST}.crt
  chmod 600 /etc/nginx/genoring/ssl/${NGINX_HOST}.key
fi

# Generate SSL config if missing.
CONF_FILE="/etc/nginx/genoring/cas_server.conf"
if [ ! -f "$CONF_FILE" ]; then
  . /genoring/modules/cas_server/env/cas_server.env
  envsubst < /genoring/modules/cas_server/res/nginx/cas_server.template > $CONF_FILE
fi
