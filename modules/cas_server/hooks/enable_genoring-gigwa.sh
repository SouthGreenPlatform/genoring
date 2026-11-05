#!/bin/sh

# Enables CAS service on Gigwa and add the appropriate certificates to Gigwa
# host.

CONFIG_FILE="/usr/local/tomcat/config/config.properties"

# HTTPS host (the port is only specified when it is not the default HTTPS one).
# Note: SSL_PORT is provided by the ssl module environment file.
SSL_PORT="${SSL_PORT:-443}"
if [ "$SSL_PORT" = "443" ]; then
  GENORING_SSL_HOST="$GENORING_HOST"
else
  GENORING_SSL_HOST="$GENORING_HOST:$SSL_PORT"
fi

# Function to update a given Gigwa config file setting.
update_property() {
  key="$1"
  value="$2"
  # Uncomment line if there, and set value.
  if grep -q "^#* *${key} *=" "$CONFIG_FILE"; then
    sed -i -E "s~^#* *${key} *=.*~${key} = ${value}~" "$CONFIG_FILE"
  else
    # Otherwise, append value.
    printf '\n%s = %s\n' "$key" "$value" >> "$CONFIG_FILE"
  fi
}

# Update Gigwa config.
update_property "enforcedWebapRootUrl" "https://${GENORING_SSL_HOST}/gigwa"
update_property "casServerURL" "https://${GENORING_SSL_HOST}/cas"
update_property "casOrganization" "GenoRing"

# Add SSL certificate...
# - Get certificate.
openssl s_client -connect "${GENORING_HOST}:${SSL_PORT}" -showcerts </dev/null 2>/dev/null \
  | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' \
  > /usr/local/share/ca-certificates/genoring.crt
# - Update OpenSSL registry.
update-ca-certificates
# - Update Java certificates (replace any previous GenoRing certificate).
keytool -delete -cacerts -alias genoring_ca -storepass changeit -noprompt >/dev/null 2>&1 || true
keytool -import -cacerts -alias genoring_ca -file /usr/local/share/ca-certificates/genoring.crt -storepass changeit -noprompt

