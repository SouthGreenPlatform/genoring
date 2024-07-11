# GenoRing

GenoRing is a platform for genomic components that fulfills GenoRing framework.


## Description

GenoRing is a platform for genomic components that fulfills GenoRing framework.
The core of GenoRing is the GenoRing Drupal distribution that articulates other
components all together using Docker features. GenoRing can operate on a
variety of genomic data

### Features

* Install and start in one command line
* Easy to maintain (auto-update by command line arguments)
* Modular (components)
* Flexible (enable/disable components, local versions)
* Highly customizable (config, data sources, CMS features with themes)
* Persistent (local data can be backuped)
* Preconfigured profiles
* Automated backups
* Data file format standardization
* Data import/export and mapping
* BrAPI compliant
* User management interface (with access restrictions)
* Integrated CMS (Drupal)
* Easy to integrate to existing systems

### Architecture

Drupal is an open source content management system (CMS) for building amazing
digital experiences. It's free and made by a dedicated community. The GenoRing
Drupal distribution is a fully packaged Drupal distribution focused on
genomic-dedicated extensions that also includes other useful more generic
extensions. It is partially pre-configured to simplify its deployment and
administration.

To offer a ready-to-use genomic platform, GenoRing relies on Docker container
system. Docker is a set of platform as a service (PaaS) products that use
OS-level virtualization to deliver software in packages called containers.
With the Docker Container system, it is possible to run the GenoRing platform
with only the required components but also to add or remove other components on
demand afterward, easily manage and update each component separately and take
profit for all the other nice features docker system offers like component
segregation, security, scalability and versioning just to name a few.

### Framework

The GenoRing framework defines the design of GenoRing components. A GenoRing
component can be a Drupal module, a docker container service or a combination of
both that is related to genomics. While some components may require others to
work properly, each component could be added or removed as needed: in case a
component has missing dependencies, it should not crash the system but rather
display a message explaining the problem(s).

GenoRing components packaged as docker containers can be replaced by
corresponding local services easily by using generated configuration files. Each
component provides a documentation on how to perform the service migration from
its docker form to a local instance.

### Data mapping

One common pitfalls in genomic tools is to support any variation of a given
input file format or a wide variety of data sources. It can become a quite
complex task to handle every special use case. To provide generic components
that will be able to work with many file format variations or data sources,
GenoRing relies on data mapping and convertion tools as well as custom data
loader, in order to insure each tool will use an expected input format to behave
properly.

### components

 * Core: Drupal CMS, PostgreSQL database, Nginx server
 * Gigwa: Gigwa, MongoDB
 * JBrowse2: JBrowse2


## Installation

GenoRing requires Docker with Docker Compose V2.

**Download** the GenoRing repository and **edit the configuration** file
"genoring.env" to change what is needed (read the file comments for help).

You will need to create an empty directory "volumes/drupal" because empty
directories can not be added to git repositories while it is requiered for
docker compose mapping.

Depending on your server architecture, you may also have to configure HTTP
server ports.

**This is it**: GenoRing is ready to be started! See "Usage" section.

See "Management" section for more details.


## Usage

Install and start GenoRing for the *first time* (from installation directory):
```
  # sudo mkdir -p volumes/drupal
  # docker compose up -d && docker compose logs -f
```
You will see the installation process and can stop watching the logs using
Ctrl+C.

Start GenoRing (from installation directory):
```
  # docker compose up -d
```

See what is going on (logs):
```
  # docker compose logs -f
```

Stop GenoRing:
```
  # docker compose down
```

Start GenoRing with Gigwa and JBrowse2 components:
```
  # export COMPOSE_PROFILES=gigwa,jbrowse2
  # docker compose up -d
```
Note: using docker compose commande line parameter "--profile" is not
recommended because it prevents GenoRing elements from knowing wich components
have been enabled. However, the environment variable COMPOSE_PROFILES allows
GenoRing extension to know  other extension enabled using the environement
variable in their environement file (ie.: COMPOSE_PROFILES=${COMPOSE_PROFILES})
and ensure next docker compose commands will also operate on the enabled
extensions.


Start GenoRing using Apache HTTPd instead of Nginx:
```
  # cp ./overrides/docker-compose.override.apache-httpd.yml docker-compose.override.yml
  # docker compose up -d
```


## Management

The first time GenoRing is run, it will install the required components
automatically which may takes several minutes before the system is ready. The
next times, it will just start the required dockers and will be faster ready.
The update process will require GenoRing to be turned off and restarted; the
update process may also take more time than a regular start to get GenoRing
online.

### Update

To manually update Drupal use this command (while GenoRing is running):
```
  # docker compose run -e DRUPAL_UPDATE=2 genoring
```
DRUPAL_UPDATE=1 is used in environment settings to auto-update Drupal each time
GenoRing starts while DRUPAL_UPDATE=2 is used to manually update Drupal without
starting GenoRing (which should be already running in another docker instance).
Note: you may add other parameters to the command line as needed.

### Reinstall

To clear all previous trials and get a clean install:
```
  # docker compose down
  # docker container prune -f
  # docker image rm genoring
  # docker image prune -f
  # docker volume rm genoring-drupal
  # sudo rm -rf volumes/
  # sudo mkdir -p volumes/drupal
```

### Switching to local components

TODO.
Idea: each module will provide a doc to follow to replace the docker module by
a local version. The core case (Drupal, database, http proxy/server) will be
described here.

### Trouble shooting

* If Drupal pages load but without style and images (many 404 in logs), it
  might be because of a Docker volume mounting issue. The proxy server can not
  access static files. You will have to investigate if the volumes are properly
  mounted and were correctly initialized.

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

## Support

Report issues or support request on GenoRing Git issue queue at:

https://gitlab.cirad.fr/agap/genoring/-/issues


## Roadmap

Alpha release:
1) Basic Drupal site with a couple of modules and minor pre-configuration
2) Integration of a Drupal GenoRing distribution
3) Integration of Gigwa component
4) Integration of JBrowse component
5) HTTP server alternative with Apache HTTPd
6) New plans toward a beta release


## Contributing

SouthGreen Platform
  * CIRAD
  * IRD
  * The Alliance Bioversity - CIAT


## Authors and acknowledgment

* Valentin GUIGNON, The Alliance Bioveristy - CIAT (CGIAR), v.guignon@cgiar.org

* SouthGreen platform.


## License

This project is licensed under the MIT License.


## Project status

Under active development.
