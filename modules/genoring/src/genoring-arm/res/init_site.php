<?php
use Drupal\node\Entity\Node;
use Drupal\user\Entity\Role;
use Drupal\user\RoleInterface;

/**
 * This file is used to initialize Drupal content (page, users, terms, ...)
 *
 * Config is not managed here but through config file synchronization.
 */

// Create homepage.
$node = Node::create([
  'type' => 'page',
  'title' => 'Welcome to GenoRing',
  'body' => [
    'value' => 'This is the GenoRing site.',
    'summary' => '',
    'format' => 'full_html',
  ],
  'uid' => 1,
  'status' => TRUE,
  'promote' => TRUE,
  'sticky' => FALSE,
  'path' => [
    'alias' => '/home',
  ],
]);
$node->save();

// Create help page.
$node = Node::create([
  'type' => 'page',
  'title' => 'Help',
  'body' => [
    'value' => 'This is the main help page.',
    'summary' => '',
    'format' => 'full_html',
  ],
  'uid' => 1,
  'status' => TRUE,
  'promote' => FALSE,
  'sticky' => FALSE,
  'path' => [
    'alias' => '/help',
  ],
]);
$node->save();

// Create tools page.
$node = Node::create([
  'type' => 'page',
  'title' => 'Tools',
  'body' => [
    'value' => 'This is the available tool list with descriptions.',
    'summary' => '',
    'format' => 'full_html',
  ],
  'uid' => 1,
  'status' => TRUE,
  'promote' => FALSE,
  'sticky' => FALSE,
  'path' => [
    'alias' => '/tools',
  ],
]);
$node->save();

// Set default permissions.
$all_roles = Role::loadMultiple([
  RoleInterface::ANONYMOUS_ID,
  RoleInterface::AUTHENTICATED_ID
]);

$all_permissions = [
  'use brapi',
];

foreach ($all_permissions as $permission) {
  $all_roles[RoleInterface::AUTHENTICATED_ID]->grantPermission($permission);
  $all_roles[RoleInterface::ANONYMOUS_ID]->grantPermission($permission);
}

$all_roles[RoleInterface::AUTHENTICATED_ID]->save();
$all_roles[RoleInterface::ANONYMOUS_ID]->save();
