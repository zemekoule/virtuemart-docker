#!/bin/bash
# Force clean reinstall modulu Packeta.
#
# Smaže DB stopy modulu (extension row + plug-in tabulky) a spustí čistý install.
# Joomlu `extension:remove` ZÁMĚRNĚ NEPOUŽÍVÁ — s aktivním druhým bind-mountem
# (./modules/packeta → /plugins/vmshipment/zasilkovna) by Joomla při uninstallu
# mazala i source soubory v ./modules/packeta na hostu. Místo toho čistíme DB
# rovnou a soubory necháme být.
#
# Použij, když změníš `zasilkovna.xml` / `install.sql` / lang soubory a chceš
# úplně čistý install (ne update path).
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "${SCRIPT_DIR}/.."

# Joomla DB prefix — viz src/configuration.php ($dbprefix). Pro náš joomla image default je joom_.
PREFIX="joom_"

if ! docker compose ps --services --status running | grep -qx joomla; then
  echo "Joomla kontejner neběží — spusť napřed ./scripts/up.sh"
  exit 1
fi

cat <<EOF
Pozor: tohle je destruktivní operace. Smaže se:
  - row v \`${PREFIX}extensions\` (folder=vmshipment, element=zasilkovna)
  - tabulka \`${PREFIX}virtuemart_shipment_plg_zasilkovna\`
  - tabulka \`${PREFIX}virtuemart_zasilkovna_carriers\`
  - tabulka \`${PREFIX}virtuemart_shipment_plg_zasilkovna_backup\` (pokud existuje)
  - tabulka \`${PREFIX}virtuemart_zasilkovna_branches\` (legacy, pokud existuje)
Data v těch tabulkách (carrier configs, pickup points apod.) přijdou nenávratně.
Pokud to chceš zachránit, udělej napřed ./scripts/db-snapshot.sh <name>.
EOF
echo
read -r -p "Pokračovat? [y/N] " ans
case "$ans" in
  y|Y|yes) ;;
  *) echo "Zrušeno."; exit 0 ;;
esac

echo "Čistím DB stopy modulu..."
docker compose exec -T mysql mariadb -uroot -pasdf joomla <<SQL
DELETE FROM \`${PREFIX}extensions\` WHERE folder='vmshipment' AND element='zasilkovna';
DROP TABLE IF EXISTS \`${PREFIX}virtuemart_shipment_plg_zasilkovna\`;
DROP TABLE IF EXISTS \`${PREFIX}virtuemart_zasilkovna_carriers\`;
DROP TABLE IF EXISTS \`${PREFIX}virtuemart_shipment_plg_zasilkovna_backup\`;
DROP TABLE IF EXISTS \`${PREFIX}virtuemart_zasilkovna_branches\`;
SQL

echo "Spouštím čistý install..."
"${SCRIPT_DIR}/install-module.sh"