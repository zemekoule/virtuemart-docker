#!/bin/bash
# Interaktivní bash v `joomla` kontejneru pod uživatelem www-data
# (UID/GID sjednocené s hostem podle ENV_UID/ENV_GID v .env).
set -e

cd "$(dirname "$0")/.."

docker compose exec -u www-data joomla bash