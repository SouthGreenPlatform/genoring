<?php
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Add Gigwa to main menu.
// @todo Implement and use GenoRing dedicated functions to manage menu items.
$menu_link = MenuLinkContent::create(["title" => "Gigwa", "link" => ["uri" => "internal:/gigwa/"], "menu_name" => "main", "expanded" => TRUE, ]);
$menu_link->save();
