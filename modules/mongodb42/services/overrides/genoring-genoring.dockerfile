# Compile with:
#   docker build -t genoring-mongodb42 .
FROM genoring

LABEL net.genoring.image.authors="v.guignon@cgiar.org"

# MongoDB PHP extension (ext-mongodb) used by Drupal modules relying on
# mongodb/mongodb (the PHP library), which requires this extension.
# Since ext-mongodb 1.17, pecl prompts for configure options; piping an empty
# line accepts the defaults (same trick as for apcu in the base image).
RUN set -eux \
  && printf "\n\n\n" | pecl install mongodb \
  && docker-php-ext-enable mongodb \
  && pecl clear-cache \
  && php -m | grep -i mongodb
