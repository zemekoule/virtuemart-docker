#!/bin/bash
# Re-buildne image podle Dockerfile. Užitečné po změnách v Dockerfile.
# Argumenty se propustí dál (např. `--no-cache`, `--pull`).
set -e

cd "$(dirname "$0")/.."

docker compose build "$@"