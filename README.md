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
genomic data as well as other types of scientific data through modules.

### Features

* Install and start in one command line
* Limited dependencies: Docker, Perl and Linux.
* Easy to maintain (auto-update by command line arguments)
* Modular and extensible (public and custom modules)
* Flexible (enable/disable modules, switch to local or alternative versions)
* Highly customizable (config, data sources, CMS features with themes, modules)
* Open source and (always) free
* Advanced user experience through integrated CMS (Drupal)
* Persistent data (backups, data releases)
* Data import/export and mapping from (almost) any sources (files, DB, REST)
* Easy to integrate to existing systems (data can be accessed "in place")
* REST services (standards and customs easy to setup)
* FAIR-oriented (metadata integration, ontologies, export tools and UI items)
* User and permission management interface (with access restrictions)
* Facilitate collaboration (REST services, user access, data comment support)
* Supported (based on community-supported elements like Docker and Drupal)

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
profit for all the other nice features Docker system offers like container
segregation, security, scalability and versioning just to name a few.

GenoRing is started and managed through a single PERL script that provides many
operations on the framework. The choice of a script rather than just using
Docker commands and config files was driven by the necessity to reliably manage
GenoRing modules as well as afford some other complex tasks. The PERL
language was selected because it is included in almost every Linux distribution
or available as a package for other systems, avoids to setup a specific
version of another language such as Python for instance and is more flexible,
robust and powerfull than a shell script.

### Framework

The GenoRing framework defines the design of GenoRing modules. A GenoRing
module can be a Drupal module, a Docker container or a combination of both that
is generally related to genomics. While some modules may require others to work
properly, each module could be added or removed as needed: in case a module has
missing dependencies, it should not crash the system but rather log a message
explaining the problem(s). GenoRing modules must be located in the GenoRing
installation "modules" directory as subdirectories (one directory per module).

GenoRing modules based on Docker containers can be replaced by equivalent local
services without too much efforts by using generated configuration files (if
needed) and following the related instructions. It is often as simple as:
`perl genoring.pl tolocal SERVICE IP` (see Switching to local components
dedicated section).

In some cases, GenoRing modules may provide alternative service containers to
suite specific needs. For instance, the core GenoRing module provides an Apache
HTTPd server as an alternative to the default NGINX proxy server for people more
confortable with Apache HTTPd config files. Switching from one to the other is
done in a single command line: `perl genoring.pl enalt genoring httpd`.

GenoRing modules use "hook scripts" that are automatically triggered by the
GenoRing PERL script to manage changes such as modules installation,
uninstallation, update, backup, etc.. There are 2 types of hooks: "local hooks"
which are PERL script launched on the server hosting GenoRing to allow local
file system operations as well as local service operations, and "container
hooks" which are scripts executed on service containers. Each container hook
script should be adapted to the service container it targets. The list of
supported hooks is documented in genoring.pl (in "ApplyLocalHooks" and
"ApplyContainerHooks" functions) as well as in the module template (in its
"hooks" directory). Hooks provide a very flexible and efficient way to allow
modules to integrate with other modules as well as to handle many tasks on a
module basis, simplifying GenoRing extension and maintenance.

#### Structure of a GenoRing module

A GenoRing module template can be found in the GenoRing "modules/TEMPLATE"
directory. A GenoRing module is a directory with the following structure:
- "README.md": a README file explaining the puprose of the module and how it
  works.
- "TOLOCAL.md": a file explaining how to turn Docker service containers into
  "local" services handled either by the server hosting GenoRing or other
  available servers.
- "env": a directory containing environment files used by the module that will
  be use by GenoRing when the module will be enabled, to ask the admin to set
  the environment variable to configure the module and its services.
  Each environment file can hold multiple environment variables, one by line,
  following the format "VARIABLE_NAME=variable value" preceded by comments
  documenting the variable usage. Some @tags should also be present to explain
  how the variable is used:
  - "SET": means it is recommended to customize the variable.
  - "OPT": means the variable can be customize or left as is.
  - "INS": means the variable is used at installation.
  - "RUN": means the variable is used at runtime.

  Ex.:
  ```
    # - Drupal admin account name
    #   @tags: OPT INS
    DRUPAL_USER=genoring
  ```
  It is important do document variables with SET or OPT so they can be managed
  by GenoRing script at installation time: the first line of the comment
  block of a variable should contain the short variable description in one line.
  The next line should be an empty comment line or only contain dashes ('-').
  The nex comment lines should contain the complete description with
  explanations on how to fill the value. The comment block should then contain
  a "@default" annotation followed by a space and the default value (could be
  empty) and the "@tags" annotation stating the use of the variable.
  See "modules/genoring/env/genoring.env" for more examples.
  Note: enabled Docker Compose profiles can be provided to a container through
  an environment variable defined as "COMPOSE_PROFILES=${COMPOSE_PROFILES}".
  See "services" note for details on Docker Compose profiles.
- "services": a set of YAML files containing the Docker definition of each
  service provided by the module. See
  https://docs.docker.com/compose/compose-file/05-services/ for details.
  The definition should not include the "services:" element nor an element name
  for the service and should not include a "container_name" parameter as it will
  be automatically set by GenoRing using the YAML file name. The indentation
  must not include extra-spaces for lisibility as they will be automatically
  managed by the GenoRing script. To avoid conflicts between modules, service
  names should be prefixed by "genoring-" followed by their module name followed
  by a dash, unless a service could be shared amongst multiple modules.
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
  Note: The "services" directory may contain a "alt" subdirectory with
  alternative services that can be used to replace the default ones. An
  "alt.yml" file contains alternative settings managed by GenoRing.
  Each alternative is defined by a (machine) name as YAML element key and
  contains a description string ("description" key), a list of substituted
  services (structured as current service name as key and new alternative
  service name as value under the "substitute" key), a list of new services to
  add ("add" key) and a list of services to remove ("remove" key).
- "volumes": a set of YAML files corresponding to named volumes shared accross
  containers. These are not to be confused with volumes that can be defined in
  the services above. A module service can mount a shared volume in its
  "volumes" section but the point is that this shared volume can also be mounted
  by services in other modules for data sharing. See
  https://docs.docker.com/compose/compose-file/07-volumes/ for details.
  Since a same shared volume may be defined in multiple modules, the GenoRing
  script will ensure they use the same definition using the volume's version
  number provided as comment in the volume's YAML file header (ie. "# v1.0").
  The GenoRing script will only keep the latest sub-version definition (ie. if
  there is a 1.0 and a 1.1 definition, it will use the 1.1 definition) or the
  last definition met and will raise an error in case of different major
  versions and abort module activation (ie. 1.0 vs 2.0).
  Note: a 'genoring-' prefix is required to avoid collisions with other volumes
  managed by Docker.
- "hooks": a directory holding hook scripts. Hook scripts may be available or
  not for a given action and can be PERL scripts for local system actions or
  shell scripts (or others) that should be run in module containers. "local
  hooks" are usually called when all containers are down (except for the
  "state.pl" hook) while "container hooks" are launched on running containers
  when the system is fully loaded.
  Those scripts use special names to by triggered on specific events.
  - "backend_<service_name>.sh" will be triggered when GenoRing is started in
    "backend" mode.
  - "backup.pl" will be called on the local system when a backup is created to
    let the module manage its backup. The first argument provided is the backup
    machine name.
  - "backup_<service_name>.sh" will be called on the corresponding container
    when a backup is created to let the module manage/generate its backup. The
    first argument provided is the backup machine name.
  - "disable.pl" will be called on the local system when the module is
    disabled.
  - "disable_<service_name>.sh" will be called on the corresponding
    container to remove the modifications made by the "enable_<service_name>.sh"
    script.
  - "enable.pl" will be called on the local system when the module is installed
    or enabled.
  - "enable_<service_name>.sh" will be called on the corresponding container to
    alter other containers when needed (eg. adding menu items for the module
    features, pre-configuring Drupal modules, etc.).
  - "init.pl" will be called on the local system when the module is installed
    (and enabled).
  - "offline_<service_name>.sh" will be triggered when GenoRing is started in
    "offline" mode.
  - "online_<service_name>.sh" will be triggered when GenoRing is started
    normally (online mode).
  - "restore.pl" will be called on the local system when a backup should be
    restored. The first argument provided is the backup machine name.
  - "restore_<service_name>.sh" will be called on the corresponding container
    when a backup shoud be restored to let the module manage/generate its
    backup restoration. The first argument provided is the backup machine name.
  - "start.pl" will be called on the local system when the GenoRing is started.
  - "state.pl" will be called on the local system when the status of the module
    is needed. When this script is not provided, the system will rely on Docker
    container state. However, in some cases like for the "genoring" service, the
    container might be running but may not be fully initialized. Therefore, such
    a script is needed to get the real container state. The script will just
    output a line with the container state. The ready state string to use is
    'running'. See the corresponding template hook script for more details.
  - "stop.pl" will be called on the local system when the GenoRing is stopped.
  - "uninstall.pl" will be called on the local system when the module is
    disabled and uninstalled. The module will be disabled first and "disable.pl"
    will be called by the system before "uninstall.pl".
  - "update.pl" will be called on the local system when the module is updated.
  - "update_<service_name>.sh" will be called on the corresponding container
    to perform updates.
  Note: When running shell scripts inside containers, the GenoRing "modules"
  directory is copied in the container as "/genoring/modules" and allow access
  to module's files if needed (like the module "res" directory for instance).
  Note: Hook scripts may be called more than one time after a site installation.
  It is up to the script to not perform several time a same operation if it has
  already been done.
- "src": if the module uses custom containers, their sources will be provided
  there in sub-directories corresponding to service names (ie. YAML file names
  without the ".yml" extensions). Service names should always be prefixed with
  "genoring-" to avoid conflicts with other non-GenoRing Docker containers and
  must correspond to a module service name as defined in the module "services"
  directory.
  The "src" must contain at least a "Dockerfile", a "Dockerfile.amd64" or a
  "Dockerfile.arm" file. "Dockerfile", if present, is assumed to be designed for
  amd64 architectures. A "Dockerfile.arm" may be provided but if not, it can be
  automatically generated by GenoRing at compilation time using the amd64
  version. Therefore, it is recommended to only provide a "Dockerfile" and only
  provide others for specific needs that can't be covered automatically.
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


## Installation

GenoRing requires Docker with Docker Compose V2+ and PERL 5.8+.

**Download** the GenoRing repository (or an archive) on your system.

Depending on your server architecture, you may have to configure your firewall
to allow external access to the GenoRing platform. To select the port to use,
use the environment variable GENORING_PORT. By default, port 8080 is used.

**This is it**: GenoRing is ready to be started!

See "Management" section for more details.


## Management

Configure and start GenoRing for the *first time* (from installation directory):
```
  # perl genoring.pl start
```
Follow the installation process.

Note: The first time GenoRing is run, it will ask for configuration element,
compile missing Docker containers and install the required modules
automatically, which may takes several minutes before the system is ready. The
next times, it will just start the required containers and will be faster ready.
The update process will require GenoRing to be turned off and restarted; the
update process may also take more time than a regular start to get GenoRing
online.

Note: on ARM systems, you must use the command line flag "-arm".

Start GenoRing (from installation directory):
```
  # perl genoring.pl start
  or on a specific HTTP port:
  GENORING_PORT=8888 perl genoring.pl start
```

See what is going on (logs):
```
  # perl genoring.pl logs -f
```

Stop GenoRing:
```
  # perl genoring.pl stop
```

Set GenoRing offline:
```
  # perl genoring.pl offline
```
or
```
  # perl genoring.pl start offline
```

Turn GenoRing back online:
```
  # perl genoring.pl online
```
or
```
  # perl genoring.pl start
```

Start GenoRing with Gigwa and JBrowse modules:
```
  # perl genoring.pl enable gigwa
  # perl genoring.pl enable jbrowse
  # perl genoring.pl start
```

Remove JBrowse module:
```
  # perl genoring.pl uninstall jbrowse
```

Start GenoRing using Apache HTTPd instead of Nginx:
```
  # perl genoring.pl enalt genoring httpd
```

Put back Nginx:
```
  # perl genoring.pl disalt genoring httpd
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
  # perl genoring.pl reset
```

Generate a backup:
```
  # perl genoring.pl backup my_backup_2024
```

Restore a backup:
```
  # perl genoring.pl restore my_backup_2024
```

Access to Drupal shell or composer:
```
  # perl genoring.pl shell
  then
  # composer ...
  or
  # drush ...
  then
  # exit
```

For more commands, just run "perl genoring.pl" or "perl genoring.pl man".


### Switching to local components

When it is possible, the process to switch from a module container to a
corresponding local service is explained in the module's README file in a
"Switching" section. It is usually as simple as:

```
  # perl genoring.pl tolocal SERVICE IP
```

where "SERVICE" is the name of the service and IP is the IP of the server
providing that service (both IPv4 and IPv6 are supported).

It is possible to later switch back to container service using:

```
  # perl genoring.pl todocker SERVICE
```

## Support

Report issues or support request on GenoRing Git issue queue at:

https://gitlab.cirad.fr/agap/genoring/-/issues

### F.A.Q.

Q. How do I access to GenoRing when it is started?
A. Just open a web browser and use the URL http://your.host.name-or-ip:8080/
   unless you specified a different port than the default "8080".
   Ex.: http://192.168.0.2:8080/ or http://my.server.com:8080/
   If you are running GenoRing on you local machine for testing, you can also
   access it through: http://localhost:8080/
   Currently, HTTPS (SSL) is not supported but it will in future versions.

Q. Why GenoRing relies on a PREL script to manage everything?
A. The main goals of GenoRing are to be easy to use, with very few requirements,
  to be modulable and, easy to maintain.
  Running it with a single command line was a key point. Several choices were
  possible:
  - Aks the user to use Docker compose commands but it would require the user to
    create a docker-compose.yml file or at least edit it manually to add and
    enable or disable modules. The user would also have to edit environment
    files manually, which is not very convenient. And to achieve more complex
    tasks (backups, use alternative services), it would not be very easy as
    well. That's why using a script was unavoidable for simplicity.
  - A shell script could have been used. While shell scripts don't require any
    software installation on Linux or Mac systems, they would not work on
    Windows systems. Furthernore, there are many reasons to avoid shell scripts:
    https://mywiki.wooledge.org/BashPitfalls
  - A PERL Script: that's the solution we choose because PERL is natively
    available on most systems and easy (and free) to install on Windows as well.
    And to reduce any other requirements, only standard PERL libraries are used.
  - A python script, a PHP script,... could have been used but they all require
    a language interpretor to be installed which would mean additional
    requirements. There also could be issues due to incompatibles versions of
    installed softwares.
  - Maybe other more complex solutions exist as well but a PERL script remains a
    simple choice and still not too complex to maintain.

Q. Is it possible to replace the Drupal CMS by another system?
A. Yes. The GenoRing code module "genoring" is just a module like the others. It
   is possible to provide an alternative service to the Drupal one. The drawback
   will be that most modules have been designed to work with Drupal and may not
   work properly with an alternative system. To mitigate that problem, a wrapper
   script provided in the CMS container supports several tasks related to CMS
   alterations (ie. menu editing, CMS module enabling, user management, etc.).
   An alternative system could provide its own implementation of that wrapper
   script to perform similar operations.

Q. I want to integrate a custom application to GenoRing. How to proceed?
A. Start by copying the module template directory (modules/TEMPLATE), remove
   unnecessary files and hooks, edit and add what is needed. Then, you should be
   able to enable your custom module and have it integrated to GenoRing just as
   any regular module.

Q. How to add Drupal extensions and themes to the Drupal instance provided by
   GenoRing? Do I need to use a local version instead?
A. You don't need to use a local version. You can use "composer" to manage
   Drupal extensions through the GenoRing shell (`genoring.pl shell`).

Q. I would like to use my institute Single Sign On service (SSO) to log into
   GenoRing automatically. Is it possible?
A. Yes, through a Drupal extension as long as such an extension exists for your
   SSO system. You will have to add that extension and configure it.

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

This project is licensed under the MIT License. See LICENSE file for details.
