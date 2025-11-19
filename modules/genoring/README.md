# GenorRing Core Module

## Services

Contains core functionalities of GenoRing (Drupal, database, proxy and volumes).
Core module provides 3 services:
- genoring: provides Drupal and PHP processing.
- genoring-db: provides a PostgreSQL database for Drupal.
- genoring-proxy: provides nginx HTTP server to serve Drupal on HTTP port.

## Alternative services

- genoring-proxy-httpd: provides an alternative to genoring-proxy service that
  uses Apache HTTPd instead of nginx. You may use it if you are more familiar
  with Apache HTTPd than with nginx.
  Note: at the time this document is being written, the alternative is still
  under development and may not work properly with other modules.
