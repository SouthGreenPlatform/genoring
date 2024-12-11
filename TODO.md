Remaining tasks:
- Add support for profiles "prod", "staging", "dev", "backend" and "offline" in
  genoring Drupal image to select modules to enable
- Add automated tests
- Change genoring Docker image USER to non-root
- Build dockers on lighter images (alpine-based)
- Improve permissions/owners on "volumes" files
- Have backup volume only writable during backup operations (or for "backend"
  profile?)
- Use a common compose file for data and backup volumes?
  https://docs.docker.com/compose/how-tos/multiple-compose-files/extends/
- See how to manage local file system operations (hooks) on Windows systems
  since there is no exposed volumes. Work through a container?
