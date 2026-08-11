#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 4 || $1 != run || $2 != -test || $3 != -config || ! -f $4 ]]; then
  echo "unexpected Xray validation arguments" >&2
  exit 1
fi

echo "Configuration OK."
