#!/bin/bash

# Automatically exit on error.
set -e

# Add JBrowse2 menu item.
drush -y scr /genoring/modules/jbrowse2/res/init_site.php
