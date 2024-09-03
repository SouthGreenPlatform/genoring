Remaining tasks:
- prefix volume files with module name to be homogenous
- on installation, copy used env files to a separate root conf directory with
  module config renamed into genoring.yml.
  Env files should be prefixed by module name tp avpod collisions.
  PERL: "use CPAN::Meta::YAML;" should be sufficient.
  https://metacpan.org/pod/CPAN::Meta::YAML
  genoring.yml:
  ----------
  modules:
    genoring:
      version: 1.0
      services:
        - genoring:genoring
        - genoring:genoring-db
        - genoring:genoring-proxy-httpd
        - ...
      volumes:
        - genoring:genoring-drupal-volume
        - ...
    gigwa:
      ...
  ----------
- handle alternatives:
  the modules/.../services/alt.yml should allow adding, removing and replacing
  services (ie. keeping the same name), even from other installed modules. It
  should handle version compatibility and manage multiple overrides (should be
  able to replace a service or one of its known replacement if the service is
  not present because it has already been replaced).
- create a "devel" module for debugging and as example
- finish genoring shell script to PERL script translation.
  - setup: offer environment file modifications
  - disable module
  - uninstall module
  - offline
  - backup
  - restore
- hook support:
  - "disable.pl"
  - "uninstall.pl"
  - "update.pl"
  - "backup.pl"
  - "disable_<container_name>.sh"
  - "update_<container_name>.sh"
- add support for profiles "prod", "staging", "dev", "backend" and "offline"
  - in genoring PERL script: choice between prod/staging/dev should be made at
    installation time. A new parameter "offline" should be supported.
  - in genoring Drupal image to select modules to enable
- test offline mode
- improve status when site is installing
- add (drush?) functions to simplify module Drupla integration to easily
  generate menu items, pages, etc.
- build dockers on lighter images (alpine-based)
- Add a module for BrAPI/BrAPI Mapper
