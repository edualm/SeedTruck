#!/bin/bash
# Frames the raw captures for the App Store: screenshot-maker renders each shot of screenshots.json with its
# template's device frame, backdrop, title, and subtitle into store-assets/final/<platform>/NN.png.
#
#   scripts/store/frame.sh [--only <pattern>] [--check] [--edit]
#
# screenshot-maker (https://github.com/edualm/app-store-screenshot-maker) is expected beside this repository;
# SCREENSHOT_MAKER points elsewhere. Its CLI drives the installed Google Chrome. To change the look, run with
# --edit, open a shot from "Open job…", adjust it, and Save Preset over its template or Copy shot changes into
# that shot.
set -euo pipefail
cd "$(dirname "$0")/../.."
maker=${SCREENSHOT_MAKER:-../screenshot-maker}
if [[ ! -f $maker/scripts/render.ts ]]; then
  echo "screenshot-maker isn't at $maker. Clone it there:" >&2
  echo "  git clone https://github.com/edualm/app-store-screenshot-maker.git $maker" >&2
  echo "or set SCREENSHOT_MAKER to a checkout." >&2
  exit 1
fi
[[ -d $maker/node_modules ]] || pnpm --dir "$maker" install --frozen-lockfile
pnpm --silent --dir "$maker" render "$PWD/scripts/store/screenshots.json" "$@"
