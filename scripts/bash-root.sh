#!/bin/bash
# Interaktivní bash v `joomla` kontejneru pod rootem (apt-get, pecl, atd.).
set -e

cd "$(dirname "$0")/.."

docker compose exec joomla bash