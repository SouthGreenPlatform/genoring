#!/bin/sh

CONFIG_FILE="/usr/local/tomcat/webapps/gigwa/WEB-INF/classes/config.properties"

# Function to update a given Gigwa config file setting.
update_property() {
  local key="$1"
  local value="$2"
  # Uncomment line if there, and set value.
  if grep -q "^#* *${key} *=" "$CONFIG_FILE"; then
    sed -i -E "s/^#* *${key} *=.*/${key} = ${value}/" "$CONFIG_FILE"
  else
    # Otherwise, append value.
    printf "\n${key} = ${value}\n" >> "$CONFIG_FILE"
  fi
}

# Add SSL certificate...
# - Get certificate.
openssl s_client -connect ${GENORING_HOST}:443 -showcerts </dev/null 2>/dev/null \
  | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' \
  > /usr/local/share/ca-certificates/genoring.crt
# - Update OpenSSL registry.
update-ca-certificates
# - Update Java certificates.
keytool -import -cacerts -alias genoring_ca -file /usr/local/share/ca-certificates/genoring.crt -storepass changeit -noprompt

# Update Gigwa config.
update_property "enforcedWebapRootUrl" "https://${GENORING_HOST}/gigwa"
update_property "casServerURL" "https://${GENORING_HOST}/cas"
update_property "casOrganization" "GenoRing"
