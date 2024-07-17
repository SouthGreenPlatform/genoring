Remaining tasks:
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
