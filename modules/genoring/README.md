# GenorRing Core Module

## Services

Contains core functionalities of GenoRing (Drupal, database, proxy and volumes).
Core module provides 3 services:
- genoring: provides Drupal and PHP processing.
- genoring-db: provides a PostgreSQL database for Drupal.
- genoring-proxy: provides nginx HTTP server to serve Drupal on HTTP port.

## Alternative services

- genoring-proxy-httpd ("httpd" alternative): provides an alternative to
  genoring-proxy service that uses Apache HTTPd instead of nginx. You may use it
  if you are more familiar with Apache HTTPd than with nginx. It provides the
  same features as the nginx proxy (module configurations, HTTPS, base paths and
  managed instances) and remains reachable by other services through the
  "genoring-proxy" host name. Its configuration is stored in
  "volumes/proxy/httpd/" (main configuration file "genoring-httpd.conf",
  module configurations in "includes/" and "genoring/" sub-directories).
