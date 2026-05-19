#!/bin/bash
# Smaže veškerý runtime state lokálního dev prostředí. Po jeho běhu stačí pustit
# ./scripts/up.sh a všechno (Joomla install, DB, mail) naběhne od nuly stejně,
# jako při úplně prvním spuštění.
#
# Smaže:
#   - kontejnery (docker compose down)
#   - obsah ./src/        — Joomla install
#   - obsah ./db/         — MariaDB data, vč. VirtueMart sample dat
#   - obsah ./mailpit/    — zachycené test maily
#   - ./packeta.zip       — build artefakt z pack-module.sh
#   - volitelně: Docker image (flag --with-image) — pro rebuild od Dockerfile dál
#
# Zachová: .env, db-snapshots/, modules/packeta/.
set -euo pipefail

cd "$(dirname "$0")/.."

WITH_IMAGE=0
for arg in "$@"; do
  case "$arg" in
    --with-image) WITH_IMAGE=1 ;;
    -h|--help)
      cat <<HELP
Použití: ./scripts/reset-env.sh [--with-image]

Smaže veškerý runtime state lokálního dev prostředí (kontejnery, obsah src/,
db/, mailpit/, packeta.zip). Po jeho běhu stačí pustit ./scripts/up.sh
a všechno naběhne od nuly stejně, jako při prvním spuštění.

Zachovává: .env, db-snapshots/, modules/packeta/.

Flagy:
  --with-image    smazat i Docker image (virtuemart-docker-joomla:latest),
                  další build proběhne od Dockerfile dál
HELP
      exit 0
      ;;
    *) echo "Neznámý argument: $arg"; echo "Použití: ./scripts/reset-env.sh [--with-image]"; exit 1 ;;
  esac
done

cat <<EOF
Tohle smaže veškerý runtime state lokálního dev prostředí:
  - kontejnery (docker compose down)
  - obsah ./src/      (Joomla install)
  - obsah ./db/       (MariaDB data — VEŠKERÁ data, vč. VirtueMart sample dat)
  - obsah ./mailpit/  (zachycené test maily)
  - ./packeta.zip     (pokud existuje)
EOF
if [ "$WITH_IMAGE" -eq 1 ]; then
  echo "  - Docker image virtuemart-docker-joomla:latest"
fi
cat <<EOF

Zachová: .env, db-snapshots/, modules/packeta/.
Po dokončení spusť ./scripts/up.sh pro čistou instalaci od nuly.
EOF
echo
read -r -p "Pokračovat? [y/N] " ans
case "$ans" in
  y|Y|yes) ;;
  *) echo "Zrušeno."; exit 0 ;;
esac

echo "Zastavuji kontejnery..."
docker compose down

echo "Mažu runtime state..."
for dir in src db mailpit; do
  rm -rf "$dir"
  mkdir "$dir"
done
rm -f packeta.zip

if [ "$WITH_IMAGE" -eq 1 ]; then
  echo "Mažu Docker image..."
  docker image rm virtuemart-docker-joomla:latest 2>/dev/null || echo "(image neexistuje, OK)"
fi

cat <<EOF

Hotovo. Prostředí je čisté. Další krok:
  ./scripts/up.sh

Po startu projdi workflow z PLAN_docker_environment.md nebo README — typicky:
  1. http://localhost:8080/administrator (admin / adminadmin1234)
  2. System → Install → Extensions → upload install/com_virtuemart...zip
  3. Extensions → Plugins → enable 'vmshipment - Weight, Countries'
  4. Components → VirtueMart → Configuration → Enable database Update tools
  5. Tools & Migration → Reset all Virtuemart tables and do a fresh install with sample data
  6. ./scripts/configure-joomla-mail.sh
  7. ./scripts/configure-joomla-debug.sh
  8. ./scripts/db-snapshot.sh clean-joomla-vm
  9. ./scripts/install-module.sh
EOF