#!/bin/sh

# mkdir -p /etc/nginx/genoring/ssl
# chmod 750 /etc/nginx/genoring/ssl
# Generate certificates if missing or expired.
# CERT_FILE="/etc/nginx/genoring/ssl/${GENORING_HOST}.crt"
# KEY_FILE="/etc/nginx/genoring/ssl/${GENORING_HOST}.key"
CERT_FILE="/etc/ssl/certs/${GENORING_HOST}.crt"
KEY_FILE="/etc/ssl/private/${GENORING_HOST}.key"
if [ ! -f "$CERT_FILE" ] || [ ! openssl x509 -checkend 0 -noout -in "$CERT_FILE" 2>/dev/null ]; then
  rm -f $KEY_FILE
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/CN=${GENORING_HOST}" \
    -addext "subjectAltName=DNS:${GENORING_HOST}" \
    -addext "extendedKeyUsage=serverAuth,clientAuth" \
    -addext "keyUsage=digitalSignature,keyEncipherment"
  chmod 644 "$CERT_FILE"
  chmod 600 "$KEY_FILE"
fi

# Generate SSL config if missing.
CONF_FILE="/etc/nginx/genoring/cas_server.conf"
if [ ! -f "$CONF_FILE" ]; then
  . /genoring/modules/cas_server/env/cas_server_cas_server.env
  envsubst < /genoring/modules/cas_server/res/nginx/cas_server.template > $CONF_FILE
fi
