<?php
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Add JBrowse2 to main menu.
// @todo Implement and use GenoRing dedicated functions to manage menu items.
$menu_link = MenuLinkContent::create(["title" => "JBrowse2", "link" => ["uri" => "internal:/jbrowse2/"], "menu_name" => "main", "expanded" => TRUE, ]);
$menu_link->save();
