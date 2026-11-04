#!/bin/sh

# Disables CAS service on Gigwa and removes the GenoRing certificates added to
# Gigwa host by the enable_genoring-gigwa.sh hook.

CONFIG_FILE="/usr/local/tomcat/config/config.properties"

# Comment out CAS-related Gigwa config settings.
if [ -f "$CONFIG_FILE" ]; then
  for key in enforcedWebapRootUrl casServerURL casOrganization; do
    sed -i -E "s~^ *(${key} *=)~#\1~" "$CONFIG_FILE"
  done
fi

# Remove SSL certificate...
# - Remove Java certificate.
keytool -delete -cacerts -alias genoring_ca -storepass changeit -noprompt >/dev/null 2>&1 || true
# - Update OpenSSL registry.
if [ -f /usr/local/share/ca-certificates/genoring.crt ]; then
  rm -f /usr/local/share/ca-certificates/genoring.crt
  update-ca-certificates --fresh
fi
