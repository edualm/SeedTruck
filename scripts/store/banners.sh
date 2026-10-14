#!/bin/bash
# Renders the App Store's two creative assets, the product page header (3840x1646) and the search result image
# (1920x1280), into store-assets/banners/. Each is a page in banners/ rendered by headless Google Chrome.
#
#   scripts/store/banners.sh
#
# The header puts the app icon's truck over a tilted wall of transfers. The search image stacks the torrent list's
# four transfers, cut from the raw dark iPhone capture in fastlane/screenshots-raw, under a headline.
set -euo pipefail
cd "$(dirname "$0")/../.."

for tool in magick; do
  command -v "$tool" >/dev/null || { echo "$tool is required (brew install imagemagick)." >&2; exit 1; }
done

chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
truck_source=Shared/AppIcon.icon/Assets/TruckWithFiles.png
list_source=fastlane/screenshots-raw/iphone/base/2.png
out=store-assets/banners
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

image_size() { magick identify -format "%wx%h" "$1"; }

for file in "$truck_source" "$list_source"; do
  [[ -f $file ]] || { echo "$file is missing." >&2; exit 1; }
done
[[ $(image_size "$list_source") == 1320x2868 ]] || { echo "$list_source isn't 1320x2868." >&2; exit 1; }
mkdir -p "$out"
cp scripts/store/banners/*.html "$work/"

# The truck, cropped to its artwork, which fills only 1170x817 of the layer's 1254x1254, and enlarged here, where
# Lanczos and a light sharpen keep its outline crisp.
magick "$truck_source" -crop 1170x817+59+269 +repage -filter Lanczos -resize 1400x -unsharp 0x1.2+0.6+0.02 \
  "$work/truck.png"

# The list's four transfers, 1200 wide at x 60, between the card's edges at y 528 and 1944 and its separators at
# 879, 1233, and 1587. Each is trimmed a pixel inside and cut out on the card's corner radius.
row=1
for span in 528:879 882:1233 1236:1587 1590:1944; do
  top=$((${span%:*} + 1)) height=$((${span#*:} - ${span%:*} - 2))
  magick "$list_source" -crop 1198x$height+61+$top +repage \
    \( -size 1198x$height xc:black -fill white -draw "roundrectangle 0,0 1197,$((height - 1)) 64,64" \) \
    -alpha off -compose copy_opacity -composite "$work/row-$row.png"
  row=$((row + 1))
done

render() {
  local page=$1 size=$2 file="$out/$1.png"
  "$chrome" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --window-size="${size/x/,}" --screenshot="$file" "file://$work/$page.html" 2>/dev/null
  [[ $(image_size "$file") == "$size" ]] || { echo "$file isn't $size." >&2; exit 1; }
  # The App Store takes no alpha.
  magick "$file" -alpha off "$file"
  echo "$file"
}

render header 3840x1646
render search 1920x1280
