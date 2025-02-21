#!/bin/sh

start_cron() {
  /usr/sbin/cron
}

start_sendmail() {
  /usr/bin/printf "$(hostname -i)\t$(hostname) $(hostname).localhost\n" | tee -a /etc/hosts
  /usr/sbin/service sendmail start
}

www_permissions() {
  /usr/bin/chown -R www-data:www-data /opt/drupal/private /opt/drupal/config /opt/drupal/web/sites/default/files
}

drupal_permission() {
  mkdir -p /data/genoring /data/upload
  /usr/bin/chown $SUDO_UID:$SUDO_GID /data/genoring /data/upload
}

if [ "$#" -ne 1 ]; then
  echo "Invalid syntax!"
  exit 1
fi

case $1 in
  start_cron)
    start_cron
    ;;
  start_sendmail)
    start_sendmail
    ;;
  www_permissions)
    www_permissions
    ;;
  drupal_permission)
    drupal_permission
    ;;
  *)
    echo "Invalid argument: $1"
    exit 1
    ;;
esac
