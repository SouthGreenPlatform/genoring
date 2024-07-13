#!/bin/bash

# Remove Gigwa menu item.
# drush -y php:eval 'use Drupal\menu_link_content\Entity\MenuLinkContent; $menu_link = MenuLinkContent::create(["title" => "Gigwa", "link" => ["uri" => "internal:/gigwa/"], "menu_name" => "main", "expanded" => TRUE, ]); $menu_link->save();'
