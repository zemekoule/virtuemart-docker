#!/bin/bash
set -e

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "Soubor .env neexistuje, vytvářím z .env.example."
  echo "Zkontroluj a uprav ENV_UID / ENV_GID podle svého hosta (id -u / id -g)."
  cp .env.example .env
fi

docker compose up -d
