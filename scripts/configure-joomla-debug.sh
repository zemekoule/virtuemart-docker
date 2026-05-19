#!/bin/bash
# Zapne Joomla debug mode + maximum error reporting — místo generického
# "An error has occurred" uvidíš plný stack trace, vč. PHP deprecation warningů.
#
# Patchuje `configuration.php` skriptem (ne ručně) — odpovídá pravidlu z CLAUDE.md
# "src/ neupravujeme rukou". Idempotentní.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! docker compose ps --services --status running | grep -qx joomla; then
  echo "Joomla kontejner neběží — spusť napřed ./scripts/up.sh"
  exit 1
fi

echo "Patchuji /var/www/html/configuration.php (debug + error_reporting)..."

docker compose exec -T -u www-data joomla php <<'PHP'
<?php
$path = '/var/www/html/configuration.php';
$src = file_get_contents($path);
if ($src === false) {
    fwrite(STDERR, "Nepodařilo se načíst $path\n");
    exit(1);
}

$updates = [
    'debug'           => true,
    'error_reporting' => 'maximum',
];

$changed = 0;
foreach ($updates as $key => $val) {
    if (is_bool($val)) {
        $newVal = $val ? 'true' : 'false';
    } elseif (is_int($val)) {
        $newVal = (string) $val;
    } else {
        $newVal = "'" . str_replace(['\\', "'"], ['\\\\', "\\'"], $val) . "'";
    }
    $pattern = '/(public\s+\$' . preg_quote($key, '/') . '\s*=\s*)([^;]+)(;)/';
    $new = preg_replace($pattern, '${1}' . $newVal . '${3}', $src, 1, $count);
    if ($count === 0) {
        fwrite(STDERR, "Klíč '$key' v configuration.php nenalezen — přeskočeno.\n");
        continue;
    }
    if ($new !== $src) {
        $src = $new;
        $changed++;
    }
}

if ($changed > 0) {
    if (file_put_contents($path, $src) === false) {
        fwrite(STDERR, "Zápis do $path selhal\n");
        exit(1);
    }
    echo "Hotovo, upraveno klíčů: $changed\n";
} else {
    echo "Žádné změny — debug už zapnutý.\n";
}
PHP