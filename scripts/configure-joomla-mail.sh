#!/bin/bash
# Nastaví Joomla mail config tak, aby odesílal přes Mailpit (kontejner `mailpit`, SMTP :1025).
#
# Patchuje `configuration.php` skriptem (ne ručně) — odpovídá pravidlu z CLAUDE.md
# "src/ neupravujeme rukou". Bind-mount způsobí, že úprava v kontejneru se propíše
# i do `src/configuration.php` na hostu, kde Joomla auto-installer toto file uložil.
# Idempotentní — bezpečně opakovatelné.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! docker compose ps --services --status running | grep -qx joomla; then
  echo "Joomla kontejner neběží — spusť napřed ./scripts/up.sh"
  exit 1
fi

echo "Patchuji /var/www/html/configuration.php (mail config)..."

docker compose exec -T -u www-data joomla php <<'PHP'
<?php
$path = '/var/www/html/configuration.php';
$src = file_get_contents($path);
if ($src === false) {
    fwrite(STDERR, "Nepodařilo se načíst $path\n");
    exit(1);
}

$updates = [
    'mailer'     => 'smtp',
    'mailfrom'   => 'admin@example.com',
    'fromname'   => 'VirtueMart Dev',
    'smtpauth'   => false,
    'smtpuser'   => '',
    'smtppass'   => '',
    'smtphost'   => 'mailpit',
    'smtpsecure' => 'none',
    'smtpport'   => 1025,
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
    echo "Žádné změny — config je už nastavený.\n";
}
PHP

cat <<EOF

Mail teď chodí přes Mailpit: http://localhost:8025
Doporučení: zkontroluj end-to-end přes
  ./scripts/send-test-mail.sh
a uvidíš zprávu v Mailpitu.
Pokud chceš mít tento stav v baseline DB dumpu, udělej nový snapshot:
  ./scripts/db-snapshot.sh clean-joomla-vm-mail
(Pozn.: mail config sám o sobě je v configuration.php na souborovém systému, ne v DB —
ale když se přepneš mezi snapshoty, configuration.php zůstane, takže to nevadí.)
EOF