<?php
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Add JBrowse to main menu.
// @todo Implement and use GenoRing dedicated functions to manage menu items.
$menu_link = MenuLinkContent::create(["title" => "JBrowse", "link" => ["uri" => "internal:/jbrowse/"], "menu_name" => "main", "expanded" => TRUE, ]);
$menu_link->save();
