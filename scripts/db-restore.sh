#!/bin/bash
# Obnoví databázi 'joomla' v běžícím kontejneru `mysql` ze snapshotu ./db-snapshots/<name>.sql.
# Drop staré DB → import dumpu (ten obsahuje CREATE DATABASE + USE díky --databases v dumpu).
# Pozn.: Joomla kontejner se nezastavuje — connection pool se znovu naváže při dalším requestu.
set -euo pipefail

cd "$(dirname "$0")/.."

NAME="${1:-}"
if [ -z "$NAME" ]; then
  echo "Usage: ./scripts/db-restore.sh <name>"
  echo
  echo "Obnoví databázi 'joomla' z ./db-snapshots/<name>.sql"
  if [ -d ./db-snapshots ] && compgen -G "./db-snapshots/*.sql" >/dev/null; then
    echo
    echo "Dostupné snapshoty:"
    for f in ./db-snapshots/*.sql; do
      printf "  %-30s %s\n" "$(basename "$f" .sql)" "$(du -h "$f" | cut -f1)"
    done
  else
    echo
    echo "Žádné snapshoty v ./db-snapshots/. Vytvoř napřed přes ./scripts/db-snapshot.sh"
  fi
  exit 1
fi

IN="./db-snapshots/${NAME}.sql"
if [ ! -f "$IN" ]; then
  echo "Snapshot '${NAME}' nenalezen (${IN})"
  exit 1
fi

read -r -p "Tohle nahradí celou databázi 'joomla' obsahem z ${IN}. Pokračovat? [y/N] " ans
case "$ans" in
  y|Y|yes) ;;
  *) echo "Zrušeno."; exit 0 ;;
esac

echo "Drop staré DB..."
docker compose exec -T mysql mariadb -uroot -pasdf -e "DROP DATABASE IF EXISTS joomla;"

echo "Importuju ${IN}..."
docker compose exec -T mysql mariadb -uroot -pasdf < "$IN"

echo "Hotovo."