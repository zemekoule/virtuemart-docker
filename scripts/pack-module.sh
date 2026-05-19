#!/bin/bash
# Zazipuje modules/packeta/ do ./packeta.zip — formát očekávaný Joomla installerem
# (manifest zasilkovna.xml musí být v kořeni zipu).
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="modules/packeta"
OUT="packeta.zip"

if [ ! -d "$SRC" ]; then
  echo "Modul nenalezen: ${SRC}"
  exit 1
fi
if [ ! -f "${SRC}/zasilkovna.xml" ]; then
  echo "V ${SRC} chybí zasilkovna.xml — to je manifest, bez něj Joomla zip nepřijme."
  exit 1
fi

rm -f "$OUT"

# zip -r běží z modulu, aby `zasilkovna.xml` skončil v rootu zipu, ne v podsložce
( cd "$SRC" && zip -rq "../../${OUT}" . \
    -x ".git/*" \
    -x ".gitignore" \
    -x ".gitattributes" \
    -x ".claude/*" \
    -x ".DS_Store" \
    -x "*/.DS_Store" )

echo "Hotovo: $(pwd)/${OUT}  ($(du -h "$OUT" | cut -f1))"