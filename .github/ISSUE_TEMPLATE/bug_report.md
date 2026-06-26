---
name: Bug report
about: Something didn't work when using the skill
title: "[BUG] "
labels: bug
assignees: ""
---

## What happened

<!-- Brief description -->

## What you ran (redact credentials!)

```bash
# Your command / conversation with the skill
```

## What the agent did (redact!)

```
Paste the agent's diagnostic output here
```

## Environment

- xray-core version: `xray version` output
- Client software: xray / mihomo / clash / mihomo2 / other
- OS: `uname -a`

## Server debug log (loglevel: debug)

```bash
# On the upstream server
sed -i 's/"loglevel": "warning"/"loglevel": "debug"/' /usr/local/etc/xray/config.json
systemctl restart xray
journalctl -u xray -n 50 --no-pager
```

Paste the relevant portion (redact IPs/UUIDs/keys if you care).

## Checklist

- [ ] I retried with `loglevel: "debug"` on the server
- [ ] I checked [Step 5 in SKILL.md](./SKILL.md#step-5-other-common-causes-in-priority-order) — none of those matched
- [ ] I redacted my real publicKey/privateKey/UUID/server IP from this issue
