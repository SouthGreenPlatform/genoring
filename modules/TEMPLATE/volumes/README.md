This directory should contain docker volume definitions just like they would
appear in the "volume" section of the docker-compose.yml file.
It's required that every definition begins with a version string such as:
# v1.0
It is used to make sure several modules sharing the same volume use the same
definition for that volume and avoid issues related to discrepencies in volume
definitions.
