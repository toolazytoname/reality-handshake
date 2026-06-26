# Contributing

Thanks for improving `reality-handshake`.

## What this skill is

A [Claude Code skill](https://docs.claude.com/en/docs/claude-code/skills) that diagnoses VLESS+Reality proxy failures. The `SKILL.md` file is the **only file Claude Code reads** — keep it focused and action-oriented.

## Submitting changes

1. Fork → branch → PR
2. Keep `SKILL.md` the source of truth (Claude reads it front-to-back)
3. Update `README.md` only if the user-facing description changes
4. **No real credentials, IPs, UUIDs, or domains in any file** — examples should be obviously fictional (`YOUR.UPSTREAM.IP`, `<UUID>`) or universally public (`www.samsung.com`, `api.ipify.org`)
5. Use the [PR template](./.github/PULL_REQUEST_TEMPLATE.md)

## What makes a good contribution

- A new dest site that's known to work (`www.something.com:443`) with a one-line note on why
- An adaptation to sing-box / shadowsocks / Trojan (parallel `SKILL-<protocol>.md` if the protocol differs significantly)
- A more accurate interpretation of a specific log line
- A translation (Chinese, Japanese, Russian all useful for this community)
- More test cases in `tests/` (if we add a test suite later)

## What to skip

- Cosmetic changes to the diagnostic flow
- New sections that don't trigger the skill
- Long prose explanations — Claude reads skills like a checklist

## Testing changes locally

```bash
mkdir -p ~/.claude/skills/reality-handshake
cp SKILL.md ~/.claude/skills/reality-handshake/SKILL.md
# Now use Claude Code and trigger the skill with phrases like:
#   "代理不管用了"
#   "my xray proxy is broken"
#   "I'm getting SSL_ERROR_SYSCALL through my SOCKS proxy"
```

## Reporting issues

Open a GitHub issue with:

- The exact error from your `journalctl -u xray` (debug log level)
- The output of `xray x25519 -i "$(grep privateKey /usr/local/etc/xray/config.json | awk -F'"' '{print $4}')"` (server publicKey, redact if posting publicly)
- Your client's `realitySettings` block (redact real values)
- The proxy client you're using (xray, mihomo, clash, sing-box, etc.)

Issue templates auto-load.

## Code of Conduct

By participating, you agree to abide by the [Code of Conduct](./CODE_OF_CONDUCT.md).
