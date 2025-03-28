Here is the place to put environment files. You can put as many environment
files as needed. Every environment file with the ".env" extension will be
processed at module installation, querying the user for settings to change or
fill, and copied into the main GenoRing "env/" directory with the module name
(follwed by an underscore) as file prefix to avoid conflicts between modules.
For example, "modules/TEMPLATE/env/example.env" would be copied into
"env/TEMPLATE_example.env" (if "TEMPLATE" was a valid module name) with user
inputs.

Each environment variable must have a header. See "example.env" for an example.
