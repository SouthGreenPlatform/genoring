# Compile with:
#   docker build -t genoring .
FROM php:8.3-fpm-bookworm

LABEL net.genoring.image.authors="v.guignon@cgiar.org"

# Arguments.
ARG GENORING_UID=6305
ARG GENORING_GID=6305

# Environment.
ENV POSTGRES_HOST=db
ENV POSTGRES_PORT=5432
ENV POSTGRES_DRUPAL_DB=drupal
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD="G3noR!n&P0stGre"
ENV DRUPAL_VERSION=10
ENV DRUPAL_TRUSTED_HOST=""
ENV DRUPAL_USER=genoring
ENV DRUPAL_PASSWORD="G3noR!n&Drup@["
ENV DRUPAL_AUTO_UPDATE=1
ENV COMPOSER_HOME=/home/genoring/.composer
ENV HOME=/home/genoring
ENV PATH=${PATH}:/opt/drupal/vendor/bin:/opt/genoring
ENV PHP_INI_SCAN_DIR=:/opt/genoring/php

# Setup applications, libraries and PHP.
# Git might be used later in genoring script for automated updates and is still
# usefull when accessing the container shell.
# Postgresql is required by genoring script.
# vim is convenient when accessing the container shell.
# rsync, unzip, wget and zip are convenient when accessing the container shell.
#   They might be required and used by GenoRing modules hooks.
RUN set -eux; \
  apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    cron \
    git \
    postgresql \
    rsync \
    sendmail \
    unzip \
    vim \
    wget \
    zip; \
  savedAptMark="$(apt-mark showmanual)"; \
  apt-get install -y --no-install-recommends \
    libfreetype6-dev \
    libjpeg-dev \
    libpng-dev \
    libxpm-dev \
    libpq-dev \
    libwebp-dev \
    libavif-dev \
    libxml2-dev \
    libzip-dev \
    libc-client-dev \
    libkrb5-dev \
    libonig-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-avif --with-xpm \
  && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
  && docker-php-ext-install -j$(nproc) gd zip pdo pdo_mysql pdo_pgsql opcache mbstring exif imap \
  # reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies.
  && apt-mark auto '.*' > /dev/null \
  && apt-mark manual $savedAptMark; \
  ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
    | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
    | sort -u \
    | xargs -r dpkg-query -S \
    | cut -d: -f1 \
    | sort -u \
    | xargs -rt apt-mark manual; \
  apt-get purge -y libc-client-dev libkrb5-dev --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
  rm -rf /var/lib/apt/lists/*

# Add genoring user and group.
RUN groupadd -g ${GENORING_GID} genoring && useradd -u ${GENORING_UID} -g genoring -m -s /bin/bash genoring

# Allow apps to know they run into a Docker container.
RUN touch /.dockerenv

# APCu setup (upload progress).
RUN printf "\n" | pecl install apcu \
  && docker-php-ext-enable apcu \
  && pecl install uploadprogress \
  && docker-php-ext-enable uploadprogress \
  && pecl clear-cache

# Sendmail setup (completed by genoring script).
# Source: https://r.je/sendmail-php-docker
RUN printf "sendmail_path=/usr/sbin/sendmail -t -i\n" >> /usr/local/etc/php/conf.d/sendmail.ini; \
  printf "\ninclude(\`/etc/mail/tls/starttls.m4')dnl\n" >> /etc/mail/sendmail.mc; \
  printf "\ninclude(\`/etc/mail/tls/starttls.m4')dnl\n" >> /etc/mail/submit.mc

# PHP (recommended) settings.
# See https://secure.php.net/manual/en/opcache.installation.php
# The final php.ini file used will be created by the "genoring" script and put
# in "/opt/drupal/php/php.ini" by copying "$PHP_INI_DIR/php.ini-drupal". This
# will allow access to php.ini on a "/opt/drupal" exposed volume.
# Alternative: use "php.ini-development".
RUN { \
    printf "opcache.memory_consumption=128\n"; \
    printf "opcache.interned_strings_buffer=8\n"; \
    printf "opcache.max_accelerated_files=4000\n"; \
    printf "opcache.revalidate_freq=60\n"; \
  } > /usr/local/etc/php/conf.d/opcache-recommended.ini; \
  cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini-drupal" \
  && perl -pi -e 's/^max_execution_time\s*=.*/max_execution_time = 300/g' "$PHP_INI_DIR/php.ini-drupal" \
  && perl -pi -e 's/^max_input_time\s*=.*/max_input_time = 300/g' "$PHP_INI_DIR/php.ini-drupal" \
  && perl -pi -e 's/^memory_limit\s*=.*/memory_limit = 512M/g' "$PHP_INI_DIR/php.ini-drupal" \
  && perl -pi -e 's/^post_max_size\s*=.*/post_max_size = 256M/g' "$PHP_INI_DIR/php.ini-drupal" \
  && perl -pi -e 's/^upload_max_filesize\s*=.*/upload_max_filesize = 256M/g' "$PHP_INI_DIR/php.ini-drupal" \
  && ln -s /opt/drupal/php/php.ini "$PHP_INI_DIR/php.ini"

# Composer setup.
# Alternative: RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/

# Cron preparation.
RUN touch /etc/cron.d/drush-cron && chmod uog+w /etc/cron.d/drush-cron

# Copy Drupal GenoRing distribution and setup file structure.
COPY res /opt/genoring

# File system adjustments.
RUN mv /opt/genoring/genoring_sudoers /etc/sudoers.d/ \
    && chmod -R uog+rX,og-w /opt/genoring \
    && chmod uog+x,ugo-w /opt/genoring/genoring /opt/genoring/genoring_root.sh \
    && mkdir -p /opt/drupal \
    && chmod ug+rw /opt/drupal \
    && chown genoring:genoring /opt/drupal \
    && rm -rf /var/www/html \
    && ln -sf /opt/drupal/web /var/www/html

# Add permission to any user for a set of commands.

USER genoring:genoring
WORKDIR /opt/drupal

CMD ["/opt/genoring/genoring", "start"]
