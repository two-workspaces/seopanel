<?php
// Installs (php sp-setup.php install) or upgrades (... upgrade) the Seo Panel database
// from the CLI, with the same steps install/index.php and install/upgrade.php take in
// the browser.
mysqli_report(MYSQLI_REPORT_OFF);  // the installer checks return values, PHP 8.1+ throws
chdir('/var/www/html/install');
define('SP_INSTALL_DIR', getcwd());
define('SP_UPGRADE_DB_FILE', SP_INSTALL_DIR.'/data/upgrade.sql');
include_once SP_INSTALL_DIR.'/install.class.php';
include_once SP_INSTALL_DIR.'/dbi.class.php';
include_once SP_INSTALL_DIR.'/../config/sp-config.php';

$db = new DBI();
$err = $db->connectDatabase(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);
if ($db->error) { fwrite(STDERR, "$err\n"); exit(1); }
$install = new Install();

if ($argv[1] == 'install') {
	foreach (['seopanel.sql', 'textlang.sql'] as $f) {
		$err = $db->importDatabaseFile(SP_INSTALL_DIR."/data/$f");
		if ($db->error) { fwrite(STDERR, "$f: $err\n"); exit(1); }
	}
	$pass = getenv('SEOPANEL_ADMIN_PASSWORD');
	$email = getenv('SEOPANEL_ADMIN_EMAIL') ?: 'admin@example.com';
	if (!$pass) { fwrite(STDERR, "SEOPANEL_ADMIN_PASSWORD is not set\n"); exit(1); }
	$db->query("update users set password='".md5($pass)."', email='".addslashes($email)."' where id=1");
} else {
	// Statements an older version already applied fail and are skipped, as in the browser.
	foreach ($install->getUpgradeDBFiles($db) as $f) $db->importDatabaseFile($f, false);
	$db->importDatabaseFile(SP_INSTALL_DIR.'/data/textlang.sql', false);
}
// Written last: its presence marks a finished install.
$install->createSeoPanelAPIKey($db);
