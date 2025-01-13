<?php

/**
 * This script handles a subset of GenoRing core API commands.
 *
 * Some core commands require YAML file parsing and PHP code. To simplify
 * code maintenance, those commands are handled here and called by
 * `drush php:script <COMMAND> <ABSOLUTE_YAML_FILE_PATH>` in a Drupal
 * environment.
 */

use Drupal\menu_link_content\Entity\MenuLinkContent;
use Drupal\node\Entity\Node;
use Drupal\site_integrator\Entity\IntegratedSite;
use Drupal\site_integrator\Entity\IntegratedSiteInterface;
use Symfony\Component\Yaml\Exception\ParseException;
use Symfony\Component\Yaml\Yaml;
use Drush\Drush;

/**
 * Converts a given name into a machine name.
 *
 * @param string $name
 *   The name to convert.
 * @param string $replacement
 *   Replacement character. Default to '_'
 *
 * @return string
 *   The corresponding machine name.
 */
function toMachineName(string $name, string $replacement = '_') {
  return preg_replace('/\W/', $replacement, strtolower($name));
}

// Get and check arguments.
[$command, $yaml_path] = $extra;

if (!$command) {
  fwrite(STDERR, "ERROR: GenoRing API: Missing command name!\n");
  exit(1);
}

if (!$yaml_path) {
  fwrite(STDERR, "ERROR: GenoRing API: Missing YAML file path!\n");
  exit(1);
}

if (!file_exists($yaml_path)) {
  fwrite(STDERR, "ERROR: GenoRing API: File '$yaml_path' not found!\n");
  exit(1);
}

// Parse YAML file.
$yaml = '';
try {
  $yaml = Yaml::parseFile($yaml_path);
}
catch (ParseException $e) {
  $err_line = $e->getParsedLine();
  if (0 <= $err_line) {
    fwrite(
      STDERR,
      'Failed to parse Yaml file "'
      . $yaml_path
      . '" near line '
      . $e->getParsedLine()
      . ': '
      . $e->getSnippet()
      . "\n"
    );
  }
  else {
    fwrite(
      STDERR,
      'Failed to parse Yaml file "'
      . $yaml_path
      . "\"\n"
    );
  }
  exit(1);
}

// Process the given command.
// For drush commands, see https://github.com/drush-ops/drush/tree/13.x/src/Commands/core .
switch ($command) {

  case 'add_menuitem':
    // Check parameters.
    if (empty($yaml['label'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing menu label ('label' field in '$yaml_path')!\n");
      exit(1);
    }
    if (empty($yaml['uri'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing menu URI ('uri' field in '$yaml_path')!\n");
      exit(1);
    }
    if (empty($yaml['menu'])) {
      $yaml['menu'] = 'main';
    }

    if (0 !== stripos($yaml['uri'], 'http')) {
      if ('/' == $yaml['uri'][0]) {
        $yaml['uri'] = 'internal:' . $yaml['uri'];
      }
      else {
        $yaml['uri'] = 'internal:/' . $yaml['uri'];
      }
    }

    $menuitem = \Drupal::entityTypeManager()
      ->getStorage('menu_link_content')
      ->loadByProperties(['link.uri' => $yaml['uri']]);
    if (empty($menuitem)) {
      // Add meu item.
      $menuitem = [
          'title' => $yaml['label'],
          'link' => [
            'uri' => $yaml['uri'],
          ],
          'menu_name' => $yaml['menu'],
        ]
        // Add provided settings.
        + $yaml
        // Complete with defaults for missing values.
        + [
          'expanded' => TRUE,
        ];
      MenuLinkContent::create($menuitem)->save();
    }
    break;

  case 'remove_menuitem':
    // Check parameters.
    if (empty($yaml['uri'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing menu URI ('uri' field in '$yaml_path')!\n");
      exit(1);
    }

    if (0 !== stripos($yaml['uri'], 'http')) {
      if ('/' == $yaml['uri'][0]) {
        $yaml['uri'] = 'internal:' . $yaml['uri'];
      }
      else {
        $yaml['uri'] = 'internal:/' . $yaml['uri'];
      }
    }
    // Remove matching menu items.
    $menuitems = \Drupal::entityTypeManager()
      ->getStorage('menu_link_content')
      ->loadByProperties(['link.uri' => $yaml['uri']]);
    foreach ($menuitems as $menuitem) {
      $menuitem->delete();
    }
    break;

  case 'add_page':
    // Check parameters.
    if (empty($yaml['name'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing page name ('name' field in '$yaml_path')!\n");
      exit(1);
    }
    if (empty($yaml['title'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing page title ('title' field in '$yaml_path')!\n");
      exit(1);
    }
    if (empty($yaml['content'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing page content ('content' field in '$yaml_path')!\n");
      exit(1);
    }

    $page_data = [
      'title' => $yaml['title'],
      'body' => $yaml['content'],
      'path' => [
        [
          'alias' => '/' . toMachineName($yaml['name'], '-'),
        ],
      ],
    ]
    // Add provided settings.
    + $yaml
    // Complete with defaults for missing values.
    + [
      'type' => 'page',
    ];

    $node = Node::create($page_data)->save();
    break;

  case 'remove_page':
    // Check parameters.
    if (empty($yaml['name'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing page name ('name' field in '$yaml_path')!\n");
      exit(1);
    }

    // Remove matching page.
    $pages = \Drupal::entityTypeManager()
      ->getStorage('node')
      ->loadByProperties(['path.alias' => '/' . toMachineName($yaml['name'], '-')]);
    foreach ($pages as $page) {
      $page->delete();
    }
    break;

  case 'add_integration':
    // Check parameters.
    if (empty($yaml['name'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing integration name ('name' field in '$yaml_path')!\n");
      exit(1);
    }
    if (empty($yaml['uri'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing URI ('uri' field in '$yaml_path')!\n");
      exit(1);
    }
    if (empty($yaml['path'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing site path ('path' field in '$yaml_path')!\n");
      exit(1);
    }
    // Integrate.
    $integration = [
        'id' => toMachineName($yaml['name']),
        'label' => $yaml['name'],
        'base_url' => $yaml['uri'],
        'path' => $yaml['path'],
      ]
      // Add provided settings.
      + $yaml
      // Complete with defaults for missing values.
      + [
        'height' => '',
        'width' => '',
        'mode' => IntegratedSiteInterface::INTEGRATION_MODE_INTERNAL_IFRAME,
        'passthrough' => [],
        'enabled' => TRUE,
        'editable' => TRUE,
        'verify' => FALSE,
        'redirections' => [],
        'filtering' => [],
        'roles' => [],
      ];
    \Drupal::entityTypeManager()->getStorage('integrated_site')
      ->create($integration)
      ->save();
    break;

  case 'remove_integration':
    // Check parameters.
    if (empty($yaml['name'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing integration name ('name' field in '$yaml_path')!\n");
      exit(1);
    }
    $integration = \Drupal::entityTypeManager()
      ->getStorage('integrated_site')
      ->load(toMachineName($yaml['name']));
    if ($integration) {
      $integration->delete();
    }
    break;

  case 'add_user':
    // Check parameters.
    if (empty($yaml['user_name'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing user name ('user_name' field in '$yaml_path')!\n");
      exit(1);
    }
    if (empty($yaml['email'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing user e-mail ('email' field in '$yaml_path')!\n");
      exit(1);
    }
    if (empty($yaml['password'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing user password ('password' field in '$yaml_path')!\n");
      exit(1);
    }

    // Add user.
    $site_alias = Drush::service('site.alias.manager')->getSelf();
    $process = Drush::processManager()->drush(
      $site_alias,
      'user:create',
      ['name' => $yaml['user_name']],
      [
        'password' => $yaml['password'],
        'mail' => $yaml['email'],
      ],
    );
    if ($process->run()) {
       fwrite(STDERR, $process->getErrorOutput());
       exit(1);
    }
    else {
       echo $process->getOutput();
    }
    break;

  case 'remove_user':
    // Check parameters.
    if (empty($yaml['user_name'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing user name ('user_name' field in '$yaml_path')!\n");
      exit(1);
    }

    // Remove user.
    $site_alias = Drush::service('site.alias.manager')->getSelf();
    $process = Drush::processManager()->drush(
      $site_alias,
      'user:cancel',
      ['names' => $yaml['user_name']],
      ['reassign-content' => TRUE],
    );
    if ($process->run()) {
       fwrite(STDERR, $process->getErrorOutput());
       exit(1);
    }
    else {
       echo $process->getOutput();
    }
    break;

  case 'add_group':
    // Check parameters.
    if (empty($yaml['group_name'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing group name ('group_name' field in '$yaml_path')!\n");
      exit(1);
    }

    // Add role.
    $site_alias = Drush::service('site.alias.manager')->getSelf();
    $process = Drush::processManager()->drush(
      $site_alias,
      'role:create',
      [
        'machine_name' => toMachineName($yaml['group_name']),
        'human_readable_name' => $yaml['group_name'],
      ],
    );
    if ($process->run()) {
       fwrite(STDERR, $process->getErrorOutput());
       exit(1);
    }
    else {
       echo $process->getOutput();
    }
    break;

  case 'remove_group':
    // Check parameters.
    if (empty($yaml['group_name'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing group name ('group_name' field in '$yaml_path')!\n");
      exit(1);
    }

    // Remove role.
    $site_alias = Drush::service('site.alias.manager')->getSelf();
    $process = Drush::processManager()->drush(
      $site_alias,
      'role:delete ',
      [
        'machine_name' => toMachineName($yaml['group_name']),
      ],
    );
    if ($process->run()) {
       fwrite(STDERR, $process->getErrorOutput());
       exit(1);
    }
    else {
       echo $process->getOutput();
    }
    break;

  case 'add_user_to_group':
    // Check parameters.
    if (empty($yaml['user_name'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing user name ('user_name' field in '$yaml_path')!\n");
      exit(1);
    }
    if (empty($yaml['group_name'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing group name ('group_name' field in '$yaml_path')!\n");
      exit(1);
    }

    // Add user to role.
    $site_alias = Drush::service('site.alias.manager')->getSelf();
    $process = Drush::processManager()->drush(
      $site_alias,
      'user:role:add',
      [
        'role' => toMachineName($yaml['group_name']),
        'names' => $yaml['user_name'],
      ],
    );
    if ($process->run()) {
       fwrite(STDERR, $process->getErrorOutput());
       exit(1);
    }
    else {
       echo $process->getOutput();
    }
    break;

  case 'remove_user_from_group':
    // Check parameters.
    if (empty($yaml['user_name'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing user name ('user_name' field in '$yaml_path')!\n");
      exit(1);
    }
    if (empty($yaml['group_name'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing group name ('group_name' field in '$yaml_path')!\n");
      exit(1);
    }

    // Remove user from role.
    $site_alias = Drush::service('site.alias.manager')->getSelf();
    $process = Drush::processManager()->drush(
      $site_alias,
      'user:role:remove',
      [
        'role' => toMachineName($yaml['group_name']),
        'names' => $yaml['user_name'],
      ],
    );
    if ($process->run()) {
       fwrite(STDERR, $process->getErrorOutput());
       exit(1);
    }
    else {
       echo $process->getOutput();
    }
    break;


  case 'add_permission':
    // Check parameters.
    if (empty($yaml['group_name'])) {
      $yaml['group_name'] = 'anonymous';
    }
    if (empty($yaml['permission'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing permission name ('permission' field in '$yaml_path')!\n");
      exit(1);
    }

    // Add permission to role.
    $site_alias = Drush::service('site.alias.manager')->getSelf();
    $process = Drush::processManager()->drush(
      $site_alias,
      'role:perm:add',
      [
        'machine_name' => toMachineName($yaml['group_name']),
        'permissions' => $yaml['permission'],
      ],
    );
    if ($process->run()) {
       fwrite(STDERR, $process->getErrorOutput());
       exit(1);
    }
    else {
       echo $process->getOutput();
    }
    break;

  case 'remove_permission':
    // Check parameters.
    if (empty($yaml['group_name'])) {
      $yaml['group_name'] = 'anonymous';
    }
    if (empty($yaml['permission'])) {
      fwrite(STDERR, "ERROR: GenoRing API: Missing permission name ('permission' field in '$yaml_path')!\n");
      exit(1);
    }

    // Remove permission from role.
    $site_alias = Drush::service('site.alias.manager')->getSelf();
    $process = Drush::processManager()->drush(
      $site_alias,
      'role:perm:remove',
      [
        'machine_name' => toMachineName($yaml['group_name']),
        'permissions' => $yaml['permission'],
      ],
    );
    if ($process->run()) {
       fwrite(STDERR, $process->getErrorOutput());
       exit(1);
    }
    else {
       echo $process->getOutput();
    }
    break;

  default:
    fwrite(STDERR, "ERROR: GenoRing API: Unsupported command name '$command'!\n");
    exit(1);
    break;
}
