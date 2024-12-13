#!/bin/sh

# Automatically exit on error.
set -e

# Enable Gigwa module.
genoring install_module gigwa

# Add Gigwa menu item.
genoring add_menuitem '/gigwa/' 'Gigwa' 'main'
