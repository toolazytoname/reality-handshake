#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)

while IFS= read -r -d '' script; do
  bash -n "$script"
done < <(find "$repo_root" -type f -name '*.sh' -not -path '*/.git/*' -print0)

python3 "$repo_root/scripts/check-markdown-links.py" "$repo_root"
"$repo_root/scripts/scan-secrets.sh" "$repo_root"

if [[ $(sed -n '1p' "$repo_root/SKILL.md") != '---' ]]; then
  echo "error: SKILL.md is missing YAML frontmatter" >&2
  exit 1
fi

if ! rg -q '^name: reality-handshake$' "$repo_root/SKILL.md"; then
  echo "error: unexpected skill name" >&2
  exit 1
fi

echo "repository verification passed"
