---
name: reality-handshake
description: Diagnose, deploy, and maintain authorized Xray VLESS+REALITY proxy paths, including client/server handshake failures, Clash Meta mixed-port Timeout or SSL_ERROR_SYSCALL when `server:` is a free DDNS hostname, macOS/Linux client onboarding, FreshTomato or OpenWrt transparent proxying, legacy low-end router Shadowsocks-to-Mihomo bridges, GFW-list split routing and split DNS, multi-node health selection, fail-open behavior, subscription refresh, rollback, and boot-time recovery. Use when a user reports a broken Reality/Mihomo/Clash proxy, asks to connect a client or make household/travel-router devices use a proxy, or wants a resilient low-maintenance setup without exposing credentials.
---

# Reality Handshake and Router Operations

Operate only systems the user owns or is authorized to administer. Prefer a reversible, evidence-led workflow over editing a live configuration in place.

## Non-negotiable rules

1. Start read-only unless the user explicitly asks for a change.
2. Never print, persist in logs, commit, or paste subscription URLs, UUIDs, private keys, public household IPs, or complete node URIs. Treat a subscription URL as a bearer credential.
3. Back up the current working state, build a candidate, validate it with the exact target binary, switch atomically, run end-to-end tests, and roll back on failure.
4. Do not diagnose an HTTP/SOCKS proxy with `ping`; ICMP does not traverse those proxies. Use an HTTP request through the proxy.
5. Do not infer a single root cause from one Reality log line. Separate observations, hypotheses, and confirmed causes.
6. Keep the router management path and Wi-Fi usable. Exclude router/local/reserved addresses from transparent interception.
7. For fail-open designs, allow data traffic to fall back to direct only with the user's consent. Never let DNS for known-blocked domains fall back to a potentially polluted direct resolver.
8. Confirm the installed Xray version and test configuration fields against that binary. Official documentation follows current releases and may describe fields unavailable in older builds.

## Select the workflow

- Broken local client, proxy port, or Reality handshake: read [references/handshake-diagnosis.md](references/handshake-diagnosis.md).
- Clash/Mihomo mixed-port Timeout, `SSL_ERROR_SYSCALL` through `7890`, or a free DDNS hostname as `server:`: read [references/handshake-diagnosis.md](references/handshake-diagnosis.md) section 8 (hostname vs TCP).
- Embedded router, FreshTomato, transparent proxy, split routing/DNS, boot scripts, or constrained ARM hardware: read [references/router-deployment.md](references/router-deployment.md).
- macOS client onboarding, blocked entry-IP diagnosis, modern OpenWrt/fw4, or a low-end OpenWrt router that must bridge legacy Shadowsocks to a Mihomo/REALITY relay: read [RUNBOOK-zh.md](RUNBOOK-zh.md) in full, then apply the universal safety transaction below.
- Multiple nodes, observatory, fail-open, subscriptions, rule updates, scheduled health checks, or rollback: read [references/resilience-and-subscriptions.md](references/resilience-and-subscriptions.md).
- Before handoff or after a risky change: read [references/verification-runbook.md](references/verification-runbook.md).

Read only the references relevant to the request, but read each selected file completely.

## Universal workflow

### 1. Establish scope and recovery

Record without secrets:

- controlled hosts and connection paths;
- router model, firmware, kernel, CPU ABI, free flash/RAM, and persistent storage;
- current network topology and the management IP that must remain reachable;
- known-good configuration, backup path, and recovery method;
- desired policy: blocked-only, foreign-site, per-device, or global proxy;
- failure policy: fail-closed or explicitly approved fail-open.

If a remote mutation could sever the only management path and there is no wired/console recovery, stop before applying it.

### 2. Build an evidence table

Use this shape in notes or the final response:

| Layer | Read-only check | Result | Interpretation |
| --- | --- | --- | --- |
| LAN/WAN | address, route, DNS, direct HTTP | pass/fail | base connectivity |
| Process | PID, listeners, RSS, file descriptors | pass/fail | runtime health |
| Proxy | HTTP request through local inbound | pass/fail | end-to-end data path |
| Reality | TCP reachability, time, credentials, logs | pass/fail | handshake layer |
| Routing | one direct and one proxied domain | pass/fail | rule behavior |
| DNS | direct-domain and blocked-domain answers | pass/fail | split DNS/pollution |
| Recovery | restart/reboot/rollback | pass/fail | operational resilience |

State uncertainty explicitly. A reachable TCP port proves only reachability, not authentication or a usable proxy.

### 3. Use a safe change transaction

For every configuration, rule-data, or subscription update:

```text
fetch/read → stage privately → normalize/whitelist → structural checks
→ exact-binary config test → isolated functional test → atomic switch
→ restart/reload → smoke tests → keep current + one backup
                         ↘ any failure: restore previous state
```

Candidate files containing credentials must be mode `0600`. Prefer `/tmp` for decoded subscription material and delete it on exit. Do not use broad search/replace against production JSON.

Use [scripts/validate-xray-candidate.sh](scripts/validate-xray-candidate.sh) for exact-binary validation when compatible with the host.

### 4. Verify the behavior the user asked for

At minimum test:

- router management remains reachable;
- a domestic or explicitly direct site stays direct;
- a GFW-list site uses a healthy proxy;
- DNS for both classes follows the intended path;
- the same tests after restarting Xray;
- fail-open or fail-closed behavior by simulating an unavailable proxy;
- boot persistence when a reboot is safe and authorized.

Compare egress IPs without publishing them. Flush the client DNS cache or reconnect Wi-Fi before concluding a router DNS fix failed.

## Design defaults for a household router

Use these only after capability checks and user approval:

- Policy: private/direct first, `geosite:gfw` through a proxy pool, `geosite:cn` and `geoip:cn` direct, unmatched traffic direct.
- Rule semantics: Xray routing is first-match; order is part of the security policy.
- DNS: normal domains use a nearby direct resolver; GFW-list domains are conditionally forwarded to a clean resolver through a proxy-only DNS path.
- Data HA: `observatory` plus `leastPing` or another supported strategy; direct fallback is allowed only for approved fail-open behavior.
- DNS HA: use a separate proxy-only selector or a fixed healthy proxy. Do not reuse a data balancer whose fallback is `direct`.
- Updates: fetch rule/subscription candidates on a schedule, do nothing when the source hash is unchanged, validate before switching, retain only current and one backup.
- Runtime: disable access logs unless actively debugging, cap error logs, raise per-process file descriptors where supported, and monitor PID/listeners/RSS/FDs.

On constrained firmware, prefer a stable conservative design over every available feature. A working split-DNS implementation using dnsmasq conditional forwarding can be safer than an unverified built-in DNS arrangement.

## Hand-off format

Report:

1. the resulting topology and policy in plain language;
2. evidence for each acceptance test;
3. exactly what starts at boot and what cron jobs exist;
4. commands for status, proxy/direct mode, restart, logs, manual update, and rollback;
5. secret locations and permissions without revealing their values;
6. known limits, especially single-provider or single-control-plane failure domains;
7. the recovery path if Wi-Fi or proxying fails.

Run [scripts/scan-secrets.sh](scripts/scan-secrets.sh) before committing any generated documentation or examples.

## Authoritative references

Prefer current official Xray documentation for field semantics:

- [Configuration](https://xtls.github.io/en/config/)
- [REALITY](https://xtls.github.io/en/config/transports/reality.html)
- [Routing](https://xtls.github.io/en/config/routing.html)
- [DNS](https://xtls.github.io/en/config/dns)
- [Observatory](https://xtls.github.io/en/config/observatory.html)
- [Inbound sniffing](https://xtls.github.io/en/config/inbound.html)
- [Socket options and TPROXY](https://xtls.github.io/en/config/transports/sockopt.html)

Use community guides as implementation context, not as a substitute for testing the installed binary.
