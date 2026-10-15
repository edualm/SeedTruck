#!/bin/bash
# Captures the raw App Store screenshots: each shot in shots.json is a showcase scene, launched fresh, waited on
# until its log says `done`, and captured. Writes store-assets/raw/<platform>/<id>.png.
#
#   scripts/store/capture.sh [<platform>…|all] [--only <id or scene>] [--skip-build]
#
# Platforms are store.json's. Simulator platforms run on simulators of their own, created on first use; the Mac
# runs the app in a fixed-size window and captures it with ScreenCaptureKit, which needs Screen Recording
# permission for the terminal once.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/store/lib.sh

SHOTS=$STORE_DIR/shots.json
only=
build=1
parse_platforms "$@"
set -- ${REST[@]+"${REST[@]}"}
while (( $# )); do
  case $1 in
    --only) only=$2; shift ;;
    --skip-build) build=0 ;;
    *) echo "Usage: $0 [$(all_platforms | tr '\n' '|')all] [--only <id or scene>] [--skip-build]" >&2; exit 64 ;;
  esac
  shift
done

shot_field() { jq -r --arg p "$1" --arg id "$2" ".[\$p][] | select(.id == \$id) | $3" "$SHOTS"; }
shot_ids() { jq -r --arg p "$1" '(.[$p] // [])[].id' "$SHOTS"; }

# The shot's fixture: its own `fixture`, or else one named like its scene, when there is one.
shot_fixture() {
  local name
  name=$(shot_field "$1" "$2" '.fixture // empty')
  if [[ -z $name && -f $STORE_DIR/fixtures/$(shot_field "$1" "$2" .scene).json ]]; then
    name=$(shot_field "$1" "$2" .scene)
  fi
  fixture_file "$name"
}

selected() {
  [[ -z $only || $2 == "$only" || $(shot_field "$1" "$2" .scene) == "$only" ]]
}

# A capture's size against its shot's `rawSize` (such as a Mac window other than the main one), else the
# platform's.
check_size() {
  local size expected
  size=$(image_size "$2")
  expected=$(shot_field "$1" "$3" '.rawSize // empty')
  [[ -n $expected ]] || expected=$(platform_field "$1" .rawSize)
  if [[ $size != "$expected" ]]; then
    echo "$2 is $size, expected $expected." >&2
    exit 1
  fi
}

# Reads a shot's launch arguments into ARGS and its state into STATE.
shot_launch() {
  local platform=$1 id=$2 fixture
  fixture=$(shot_fixture "$platform" "$id")
  ARGS=()
  while IFS= read -r arg; do ARGS+=("$arg"); done < <(scene_args "$platform" still \
    "$(shot_field "$platform" "$id" .scene)" "$(shot_field "$platform" "$id" '.args // []')" "$fixture")
  STATE=$(fixture_state "$fixture")
  APPEARANCE=$(item_appearance "$(shot_field "$platform" "$id" '.appearance // empty')")
}

capture_simulator() {
  local platform=$1 udid
  udid=$(platform_simulator "$platform")
  xcrun simctl install "$udid" "$(platform_app "$platform")"
  APP_BUNDLE_ID=$(platform_bundle_id "$platform")
  check_setup "$platform" "$udid"
  for id in $(shot_ids "$platform"); do
    selected "$platform" "$id" || continue
    local out=$ASSETS/raw/$platform/$id.png log
    echo "$platform/$id"
    shot_launch "$platform" "$id"
    set_simulator_appearance "$udid" "$APPEARANCE"
    log=$(launch_ios "$udid" "$STATE" "${ARGS[@]}")
    wait_for_event "$log" done
    xcrun simctl io "$udid" screenshot --type png --display="$(platform_display "$platform")" --mask=ignored \
      "$out" >/dev/null 2>&1
    # A landscape iPad is captured in the display's portrait orientation.
    local raw
    raw=$(platform_field "$platform" .rawSize)
    if [[ $(platform_field "$platform" '.rotate // false') == true && $(image_size "$out") == "${raw#*x}x${raw%x*}" ]]; then
      magick "$out" -rotate 90 "${PNG_STABLE[@]}" "$out"
    fi
    patch_status_bar "$platform" "$out"
    check_size "$platform" "$out" "$id"
  done
  xcrun simctl terminate "$udid" "$APP_BUNDLE_ID" 2>/dev/null || true
}

capture_mac() {
  local platform=$1 tool log=$STORE_BUILD/mac-showcase.jsonl
  tool=$(mac_capture_tool)
  trap stop_mac EXIT
  for id in $(shot_ids "$platform"); do
    selected "$platform" "$id" || continue
    local out=$ASSETS/raw/$platform/$id.png
    echo "$platform/$id"
    shot_launch "$platform" "$id"
    while IFS= read -r arg; do ARGS+=("$arg"); done < <(appearance_args "$APPEARANCE")
    launch_mac "$log" "$STATE" "$WINDOW_ARG" "$(platform_field "$platform" .window)" "${ARGS[@]}"
    wait_for_event "$log" done
    "$tool" --pid "$MAC_PID" --out "$out"
    stop_mac
    check_size "$platform" "$out" "$id"
  done
}

for platform in "${PLATFORMS[@]}"; do
  [[ -n $(shot_ids "$platform") ]] || continue
  mkdir -p "$ASSETS/raw/$platform"
  prepare_build "$platform" "$build"
  if is_mac "$platform"; then capture_mac "$platform"; else capture_simulator "$platform"; fi
done
