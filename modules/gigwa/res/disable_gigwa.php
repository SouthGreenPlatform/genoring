<?php
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Remove Gigwa menu item.
// @todo Implement and use GenoRing dedicated functions to manage menu items.
$gigwa_menuitems = \Drupal::entityTypeManager()->getStorage('menu_link_content')->loadByProperties(['title' => 'Gigwa']);
foreach ($gigwa_menuitems as $gigwa_menuitem) {
  $gigwa_menuitem->delete();
}
