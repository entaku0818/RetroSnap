#!/bin/bash
#
# 版下（app-store-*.html）から App Store 用の PNG を焼く。
#
#   ./fastlane/screenshots/source/render.sh          # ja を焼く
#   ./fastlane/screenshots/source/render.sh ja en-US # 指定のロケールだけ焼く
#
# 出力先は fastlane/screenshots/<locale>/ で、これは fastlane deliver の置き場所と同じ。
# ★このスクリプトは画像を作るだけ。deliver / upload は一切しない。
#
set -euo pipefail

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_ROOT="$(dirname "$SOURCE_DIR")"

# App Store の 6.9" / 6.7" 用サイズ。ここを変えると審査で弾かれるので触らない。
WIDTH=1290
HEIGHT=2796

# 1枚目から順に、この名前で出す。App Store Connect 上の並び順になる。
NAMES=(
  "01-shoot"
  "02-switch"
  "03-datestamp"
  "04-store"
  "05-gallery"
)

LOCALES=("$@")
if [ ${#LOCALES[@]} -eq 0 ]; then
  LOCALES=("ja")
fi

if [ ! -x "$CHROME" ]; then
  echo "Google Chrome が見つからない: $CHROME" >&2
  exit 1
fi

for locale in "${LOCALES[@]}"; do
  # ja -> app-store-ja.html, en-US -> app-store-en-US.html
  page="$SOURCE_DIR/app-store-${locale}.html"
  if [ ! -f "$page" ]; then
    echo "版下が無い: $page" >&2
    exit 1
  fi

  out_dir="$OUTPUT_ROOT/$locale"
  mkdir -p "$out_dir"

  for index in "${!NAMES[@]}"; do
    shot=$((index + 1))
    name="${NAMES[$index]}"
    out="$out_dir/${name}.png"

    "$CHROME" \
      --headless \
      --disable-gpu \
      --hide-scrollbars \
      --force-device-scale-factor=1 \
      --default-background-color=00000000 \
      --virtual-time-budget=8000 \
      --window-size="${WIDTH},${HEIGHT}" \
      --screenshot="$out" \
      "file://${page}?only=${shot}" >/dev/null 2>&1

    if [ ! -f "$out" ]; then
      echo "書き出しに失敗: $out" >&2
      exit 1
    fi

    # サイズが違うと App Store Connect に上げられない。ここで気づけるようにする。
    size=$(sips -g pixelWidth -g pixelHeight "$out" | awk '/pixel/ {printf "%s", $2 " "}')
    echo "$locale/$name.png  ${size}"
    if [ "$size" != "$WIDTH $HEIGHT " ]; then
      echo "  ↑ サイズが ${WIDTH}x${HEIGHT} でない" >&2
      exit 1
    fi
  done
done
