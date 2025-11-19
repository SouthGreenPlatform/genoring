# Local services

## genoring-proxy

The proxy service can use a local instance of nginx (or Apache HTTPd). Here is
how to process:
- GenoRing must have been started normaly at least once to be properly
  initialized.
- Stop GenoRing and run:
  ```
  perl genoring.pl toexternal genoring-proxy <LOCAL_IP>
  ```
  where <LOCAL_IP> must be replaced by the public IP of the host (Warning: do
  not use 127.0.0.1 as it will not work).
- Edit GenoRing `docker-compose.yml` file and add a port section to the
  `genoring` service:
  ```
    ports:
      - 127.0.0.1:9010:9000
  ```
  This will expose on the host only (not accessible from outside) the PHP-FPM
  port used to run Drupal from the local nginx service. You may replace 9010 by
  any unused suitable port that meets your needs.
- Then configure your local proxy:
  You may either configure it manually or use the provided config:
  ```
  sudo ln -nfs "$PWD/volumes/proxy/nginx/genoring-fpm.conf"  /etc/nginx/sites-enabled/genoring.conf
  ```
  Adjust the config file "$PWD/volumes/proxy/nginx/genoring-fpm.conf":
  - replace `${NGINX_PORT}` by the GenoRing port to use for HTTP.
  - replace `${GENORING_HOST}` by the GenoRing server (public) name.
  - replace the path in `root /opt/drupal/web;` by the the path to your
    corresponding Drupal volume directory. You can get it from your GenoRing
    root directory using the command:
    ```
    echo "$PWD/volumes/drupal/web"
    ```
  - replace `fastcgi_pass genoring:9000;` by `fastcgi_pass 127.0.0.1:9010;`.
    "genoring" was resolved in the Docker compose environment as the Drupal
    service but now the proxy is outside Docker compose environement, it needs
    to use the Drupal port exposed by Docker on this host (127.0.0.1) as defined
    before in the docker-compose.yml file (see above).
  - if you want to manage other GenoRing module inclusion manually, watch what
    is in "$PWD/volumes/proxy/nginx/includes" and
    "$PWD/volumes/proxy/nginx/genoring" and adapt the config (ie. remove
    `include genoring/*.conf;` and `include includes/*.conf;` lines).
    Otherwise, you may just do:
    ```
    sudo ln -ns "$PWD/volumes/proxy/nginx/includes"  /etc/nginx/includes
    sudo ln -nfs "$PWD/volumes/proxy/nginx/genoring"  /etc/nginx/genoring
    ```
    and you may have to adjust manually files added there by GenoRing modules.
  - You may need to comment
    ```
    client_max_body_size 512m;
    ```
    if it is already set somewhere else in your global nginx configuration.
- finaly, restart nginx and start GenoRing (the order does not matter).
