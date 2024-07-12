#!/bin/bash

# Automatically exit on error.
set -e

# Add JBrowse2 menu item.
drush -y php:eval 'use Drupal\menu_link_content\Entity\MenuLinkContent; $menu_link = MenuLinkContent::create(["title" => "JBrowse2", "link" => ["uri" => "internal:/jbrowse2/"], "menu_name" => "main", "expanded" => TRUE, ]); $menu_link->save();'
