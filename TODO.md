Remaining tasks:
- Add support for profiles "prod", "staging", "dev", "backend" and "offline" in
  genoring Drupal image to select modules to enable
- Add automated tests
- Change genoring Docker image USER to non-root
- Build dockers on lighter images (alpine-based)
- Improve permissions/owners on "volumes" files
- Have backup volume only writable during backup operations (or for "backend"
  profile?)
- See how to manage local file system operations (hooks) on Windows systems
  since there is no exposed volumes. Work through a container?
- "genoring" container script API should be defined and documented. Several
  functions should use YAML input file for better evolution and optional support
  for extra features.
