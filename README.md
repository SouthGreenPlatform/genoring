# GenoRing

GenoRing is a platform for genomic tools that fulfills GenoRing framework.


## Table of contents

- Description
- Installation
- Management
- Support
- Authors and acknowledgment
- License


## Description

GenoRing is a platform for genomic tools that fulfills GenoRing framework.
The core of GenoRing is the GenoRing Drupal distribution that articulates other
tools all together using Docker features. GenoRing can operate on a variety of
genomic data as well as other type of scientific data through modules.

### Features

* Install and start in one command line
* Limited dependencies: Docker, Perl and Linux.
* Easy to maintain (auto-update by command line arguments)
* Modular (modules)
* Flexible (enable/disable modules, switch to local versions)
* Integrated CMS (Drupal)
* Highly customizable (config, data sources, CMS features with themes)
* Persistent (data can be backuped)
* Automated backups
* Data file format standardization
* Data import/export and mapping
* BrAPI compliant and customizable JSON REST services
* User management interface (with access restrictions)
* Easy to integrate to existing systems (through external data mapping UI)

### Architecture

Drupal is an open source content management system (CMS) for building amazing
digital experiences. It's free and made by a dedicated community. The GenoRing
Drupal distribution is a fully packaged Drupal distribution focused on
genomic-dedicated modules that also includes other useful more generic
modules. It is partially pre-configured to simplify its deployment and
administration.

To offer a ready-to-use genomic platform, GenoRing relies on Docker container
system. Docker is a set of platform as a service (PaaS) products that use
OS-level virtualization to deliver software in packages called containers.
With the Docker Container system, it is possible to run the GenoRing platform
with only the required modules but also to add or remove other modules on
demand afterward, easily manage and update each module separately and take
profit for all the other nice features docker system offers like container
segregation, security, scalability and versioning just to name a few.

GenoRing is started and managed through a single PERL script that provides many
operations on the framework. The choice of a script rather than just using
docker commands and config files was driven by the necessity to reliably manage
GenoRing modules as well as afford some other complex tasks. The PERL
language was selected because it is included in almost every Linux distribution
or available as a package for other systems, avoids to setup a specific
version of another language such as Python for instance and is more flexible,
robust and powerfull than a shell script.

### Framework

The GenoRing framework defines the design of GenoRing modules. A GenoRing
module can be a Drupal module, a docker container or a combination of both that
is generally related to genomics. While some modules may require others to work
properly, each module could be added or removed as needed: in case a module has
missing dependencies, it should not crash the system but rather log a message
explaining the problem(s). GenoRing modules must be located in the GenoRing
installation "modules" directory as subdirectories (one directory per module).

GenoRing modules based on docker containers can be replaced by equivalent local
services without too much efforts by using generated configuration files and
following the related instructions.

In some cases, GenoRing modules may provide alternative dockers to suite
specific needs. For instance, the core GenoRing module provides an Apache HTTPd
server as an alternative to the default NGINX proxy server for people more
confortable with Apache HTTPd config files. A documentation explaining how to
switch from a component to another is provided in such cases.

GenoRing modules use "hook scripts" that are automatically triggered by the
GenoRing PERL script to manage changes such as modules installation,
uninstallation and update.

#### Structure of a GenoRing module

A GenoRing module is a directory with the following structure:
- "README.md": a README file explaining the puprose of the module and how it
  works.
- "env": a directory containing environment files used by the module that may be
  edited by the site administrator to adjust configuration elements.
  Each environment file can hold multiple environment variables, one by line,
  following the format "VARIABLE_NAME=variable value" preceded by comments
  documenting the variable usage. Some @tags should also be present to explain
  how the variable is used:
  - "SET": means it is recommended to customize the variable
  - "OPT": means the variable can be customize or left as is
  - "INS": means the variable is used at installation
  - "RUN": means the variable is used at runtime
  Ex.:
    # - Drupal admin account name
    #   @tags: OPT INS
    DRUPAL_USER=genoring
  See modules/genoring/env/genoring.env for more examples.
  Note: enabled Docker Compose profiles can be provided to a container through
  an environment variable defined as "COMPOSE_PROFILES=${COMPOSE_PROFILES}".
  See "services" note for details on Docker Compose profiles.
- "services": a set of YAML files containing the docker definition of each
  service provided by the module. See
  https://docs.docker.com/compose/compose-file/05-services/ for details.
  The definition should not include the "services:" element nor an element name
  for the service and should not include a "container_name" parameter as it will
  be automatically set by GenoRing using the YAML file name. The indentation
  must not include extra-spaces for lisibility as they will be automatically
  managed by the GenoRing script. To avoid conflicts between modules, service
  names should be prefixed by their module name followed by a dash.
  Note: 5 profiles are managed by GenoRing and can be used in the service
  definitions (ie. "profiles: [...]") to limit the use of a service to a given
  context:
  - "prod": set for production site.
  - "staging": set for staging site.
  - "dev": set for developement site.
  - "backend": only enabled for backend operations like module installation,
    update and uninstallation.
  - "offline": only enabled when the site is offline.
  Without specific profiles, the service is always loaded (if the module is
  enabled).
- "volumes": a set of YAML files corresponding to named volumes shared accross
  dockers. These are not to be confused with volumes that can be defined in the
  services above. A module service can mount a shared volume in its "volumes"
  section but the point is that this shared volume can also be mounted by
  services in other modules for data sharing. See
  https://docs.docker.com/compose/compose-file/07-volumes/ for details.
  Since a same shared volume may be defined in multiple modules, the GenoRing
  script will ensure they use the same definition using the volume's version
  number provided as comment in the volume's YAML file header (ie. "# v1.0").
  The GenoRing script will only keep the latest sub-version definition (ie. if
  there is a 1.0 and a 1.1 definition, it will use the 1.1 definition) or the
  last definition met and will raise an error in case of different major
  versions and abort module activation (ie. 1.0 vs 2.0).
  Note: while YAML files do not need a 'genoring-' prefix, this prefix will be
  automatically added to avoid collisions with other volumes managed by docker.
  Therefore, this prefix must be used in service definitions where a shared
  volume names are used.
- "hooks": a directory holding hook scripts. Hook scripts may be available or
  not for a given action and can be PERL scripts for local system actions or
  shell scripts that should be run in module containers.
  Those scripts use special names to by triggered on specific events.
  - "init.pl" will be called on the local system when the module is installed
    and enabled.
  - "disable.pl" will be called on the local system when the module is
    disabled.
  - "uninstall.pl" will be called on the local system when the module is
    disabled and uninstalled. The module will be disabled first and "disable.pl"
    will be called by the system before "uninstall.pl".
  - "update.pl" will be called on the local system when the module is updated.
  - "backup.pl" will be called on the local system before a backup will be
    created.
  - "state.pl" will be called on the local system when the status of the module
    is needed. When this script is not provided, the system will rely on Docker
    container state. However, in some cases like for the genoring service, the
    container might be running but may not be fully initialized. Therefore, such
    a script is needed to get the real container state. The script will just
    output a line with the container state. The ready state string to use is
    'running'.
  - "enable_<container_name>.sh" will be called on the corresponding container to
    alter other containers when needed (eg. adding menu items for the module
    features, pre-configuring Drupal modules, etc.).
  - "disable_<container_name>.sh" will be called on the corresponding
    container to remove the modifications made by the "init_<container_name>.sh"
    script.
  - "update_<container_name>.sh" will be called on the corresponding container
    to perform updates.
  Note: When running shell scripts inside containers, the GenoRing "modules"
  directory is mounted in the container as "/genoring/modules" and allow access
  to module's files if needed.
  Note: Hook scripts may be called more than one time after a site installation.
  It is up to the script to not perform several time a same operation if it has
  already been done.
- "src": if the module uses custom containers, their sources will be provided
  there in sub-directories corresponding to service names (ie. YAML file names
  without the ".yml" extensions).
- "res": if the module needs additional directory and files, that could be
   mounted in containers for instance, they should be put in this resources
   directory.
   Note: Any resource that could be edited by the administrator for
   customization should be copied in a sub-directory of the "./volumes/"
   directory at installation time.

### Data mapping

One common pitfalls in genomic tools is to support any variation of a given
input file format or a wide variety of data sources. It can become a quite
complex task to handle every special use case. To provide generic modules
that will be able to work with many file format variations or data sources,
GenoRing relies on data mapping and convertion tools as well as custom data
loader, in order to insure each tool will use an expected input format to behave
properly.

### Modules

* genoring: core GenoRing system.
  Services:
  * genoring: Drupal CMS and PHP processor (FPM)
  * genoring-db: PostgreSQL database
  * genoring-proxy: Nginx server
* gigwa: Genotype Investigator for Genome-Wide Analyses application.
  Services:
  * genoring-gigwa: Apache Tomcat server serving GIGWA
  * genoring-mongodb: MongoDB database
* jbrowse2: JBrowse2 genome web browser.
  Services:
  * jbrowse2: npx serving JBrowse2


## Installation

GenoRing requires Docker with Docker Compose V2+ and PERL 5.

**Download** the GenoRing repository on your system.

Depending on your server architecture, you may have to configure HTTP server
ports to allow external access to the GenoRing platform.

**This is it**: GenoRing is ready to be started!

See "Management" section for more details.


## Management

Configure and start GenoRing for the *first time* (from installation directory):
```
  # perl genoring.pl start
```
Follow the installation process.

Note: The first time GenoRing is run, it will install the required modules
automatically which may takes several minutes before the system is ready. The
next times, it will just start the required containers and will be faster ready.
The update process will require GenoRing to be turned off and restarted; the
update process may also take more time than a regular start to get GenoRing
online.

Start GenoRing (from installation directory):
```
  # perl genoring.pl start
```

See what is going on (logs):
```
  # perl genoring.pl logs -f
```

Stop GenoRing:
```
  # perl genoring.pl stop
```

Start GenoRing with Gigwa and JBrowse2 modules:
```
  # perl genoring.pl install gigwa jbrowse2
  # perl genoring.pl start
```

Remove JBrowse2 module:
```
  # perl genoring.pl uninstall jbrowse2
```

Start GenoRing using Apache HTTPd instead of Nginx:
```
  # perl genoring.pl mod genoring httpd
  # perl genoring.pl start
```

Put back Nginx:
```
  # perl genoring.pl mod genoring nginx
```

Update all modules:
```
  # perl genoring.pl update
```

Just update the core (Drupal):
```
  # perl genoring.pl update genoring
```

Just update the Gigwa module:
```
  # perl genoring.pl update gigwa
```

If you run into problems, the GenoRing system appears to be crashed, can't be
restarted and you don't have backups, you may need to completly reinitialize the
GenoRing platform.

To clear all previous trials and get a clean install:
```
  # perl genoring.pl reinitialize
```

### Switching to local components

When it is possible, the process to switch from a module container to a
corresponding local service is explained in the module's README file in a
"Switching" section.

## Support

Report issues or support request on GenoRing Git issue queue at:

https://gitlab.cirad.fr/agap/genoring/-/issues

### Trouble shooting

* When installing Drupal (the first time), the database docker logs a couple of
  errors like "ERROR:  relation "..." does not exist ... STATEMENT: ...".
  These errors, as long as they occure before Drupal installation is completed,
  can be ignored as they are due to the way Drupal checks if tables exist.

* "The provided host name is not valid for this server." error message means you
  did not setup the environment variable "DRUPAL_TRUSTED_HOST" in
  "env/genoring.env" when installing.
  You will have to edit "./volumes/drupal/web/sites/default/settings.php" and
  update the setting "$settings['trusted_host_patterns']".

* Mails are not sent: the "DRUPAL_SITE_MAIL" environment variable as not been
  set properly.

* If Drupal pages load but without style and images (many 404 in logs), it
  might be because of a Docker volume mounting issue. The proxy server can not
  access static files. You will have to investigate if the volumes are properly
  mounted and were correctly initialized.


## Authors and acknowledgment

* Valentin GUIGNON, The Alliance Bioveristy - CIAT (CGIAR), v.guignon@cgiar.org

* SouthGreen platform.

### Contributing

SouthGreen Platform
  * CIRAD
  * IRD
  * INRAE
  * The Alliance Bioversity - CIAT


## License

This project is licensed under the MIT License.
