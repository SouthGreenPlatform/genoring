<?php
use Drupal\node\Entity\Node;
use Drupal\user\Entity\Role;
use Drupal\user\RoleInterface;

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
