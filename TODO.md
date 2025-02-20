Remaining tasks:
- Add support for profiles "prod", "staging", "dev", "backend" and "offline" in
  genoring Drupal image to select modules to enable
- Add automated tests
- Secure environment passwords (Postgres)? Useless as it is also in
  settings.php?
- Have backup volume only writable during backup operations (or for "backend"
  profile?)
- See how to manage local file system operations (hooks) on Windows systems
  since there is no exposed volumes. Work through a container?
- Build dockers on lighter images (alpine-based)
