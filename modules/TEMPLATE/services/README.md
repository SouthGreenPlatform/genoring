This directory contains Docker service container definitions provided by this
module. Each service should be prefixed by "genoring-" (and not the module name)
to avoid possible conflicts with other Docker services.

See genoring-EXAMPLE.yml for a service example.

It is possible to merge service configs or even override config elements using
respectively genoring-OTHER.merge.yml or genoring-OTHER.override.yml.

Config keys in genoring-OTHER.merge.yml will be merged to the ones of the
service defined by genoring-OTHER.yml on the following basis:
- if the merge key does not exist on the other service, it will be added.
- if the merge key is a sub-structure and the other service is a not, the
  merge key will replace the other key.
- if structure are of different types, the merge key replace the other one.
- if both structure are lists, the merge values are added to the other ones.
- if both structure are key-value pairs, the merge values are merge to the
  corresponding ones on the basis defined above.

Config keys in genoring-OTHER.override.yml will override to the ones of the
service defined by genoring-OTHER.yml on the following basis:
- if the merge key does not exist on the other service, nothing is added.
- if the merge key is empty, the other service corresponding key is removed.
- if both structure are lists, the override list will replace the other one.
- in other cases, the override values will alway replace the other values.
