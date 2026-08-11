#!/usr/bin/env bash
# Fail when repository text contains common proxy credentials or subscription tokens.

set -euo pipefail

if ! command -v rg >/dev/null 2>&1; then
  echo "error: ripgrep (rg) is required" >&2
  exit 2
fi

common_args=(
  -n -I --hidden
  --glob '!.git/**'
  --glob '!**/docs/assets/**'
  --glob '!**/scripts/scan-secrets.sh'
  --glob '!LICENSE'
)

patterns=(
  '(vless|vmess|trojan|ss)://[^[:space:]<>]+'
  '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}'
  "(private[Kk]ey|private[-_]key|subscription[-_ ]?(url|token)|api[-_ ]?(key|token))[[:space:]]*[:=][[:space:]]*[\"']?[A-Za-z0-9_./+?=&%-]{16,}"
  'https?://[^[:space:]<>]+/[A-Za-z0-9_-]{32,}([?&#][^[:space:]<>]*)?'
  "(password|uuid|public[Kk]ey|public[-_]key)[[:space:]]*[:=][[:space:]]*[\"']?[A-Za-z0-9_./+?=&%-]{16,}"
)

if [[ ${1:-} == '--self-test' ]]; then
  samples=(
    'vless://REDACTED@example.invalid:443'
    '123e4567-e89b-12d3-a456-426614174000'
    'subscription_url=not-a-real-token-value'
    'https://example.invalid/sub/REDACTED012345678901234567890123456789'
    'publicKey=REDACTED012345678901234567890123456789012345'
  )
  for index in "${!patterns[@]}"; do
    if ! printf '%s\n' "${samples[$index]}" | rg -q -e "${patterns[$index]}"; then
      echo "error: secret scanner self-test failed at pattern $index" >&2
      exit 1
    fi
  done
  echo "secret scanner self-test passed"
  exit 0
fi

scan_root=${1:-.}
result_file=$(mktemp "${TMPDIR:-/tmp}/reality-secret-scan.XXXXXX")
trap 'rm -f "$result_file"' EXIT HUP INT TERM

found=0
for pattern in "${patterns[@]}"; do
  if rg "${common_args[@]}" -e "$pattern" "$scan_root" >>"$result_file" 2>/dev/null; then
    found=1
  fi
done

if [[ $found -ne 0 ]]; then
  echo "error: possible credential or subscription secret found:" >&2
  sort -u "$result_file" >&2
  echo "Use obvious placeholders, rotate any exposed secret, then rerun." >&2
  exit 1
fi

echo "secret scan passed: $scan_root"
