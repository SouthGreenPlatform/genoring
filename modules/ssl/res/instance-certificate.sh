#!/bin/sh

# Generates a self-signed certificate for a GenoRing managed instance host if
# missing or expired. Run in the proxy container with INSTANCE_HOST set.

if [ -z "$INSTANCE_HOST" ]; then
  echo "ERROR: Missing INSTANCE_HOST!" >&2
  exit 1
fi

CERT_FILE="/etc/ssl/certs/${INSTANCE_HOST}.crt"
KEY_FILE="/etc/ssl/private/${INSTANCE_HOST}.key"
if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ] || ! openssl x509 -checkend 0 -noout -in "$CERT_FILE" >/dev/null 2>&1; then
  rm -f "$KEY_FILE"
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/CN=${INSTANCE_HOST}" \
    -addext "subjectAltName=DNS:${INSTANCE_HOST}" \
    -addext "extendedKeyUsage=serverAuth,clientAuth" \
    -addext "keyUsage=digitalSignature,keyEncipherment"
  chmod 644 "$CERT_FILE"
  chmod 600 "$KEY_FILE"
fi

test -f "$CERT_FILE" && test -f "$KEY_FILE"
