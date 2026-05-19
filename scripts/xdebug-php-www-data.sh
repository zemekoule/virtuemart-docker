#!/bin/bash
# To samé jako `php-www-data.sh`, ale s aktivním Xdebug triggerem
# (xdebug.start_with_request=trigger v xdebug.ini, viz PhpStorm "Listen for PHP Debug Connections").
# Použití: `./scripts/xdebug-php-www-data.sh cli/joomla.php list extension`
set -e

cd "$(dirname "$0")/.."

docker compose exec -u www-data -e XDEBUG_TRIGGER=1 joomla php "$@"