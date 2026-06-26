---
name: reality-handshake
description: Diagnose VLESS+Reality / proxy handshake failures. Use PROACTIVELY when user reports "proxy doesn't work", "代理不管用了", "代理失效", curl through proxy returns empty / SSL_ERROR_SYSCALL, or ping to a host returns 100% loss (which is NORMAL and not a proxy bug). Guides through client-side (.bashrc aliases, env vars) and server-side (xray debug logs on the upstream Vultr/host) investigation, then fixes the most common cause — dest site banning the server's IP — by rotating the dest/serverNames in both server config.json and client config.
---

# Reality Handshake Debug

A protocol-level debugging skill for VLESS+Reality (and similar Xray/Sing-box/Mihomo) setups. Use when the user has a configured proxy that "used to work" or "doesn't connect now."

## The #1 Mistake: Testing Proxy with Ping

**`ping` uses ICMP, which HTTP/SOCKS proxies do NOT forward.** `ping google.com` returning 100% loss under `proxy-on` is normal — it does NOT mean the proxy is broken.

Test the proxy with **`curl`** instead:

```bash
# Direct (no proxy) baseline
curl -v --max-time 8 https://api.ipify.org
# Through HTTP proxy
curl -v --max-time 8 -x http://127.0.0.1:10809 https://api.ipify.org
# Through SOCKS5 proxy
curl -v --max-time 8 --socks5-hostname 127.0.0.1:10810 https://api.ipify.org
```

`api.ipify.org` returns the egress IP — instant "did the proxy work?" check.

## Step 1: Client-Side Audit (Read-Only)

Find what `proxy-on`/`proxy-off` actually do, and what ports they target:

```bash
ssh user@CLIENT_HOST bash <<'EOF'
grep -E "proxy|export" /root/.bashrc /etc/profile.d/* 2>/dev/null | grep -iE "10809|10810|http_proxy|socks"
ss -tlnp | grep -E "10809|10810|7890|9090"
ls /etc/xray /usr/local/etc/xray /etc/mihomo 2>/dev/null
EOF
```

The typical setup (xray):
- `http_proxy=http://127.0.0.1:10809` ← xray HTTP inbound
- `https_proxy=http://127.0.0.1:10809` ← same
- `all_proxy=socks5://127.0.0.1:10809` (or `10810`)

The ports **must match** xray's `inbounds.port` exactly.

## Step 2: Server-Side Audit (SSH to Upstream)

If the client-side looks right but curl still fails, **SSH to the upstream proxy server** (often Vultr/DO/Hetzner, look for it in user's `~/.ssh/config` or `/root/.ssh/known_hosts`). The upstream server hosts the **Reality server config**, not just the client.

```bash
ssh root@UPSTREAM_IP bash <<'EOF'
echo "=== xray server config ==="
cat /usr/local/etc/xray/config.json
echo ""
echo "=== derive publicKey from server's privateKey ==="
/usr/local/bin/xray x25519 -i "PRIVATE_KEY_HERE"
echo ""
echo "=== xray debug logs (last 50) ==="
journalctl -u xray -n 50 --no-pager
echo ""
echo "=== can the server reach its dest? ==="
# Replace www.samsung.com with the actual dest
timeout 5 bash -c "echo > /dev/tcp/www.samsung.com/443" && echo "dest reachable" || echo "dest BLOCKED"
EOF
```

## Step 3: Match Client Credentials to Server

The four Reality credentials that **must match** between client and server:

| Field | Client side | Server side |
|-------|-------------|-------------|
| UUID | `vnext[].users[].id` | `inbounds[].settings.clients[].id` |
| publicKey | `realitySettings.publicKey` | derived from `realitySettings.privateKey` via `xray x25519 -i <privkey>` |
| shortId | `realitySettings.shortId` | `realitySettings.shortIds[]` (any match) |
| serverName | `realitySettings.serverName` | must be in `realitySettings.serverNames[]` |

```bash
# Verify the publicKey/privateKey pair matches:
SERVER_PRIV="paste_from_server_config"
CLIENT_PUB="paste_from_client_config"
SERVER_PUB=$(/usr/local/bin/xray x25519 -i "$SERVER_PRIV" | grep "Public key" | awk '{print $NF}')
[ "$SERVER_PUB" = "$CLIENT_PUB" ] && echo "✓ keys match" || echo "✗ MISMATCH — rotate keys"
```

**If all four match and it's still broken, jump to Step 4.**

## Step 4: The "dest Banned Our IP" Diagnosis

This is the failure mode that looks like "broken proxy" but isn't — the server is fine, the keys are fine, but the **dest site (www.microsoft.com, etc.) has banned the upstream server's IP** from being impersonated via REALITY.

### Symptom in server debug log:

```
REALITY remoteAddr: CLIENT_IP:PORT
hs.c.AuthKey[:16]: [...]            ← X25519 OK
hs.c.ClientVer: [1 8 24]            ← client version reported
hs.c.ClientTime: ...                ← client time reported
hs.c.ClientShortId: [104 ...]       ← shortId matched
hs.c.conn == conn: true             ← conn matched
[s2c bytes get written — Server Hello, CCS, EE, Certificate]
hs.c.handshakeStatus: false         ← but client never Finished
[Info] transport/internet/tcp: REALITY: processed invalid connection
```

All crypto checks pass, but the server still marks the connection invalid. This is **NOT a config bug** — it's the dest site (e.g. Microsoft) refusing to serve a forged handshake from this Vultr IP.

### The Fix: Rotate `dest` (and `serverNames`)

Pick a different HTTPS site as the new dest. Known-working options (try in order):
- `www.samsung.com:443` (commonly used, rarely blocks)
- `www.apple.com:443`
- `gateway.icloud.com:443`
- `dl.google.com:443`
- `www.mozilla.org:443`
- **"Steal yourself"** (best long-term): point dest at your own domain on the same server (Caddy/Nginx with a real cert on port 9443, then `dest: 127.0.0.1:9443`)

**Apply on BOTH sides:**

```bash
# On the server (your upstream provider):
ssh root@UPSTREAM_IP bash <<'EOF'
sed -i 's|"dest": "www.microsoft.com:443"|"dest": "www.samsung.com:443"|' /usr/local/etc/xray/config.json
sed -i 's|"serverNames": \["www.microsoft.com"\]|"serverNames": ["www.samsung.com","samsung.com"]|' /usr/local/etc/xray/config.json
systemctl restart xray
EOF

# On the client:
sed -i 's|"serverName": "www.microsoft.com"|"serverName": "www.samsung.com"|' /usr/local/etc/xray/config.json
systemctl restart xray  # or kill mihomo and restart
```

Test:
```bash
curl -s --max-time 10 -x http://127.0.0.1:10809 https://api.ipify.org
# Should return your upstream server's public IP
```

## Step 5: Other Common Causes (in priority order)

1. **Wrong port forward / firewall** — `ss -tlnp` on server, check inbound port matches client `port:`. Test raw TCP: `timeout 5 bash -c "echo > /dev/tcp/UPSTREAM/PORT"`.
2. **Stale keys after migration** — re-run `xray x25519` on server, paste new `publicKey` into client.
3. **Network blocks 443 outbound** — check if your LAN blocks outbound 443: `timeout 5 bash -c "echo > /dev/tcp/1.1.1.1/443"`. Reality needs outbound 443.
4. **`xver` mismatch** — `xver: 1` or `2` requires the dest (e.g. nginx) to have `proxy_protocol` enabled. Set `xver: 0` unless you know the dest supports it.
5. **`flow` field** — Reality works fine with `flow: ""` (empty). Don't set `flow: xtls-rprx-vision` for Reality (that's for older XTLS-Vision setups).
6. **Server time skew** — Reality validates client time. If client clock is >1 min off, auth fails silently. Check `date` on both.
7. **mihomo xray service conflict** — both default to port 10809. Run only one at a time. `pkill -f mihomo` before starting xray, or vice versa.

## Diagnostic Command Cheat Sheet

```bash
# Egress IP (direct vs proxy)
curl -s https://api.ipify.org
curl -s -x http://127.0.0.1:10809 https://api.ipify.org

# Watch debug log while triggering
ssh root@UPSTREAM_IP 'journalctl -u xray -f --no-pager' &

# See Reality auth details (set on server first)
sed -i 's/"loglevel": "warning"/"loglevel": "debug"/' /usr/local/etc/xray/config.json
ssh root@UPSTREAM_IP 'systemctl restart xray'

# Try multiple SNIs to test which dest sites are reachable from server
for sni in www.microsoft.com www.apple.com gateway.icloud.com dl.google.com www.samsung.com; do
  timeout 5 bash -c "echo > /dev/tcp/$sni/443" && echo "✓ $sni:443" || echo "✗ $sni:443"
done
```

## TL;DR Diagnosis Flow

```
proxy broken?
  ↓
[1] is ping the only test? → use curl instead
  ↓
[2] direct curl works?     → proxy path is the issue
  ↓
[3] ports match client↔server? → check xray config.json both sides
  ↓
[4] credentials match?     → derive server pubKey, compare to client
  ↓
[5] server debug log shows
    "handshakeStatus: false" + "processed invalid connection"
    with conn/AuthKey/shortId ALL matching?
  ↓
[6] DEST IS BANNED. Rotate dest+serverNames both sides. Done.
```

## When to Ask User vs Act

- If client-side is unambiguous and you can SSH upstream → **act, fix, verify**
- If you can't reach the upstream server → **stop, ask user for Vultr/console access**
- If the user provides a new working proxy URL/sub → **just regenerate client config**
