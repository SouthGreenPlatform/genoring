#!/bin/sh

BASEDIR=$(dirname $0)
cd "${BASEDIR}"
umask 002

##
# Displays script usage.
#
print_help () {
  echo "usage: $0 [start|stop|restart|status|help]

Commands:
  start:      Starts GenoRing system.
  stop:       Stops GenoRing system.
  restart:    Stops and restarts GenoRing.
  status:     Tells if GenoRing is running or not.
  logs:       Get GenoRing logs.
  help:       Displays this help.
"
}

##
# Starts GenoRing by running the selected set of containers.
#
start_genoring () {
  # @todo Check if setup needs to be run first.
  # @todo Get profiles to enable.
  docker compose up -d
}

##
#  Stops GenoRing containers.
#
stop_genoring () {
  docker compose down
}

##
# Returns the status of GenoRing system.
#
# Arguments:
#  service: the service/extension to check.
#
# Return:
#   0 if all is ok and a non-zero value otherwise.
#
genoring_status () {
  # @todo Check if the dockers are running.
  echo "TODO"
}

##
# Displays GenoRing logs.
#
# Arguments:
#  service: the service/extension to check.
#  -f: enables logs "follow" mode.
#
genoring_logs () {
  # @todo Check if a specific service has been specified.
  docker compose logs -f
}

##
# Removes Drupal files and database data for a full reinstall.
#
genoring_clear () {
  # @todo Warn and ask for confirmation.
  stop_genoring
  docker container prune -f
  docker volume rm genoring-drupal
  # @todo Check if only a sub-part should be managed.
  # @todo Add an option to remove ALL and not just Drupal and its db.
  sudo rm -rf volumes/drupal
  # sudo rm -rf volumes/data
  sudo rm -rf volumes/db
  # @todo Clear enabled extensions.
  mkdir -p volumes/drupal
  mkdir -p volumes/data
}

##
# Initializes GenoRing system with user inputs.
#
genoring_setup () {
  mkdir -p volumes/drupal
  mkdir -p volumes/data
  # @toto Manage environment file generation.
  # Ask for ...
  while [ -z "$value" ]; do
    read -p "Enter a value: " value
  done

  # @todo Check for extensions to enable.
  # docker exec -v ./extensions/profile/path/to/:/path/to/ -it genoring /path/to/script.sh
  # @toto Ask to start genoring.
  start_genoring
}

##
# Clears previous settings and re-run setup process.
#
# Arguments:
#  service (optional): the service/extension to reinitialize. If not set, all is
#    reinitialized.
#
genoring_reinit () {
  # @todo Check if only a sub-part should be managed.
  # @todo Check if database or Drupal should be kept.
  genoring_clear
  mkdir -p volumes/drupal
  mkdir -p volumes/data
}

##
# Updates the GenoRing system or the specified extension.
#
# Arguments:
#  service (optional): the service/extension to update. If not set, all is
#    updated.
#
genoring_update () {
  # @todo Check if running.
  # @todo Check if only some parts should be updated or update all.
  docker compose run -e DRUPAL_UPDATE=2 genoring
}

##
# Enables the given GenoRing extension.
#
# Arguments:
#  extension: the extension to enable and setup.
#
genoring_enable () {
  if [ -z $1 ]; then
    >&2 echo "ERROR: genoring_enable: No extension name provided!"
    exit 1
  fi
  # Get extension status.
  get_extension_status $1
  if [ -z "$extension_status" ]; then
    >&2 echo "ERROR: genoring_enable: Extension not found ($1)!"
    exit 1
  elif [ "0" -eq "$extension_status" ]; then
    # Enable specified extensions.
    # Add extension to the enabled extension file.
    echo "$1" >> ./enabled_extensions.txt
    # Copy nginx config.
    if [ -x "./extensions/$1/nginx/$1.conf" ]; then
      # Do not overwrite existing.
      cp -n "./extensions/$1/nginx/$1.conf" ./proxy/extensions/
    fi
    # Call init scripts.
    echo "Initializing..."
    if [ -x "./extensions/$1/hook/init.sh" ]; then
      echo "- $1"
      ./extensions/$1/hook/init.sh
    fi
    # Loop on docker initialization scripts.
    for scriptname in ./extensions/$1/hooks/init_*.sh; do
      echo "* $scriptname"
      container_name=$(echo $scriptname | perl -p -e "s#\./extensions/$1/hooks/init_(.+)\.sh#\$1#g")
      echo "- $container_name"
      # Check if the corresponding container is running.
      container_is_running $container_name
      if [ "1" -eq "$container_is_running" ]; then
        echo docker exec -v ./extensions/$1/hooks/init_$container_name.sh:/usr/init/init_$container_name.sh -it $container_name /user/init/init_$container_name.sh
      fi
    done
    echo "...initialization done."
  elif [ "1" -eq "$extension_status" ]; then
    echo "WARNING: genoring_enable: Extension already enabled ($1)."
  fi
}

##
# Disables and uninstalls the given GenoRing extension.
#
# Arguments:
#  extension: the extension to disable and uninstall.
# @todo Maybe see if uninstall could be optional.
#
genoring_disable () {
  # @todo Warn and ask for confirmation.
  if [ -z $1 ]; then
    >&2 echo "ERROR: genoring_disable: No extension name provided!"
    exit 1
  fi
  # Get extension status.
  get_extension_status $1
  if [ -z "$extension_status" ]; then
    >&2 echo "ERROR: genoring_disable: Extension not found ($1)!"
    exit 1
  elif [ "1" -eq "$extension_status" ]; then
    # Disable specified extensions.
    # Remove extension from the enabled extension file.
    perl -p -i -e "s/^\\s*\\Q$1\\E\\s*\\$//g" ./enabled_extensions.txt
    # Remove nginx config.
    if [ -f "./proxy/extensions/$1.conf" ]; then
      rm ./proxy/extensions/$1.conf 
    fi
    # Call uninstall scripts.
    echo "Uninstalling..."
    if [ -x "./extensions/$1/hook/uninstall.sh" ]; then
      echo "- $1"
      ./extensions/$1/hook/uninstall.sh
    fi
    # Loop on docker uninstallation scripts.
    for scriptname in ./extensions/$1/hooks/uninstall_*.sh; do
      echo "* $scriptname"
      container_name=$(echo $scriptname | perl -p -e "s#\./extensions/$1/hooks/uninstall_(.+)\.sh#\$1#g")
      echo "- $container_name"
      # Check if the corresponding container is running.
      container_is_running $container_name
      if [ "1" -eq "$container_is_running" ]; then
        echo docker exec -v ./extensions/$1/hooks/uninstall_$container_name.sh:/usr/init/uninstall_$container_name.sh -it $container_name /user/init/uninstall_$container_name.sh
      fi
    done
    echo "...uninstallation done."
  elif [ "0" -eq "$extension_status" ]; then
    echo "WARNING: genoring_disable: Extension already disabled ($1)."
  fi
}

##
# Performs a general backup of the GenoRing system into an archive file.
#
genoring_backup () {
  # @todo Backup config and data to an archive.
  echo "TODO"
}

##
# Restores GenoRing from a given backup archive.
genoring_restore () {
  # @todo Restore a given backup archive.
  echo "TODO"
}

##
# Recompiles a given container.
#
# Arguments:
#  $1: Container image name.
#  $2: Container source path where the Dockerfile is.
#  $3: (optional) Container name.
#
genoring_recompile () {
  if [ -z $1 ]; then
    >&2 echo "ERROR: genoring_recompile: Container image name not provided!"
    exit 1
  elif [ -z $2 ]; then
    >&2 echo "ERROR: genoring_recompile: Container source path not provided!"
    exit 1
  elif [ ! -f $2 ]; then
    >&2 echo "ERROR: get_env_setting: Container source path not found ($2)!"
    exit 1
  fi
  if [ -z $3 ]; then
    set -- $1 $2 $1
  fi
  # Test if container is running and if so, stop it and rerun it after.
  container_is_running $3
  if [ ! -z "$container_is_running" ]; then
    echo "WARNING: genoring_recompile: The container was running and will be stopped."
    docker stop $3
    docker container prune -f
  fi
  docker image rm $1
  docker image prune -f
  docker build -t $1 $2
}

##
# Returns a list of GenoRing extensions.
#
# Arguments:
#  status (optional): if non-zero, only returns enabled extensions, if 0 only
#    returns disabled available extensions and if not set, returns all available
#    extensions.
#
get_genoring_extensions () {
  if [ -z $1 ]; then
    ls -Aw1 ./extensions
  elif [ "0" -eq "$1" ]; then
    ls -Aw1 ./extensions | grep -v -x -f ./enabled_extensions.txt
  elif [ "1" -eq "$1" ]; then
    cat ./enabled_extensions.txt
  fi
}

##
# Returns the status of a GenoRing extensions.
#
# Arguments:
#   $1: the name of the extension.
#
# Return:
#   Sets the variable 'extension_status' to an empty value if the extension was
#   not found (ie. does not exist), 0 if the extension is disabled and 1 if the
#   extension is enabled.
#
get_extension_status () {
  if [ -z $1 ]; then
    >&2 echo "ERROR: get_extension_status: No extension name provided!"
    exit 1
  fi
  extension_status=
  if [ ! -z $(grep -v -x $1 ./enabled_extensions.txt) ]; then
    extension_status=1
  elif [! -z $(ls -Aw1 ./extensions | grep -v -x $1) ]; then
    extension_status=0
  fi
}

##
# Returns the value of an environment variable in an env file.
#
# Arguments:
#   $1: environment file path.
#   $2: setting variable name.
#
# Return: 
#   Sets the variable 'env_value'.
#
get_env_setting () {
  env_value=
  if [ -z $1 ]; then
    >&2 echo "ERROR: get_env_setting: Environment file not provided!"
    exit 1
  elif [ ! -f $1 ]; then
    >&2 echo "ERROR: get_env_setting: Environment file not found ($1)!"
    exit 1
  elif [ -z $2 ]; then
    >&2 echo "ERROR: get_env_setting: No setting variable requested!"
    exit 1
  fi
  env_value=$(grep -P "\s*$2\s*[=:]" $1 | sed -r "s/\s*$2\s*[=:]\s*//" | sed -r "s/^'(.*)'\\s*\$|^\"(.*)\"\\s*\$/\1\2/")
}

##
# Sets the value of an environment variable in a given env file.
#
# Arguments:
#   $1: environment file path.
#   $2: setting variable name.
#   $3: new setting variable value.
#
set_env_setting () {
  if [ -z $1 ]; then
    >&2 echo "ERROR: set_env_setting: Environment file not provided!"
    exit 1
  elif [ ! -f $1 ]; then
    >&2 echo "ERROR: set_env_setting: Environment file not found ($1)!"
    exit 1
  elif [ -z $2 ]; then
    >&2 echo "ERROR: set_env_setting: No setting variable requested!"
    exit 1
  fi
  # Check if setting is there.
  if [ -z $(grep -P "\s*$2\s*[=:]" $1) ]; then
    echo "\n$2=$3" >> $1
  else
    perl -p -i -e "s/\s*\Q$2\E\s*[=:].*/$2=$3/g" $1
  fi
}

##
# Tells if a container is running.
#
# Arguments:
#  $1: container_name
#
# Return:
#   Sets 'container_is_running' value to an empty value if not running or to
#   a non-empty string otherwise.
container_is_running () {
  container_is_running=$(docker ps | grep -P "\s\Q$1\E(?:\s|$)")
}

# Processes command line arguments.
case "$1" in
  start)
    start_genoring "$@:2"
    ;;
  stop)
    stop_genoring
    ;;
  restart)
    start_genoring
    stop_genoring
    ;;
  status)
    genoring_status "$@:2"
    ;;
  logs)
    genoring_logs "$@:2"
    ;;
  setup)
    genoring_setup "$@:2"
    ;;
  clear)
    genoring_clear "$@:2"
    ;;
  reinit)
    genoring_reinit "$@:2"
    ;;
  update)
    genoring_update "$@:2"
    ;;
  upgrade)
    echo "Not implemented: Upgrades GenoRing system."
    ;;
  compile)
    case "$2" in
      genoring)
        genoring_recompile genoring src/genoring-docker/
        ;;
      jbrowse2)
        genoring_recompile genoring-jbrowse2 extensions/jbrowse2/
        ;;
      *)
        print_help
        exit 1
        ;;
    esac
    ;;
  test)
    get_genoring_extensions $2
    ;;
  help|-help|--help|/?)
    print_help
    ;;
  *)
    print_help
    exit 1
    ;;
esac
