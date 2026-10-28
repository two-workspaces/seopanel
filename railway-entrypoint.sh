#!/bin/bash
# Railway entrypoint for Seo Panel: the config written from the service variables, the
# database installed on first boot with a generated admin password (the web installer
# is never reachable) and upgraded when the image brings a new release, the report and
# site-auditor crons in the background.
set -euo pipefail

# Railway flattens the image layers, which brings back the mpm_event links the PHP
# image deleted: "AH00534: More than one MPM loaded". mod_php needs prefork only.
rm -f /etc/apache2/mods-enabled/mpm_event.* /etc/apache2/mods-enabled/mpm_worker.*
# Prefork's default of 150 processes would outgrow a small plan; a Seo Panel page takes
# 20-40 MB.
printf '<IfModule mpm_prefork_module>\n\tMaxRequestWorkers %s\n</IfModule>\n' \
  "${SEOPANEL_APACHE_WORKERS:-20}" > /etc/apache2/conf-enabled/zz-workers.conf

: "${SEOPANEL_URL:?SEOPANEL_URL is not set: the site address, https://<your domain>}"
: "${DB_HOST:?DB_HOST is not set}" "${DB_PASSWORD:?DB_PASSWORD is not set}"
export DB_NAME=${DB_NAME:-seopanel} DB_USER=${DB_USER:-root}
php -r '
$c = ["SP_WEBPATH" => rtrim(getenv("SEOPANEL_URL"), "/"), "DB_NAME" => getenv("DB_NAME"),
  "DB_USER" => getenv("DB_USER"), "DB_PASSWORD" => getenv("DB_PASSWORD"), "DB_HOST" => getenv("DB_HOST"),
  "DB_ENGINE" => "mysql", "SP_INSTALLED" => getenv("SEOPANEL_VERSION"), "SP_DEBUG" => 0, "SP_TIMEOUT" => 18000];
$s = "<?php\n// Written by the Railway entrypoint on every start; set the service variables instead.\n";
foreach ($c as $k => $v) $s .= "define(\"$k\", " . var_export($v, true) . ");\n";
file_put_contents("config/sp-config.php", $s);'
chmod 644 config/sp-config.php

trap 'kill $(jobs -p) 2>/dev/null; wait; exit 0' TERM INT

# On a fresh deploy MariaDB may still be initializing.
q() { MYSQL_PWD=$DB_PASSWORD mariadb -h "$DB_HOST" -u "$DB_USER" -N -B "$DB_NAME" -e "$1"; }
for i in $(seq 90); do
  q 'select 1' >/dev/null 2>&1 && break
  [ "$i" = 90 ] && { echo "railway: database not reachable after 3 minutes"; exit 1; }
  sleep 2
done

# The API key is written last, so tables without it are an install that was cut short
# (a redeploy during the first boot): no data yet, so clear them and start over.
installed=$(q "select count(*) from information_schema.tables where table_schema = database() and table_name = 'settings'")
[ "$installed" = 1 ] && installed=$(q "select count(*) from settings where set_name = 'SP_API_KEY' and set_val <> ''")
if [ "$installed" = 0 ]; then
  tables=$(q "select group_concat(concat('\`', table_name, '\`')) from information_schema.tables where table_schema = database()")
  if [ "$tables" != NULL ]; then
    echo "railway: an earlier install did not finish; clearing it and starting over"
    q "drop table $tables"
  fi
  echo "railway: first boot, installing Seo Panel $SEOPANEL_VERSION"
  php /usr/local/share/seopanel/sp-setup.php install
else
  current=$(q "select set_val from settings where set_name = 'SP_VERSION_NUMBER'")
  if [ "$current" != "$SEOPANEL_VERSION" ]; then
    echo "railway: upgrading the database from Seo Panel $current to $SEOPANEL_VERSION"
    php /usr/local/share/seopanel/sp-setup.php upgrade
  fi
fi

apache2-foreground &
echo "railway: Seo Panel $SEOPANEL_VERSION is up at $SEOPANEL_URL (login: spadmin)"

# The crons Seo Panel asks for every 15 minutes: scheduled reports (rank, backlinks,
# saturation...) and the site auditor. They read the code path from the working
# directory.
while sleep 900; do
  for job in cron.php siteauditorcron.php; do
    setpriv --reuid=www-data --regid=www-data --init-groups php "$job" >/dev/null 2>&1 \
      || echo "railway: $job failed"
  done
done &

wait -n
exit 1
