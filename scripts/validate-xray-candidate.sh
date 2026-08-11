#!/usr/bin/env bash
# Validate an Xray candidate with the exact binary that will run it.

set -euo pipefail

usage() {
  echo "Usage: XRAY_BIN=/path/to/xray $0 CONFIG.json [ASSET_DIR]" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi

config_path=$1
asset_dir=${2:-}
xray_bin=${XRAY_BIN:-xray}

if [[ ! -f "$config_path" || -L "$config_path" ]]; then
  echo "error: candidate must be a regular, non-symlink file: $config_path" >&2
  exit 1
fi

if [[ -n "$asset_dir" && ! -d "$asset_dir" ]]; then
  echo "error: asset directory does not exist: $asset_dir" >&2
  exit 1
fi

if [[ "$xray_bin" == */* ]]; then
  if [[ ! -x "$xray_bin" ]]; then
    echo "error: Xray binary is not executable: $xray_bin" >&2
    exit 1
  fi
elif ! command -v "$xray_bin" >/dev/null 2>&1; then
  echo "error: Xray binary not found: $xray_bin" >&2
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  jq -e . "$config_path" >/dev/null
fi

echo "validating candidate with: $xray_bin" >&2
if [[ -n "$asset_dir" ]]; then
  XRAY_LOCATION_ASSET="$asset_dir" "$xray_bin" run -test -config "$config_path"
else
  "$xray_bin" run -test -config "$config_path"
fi

echo "candidate accepted by target Xray binary" >&2
