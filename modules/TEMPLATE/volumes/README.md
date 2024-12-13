This directory should contain docker volume definitions just like they would
appear in the "volume" section of the docker-compose.yml file.

Volume file names must begin with the "genoring-" prefix to avoid conflicts with
other possible Docker volumes.

It's required that every definition begins with a version string such as:
# v1.0

See genoring module "volumes/*.yml" files for examples. Only volumes specific to
the module should be defined here. Other used volumes can be set in the module
main YAML file.
