# reality-handshake

> A [Claude Code skill](https://docs.claude.com/en/docs/claude-code/skills) for diagnosing **VLESS+Reality / XTLS** proxy handshake failures — and for connecting new clients (Linux servers, macOS CLI, macOS GUI) to an existing Reality server.

When your proxy "doesn't work anymore", this skill walks through client-side and server-side diagnosis, then fixes the most common cause: **the dest site has banned your upstream server's IP from being impersonated**. It also covers the second-most-common cause: **the entry IP your domain resolves to is blocked, while another IP of the same server works fine**.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![xray-core: 1.8.x–26.x](https://img.shields.io/badge/xray--core-1.8.x--26.x-blue)](https://github.com/XTLS/Xray-core)

## What it does

Triggers when a user reports:

- "代理不管用了" / "proxy doesn't work" / "代理失效"
- `curl` through the proxy returns empty / `SSL_ERROR_SYSCALL`
- `ping` shows 100% loss (which is **NORMAL** and not a proxy bug — see [Why ping is the wrong test](#why-ping-is-the-wrong-test))
- "can my Mac also use this proxy?" — yes, two ways

The skill walks an AI agent through:

1. **Client-side audit** — `.bashrc` aliases, `http_proxy` env vars, xray inbounds
2. **Server-side audit** — SSH to upstream, read `config.json`, derive server `publicKey` from `privateKey`
3. **Credential matching** — UUID / publicKey / shortId / serverName all match between client and server
4. **Blocked entry IP diagnosis** — distinguish **port-level vs IP-level blocking** with `nc` probes; if the domain's IP is dead on all ports but another IP of the same server is alive, repoint the client `address` at the working IP (Reality only cares about SNI, not the connect IP)
5. **Debug log inspection** — set `loglevel: "debug"`, look for the smoking gun:
   ```
   hs.c.conn == conn: true
   hs.c.handshakeStatus: false
   [Info] REALITY: processed invalid connection
   ```
6. **Fix** — rotate `dest` and `serverNames` on both sides

### macOS client setup (two verified paths)

- **CLI**: `brew install xray` hangs without a proxy (chicken-and-egg) — download `Xray-macos-arm64-v8a.zip` on an already-proxied server and `scp` it back; same JSON config as Linux, no systemctl; files fetched via `scp` carry no quarantine attribute and run directly
- **GUI**: original ClashX **cannot** do VLESS+Reality — use **ClashX Meta** (mihomo core). Covers config skeleton, port deconfliction (7891/9097 vs 7890/9090), config validation with the bundled core, and the #1 gotcha: **the core only starts after an interactive privileged-helper authorization** — the app looks alive but binds nothing until the user clicks it. Let the app manage the system proxy itself (hand-setting it via `networksetup` will cut your network)

### Low-end OpenWrt travel router (透明代理随身路由)

When xray physically can't run on the device (4MB flash / 32MB RAM, e.g. TL-WR720N): router `ss-redir` (legacy aes-256-cfb) → **gost bridge on a domestic relay VPS** → existing mihomo/xray client → Reality upstream. Covers the cipher gap (xray dropped stream ciphers; old ss clients have *only* stream ciphers), why the two-hop relay protects the foreign IP instead of adding fragility, dropbear/flash-space gotchas on Chaos Calmer, per-leg verification commands, and a reboot-test acceptance checklist.

For day-to-day operations (changing servers, troubleshooting), see the Chinese runbook: [RUNBOOK-zh.md](./RUNBOOK-zh.md).

## Quick start

### Install — one line

```bash
curl -fsSL https://raw.githubusercontent.com/toolazytoname/reality-handshake/main/install.sh | sh
```

That's it. No `git clone`, no `mkdir`, no manual `cp`. The script:

- Downloads `SKILL.md` straight from `main`
- Installs to `~/.claude/skills/reality-handshake/SKILL.md`
- Verifies the download looks like a real SKILL.md (frontmatter check)
- Re-running is safe (overwrites in place)

**Custom paths:**

```bash
# Per-project install
INSTALL_DIR="$PWD/.claude/skills/reality-handshake" \
  curl -fsSL https://raw.githubusercontent.com/toolazytoname/reality-handshake/main/install.sh | sh

# Different branch / fork
BRANCH=dev REPO=yourname/reality-handshake \
  curl -fsSL https://raw.githubusercontent.com/toolazytoname/reality-handshake/main/install.sh | sh
```

### Manual install (if you don't trust curl | sh)

```bash
mkdir -p ~/.claude/skills/reality-handshake
curl -fsSL https://raw.githubusercontent.com/toolazytoname/reality-handshake/main/SKILL.md \
  -o ~/.claude/skills/reality-handshake/SKILL.md
```

Or if you've cloned this repo:

```bash
cp SKILL.md ~/.claude/skills/reality-handshake/SKILL.md
```

### Verify

```bash
ls -la ~/.claude/skills/reality-handshake/SKILL.md
head -3 ~/.claude/skills/reality-handshake/SKILL.md
# Should show: --- / name: reality-handshake / description: Diagnose VLESS+Reality...
```

### Uninstall

```bash
rm -rf ~/.claude/skills/reality-handshake
```

Claude Code picks up the skill automatically on next message — no restart needed.

### Trigger

In Claude Code, ask anything like:
- "代理不管用了"
- "my proxy is broken"
- "xray connects but SSL_ERROR_SYSCALL"
- "I'm getting `processed invalid connection` in xray logs"

The skill will guide the agent through diagnosis and fix. On macOS it can also set up a new client from scratch — command-line xray or the ClashX Meta GUI.

## Why ping is the wrong test

`ping` uses **ICMP**, which HTTP/SOCKS proxies don't forward. A `ping google.com` returning 100% loss under `proxy-on` is normal protocol behavior — it does **not** mean the proxy is broken.

Use `curl` instead:

```bash
# Direct (no proxy) baseline
curl -s https://api.ipify.org

# Through HTTP proxy
curl -s -x http://127.0.0.1:10809 https://api.ipify.org

# Through SOCKS5 proxy
curl -s --socks5-hostname 127.0.0.1:10810 https://api.ipify.org
```

`api.ipify.org` returns your egress IP — instant "did the proxy work?" check.

## The fix in 30 seconds

If the server debug log shows `handshakeStatus: false` after all crypto checks pass, the **dest site has banned your server's IP**. Fix:

```bash
# On the upstream server
ssh root@YOUR.UPSTREAM.IP
sed -i 's|"dest": "www.microsoft.com:443"|"dest": "www.samsung.com:443"|' /usr/local/etc/xray/config.json
sed -i 's|"serverNames": \["www.microsoft.com"\]|"serverNames": ["www.samsung.com","samsung.com"]|' /usr/local/etc/xray/config.json
systemctl restart xray

# On the client
sed -i 's|"serverName": "www.microsoft.com"|"serverName": "www.samsung.com"|' /usr/local/etc/xray/config.json
systemctl restart xray
```

Test: `curl -s -x http://127.0.0.1:10809 https://api.ipify.org` — should return your upstream server's public IP.

For the full diagnostic flow, see [SKILL.md](./SKILL.md).

## Tested with

- **xray-core** 1.8.24 (client and server) and 26.3.27 (darwin/arm64 client)
- **mihomo** (Clash Meta) v1.19.28 via **ClashX Meta** v1.4.43 on macOS — same config, same root cause
- **clash** (premium, classic)
- **mihomo2** (fork with embedded cache)
- Xray Reality protocol variants (XTLS-Vision should also work with adjusted `flow`)
- macOS clients: both command-line xray and GUI (ClashX Meta) paths verified end-to-end

Other proxy stacks (sing-box, Outline, shadowsocks) have different protocols but similar diagnostic flow.

## Project structure

```
.
├── SKILL.md              # The skill itself (only file Claude Code reads)
├── install.sh            # curl-able one-line installer
├── README.md             # This file
├── LICENSE               # MIT
├── CONTRIBUTING.md       # How to contribute
├── SECURITY.md           # Reporting vulnerabilities
├── CHANGELOG.md          # Version history
├── CODE_OF_CONDUCT.md    # Community guidelines
├── .gitignore
└── .github/
    ├── ISSUE_TEMPLATE/
    │   ├── bug_report.md
    │   └── feature_request.md
    └── PULL_REQUEST_TEMPLATE.md
```

## Contributing

PRs welcome for:

- Additional "dest banned our IP" workarounds (Microsoft, Google, Apple, etc.)
- Adapting the flow to sing-box / shadowsocks / Trojan
- Diagnostic improvements (more accurate `handshakeStatus: false` interpretation)
- Translations (Chinese version overdue)

See [CONTRIBUTING.md](./CONTRIBUTING.md).

## Security

**Do not commit real credentials.** This skill is sanitized — examples use placeholder values like `YOUR.UPSTREAM.IP`, `<UUID>`, or universally public domains (`www.samsung.com`, `api.ipify.org`).

If you find a real credential leak in a public PR or issue, see [SECURITY.md](./SECURITY.md).

## Credits

Distilled from a real 2-hour debugging session on 4 production machines. Special thanks to the [XTLS/Xray-core issue tracker](https://github.com/XTLS/Xray-core/issues), especially:

- [#2931](https://github.com/XTLS/Xray-core/issues/2931) — "Microsoft bans your IP" failure mode
- [#2724](https://github.com/XTLS/Xray-core/issues/2724) — "processed invalid connection" baseline

## License

MIT — see [LICENSE](./LICENSE).
