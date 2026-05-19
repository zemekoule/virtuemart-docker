#!/bin/bash
# Po nahrání VirtueMart zipu (Extensions: Install → Upload Package File) je
# potřeba před spuštěním "Install Sample Data" / před první navigací do VM
# admina udělat dva kroky, které VM defaultně nezařídí sám:
#
#   1) Povolit plugin `vmshipment - weight_countries` (defaultně enabled=0).
#      Bez něj sample importer padá v PHP 8+ na
#      "Attempt to assign property name on null" (helpers/vdispatcher.php:240).
#
#   2) Nakonfigurovat VM Safe Path. VM ho po čisté instalaci nemá nastavený
#      a hází na každé stránce admina warning "vmError: Warning, the Safe
#      Path is not configured yet". V devu volíme fixní cestu uvnitř webroot
#      (`<admin>/components/com_virtuemart/safepath/`) — bind-mountnutá přes
#      ./src/, takže přežije `docker compose restart`. Pro produkční prostředí
#      by se hodila cesta mimo webroot, ale tady řešíme jen dev nag.
#
# Skript je idempotentní — opakovaný běh nedělá nic, pokud je vše už nastavené.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! docker compose ps --services --status running | grep -qx mysql; then
  echo "MariaDB kontejner neběží — spusť napřed ./scripts/up.sh"
  exit 1
fi
if ! docker compose ps --services --status running | grep -qx joomla; then
  echo "Joomla kontejner neběží — spusť napřed ./scripts/up.sh"
  exit 1
fi

# ---------------------------------------------------------------------------
# 1) Plugin weight_countries
# ---------------------------------------------------------------------------
echo "1) Povoluji vmshipment - weight_countries plugin..."

docker compose exec -T mysql mariadb -uroot -pasdf joomla 2>&1 <<'SQL' | grep -v '\[Warning\]' || true
UPDATE joom_extensions
   SET enabled = 1
 WHERE folder  = 'vmshipment'
   AND element = 'weight_countries'
   AND enabled = 0;

SELECT
  CASE
    WHEN (SELECT enabled FROM joom_extensions
          WHERE folder='vmshipment' AND element='weight_countries') = 1
    THEN 'OK: weight_countries enabled=1'
    ELSE 'WARN: weight_countries je stále enabled=0 — zkontroluj DB ručně'
  END AS result;
SQL

# ---------------------------------------------------------------------------
# 2) Safe Path — vytvořit adresář + zapsat do joom_virtuemart_configs.config
# ---------------------------------------------------------------------------
SAFEPATH=/var/www/html/administrator/components/com_virtuemart/safepath

echo "2) Vytvářím Safe Path adresář ($SAFEPATH/, keys/, invoices/)..."
docker compose exec -T -u www-data joomla mkdir -p "$SAFEPATH/keys" "$SAFEPATH/invoices"
echo "   ✓ adresáře existují"

echo "3) Nastavuji forSale_path v joom_virtuemart_configs.config..."

docker compose exec -T -u www-data joomla php <<'PHP'
<?php
// VM ukládá hlavní config jako custom-serialized string v
// joom_virtuemart_configs.config:  key1="value1"|key2="value2"|...
// Slashes v hodnotách jsou JSON-style escapované (\/). Místo lámání SQL
// REPLACE escapováním přečteme config přes PDO, upravíme regexem a uložíme zpět.
$pdo = new PDO('mysql:host=dev_db;dbname=joomla;charset=utf8mb4',
               'root', 'asdf',
               [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);

$row = $pdo->query("SELECT config FROM joom_virtuemart_configs WHERE virtuemart_config_id=1")
           ->fetch(PDO::FETCH_ASSOC);
if (!$row) {
    fwrite(STDERR, "ERR: joom_virtuemart_configs#1 nenalezen — VM možná není nainstalován\n");
    exit(1);
}

$newPath     = '/var/www/html/administrator/components/com_virtuemart/safepath/';
$escapedPath = str_replace('/', '\\/', $newPath);
$replacement = 'forSale_path="' . $escapedPath . '"';

$newConfig = preg_replace('/forSale_path="[^"]*"/', $replacement, $row['config'], 1, $count);
if ($count === 0) {
    fwrite(STDERR, "WARN: forSale_path key nenalezen v config — VM verze možná používá jiné jméno\n");
    exit(2);
}
if ($newConfig === $row['config']) {
    echo "   ✓ forSale_path už nastaveno na cílovou hodnotu (skip)\n";
    exit(0);
}

$stmt = $pdo->prepare("UPDATE joom_virtuemart_configs SET config = ? WHERE virtuemart_config_id = 1");
$stmt->execute([$newConfig]);
echo "   ✓ forSale_path nastaveno na $newPath\n";
PHP

cat <<EOF

Hotovo. Teď můžeš:
  - z VirtueMart post-install obrazovky kliknout "Install Sample Data"
    bez chyby v PHP 8+,
  - libovolně navigovat ve VM adminu bez Safe Path warningu.
EOF
