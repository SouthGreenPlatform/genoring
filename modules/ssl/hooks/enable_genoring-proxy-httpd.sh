#!/bin/sh

CERT_FILE="/etc/ssl/certs/${GENORING_HOST}.crt"
KEY_FILE="/etc/ssl/private/${GENORING_HOST}.key"
if [ ! -f "$CERT_FILE" ] || ! openssl x509 -checkend 0 -noout -in "$CERT_FILE" >/dev/null 2>&1; then
  mkdir -p /etc/ssl/certs /etc/ssl/private
  rm -f "$KEY_FILE"
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
# Note: it is an "includes" file (and not a "genoring" one) as Apache HTTPd
# needs a dedicated virtual host for HTTPS. Its name makes it included before
# managed instance configs so the main site is the default HTTPS virtual host.
CONF_FILE="/usr/local/apache2/conf/includes/genoring-ssl.conf"
if [ ! -f "$CONF_FILE" ]; then
  # SSL_PORT is provided by the instance environment (env/ssl_ssl.env).
  SSL_PORT="${SSL_PORT:-443}"
  sed -e "s/\${SSL_PORT}/${SSL_PORT}/g" -e "s/\${GENORING_HOST}/${GENORING_HOST}/g" \
    /genoring/modules/ssl/res/httpd/ssl.template > $CONF_FILE
fi
