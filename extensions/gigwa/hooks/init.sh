#!/bin/bash

# Install Gigwa config.
docker run -it -v $(pwd)/volumes/gigwa:/copy  --entrypoint=/bin/cp guilhemsempere/gigwa:2.8-RELEASE -r /usr/local/tomcat/config /copy
