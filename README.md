# GenoRing

GenoRing is both a platform and a framework designed to handle biological data
through an easy-to-deploy web portal that integrates "à la carte" bioinformatics
tools.

[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](https://lbesson.mit-license.org/)

## Table of contents

- Description
- Installation & requirements
- Management
- Support
- Authors and acknowledgment
- License


## Description

GenoRing is both a platform and a framework designed to handle biological data
through an easy-to-deploy web portal that integrates "à la carte" bioinformatics
tools. By promoting open science principles, GenoRing aims to empower
laboratories and research teams -particularly those with limited resources- to
effortlessly establish and maintain bioinformatics tools for curating and
sharing their data.

The platform serves as a central hub for data exploration, ensuring efficient
storage, usage, and accessibility with minimal effort. Installation, startup,
and maintenance are simplified, requiring only a few command lines and minimal
software prerequisites. The user-friendly graphical interface enables easy
configuration, alignment with standard data models, and utilization of
preconfigured tools, including data-sharing functionalities, thereby minimizing
setup challenges and saving time.

The framework features a highly flexible and easily extensible architecture.
GenoRing employs a modular approach: each component of GenoRing, including its
core, is a module that can be deployed individually while maintaining tight
integration with other enabled modules. It uses a hooking mechanism to allow
modules to handle a wide range of events, interact with each other, and manage
data. Modules can range from simple scripts to complex applications, which are
easily deployed using Docker containers. The framework supports module
alternatives, enabling users to switch between multiple tool variants to select
the most appropriate one for a given problem. Furthermore, provided Docker
services can be replaced with local or external services -particularly if they
are more efficient (ie. HPC)— with minimal configuration changes.

The base version of the GenoRing platform is shipped with the Drupal CMS and a
basic set of modules, primarily based on Docker. It only requires PERL (core) to
manage the platform and Docker for easy deployment. Once the GenoRing platform
is downloaded from the GitHub project, it can be set up and launched with a
single command line. Customizable settings are managed through an interactive
prompt. After the Drupal portal is fully initialized, additional customization
and data-loading features become available through the web interface.


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


## Installation & requirements

GenoRing requires PERL 5.8+ core and Docker v20.10.13+.
- PERL 5.8+ is installed by default on most Linux distributions and Mac while
  it requires Perl installation on Windows systems (ActiveState Perl or
  Strawberry Perl). See https://www.perl.org/get.html
- Docker v20.10.13+ includes "Docker Compose V2+" (docker-compose-plugin) and
  "BuildKit" (buildx) plugins.

**Download** the GenoRing repository (or an archive) on your system.

Depending on your server architecture, you may have to configure your firewall
to allow external access to the GenoRing platform. To select the port to use,
use the parameter "-port=<HTTP_PORT>". By default, port 8080 is used.

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
  perl genoring.pl start -port=8888
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
If you still encounter problems, try:
```
  # perl genoring.pl reset -delete-containers
```
To clear all previous trials and get a clean install but keep current config:
```
  # perl genoring.pl reset -keep-env
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
  # su genoring
  # composer ...
  # drush ...
  # exit
  # exit
```

To run Drupal automated tests:
```
  # perl genoring.pl shell
  only needed the first time:
  # genoring inittest
  then to run tests:
  # su genoring
  # ./vendor/bin/phpunit -c ./web/core ./web/modules/contrib/
  ...
  # exit
  # exit
```

Run multiple instances of GenoRing:
You will have to create a volume directory for each instance.
```

  # COMPOSE_PROJECT_NAME=gr_inst1 perl genoring.pl start
  # COMPOSE_PROJECT_NAME=gr_inst2 perl genoring.pl start
  # COMPOSE_PROJECT_NAME=gr_inst3 perl genoring.pl start
  ...
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

### Known issues

- ARM support is not fully functional yet.
- For Windows platform support, exposed GenoRing volumes are disabled. Due to a
  large amount of files generated, it often crashes Docker Desktop and prevents
  GenoRing from functionning. Since named Docker volumes can still be accessed
  through Docker Desktop, having those also shared as local files in local file
  system is not necessary and is automatically disabled. To force the use of
  such exposed volumes on Windows system (and face associated issues), you can
  however use the flag "--no-exposed-volumes=0". And in reverse, you can disable
  the use of exposed volumes on local file system using "--no-exposed-volumes"
  on any system.

### Report

Report issues or support request on GenoRing Git issue queue at:

[https://github.com/SouthGreenPlatform/genoring/issues](https://github.com/SouthGreenPlatform/genoring/issues)

### F.A.Q.

Q. How do I access to GenoRing when it is started?
A. Just open a web browser and use the URL http://your.host.name-or-ip:8080/
   unless you specified a different port than the default "8080".
   Ex.: http://192.168.0.2:8080/ or http://my.server.com:8080/
   If you are running GenoRing on you local machine for testing, you can also
   access it through: http://localhost:8080/
   Currently, HTTPS (SSL) is not supported but it will in future versions.

Q. Why GenoRing relies on a PERL script to manage everything?
A. The main goals of GenoRing are to be easy to use, with very few requirements,
  to be modular and, easy to maintain.
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
    Windows systems. Furthermore, there are many reasons to avoid shell scripts:
    https://mywiki.wooledge.org/BashPitfalls
  - A PERL Script: that's the solution we choose because PERL is natively
    available on most systems and easy (and free) to install on Windows as well.
    And to reduce any other requirements, only standard PERL libraries are used.
  - A python script, a PHP script,... could have been used but they all require
    a language interpreter to be installed which would mean additional
    requirements. There also could be issues due to incompatibles versions of
    installed software.
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

* When trying to start, it says:
  "ERROR: Current user not allowed to manage containers with 'docker' command!"
  It means the docker command is available at the correct version but current
  user running GenoRing is not allowed to manage docker containers.
  You may consider eiter using a different user to run GenoRing or add current
  user to the "docker" group: "sudo usermod -aG docker $USER" (and restart a
  new session).

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
