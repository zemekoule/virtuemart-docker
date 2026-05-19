#!/bin/bash
# Vytvoří dump databáze 'joomla' z běžícího kontejneru `mysql` do ./db-snapshots/<name>.sql
# Dump obsahuje CREATE DATABASE i USE (díky --databases), takže db-restore.sh stačí
# jen dropnout starou DB a obsah importovat.
set -euo pipefail

cd "$(dirname "$0")/.."

NAME="${1:-}"
if [ -z "$NAME" ]; then
  echo "Usage: ./scripts/db-snapshot.sh <name>"
  echo
  echo "Vytvoří dump databáze 'joomla' do ./db-snapshots/<name>.sql"
  if [ -d ./db-snapshots ] && compgen -G "./db-snapshots/*.sql" >/dev/null; then
    echo
    echo "Existující snapshoty:"
    for f in ./db-snapshots/*.sql; do
      printf "  %-30s %s\n" "$(basename "$f" .sql)" "$(du -h "$f" | cut -f1)"
    done
  fi
  exit 1
fi

mkdir -p ./db-snapshots
OUT="./db-snapshots/${NAME}.sql"

if [ -f "$OUT" ]; then
  read -r -p "Soubor ${OUT} už existuje — přepsat? [y/N] " ans
  case "$ans" in
    y|Y|yes) ;;
    *) echo "Zrušeno."; exit 1 ;;
  esac
fi

TMP="${OUT}.tmp"
echo "Dumpuju 'joomla' do ${OUT}..."
docker compose exec -T mysql mariadb-dump \
  -uroot -pasdf \
  --single-transaction \
  --routines --triggers --events \
  --databases joomla \
  > "$TMP"
mv "$TMP" "$OUT"

echo "Hotovo. Velikost: $(du -h "$OUT" | cut -f1)"