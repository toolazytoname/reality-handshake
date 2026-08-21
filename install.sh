#!/bin/sh
# Atomic installer for the reality-handshake skill.

set -eu

repo=${REPO:-toolazytoname/reality-handshake}
branch=${BRANCH:-main}
target=${TARGET:-codex}
source_dir=${SOURCE_DIR:-}

if [ -n "${INSTALL_DIR:-}" ]; then
  install_dir=$INSTALL_DIR
else
  case "$target" in
    codex)
      codex_root=${CODEX_HOME:-"$HOME/.codex"}
      install_dir="$codex_root/skills/reality-handshake"
      ;;
    claude)
      install_dir="$HOME/.claude/skills/reality-handshake"
      ;;
    *)
      echo "error: TARGET must be 'codex' or 'claude'" >&2
      exit 2
      ;;
  esac
fi

case "$install_dir" in
  ""|/|"$HOME"|"$HOME/")
    echo "error: refusing unsafe INSTALL_DIR: $install_dir" >&2
    exit 2
    ;;
esac

manifest='SKILL.md
RUNBOOK-zh.md
agents/openai.yaml
references/handshake-diagnosis.md
references/router-deployment.md
references/resilience-and-subscriptions.md
references/verification-runbook.md
references/macos-always-on-client.md
scripts/check-markdown-links.py
scripts/scan-secrets.sh
scripts/validate-xray-candidate.sh
scripts/verify-repo.sh'

if [ -z "$source_dir" ]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "error: curl is required for a remote install" >&2
    exit 1
  fi
  if ! command -v tar >/dev/null 2>&1; then
    echo "error: tar is required for a remote install" >&2
    exit 1
  fi
fi

install_parent=$(dirname "$install_dir")
mkdir -p "$install_parent"
stage_dir=$(mktemp -d "$install_parent/.reality-handshake.install.XXXXXX")
payload_dir="$stage_dir/payload"
mkdir -p "$payload_dir"

cleanup() {
  rm -rf "$stage_dir"
}
trap cleanup EXIT HUP INT TERM

echo "staging reality-handshake for $target ..."
if [ -z "$source_dir" ]; then
  source_dir="$stage_dir/source"
  archive_file="$stage_dir/source.tar.gz"
  mkdir -p "$source_dir"
  archive_url="https://codeload.github.com/$repo/tar.gz/refs/heads/$branch"
  if ! curl -fsSL --retry 2 --connect-timeout 10 "$archive_url" -o "$archive_file"; then
    echo "error: download failed: $repo@$branch" >&2
    exit 1
  fi
  if ! tar -xzf "$archive_file" -C "$source_dir" --strip-components=1; then
    echo "error: downloaded repository archive is invalid" >&2
    exit 1
  fi
fi

for relative_path in $manifest; do
  destination="$payload_dir/$relative_path"
  mkdir -p "$(dirname "$destination")"
  source_path="$source_dir/$relative_path"
  if [ ! -f "$source_path" ]; then
    echo "error: source file missing: $source_path" >&2
    exit 1
  fi
  cp "$source_path" "$destination"
done

if [ "$(sed -n '1p' "$payload_dir/SKILL.md")" != '---' ]; then
  echo "error: staged SKILL.md is missing YAML frontmatter" >&2
  exit 1
fi

if ! grep -q '^name: reality-handshake$' "$payload_dir/SKILL.md"; then
  echo "error: staged skill has an unexpected name" >&2
  exit 1
fi

chmod 755 "$payload_dir/scripts/"*.sh "$payload_dir/scripts/"*.py

backup_dir="${install_dir}.previous.$$"
had_previous=0
if [ -e "$install_dir" ]; then
  mv "$install_dir" "$backup_dir"
  had_previous=1
fi

if mv "$payload_dir" "$install_dir"; then
  if [ "$had_previous" -eq 1 ]; then
    rm -rf "$backup_dir"
  fi
else
  echo "error: install switch failed; restoring previous skill" >&2
  if [ "$had_previous" -eq 1 ] && [ -e "$backup_dir" ]; then
    mv "$backup_dir" "$install_dir"
  fi
  exit 1
fi

file_count=$(find "$install_dir" -type f | wc -l | tr -d ' ')
echo "installed reality-handshake to $install_dir ($file_count files)"
echo "Try: 先只读检查我的 Xray/REALITY 或路由器代理，不要改配置。"
