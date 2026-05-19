#!/bin/bash
# Spustí PHP CLI v `joomla` kontejneru pod www-data. Argumenty se propustí.
# Použití: `./scripts/php-www-data.sh cli/joomla.php list extension`
#         `./scripts/php-www-data.sh -v`
set -e

cd "$(dirname "$0")/.."

docker compose exec -u www-data joomla php "$@"