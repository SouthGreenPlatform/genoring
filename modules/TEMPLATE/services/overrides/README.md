This directory contains Dockerfiles that extend an existing GenoRing service
image. Declare each override in the module's `overrides` mapping and name its
Dockerfile `<target>.dockerfile`, where `<target>` is the mapping key. The
recommended target key is `genoring-<service_name>`; the exact service name or
current image name is also accepted.

The Dockerfile must use the targeted service's original image in a `FROM`
instruction. GenoRing substitutes that image with the previous image in the
chain, so the same Dockerfile can be layered with overrides from other modules.
The directory is the Docker build context; include files used by `COPY` here.

Overrides are considered only while the module and targeted service are active.
The optional `alternatives` list on an override selects the module alternative
names for which it applies. Use the module name to select the default services.
