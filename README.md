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

...

## Installation

GenoRing requires Docker with Docker Compose V2.

**Download** the GenoRing repository and **edit the configuration** file
"genoring.env" to change what is needed (read the file comments for help).

Depending on your server architecture, you may also have to configure HTTP
server ports.

**This is it**: GenoRing is ready to be started!

See "Management" section for more details.


## Usage

Start GenoRing (from installation directory):
```
  # docker compose up -d
```

Stop GenoRing:
```
  # docker compose down -d
```

Start GenoRing with Gigwa and JBrowse components:
```
  # docker compose --profile gigwa --profile jbrowse up -d
```

Start GenoRing using Apache HTTPd instead of Nginx:
```
  # cp ./overrides/docker-compose.override.apache-httpd.yml docker-compose.override.yml
  # docker compose --env-file ./env/httpd.env up -d
```


## Management

The first time GenoRing is run, it will install the required components
automatically which may takes several minutes before the system is ready. The
next times, it will just start the required dockers and will be faster ready.
The update process will require GenoRing to be turned off and restarted; the
update process may also take more time than a regular start to get GenoRing
online.

### Update

To update Drupal use the command:
```
  # docker compose -e DRUPAL_UPDATE=1 up -d
```
Note: you may add other parameters to the command line as needed.

### Reinstall

...

### Switching to local components

...

### Trouble shooting

...

## Support

Report issues or support request on GenoRing Git issue queue at:

https://gitlab.cirad.fr/agap/genoring/-/issues


## Roadmap

Alpha release:
1) Basic Drupal site with a couple of modules and minor pre-configuration
2) Integration of a Drupal GenoRing distribution
3) Integration of Gigwa component
4) HTTP server alternative with Apache HTTPd
5) New plans toward a beta release


## Contributing

SouthGreen Platform
  * CIRAD
  * IRD
  * The Alliance Bioversity - CIAT


## Authors and acknowledgment

* Valentin GUIGNON, The Alliance Bioveristy - CIAT (CGIAR), v.guignon@cgiar.org

* ...


## License

This project is licensed under the MIT License.


## Project status

Under active development.
