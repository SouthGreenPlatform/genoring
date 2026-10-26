# Compile with:
#   docker build -t genoring -f  genoring-genoring.dockerfile .
FROM genoring

LABEL net.genoring.image.authors="v.guignon@cgiar.org"

# Switch to root for installation.
USER root

# MongoDB PHP extension (ext-mongodb) used by Drupal modules relying on
# mongodb/mongodb (the PHP library), which requires this extension.
# Since ext-mongodb 1.17, pecl prompts for configure options; piping an empty
# line accepts the defaults (same trick as for apcu in the base image).
RUN set -eux \
  && apt-get update \
  && apt-get install -y --no-install-recommends libssl-dev \
  && rm -rf /var/lib/apt/lists/* \
  && printf "\n\n\n" | pecl install --configureoptions='with-mongodb-ssl="openssl"' mongodb \
  && docker-php-ext-enable mongodb \
  && pecl clear-cache \
  && php --ri mongodb | grep -i -E 'SSL.*enabled'

# Switch back to genoring user.
USER genoring:genoring
