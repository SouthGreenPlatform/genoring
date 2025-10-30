Remaining tasks:
- Add support for profiles "prod", "staging", "dev", "backend" and "offline" in
  genoring Drupal container image to select modules to enable (ie. dev modules,
  admin UI modules, site stats modules, ...).
- Add automated tests
- Have backup volume only writable during backup operations (or for "backend"
  profile?)
- Build dockers on lighter images (alpine-based)
