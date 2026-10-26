#!/bin/sh

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
CONF_FILE="/etc/nginx/genoring/ssl.conf"
if [ ! -f "$CONF_FILE" ]; then
  . /genoring/modules/ssl/env/ssl.env
  envsubst < /genoring/modules/ssl/res/nginx/ssl.template > $CONF_FILE
fi
