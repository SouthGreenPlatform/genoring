This directory should contain "shared" Docker volume definitions just like they
would appear in the "volumes" section of the docker-compose.yml file.

By "shared", we mean volumes that may be used by more than one container in
different GenoRing modules. However, some volumes may be used by more than one
container (even in different modules while it is not recommanded) and may not be
defined as "shared" if they are not considered by the module developer as
"shared".

Volume file names must begin with the "genoring-" prefix to avoid conflicts with
other possible Docker volumes and be followed by a meaningful name using
only lower case characters, numbers and dashes (NO underscores or dots!). The
volume name must not begin with "genoring-volume-" (reserved for non-shared
volume names that may be automatically generated). The volume name should end by
"-volume".

See "genoring-example-volume.yml" and genoring module "volumes/*.yml" files for
examples. Only shared volumes specificaly provided and shared by this module
should be defined here. Other used shared volumes, used by this module, can be
set in the module main YAML file.

Note: When using local path, use the syntax "${PWD}/volumes/[...]", where
"[...]" is a sub-directory of the local "volumes" directory. This is required to
support Win32 systems as well as the "-no-exposed-volumes" option.
