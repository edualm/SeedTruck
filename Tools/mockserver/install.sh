#!/bin/sh

set -eu

SERVICE_NAME=seedtruck-mockserver.service
BINARY_PATH=/usr/local/bin/seedtruck-mockserver
SERVICE_PATH=/etc/systemd/system/$SERVICE_NAME
SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
BUILD_OUTPUT=$(mktemp "${TMPDIR:-/tmp}/seedtruck-mockserver.XXXXXX")

cleanup() {
    rm -f "$BUILD_OUTPUT"
}
trap cleanup EXIT HUP INT TERM

run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

command -v go >/dev/null 2>&1 || {
    printf '%s\n' "go is required" >&2
    exit 1
}
command -v systemctl >/dev/null 2>&1 || {
    printf '%s\n' "systemctl is required" >&2
    exit 1
}
if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || {
        printf '%s\n' "run as root or install sudo" >&2
        exit 1
    }
fi

printf '%s\n' "Building seedtruck-mockserver..."
(
    cd "$SCRIPT_DIR"
    go build -trimpath -o "$BUILD_OUTPUT" .
)

printf '%s\n' "Installing $BINARY_PATH..."
run_as_root install -m 0755 "$BUILD_OUTPUT" "$BINARY_PATH"

printf '%s\n' "Installing $SERVICE_PATH..."
run_as_root install -m 0644 "$SCRIPT_DIR/$SERVICE_NAME" "$SERVICE_PATH"

printf '%s\n' "Reloading systemd and starting $SERVICE_NAME..."
run_as_root systemctl daemon-reload
run_as_root systemctl enable "$SERVICE_NAME"
run_as_root systemctl restart "$SERVICE_NAME"

printf '%s\n' "$SERVICE_NAME is installed and running on 0.0.0.0:9091"
