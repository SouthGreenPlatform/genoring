#!/bin/bash

# Automatically exit on error.
set -e

# Add JBrowse menu item.
drush -y scr /genoring/modules/jbrowse/res/init_site.php
