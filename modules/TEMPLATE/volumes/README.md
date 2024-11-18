This directory should contain docker volume definitions just like they would
appear in the "volume" section of the docker-compose.yml file.

Volume file names must begin with the "genoring-" prefix to avoid conflicts with
other possible Docker volumes.

It's required that every definition begins with a version string such as:
# v1.0
It is used to make sure several modules sharing the same volume use the same
definition for that volume and avoid issues related to discrepencies in volume
definitions.

See *.yml files for examples. "genoring-data-volume.yml" should be common to all
GenoRing modules working with biological data. "genoring-backups-volume.yml"
should be common to all GenoRing modules that can backup or restore data.
