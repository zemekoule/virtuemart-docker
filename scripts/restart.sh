#!/bin/bash
# Restartuje všechny služby stacku. Užitečné po změnách v php.ini / xdebug.ini.
# Pokud potřebuješ jen jednu službu: `./scripts/restart.sh joomla`.
# Po změně docker-compose.yml (např. odkomentování bind-mountu) restart NESTAČÍ —
# použij `./scripts/up.sh`, který kontejner recreate-ne.
set -e

cd "$(dirname "$0")/.."

docker compose restart "$@"