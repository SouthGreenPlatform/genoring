# AGENTS.md

## Services

The `genoring` module provides a web interface based on Drupal through 3
services:

- `genoring`, which contains the Drupal code part run by a PHP-FPM service;
- `genoring-proxy`, which contains the HTTP proxy part provided by an nginx
  service;
- `genoring-db`, which contains the Drupal database part run by a PostgreSQL
  service.

## `genoring` service

The `genoring` service provides a PHP-FPM service that serves Drupal. It is
used by the `genoring-proxy` service to expose Drupal through HTTP. The Docker
image is based on an official PHP-FPM image with a Debian release. It has a set
of pre-installed packages which includes PostgreSQL and MariaDB clients, as
well as mail tools, cron job handling, and Drupal utilities (Composer, Drush),
amongst others. It provides a `genoring` script that is used to manage Drupal
internally: database check, directory setup, installation, update, backups,
Drupal recipe deployment, etc.

The `genoring` script is documented and designed to use generic commands, to
enable the possibility to provide an alternative service that could use a
different CMS, while supporting the same functionalities with the same syntax.
Therefore, other GenoRing modules that need to integrate with the CMS should
use that script in container hooks (rather than using Composer or Drush
directly), to allow alternatives to handle them.
See the "GenoRing core API" section of DEVEL.md for details.

### Drupal

Drupal is installed in the exposed volume directory `volumes/drupal/`. An
additional directory, `volumes/drupal/php/`, contains PHP and Drush
configuration files, to allow easy and persistent user customizations.

It is possible to run `composer` from the Drupal exposed volume directory on
the host system, but this is discouraged because the elements available on the
host may differ from the ones in the container (the PHP version, for
instance), which may lead to inconsistencies.

## `genoring-proxy` service

The proxy service is based on nginx. An alternative based on Apache HTTPd is
provided. The nginx proxy uses a main configuration file, `genoring-fpm.conf`,
stored in the exposed volume directory `volumes/proxy/nginx/`.

Two subdirectories allow other modules to use the proxy in 2 ways:

- the `includes` subdirectory contains nginx configuration files that are
  loaded at the "http" context level, after the main "GenoRing" web server
  definition. It can be used to provide new web services (REST APIs, web
  applications, etc.) and alternative web servers.
- the `genoring` subdirectory contains nginx configuration files that are
  loaded in the "server" context of the main "GenoRing" web server definition.
  It can be used to handle GenoRing website paths differently, or to handle
  SSL or other security aspects, for instance.

## `genoring-db` service

The database service provides a database backend for Drupal and other services.
It is based on PostgreSQL with a set of pre-installed extensions like PostGIS
and PgVector.
