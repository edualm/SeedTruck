# Shared by the store scripts: settings, builds, simulators, and launching a showcase scene.
# Source it from the repository root. Everything project-specific is in scripts/store/store.json.

STORE_DIR=scripts/store
STORE_CONFIG=$STORE_DIR/store.json
STORE_BUILD=$PWD/.build/store
ASSETS=$PWD/store-assets

for tool in jq magick; do
  command -v "$tool" >/dev/null || { echo "$tool is required (brew install ${tool/magick/imagemagick})." >&2; exit 1; }
done

# A field of store.json, as raw text.
config() { jq -r "$1" "$STORE_CONFIG"; }

# A field of one platform in store.json.
platform_field() { jq -r --arg p "$1" ".platforms[\$p] | $2" "$STORE_CONFIG"; }

# Every platform in store.json, in its order.
all_platforms() { jq -r '.platforms | keys_unsorted[]' "$STORE_CONFIG"; }

BUNDLE_ID=$(config .bundleId)
SCENE_ARG=$(config '.hooks.scene // "--showcase"')
LOG_ARG=$(config '.hooks.log // "--showcase-log"')
WINDOW_ARG=$(config '.hooks.window // "--showcase-window"')
APPEARANCE_ARG=$(config '.hooks.appearance // "--showcase-appearance"')
STATE_ENV=$(config '.hooks.stateEnv // "SHOWCASE_STATE"')
SESSION_ENV=$(config '.hooks.sessionEnv // "SHOWCASE_SESSION"')

# Reads platform names from the command line into PLATFORMS: any of store.json's, or `all`. Other arguments are
# left in REST for the caller.
parse_platforms() {
  PLATFORMS=() REST=()
  local known
  known=" $(all_platforms | tr '\n' ' ') "
  while (( $# )); do
    if [[ $1 == all ]]; then
      PLATFORMS=()
      while IFS= read -r p; do PLATFORMS+=("$p"); done < <(all_platforms)
    elif [[ $known == *" $1 "* ]]; then
      PLATFORMS+=("$1")
    else
      REST+=("$1")
    fi
    shift
  done
  if (( ! ${#PLATFORMS[@]} )); then
    while IFS= read -r p; do PLATFORMS+=("$p"); done < <(all_platforms)
  fi
}

is_mac() { [[ $(platform_field "$1" '.kind // "simulator"') == mac ]]; }

# A simulator platform's OS: iOS unless store.json's `os` says otherwise (watchOS).
platform_os() { platform_field "$1" '.os // "iOS"'; }
is_watch() { [[ $(platform_os "$1") == watchOS ]]; }

# The app a simulator platform runs: the watch app on watchOS (build.watch.bundleId), else the iOS app.
platform_bundle_id() {
  if is_watch "$1"; then config .build.watch.bundleId; else echo "$BUNDLE_ID"; fi
}
platform_app() {
  if is_watch "$1"; then echo "$WATCH_APP"; else echo "$IOS_APP"; fi
}

# xcodebuild's -project or -workspace.
xcode_container() {
  local workspace
  workspace=$(config '.xcode.workspace // empty')
  if [[ -n $workspace ]]; then echo -workspace "$workspace"; else echo -project "$(config .xcode.project)"; fi
}

# The .app a build made: build.<kind>.app if named, else the only one in the products folder.
built_app() {
  local products=$1 name=$2
  if [[ -n $name ]]; then echo "$products/$name.app"; return; fi
  find "$products" -maxdepth 1 -name '*.app' | head -1
}

# Debug builds: the showcase hooks exist only in DEBUG. Each build gets its own derived data, so captures never
# disturb the developer's builds. build.ios.settings can add build settings, such as
# INFOPLIST_KEY_UIRequiresFullScreen=YES, which iPadOS needs to turn an app to landscape on request.
build_ios() {
  local settings=()
  while IFS= read -r s; do [[ -n $s ]] && settings+=("$s"); done < <(config '(.build.ios.settings // [])[]')
  echo "Building $(config .build.ios.scheme) (Debug, simulator)…" >&2
  # shellcheck disable=SC2046
  xcodebuild build -quiet $(xcode_container) -scheme "$(config .build.ios.scheme)" -configuration Debug \
    -destination "generic/platform=iOS Simulator" -derivedDataPath "$STORE_BUILD/ios" \
    ${settings[@]+"${settings[@]}"} >&2
  ios_app_path
}

ios_app_path() {
  IOS_APP=$(built_app "$STORE_BUILD/ios/Build/Products/Debug-iphonesimulator" "$(config '.build.ios.app // empty')")
  [[ -d $IOS_APP ]] || { echo "No iOS app built in $STORE_BUILD/ios; run without --skip-build." >&2; exit 1; }
}

# The watch app, on its own: a watch simulator installs it without the iPhone app.
build_watch() {
  echo "Building $(config .build.watch.scheme) (Debug, simulator)…" >&2
  # shellcheck disable=SC2046
  xcodebuild build -quiet $(xcode_container) -scheme "$(config .build.watch.scheme)" -configuration Debug \
    -destination "generic/platform=watchOS Simulator" -derivedDataPath "$STORE_BUILD/watch" >&2
  watch_app_path
}

watch_app_path() {
  WATCH_APP=$(built_app "$STORE_BUILD/watch/Build/Products/Debug-watchsimulator" "$(config '.build.watch.app // empty')")
  [[ -d $WATCH_APP ]] || { echo "No watch app built in $STORE_BUILD/watch; run without --skip-build." >&2; exit 1; }
}

# Unsigned by default: no sandbox, so the app can write its log anywhere, and no keychain prompts.
build_mac() {
  local settings=()
  while IFS= read -r s; do [[ -n $s ]] && settings+=("$s"); done < <(config '(.build.mac.settings // ["CODE_SIGNING_ALLOWED=NO"])[]')
  echo "Building $(config .build.mac.scheme) (Debug)…" >&2
  # shellcheck disable=SC2046
  xcodebuild build -quiet $(xcode_container) -scheme "$(config .build.mac.scheme)" -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath "$STORE_BUILD/mac" \
    ${settings[@]+"${settings[@]}"} >&2
  mac_app_path
}

mac_app_path() {
  MAC_APP=$(built_app "$STORE_BUILD/mac/Build/Products/Debug" "$(config '.build.mac.app // empty')")
  [[ -d $MAC_APP ]] || { echo "No Mac app built in $STORE_BUILD/mac; run without --skip-build." >&2; exit 1; }
  # Its real path, as the running process reports it, for finding it (a symlinked folder like /tmp would differ).
  MAC_APP=$(cd "$MAC_APP" && pwd -P)
}

# Builds (or, with build=0, finds) what a platform needs, once per run.
prepare_build() {
  local platform=$1 build=$2
  if is_mac "$platform"; then
    [[ -n ${MAC_APP:-} ]] && return
    if (( build )); then build_mac; else mac_app_path; fi
  elif is_watch "$platform"; then
    [[ -n ${WATCH_APP:-} ]] && return
    if (( build )); then build_watch; else watch_app_path; fi
  else
    [[ -n ${IOS_APP:-} ]] && return
    if (( build )); then build_ios; else ios_app_path; fi
  fi
}

# A platform's simulator, of our own, so captures never depend on, or change, the ones in daily use: in the
# configured language, booted, with Apple's marketing status bar. Created on first use. Prints its UDID.
platform_simulator() {
  local platform=$1 name type udid
  name=$(platform_field "$platform" .simulator)
  type=$(platform_field "$platform" .deviceType)
  udid=$(xcrun simctl list devices -j | jq -r --arg name "$name" \
    '[.devices[][] | select(.name == $name and .isAvailable)][0].udid // empty')
  if [[ -z $udid ]]; then
    local runtime os
    os=$(platform_field "$platform" '.os // "iOS"')
    # The newest installed runtime of the platform's OS (iOS unless `os` says otherwise) that offers this device.
    runtime=$(xcrun simctl list runtimes -j | jq -r --arg type "$type" --arg os "$os" \
      '[.runtimes[] | select(.platform == $os and .isAvailable and any(.supportedDeviceTypes[]; .identifier == $type))]
       | sort_by(.version | split(".") | map(tonumber)) | last | .identifier // empty')
    [[ -n $runtime ]] || { echo "No installed $os runtime offers $type." >&2; return 1; }
    udid=$(xcrun simctl create "$name" "$type" "$runtime")
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b >/dev/null
    # The status bar's date and clock follow the device's language and region.
    xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array "$(config '.locale.language // "en"')"
    xcrun simctl spawn "$udid" defaults write -g AppleLocale -string "$(config '.locale.region // "en_US"')"
    # iPad: Full Screen Apps rather than Windowed Apps or Stage Manager, so no window controls show.
    xcrun simctl spawn "$udid" defaults write com.apple.springboard SBMedusaMultitaskingEnabled -bool false
    xcrun simctl spawn "$udid" defaults write com.apple.springboard SBChamoisWindowingEnabled -bool false
    xcrun simctl shutdown "$udid"
  fi
  if ! xcrun simctl list devices -j | jq -e --arg udid "$udid" \
      '.devices[][] | select(.udid == $udid and .state == "Booted")' >/dev/null; then
    xcrun simctl boot "$udid"
  fi
  xcrun simctl bootstatus "$udid" -b >/dev/null
  # Watch simulators take no status bar overrides.
  if is_watch "$platform"; then echo "$udid"; return; fi
  # 9:41 on Tuesday 9 January in this Mac's time zone, which the simulator shares. It takes only UTC.
  local time
  time=$(TZ=UTC date -j -r "$(date -j -f '%Y-%m-%d %H:%M:%S' '2024-01-09 09:41:00' +%s)" +%Y-%m-%dT%H:%M:%S.000Z)
  xcrun simctl status_bar "$udid" override \
    --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
    --operatorName "" --batteryState discharging --batteryLevel 100
  # On its own: given with the other overrides, the time loses its date and the iPad shows the wrong weekday.
  xcrun simctl status_bar "$udid" override --time "$time"
  echo "$udid"
}

# The screen to capture: `display` in store.json (an iPhone Duo's inner screen is primary-1), or the only one.
platform_display() { platform_field "$1" '.display // "primary"'; }

# A platform with a `setup` note needs something done by hand that no script can do, such as opening an iPhone
# Duo in DeviceHub. Checks the screen is lit and the expected size, and stops with the note if not.
check_setup() {
  local platform=$1 udid=$2 note still=$STORE_BUILD/$1-check.png
  note=$(platform_field "$platform" '.setup // empty')
  [[ -n $note ]] || return 0
  mkdir -p "$STORE_BUILD"
  if ! xcrun simctl io "$udid" screenshot --display="$(platform_display "$platform")" --mask=ignored "$still" \
        >/dev/null 2>&1 \
      || [[ $(magick "$still" -alpha off -format '%[fx:mean > 0.02]' info:) != 1 ]] \
      || ! size_matches "$platform" "$(image_size "$still")"; then
    echo "The $(platform_field "$platform" .simulator) simulator isn't ready: $note Then run this again." >&2
    return 1
  fi
}

# Whether a size is the platform's raw size, either way round for rotating platforms.
size_matches() {
  local raw
  raw=$(platform_field "$1" .rawSize)
  [[ $2 == "$raw" ]] || { [[ $(platform_field "$1" '.rotate // false') == true ]] && [[ $2 == "${raw#*x}x${raw%x*}" ]]; }
}

# A fixture file's arguments and its state, base64 of its compact JSON, for the state environment variable.
fixture_file() {
  [[ -n $1 && $1 != null ]] || return 0
  local file=$STORE_DIR/fixtures/$1.json
  [[ -f $file ]] || { echo "No fixture $file." >&2; exit 1; }
  echo "$file"
}
fixture_args() {
  [[ -z $1 ]] || jq -r '(.args // [])[]' "$1"
}
fixture_state() {
  if [[ -n $1 ]] && jq -e 'has("state")' "$1" >/dev/null; then jq -c .state "$1" | base64 | tr -d '\n'; fi
}

# A scene's full launch arguments, earliest first, since the showcase reads the first of a repeated flag: the
# scene, the item's own arguments, its fixture's, the mode's (stillArgs or clipArgs), the platform's, and the
# common launchArgs. So a shot's own arguments win over its fixture's, and both over the defaults.
scene_args() {
  local platform=$1 mode=$2 scene=$3 items=$4 fixture=$5
  printf '%s\n' "$SCENE_ARG" "$scene"
  jq -r '.[]' <<<"$items"
  fixture_args "$fixture"
  config "(.${mode}Args // [])[]"
  platform_field "$platform" '(.args // [])[]'
  config '(.launchArgs // [])[]'
}

# Waits for `event` in a showcase log; `drop` also matches `drop:4`. Fails on a `failed` entry or after
# `timeout` seconds.
wait_for_event() {
  local log=$1 event=$2 timeout=${3:-90} waited=0
  while (( waited < timeout * 10 )); do
    if [[ -f $log ]]; then
      if grep -q '"event":"failed' "$log"; then
        echo "The scene failed: $(grep -o '"event":"failed[^"]*"' "$log")" >&2
        return 1
      fi
      grep -q -E "\"event\":\"$event[\":]" "$log" && return 0
    fi
    sleep 0.1
    (( waited += 1 ))
  done
  echo "Timed out waiting for $event in $log" >&2
  return 1
}

# Relaunches the app on a simulator with a fresh session and the given state. Prints the showcase log's path,
# which the app writes in its Caches. APP_BUNDLE_ID picks another app than store.json's, such as the watch app.
launch_ios() {
  local udid=$1 state=$2 bundle=${APP_BUNDLE_ID:-$BUNDLE_ID}
  shift 2
  local container log
  container=$(xcrun simctl get_app_container "$udid" "$bundle" data)
  log=$container/Library/Caches/showcase.jsonl
  rm -f "$log"
  env "SIMCTL_CHILD_$SESSION_ENV=$(uuidgen)" "SIMCTL_CHILD_$STATE_ENV=$state" \
    xcrun simctl launch --terminate-running-process "$udid" "$bundle" \
    "$LOG_ARG" showcase.jsonl "$@" >/dev/null
  echo "$log"
}

# Starts the Mac app with a fresh session and sets MAC_PID. Its log is `log`. It opens through Launch Services,
# as from the Finder, so its window comes to the front and is active: started from a terminal, it would open
# behind it, with grey window buttons.
launch_mac() {
  local log=$1 state=$2
  shift 2
  rm -f "$log"
  local binary
  binary=$MAC_APP/Contents/MacOS/$(defaults read "$MAC_APP/Contents/Info" CFBundleExecutable)
  # Any copy left running would be reused instead of started.
  pkill -f "^$binary" 2>/dev/null || true
  open -n -a "$MAC_APP" --env "$SESSION_ENV=$(uuidgen)" --env "$STATE_ENV=$state" \
    --args "$LOG_ARG" "$log" "$@"
  MAC_PID=
  local tries=0
  until MAC_PID=$(pgrep -n -f "^$binary"); do
    # A fresh build's first launch waits on the system's check of the new binary.
    (( ++tries < 300 )) || { echo "The app didn't start." >&2; return 1; }
    sleep 0.1
  done
}

stop_mac() {
  if [[ -n ${MAC_PID:-} ]]; then
    kill "$MAC_PID" 2>/dev/null || true
    while kill -0 "$MAC_PID" 2>/dev/null; do sleep 0.1; done
  fi
  MAC_PID=
}

# ScreenCaptureKit window capture, compiled once.
mac_capture_tool() {
  local tool=$STORE_BUILD/mac-capture
  if [[ ! -x $tool || $STORE_DIR/mac-capture.swift -nt $tool ]]; then
    mkdir -p "$STORE_BUILD"
    # Its AVAssetWriter calls may be deprecated but still work; show the output only if it fails.
    local output
    output=$(swiftc -O -parse-as-library "$STORE_DIR/mac-capture.swift" -o "$tool" 2>&1) || { echo "$output" >&2; return 1; }
  fi
  echo "$tool"
}

image_size() { magick identify -format '%wx%h' "$1"; }

# ImageMagick stamps PNGs with the time they were written; without it, identical captures are identical files.
PNG_STABLE=(-define png:exclude-chunks=date,time)

# Light or dark, for a shot or clip: its own `appearance`, else store.json's, else light.
item_appearance() {
  local own=$1
  [[ -n $own && $own != null ]] && { echo "$own"; return; }
  config '.appearance // "light"'
}

# Simulators switch the whole device, so system UI matches. The Mac has no per-app switch from outside, so the
# app gets an argument (Showcase.swift applies it) instead; see appearance_args.
set_simulator_appearance() {
  # Watches are always dark, and take no appearance setting.
  [[ $(xcrun simctl list devices -j | jq -r --arg udid "$1" '.devices | to_entries[] | select(any(.value[]; .udid == $udid)) | .key') == *watchOS* ]] && return
  xcrun simctl ui "$1" appearance "$2"
}
appearance_args() {
  printf '%s\n' "$APPEARANCE_ARG" "$1"
}

# Fills a platform's `statusBarPatch` ("x,y,w,h" in raw pixels, such as the iPad's date, which no override
# hides): each row is a blend from the pixel left of the area to the pixel right of it, which follows a gradient
# backdrop. A no-op without one.
patch_status_bar() {
  local platform=$1 file=$2 patch x y w h
  patch=$(platform_field "$platform" '.statusBarPatch // empty')
  [[ -n $patch ]] || return 0
  IFS=, read -r x y w h <<<"$patch"
  magick "$file" \
    \( -clone 0 -crop "1x$h+$((x + w + 1))+$y" +repage -scale "${w}x$h!" \) \
    \( -clone 0 -crop "1x$h+$((x - 1))+$y" +repage -scale "${w}x$h!" \) \
    \( -size "${h}x$w" gradient:white-black -rotate -90 \) \
    \( -clone 1-3 -composite \) -delete 1-3 -geometry "+$x+$y" -composite "${PNG_STABLE[@]}" "$file"
}
