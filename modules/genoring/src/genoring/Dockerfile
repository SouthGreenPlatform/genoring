# genoring4.0.0beta3-drupal10.1.2-php8.2-fpm-bookworm
# Compile with:
# docker build -t genoring .
# docker build -t genoring4.0.0beta3-drupal10.1.2-php8.2-fpm-bookworm .
FROM php:8.2-fpm-bookworm

LABEL net.genoring.image.authors="v.guignon@cgiar.org"

# Environment
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
# https://github.com/docker-library/drupal/pull/259
# https://github.com/moby/buildkit/issues/4503
# https://github.com/composer/composer/issues/11839
# https://github.com/composer/composer/issues/11854
# https://github.com/composer/composer/blob/94fe2945456df51e122a492b8d14ac4b54c1d2ce/src/Composer/Console/Application.php#L217-L218
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_HOME=/root/.composer
ENV PATH=${PATH}:/opt/drupal/vendor/bin

# Setup libraries and PHP
RUN set -eux; \
  savedAptMark="$(apt-mark showmanual)"; \
  apt-get update && apt-get install -y --no-install-recommends \
    libfreetype6-dev \
    libjpeg-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libpq-dev \
    libwebp-dev \
    libxml2-dev \
    libzip-dev \
    libc-client-dev \
    libkrb5-dev \
    libonig-dev \
    zip \
    unzip \
    git \
    wget \
    rsync \
    vim \
    sendmail \
    postgresql \
  && docker-php-ext-install -j$(nproc) gd zip pdo pdo_mysql pdo_pgsql opcache mbstring exif imap \
  && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-avif --with-xpm \
  && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
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

# APCu setup
RUN printf "\n" | pecl install apcu \
  && docker-php-ext-enable apcu \
  && pecl install uploadprogress \
  && docker-php-ext-enable uploadprogress \
  && pecl clear-cache

# Sendmail setup
# Source: https://r.je/sendmail-php-docker
RUN echo "sendmail_path=/usr/sbin/sendmail -t -i" >> /usr/local/etc/php/conf.d/sendmail.ini \
  && sed -i '/#!\/bin\/sh/aservice sendmail restart' /usr/local/bin/docker-php-entrypoint \
  && sed -i '/#!\/bin\/sh/aecho "$(hostname -i)\t$(hostname) $(hostname).localhost" >> /etc/hosts' /usr/local/bin/docker-php-entrypoint

# PostgeSQL access setup
RUN echo "$POSTGRES_HOST:$POSTGRES_PORT:*:$POSTGRES_USER:$POSTGRES_PASSWORD" >~/.pgpass \
  && chmod go-rwx ~/.pgpass

# PHP (recommended) settings
# See https://secure.php.net/manual/en/opcache.installation.php
RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=60'; \
  } > /usr/local/etc/php/conf.d/opcache-recommended.ini; \
  cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
  && perl -pi -e 's/^max_execution_time\s*=.*/max_execution_time = 300/g' "$PHP_INI_DIR/php.ini" \
  && perl -pi -e 's/^max_input_time\s*=.*/max_input_time = 300/g' "$PHP_INI_DIR/php.ini" \
  && perl -pi -e 's/^memory_limit\s*=.*/memory_limit = 512M/g' "$PHP_INI_DIR/php.ini" \
  && perl -pi -e 's/^post_max_size\s*=.*/post_max_size = 256M/g' "$PHP_INI_DIR/php.ini" \
  && perl -pi -e 's/^upload_max_filesize\s*=.*/upload_max_filesize = 256M/g' "$PHP_INI_DIR/php.ini"

# Composer setup
# Alternative: RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/

# Drupal pre-setup
COPY ./res /opt/genoring
RUN chmod u+rx /opt/genoring/init.sh
RUN mkdir -p /opt/drupal
WORKDIR /opt/drupal

CMD ["/opt/genoring/init.sh"]
