<?php
/**
 * @file
 * Drush alias file.
 *
 * Alias files that are named after the single alias they contain
 * may use the syntax for the canonical alias shown at the top of
 * this file, or they may set values in $options, just
 * like a drushrc.php configuration file:
 *
 * @code
 * $options['uri'] = 'http://mysite.com';
 * $options['root'] = '/var/www/path/to/drupal';
 * @endcode
 *
 * When alias files use this form, then the name of the alias
 * is taken from the first part of the alias filename.
 *
 * e.g., Filename: MYSITE.aliases.drushrc.php == drush @mysite [command]
 */
$aliases['mysite'] = array(
  'root' => '/var/www/drupal_root',
  'uri' => 'http://mysite.dev',
);

