Remaining tasks:
- Add a Drush wrapper script to offer generic module integration to easyly
  generate menu items, pages, user accounts/groups, permissions, theme
  customization, etc. regardless Drupal system.
- Add a module for BrAPI/BrAPI Mapper without docker services
- Make Drupal installation script use GenoRing Drupal distribution and use a
  GenoRing default theme.
- Add support for profiles "prod", "staging", "dev", "backend" and "offline" in
  genoring Drupal image to select modules to enable
- Add automated tests
- Test cron support
- Test mail support
- Change genoring Docker image USER to non-root
- Build dockers on lighter images (alpine-based)
- Improve status when site is installing
- Improve permissions/owners on "volumes" files
