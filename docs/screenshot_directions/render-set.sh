#!/bin/bash
# A案の本番セットを書き出す。出力は docs/screenshots_2026-10/<locale>/0N.png（1320x2868）
set -euo pipefail
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$(dirname "$HERE")/screenshots_2026-10"
for pair in "ja:ja" "en:en-US"; do
  lang=${pair%%:*}; locale=${pair#*:}; mkdir -p "$OUT/$locale"
  for shot in 1 2 3; do
    "$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
      --allow-file-access-from-files --virtual-time-budget=10000 --window-size=1320,2868 \
      --screenshot="$OUT/$locale/0$shot.png" "file://$HERE/src/a-film-set.html?shot=$shot&lang=$lang" 2>/dev/null
    python3 -c "from PIL import Image;import sys;s=Image.open(sys.argv[1]).size;assert s==(1320,2868),s" "$OUT/$locale/0$shot.png"
  done
done
echo "done: $OUT"
