#!/bin/bash
# Zastaví a odstraní všechny kontejnery stacku. Data v ./db, ./src, ./mailpit
# zůstávají (bind mounty na hostu).
set -e

cd "$(dirname "$0")/.."

docker compose down