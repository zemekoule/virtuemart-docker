#!/bin/bash
# Po nahrání VirtueMart zipu (Extensions: Install → Upload Package File) je
# potřeba před spuštěním "Install Sample Data" povolit plugin
# `vmshipment - weight_countries`, jinak sample importer padá v PHP 8+ na
# "Attempt to assign property name on null" (helpers/vdispatcher.php:240).
#
# Tenhle skript to udělá za tebe SQL UPDATEem (idempotentní), takže můžeš
# z post-install obrazovky VM kliknout rovnou na "Install Sample Data"
# bez navigace do Extensions → Plugins.
#
# Pokud sem v budoucnu přibudou další "extra" nastavení, která VM po
# defaultní instalaci potřebuje (a která sample importer / běh storefrontu
# vyžaduje), přidávej je do bloku níže.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! docker compose ps --services --status running | grep -qx mysql; then
  echo "MariaDB kontejner neběží — spusť napřed ./scripts/up.sh"
  exit 1
fi

echo "Povoluji vmshipment - weight_countries plugin..."

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

cat <<EOF

Hotovo. Teď můžeš z VirtueMart post-install obrazovky (nebo
Components → VirtueMart → Tools & Migration) kliknout na "Install Sample Data"
bez chyby v PHP 8+.
EOF
