#!/usr/bin/env bash
# install.sh — one-line installer for the reality-handshake Claude Code skill
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/toolazytoname/reality-handshake/main/install.sh | sh
#
# What it does:
#   - Downloads SKILL.md from GitHub
#   - Installs to ~/.claude/skills/reality-handshake/SKILL.md
#   - No sudo required (user-level install)
#   - Re-running is safe (overwrites)
#
# Options (via env vars):
#   INSTALL_DIR=/custom/path   — override install directory
#   BRANCH=main                — override git branch
#   REPO=owner/name            — override source repo

set -euo pipefail

REPO="${REPO:-toolazytoname/reality-handshake}"
BRANCH="${BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.claude/skills/reality-handshake}"
SKILL_FILE="$INSTALL_DIR/SKILL.md"
URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/SKILL.md"

# Pre-flight checks
if ! command -v curl >/dev/null 2>&1; then
  echo "✗ curl not found. Install curl first." >&2
  exit 1
fi

if [[ -d "$HOME/.claude/skills" && ! -w "$HOME/.claude/skills" ]]; then
  echo "✗ $HOME/.claude/skills exists but is not writable." >&2
  echo "  Try: INSTALL_DIR=\$HOME/somewhere/writable $0" >&2
  exit 1
fi

# Install
mkdir -p "$INSTALL_DIR"

echo "→ Downloading SKILL.md from $REPO@$BRANCH ..."
if ! curl -fsSL "$URL" -o "$SKILL_FILE"; then
  echo "✗ Download failed. Check your network and that $REPO@$BRANCH exists." >&2
  exit 1
fi

# Verify it looks like a real SKILL.md (frontmatter check)
if ! head -1 "$SKILL_FILE" | grep -q "^---$"; then
  echo "✗ Downloaded file doesn't look like a SKILL.md (missing YAML frontmatter)." >&2
  echo "  Saved (just in case) to: $SKILL_FILE" >&2
  exit 1
fi

# Show what we installed
SIZE=$(wc -c < "$SKILL_FILE" | tr -d ' ')
echo "✓ reality-handshake installed to $SKILL_FILE ($SIZE bytes)"
echo ""
echo "Try it. In Claude Code, ask anything like:"
echo "  • 代理不管用了"
echo "  • my proxy is broken"
echo "  • I'm getting SSL_ERROR_SYSCALL through my SOCKS proxy"
echo "  • xray shows 'processed invalid connection' in debug log"
echo ""
echo "Uninstall:"
echo "  rm -rf '$INSTALL_DIR'"
