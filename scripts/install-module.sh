#!/bin/bash
# Zazipuje a nainstaluje modul Packeta do běžící Joomly přes joomla.php CLI.
# Použití: po prvotním instalu odkomentovat v docker-compose.yml druhý bind-mount
# (./modules/packeta → plugins/vmshipment/zasilkovna) a dál stačí restart kontejneru.
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "${SCRIPT_DIR}/.."

ZIP="packeta.zip"
TMP_IN_CONTAINER="/tmp/packeta.zip"

"${SCRIPT_DIR}/pack-module.sh"

if ! docker compose ps --services --status running | grep -qx joomla; then
  echo "Joomla kontejner neběží — spusť napřed ./scripts/up.sh"
  exit 1
fi

echo "Kopíruju ${ZIP} do kontejneru..."
docker compose cp "$ZIP" "joomla:${TMP_IN_CONTAINER}"

echo "Spouštím Joomla CLI install..."
docker compose exec -T -u www-data joomla php cli/joomla.php extension:install --path "$TMP_IN_CONTAINER"

echo "Úklid /tmp v kontejneru..."
docker compose exec -T joomla rm -f "$TMP_IN_CONTAINER"

echo "Hotovo. Plugin zkontroluj v adminu: Extensions → Plugins, filter 'vmshipment'."