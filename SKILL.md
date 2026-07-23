---
name: reality-handshake
description: Diagnose VLESS+Reality / proxy handshake failures, connect new clients (Linux server, macOS CLI, macOS GUI/ClashX Meta) to an existing Reality server, and build transparent-proxy travel routers on low-end OpenWrt hardware (随身路由器/透明代理) where xray can't run — bridging legacy Shadowsocks clients (aes-256-cfb only) to a modern Reality chain via a mihomo shadowsocks-listener relay on a domestic VPS. Use PROACTIVELY when user reports "proxy doesn't work", "代理不管用了", "代理失效", curl through proxy returns empty / SSL_ERROR_SYSCALL, ping to a host returns 100% loss (which is NORMAL and not a proxy bug), or asks to put a proxy on a router/OpenWrt/路由器上装代理. Guides through client-side (.bashrc aliases, env vars) and server-side (xray debug logs on the upstream Vultr/host) investigation, fixes the most common cause — dest site banning the server's IP — by rotating dest/serverNames, detects blocked entry IPs (domain IP dead on all ports while the server's other IP works), prefers IPs over free dynamic-DNS names in configs, and sets up macOS clients two ways: command-line xray or ClashX Meta GUI.
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

## Step 5b: The "Entry IP Is Blocked, But the Server Isn't" Diagnosis

A different failure mode: config and credentials are 100% correct, but the client simply cannot TCP-connect to the server. Before blaming the protocol, check **which IP you're connecting to** — a server can have several IPs, and GFW/ISP blocking is per-IP, not per-server.

Real case: a VPS had its xray domain resolving to IP-A (dead from the client's home network on **every** port), while its primary IP-B (the one in `~/.ssh/config`, used daily for SSH) was fully reachable — including the xray inbound port, because xray listens on `0.0.0.0`.

### How to check

```bash
# 1. What IP does the client config actually use?
dig +short your.xray.domain

# 2. Single-port block or whole-IP block? Test several ports:
for p in 8443 443 80 22; do nc -z -G 4 IP_A $p && echo "$p ok" || echo "$p DEAD"; done
# ALL ports dead = IP-level block. Only the xray port dead = port-level.

# 3. Does the server have another IP you already reach (e.g. for SSH)?
grep -A3 'Host myserver' ~/.ssh/config | grep HostName
for p in 8443 22; do nc -z -G 4 IP_B $p && echo "$p ok" || echo "$p DEAD"; done
```

### The fix

Point the client `address` at the reachable IP. Reality does **not** care about the connecting IP or the domain — `serverName` (SNI) is what matters, so no other config change is needed.

**Tell-tale symptom of partial/transient blocking:** an otherwise-correct chain that flaps — Google works, then times out, then works again — while the server's own egress is perfect (`curl` from the server itself: 200 in 0.06s). That's QoS/blocking on the transit path to that specific IP, not a config bug.

## macOS: Connecting a Mac Client to an Existing Reality Server

Two supported paths. Both verified end-to-end (xray 26.3.27 darwin/arm64, mihomo v1.19.28 / ClashX Meta v1.4.43).

### Path A — CLI xray (mirrors the Linux server setup)

1. **Install.** `brew install xray` often hangs forever because GitHub is unreachable without a proxy (chicken-and-egg). Workaround: download the release **on an already-proxied server** (or the upstream itself) and `scp` it back:
   ```bash
   ssh root@UPSTREAM 'cd /tmp && curl -sLO https://github.com/XTLS/Xray-core/releases/download/vX.Y.Z/Xray-macos-arm64-v8a.zip && unzip -qo Xray-macos-arm64-v8a.zip -d xray-mac'
   mkdir -p ~/xray-local && scp root@UPSTREAM:/tmp/xray-mac/{xray,geoip.dat,geosite.dat} ~/xray-local/ && chmod +x ~/xray-local/xray
   ```
   ⚠️ Asset name trap: the arm64 asset is `Xray-macos-arm64-v8a.zip` — `Xray-macos-arm64.zip` returns a 9-byte "Not Found". Intel Macs use `Xray-macos-64.zip`. Check real names via `api.github.com/repos/XTLS/Xray-core/releases/latest`. Files copied via `scp` carry **no quarantine xattr** and run directly; browser-downloaded ones need `xattr -dr com.apple.quarantine`.
2. **Config.** Same JSON as a Linux client. No `systemctl` — run it plainly:
   ```bash
   cd ~/xray-local && ./xray run -c config.json   # foreground/background
   pkill -f 'xray run'                             # stop
   ```
   Use `launchd` if autostart is needed.
3. **Verify:** `curl -s -x http://127.0.0.1:10809 https://api.ipify.org` → upstream IP.

### Path B — GUI: ClashX Meta

1. **Original ClashX cannot do VLESS+Reality** (Clash Premium core). You need a mihomo-core GUI: ClashX Meta, Mihomo Party, Clash Verge (rev). Check what's installed: `ls /Applications | grep -i clash`.
2. **Config dir is `~/.config/clash.meta/`** (original ClashX uses `~/.config/clash/`). Write a `config.yaml` there — full working skeleton:
   ```yaml
   mixed-port: 7891                      # 7890/9090 belong to original ClashX — pick free ports
   external-controller: 127.0.0.1:9097
   mode: rule
   log-level: warning
   proxies:
     - name: "my-reality"
       type: vless
       server: REACHABLE_IP              # see Step 5b — IP is fine, SNI does the work
       port: 8443
       uuid: <UUID>
       network: tcp
       udp: true
       tls: true
       servername: www.samsung.com       # = serverNames[] on the server
       client-fingerprint: chrome
       reality-opts:
         public-key: <PUBLIC_KEY>
         short-id: "68"
   proxy-groups:
     - {name: PROXY, type: select, proxies: [my-reality, DIRECT]}
   rules:
     - GEOSITE,cn,DIRECT
     - GEOIP,CN,DIRECT
     - MATCH,PROXY
   ```
3. **Validate the config without the GUI** — the mihomo core ships gzipped inside the bundle:
   ```bash
   gunzip -c "/Applications/ClashX Meta.app/Contents/Resources/com.metacubex.ClashX.ProxyConfigHelper.meta.gz" > /tmp/mihomo && chmod +x /tmp/mihomo
   /tmp/mihomo -d ~/.config/clash.meta -f ~/.config/clash.meta/config.yaml -t
   ```
4. **The #1 GUI gotcha: the core is spawned by a privileged helper.** On first launch the app stays alive but **no core ever starts** (empty `~/.config/clash.meta/logs/*/clashx_mihomo.log`, no listening ports) until the user authorizes the helper install **interactively** (password dialog / System Settings → Login Items). Launching from a terminal cannot click that dialog — hand this step to the user. Verify the helper landed: `ls /Library/PrivilegedHelperTools/com.metacubex.ClashX.ProxyConfigHelper`. After it exists, `open -a "ClashX Meta"` starts the core normally.
5. **Verify via the core API:**
   ```bash
   curl -s http://127.0.0.1:9097/version                                    # {"meta":true,...}
   curl -s "http://127.0.0.1:9097/proxies/my-reality/delay?url=https://www.gstatic.com/generate_204&timeout=10000"
   curl -s -x http://127.0.0.1:7891 https://api.ipify.org                   # → upstream IP
   ```
6. **System proxy: let the app manage it.** Do NOT write it yourself with `networksetup` — the app restores the setting on quit only if it set it; a `networksetup`-written proxy pointing at a dead app kills the whole machine's network. The user clicks "设置为系统代理" in the menu bar.
7. **Coexistence.** Only one client may hold "set as system proxy". Quit the original gracefully: `osascript -e 'quit app "ClashX"'` (it restores system proxy on quit).

### macOS vs Linux cheat sheet

| Linux | macOS |
|---|---|
| `systemctl restart xray` | run binary directly / `launchd` |
| `ss -tlnp` | `lsof -nP -iTCP:PORT -sTCP:LISTEN` |
| `timeout 5 bash -c "echo > /dev/tcp/H/P"` | `nc -z -G 5 H P` |
| `/usr/local/etc/xray/config.json` | anywhere, e.g. `~/xray-local/config.json` |
| quit service | `osascript -e 'quit app "X"'` / `pkill -f` |

## Low-End OpenWrt Travel Router: Transparent Proxy When xray Can't Run

Scenario: user wants a pocket router (e.g. TP-Link TL-WR720N, AR9330 400MHz, **4MB flash / 32MB RAM**) where any phone/laptop that joins its Wi-Fi gets auto-proxied. **Do NOT try to run xray/mihomo/sing-box on the device** — the binary alone (~20-30MB, ~40MB+ RAM under load) exceeds the whole machine. Reality on the router is physically impossible; don't burn time attempting it.

### The architecture that works

```
clients ⇵ router (ss-redir, aes-256-cfb) ⇵ domestic relay VPS ⇵ Reality ⇵ upstream VPS ⇵ out
```

Three legs, each with a distinct job:

1. **Router → domestic relay: Shadowsocks with a legacy cipher.** Old routers ship `shadowsocks-libev` (ss-redir/ss-tunnel) — tiny and already installed. This leg is domestic traffic, so GFW doesn't interfere.
2. **Relay → upstream: your existing Reality chain, unchanged.** The relay runs its normal mihomo/xray client.
3. **The bridge: mihomo's own shadowsocks inbound** (a `listeners:` entry). This is the key trick — see "The cipher gap" below. No extra software needed if the relay already runs mihomo.

### The cipher gap (why you can't point ss-redir at xray directly)

- Xray's shadowsocks inbound **dropped all legacy stream ciphers** (aes-256-cfb, chacha20, ...) — AEAD only now.
- Old router ss clients (e.g. shadowsocks-libev 2.4.5-polarssl on Chaos Calmer) **only have stream ciphers** — no aes-gcm, no chacha20-ietf-poly1305. Check with `ss-redir -h`.

No common cipher ⇒ no direct connection. If the relay runs **mihomo**, its built-in shadowsocks inbound still accepts legacy ciphers (aes-256-cfb included) and handles UDP relay natively — add a listener and the bridge is done, zero new software:

```yaml
# On the domestic relay (Aliyun/Tencent Cloud — NOT the foreign upstream),
# in mihomo config.yaml:
listeners:
- name: ss-in
  type: shadowsocks
  port: 8388
  listen: 0.0.0.0
  cipher: aes-256-cfb
  password: RANDOM_PASS
  udp: true
```

**gost is NOT a working alternative for UDP.** gost v2's `ss://` TCP listener chains fine (`-F socks5://...`), but its `ssu://` UDP handler is incompatible with shadowsocks-libev clients — every ss-tunnel packet dies with `[ssu] EOF` (verified v2.12.0 ↔ libev 2.4.5, reproduced client-local). If the relay's Reality client is xray (no SS inbound at all), use mihomo just for the SS leg instead.

### mihomo ss-inbound UDP ignores the rule engine (the DNS trap)

Verified on mihomo v1.19.2: UDP packets arriving on a shadowsocks listener **skip all rules and go DIRECT** (`[UDP] x --> 8.8.8.8:53 doesn't match any rule using DIRECT`) — even `DST-PORT,53,proxy` and even though TCP on the same listener matches `MATCH,proxy` correctly. Pointing the router's `ss-tunnel -L` at `8.8.8.8:53` therefore sends DNS out the relay's direct uplink → GFW poisons the answers (chatgpt.com → Facebook/Twitter IPs).

Fix: don't fight the rule engine — aim the tunnel at mihomo's **own DNS module on localhost**, where DIRECT is exactly where the packet needs to go, and let the module resolve via DoH *through* the proxy:

```yaml
dns:
  enable: true
  listen: 127.0.0.1:1053
  ipv6: false
  respect-rules: true            # routes the DoH below through the proxy chain
  proxy-server-nameserver:       # mandatory when respect-rules is on; only used
  - 223.5.5.5                    #   to resolve proxy-node domains (IP nodes: unused)
  nameserver:
  - https://1.1.1.1/dns-query    # IP-literal DoH — no bootstrap resolution needed
  - https://8.8.8.8/dns-query
```

Do NOT add a domestic plain-DNS server (223.5.5.5 etc.) to `nameserver` — mihomo races all nameservers and the poisoned fast answer wins for GFW'd domains. The tunnel only ever carries blocked domains anyway (router dnsmasq sends domestic domains to the ISP DNS directly), so DoH-only is correct here. Then on the router: `ss-tunnel -u -l 5353 -L 127.0.0.1:1053` (NOT `-L 8.8.8.8:53`).

### Why two hops is protection, not fragility

SS traffic is far more fingerprintable than Reality. A home broadband → foreign VPS SS link gets the VPS IP burned fast (Reality direct from home already burned it in a day, in practice). The domestic relay means GFW only ever sees home→domestic-VPS; the foreign IP stays hidden. The relay should be a cloud VPS in the user's own country (Aliyun/Tencent), ideally same city — it adds ~2-5ms, the international leg dominates latency anyway.

The real fragility is **unmanaged processes**: hand-started proxies in /tmp die with the SSH session. systemd-ize everything on the relay with `Restart=always`:

```ini
# /etc/systemd/system/mihomo.service
[Service]
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
Restart=always
RestartSec=5
```

Don't forget the cloud **security group** (Aliyun ECS console): inbound **TCP _and_ UDP** 8388 — they're separate rules, and the OS firewall being open is not enough. Forgetting UDP 8388 = TCP browsing works but DNS times out.

### Router side (legacy OpenWrt, e.g. Chaos Calmer)

Classic transparent-proxy trinity, often already present from a previous owner — audit before rebuilding:

- `/etc/shadowsocks.json` → ss-redir (transparent proxy) + ss-tunnel (DNS → relay's mihomo DNS module `127.0.0.1:1053` via SS-UDP on local 5353 — see "the DNS trap" above)
- `/etc/firewall.user` → `ipset -N gfwlist iphash` + `iptables -t nat -A PREROUTING -p tcp -m set --match-set gfwlist dst -j REDIRECT --to-port 1080` (also `-A OUTPUT` for the router itself)
- dnsmasq-full + a gfwlist file (`/etc/dnsmasq.d/*.conf`) with `server=/.domain/127.0.0.1#5353` + `ipset=/.domain/gfwlist` pairs — GFW'd domains get unpolluted DNS via the tunnel AND their IPs land in the ipset → redirected through SS. Everything else goes direct (WeChat/Alipay keep a domestic IP — important: foreign IPs trigger account security checks).

Self-healing watchdog (these old init scripts leak duplicate processes on restart — `kill -9` leftovers before `start`):

```cron
*/2 * * * * pgrep -x ss-redir >/dev/null || /etc/init.d/shadowsocks start
```

### Router side (modern OpenWrt 21.02+/23.x, fw4/nftables)

Same architecture, different plumbing. Verified on 23.05.3 (MT7620, 128MB RAM):

- **Client: `shadowsocks-libev` from the OpenWrt feeds** (`opkg install shadowsocks-libev-ss-redir shadowsocks-libev-ss-tunnel`) — the musl-safe choice. shadowsocks-rust publishes **glibc-only** mipsel binaries (useless on OpenWrt's musl); a mihomo binary (~50MB) in tmpfs on a 128MB box is an OOM waiting to happen.
- **Supervision: procd, not cron.** One `/etc/init.d/ssproxy` (START=99) with two `procd_open_instance` blocks — `ss-redir -c /etc/shadowsocks.json -b 0.0.0.0` and `ss-tunnel -c ... -b 127.0.0.1 -u -l 5353 -L 127.0.0.1:1053` — each with `procd_set_param respawn 3600 5 5`. `/etc/init.d/ssproxy enable` creates the S99 symlink.
- **nftables, not iptables/ipset.** fw4 auto-includes `/etc/nftables.d/*.nft` inside `table inet fw4`; dnsmasq 2.90+ uses `nftset=` (there is no ipset):

  ```
  # /etc/nftables.d/99-gfw.nft
  set gfwlist { type ipv4_addr; flags interval; }
  chain gfw_prerouting {
      type nat hook prerouting priority dstnat; policy accept;
      ip daddr { 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4 } return
      ip daddr @gfwlist meta l4proto tcp redirect to :1080
  }
  chain gfw_output {
      type nat hook output priority -100; policy accept;   # numeric! 'dstnat' is REJECTED on the output hook
      oifname "lo" return
      ip daddr { 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4 } return
      ip daddr @gfwlist meta l4proto tcp redirect to :1080
  }
  ```

- gfwlist file line format becomes `server=/.domain/127.0.0.1#5353` + `nftset=/.domain/4#inet#fw4#gfwlist` (the `4#` = ipv4 family).
- **`confdir` is load-bearing and its failure is silent.** `/etc/dnsmasq.d/*.conf` is only read when `uci get dhcp.@dnsmasq[0].confdir` is `/etc/dnsmasq.d`. If that option is missing, the generated `/var/etc/dnsmasq.conf.*` falls back to `conf-dir=/tmp/dnsmasq.d` and the ENTIRE gfwlist is ignored — every blocked domain resolves via poisoned ISP DNS while everything else looks perfectly healthy. Verify with `grep conf-dir /var/etc/dnsmasq.conf.*`, never by assuming.
- **Poisoned AAAA**: if the WAN has no global IPv6, GFW-injected AAAA answers (e.g. Facebook v6 for chatgpt.com) break clients even when A is clean → `uci set dhcp.@dnsmasq[0].filter_aaaa='1'`.
- **File transfer**: dropbear has **no sftp-server** — plain `scp` fails; use `scp -O` (legacy protocol) or tar-over-ssh. BusyBox has no `base64`, no `blkid` applet on some builds.
- **Factory recovery**: a fresh OpenWrt (after `firstboot`) accepts SSH root login with an **empty password** — `sshpass -p '' ssh -o PreferredAuthentications=password root@192.168.1.1` gets you in without touching LuCI.

### Gotchas that WILL bite (all hit in practice)

1. **Dropbear on Chaos Calmer is ancient (2015.67)**: modern OpenSSH clients need `-o KexAlgorithms=+diffie-hellman-group14-sha1 -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa`. Put them in a `~/.ssh/config` Host block.
2. **No ed25519 support** in dropbear 2015.67 — `ssh-copy-id` of your default ed25519 key silently can't work. Use an RSA key.
3. **OpenWrt dropbear reads `/etc/dropbear/authorized_keys`**, NOT `~/.ssh/authorized_keys` — `ssh-copy-id` puts the key in the wrong place.
4. **LuCI "Save" ≠ "Save & Apply"** — changes are staged, not live. Symptom: "SSH password auth is enabled but still rejects root".
5. **4MB flash discipline**: check `df -h /` (may be ~72KB free). Config edits only — no `opkg install`, no file drops.
6. **Write IPs, never free dynamic-DNS names, in proxy configs.** A free hostname (abrdns etc.) silently rotated to a dead third IP and caused "works sometimes" flapping. Reality only needs SNI to match — the `server`/`address` field can be any reachable IP.
7. **Reboot test is the acceptance test** for a travel router: it must come back with ss-redir + iptables + DNS all working, zero touch. Verify from the WAN side too (`ping <wan-ip>` from another LAN host) in case the LAN cable is unplugged during testing.
8. BusyBox is stripped: no `pgrep -a`, no `hostname`, `pgrep -x` only.
9. **dnsmasq `killall -HUP` does NOT flush its cache** — it only re-reads config. After fixing upstream DNS you must `/etc/init.d/dnsmasq restart`, or poisoned answers from the ISP-DNS fallback keep getting served for minutes/hours and look exactly like "the fix didn't work".
10. **GFW poison answers are a zoo, not a pattern**: seen Facebook (31.13.x/157.240.x), Twitter (104.244.x/199.59.x), SoftLayer, and random-cloud IPs injected for blocked domains. Don't "recognize" poisoning by range — verify the real IP via DoH (`curl -H 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name=X&type=A'` through a working proxy) before concluding an answer is fake. (claude.ai's real IP is 160.79.104.10 — looks fake, isn't.)
11. **OpenWrt config changes that vanish after reboot = rotten jffs2, not ghosts.** Symptom cluster: uci options "lost" between boots, services "not autostarting" despite correct rc.d symlinks, dropbear host key changing every boot (host keys live on the overlay). Diagnose with `dmesg | grep jffs2`: a healthy overlay mounts in ~1-10s; a corrupted one takes 60s+ with `Node header CRC failed` — preinit's `mount_root` gives up (~10s), boots on tmpfs, and the late-mounting jffs2 then discards recent writes at the CRC-bad offsets. Usually caused by a flash-full incident or dirty shutdown, not dying hardware. Cure: back up first (`ssh router "tar -C /overlay -cf - upper" > router-backup.tar` — the overlay holds EVERYTHING: config, host keys, authorized_keys, opkg-installed binaries), then `firstboot -y && reboot` (asks the user first — it factory-resets the router), then restore.
12. **Ancient/cheap USB sticks can be unreadable ONLY during preinit.** extroot mount fails at boot with `Block bitmap for group 0 overlaps superblock` / `group descriptors corrupted` / `error loading journal` — on a filesystem that mounts perfectly minutes later. The controller returns garbage on early reads; no software fix (`delay_root` is a device-appearance timeout, not a fixed delay; journal-less ext4 doesn't help; fsck finds nothing). Cheap sticks can also wedge the SCSI layer under sustained writes (recover via `echo 0|1 > /sys/bus/usb/devices/1-1/authorized`). Verdict: don't extroot onto old USB 2.0 sticks — keep root on a healthy jffs2 and use the stick for logs/backups at most.
13. **overlayfs never sees behind-its-back writes.** Restoring a backup tar straight into `/overlay/upper` puts the files on disk, but the running root fs won't show them until a full REBOOT (a `remount` does not refresh the upperdir view). Verify a restore after rebooting, not before — everything looks "missing" otherwise.

### Per-leg verification commands

```bash
# Leg 2+3 (on the relay): does the Reality client work? → upstream IP
curl -s --max-time 15 --socks5-hostname 127.0.0.1:10809 https://api.ipify.org

# Leg 2 (on the relay): does mihomo's SS inbound accept legacy SS? install ss client locally:
apt-get install -y shadowsocks-libev
ss-local -s 127.0.0.1 -p 8388 -l 11080 -k 'PASS' -m aes-256-cfb -b 127.0.0.1 &
curl -s --max-time 20 --socks5-hostname 127.0.0.1:11080 https://api.ipify.org   # → upstream IP

# Leg 1 DNS (on the relay): ss-tunnel UDP → mihomo dns module
ss-tunnel -s 127.0.0.1 -p 8388 -l 5355 -L 127.0.0.1:1053 -k 'PASS' -m aes-256-cfb -u -b 127.0.0.1 &
dig @127.0.0.1 -p 5355 chatgpt.com +short   # → real IPs, NOT 31.13.x/157.240.x/104.244.x

# End-to-end (on the router): gfwlisted domain must work via proxy, domestic direct
wget -q -T 15 -O /dev/null http://www.gstatic.com/generate_204 && echo PROXY-OK
wget -q -T 8  -O /dev/null http://www.baidu.com && echo DIRECT-OK

# From a LAN client: gstatic 204 + a domestic IP-echo site showing the home IP
```

Throughput expectation on AR9330-class hardware: **~8-15 Mbps** (single 400MHz core doing SS crypto + NAT). Fine for phones/browsing, not for speedtests.

### When the user wants REAL Reality on a travel router

Need ≥128MB RAM and a modern OpenWrt — e.g. GL.iNet MT300N-V2 class (~¥100 used), then xray's `linux-mipsle`/`linux-mips32` static binary actually fits. That's the upgrade path; the relay bridge is the zero-cost path for hardware already in hand.

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
[2b] can't even TCP-connect to server? → nc several ports;
     ALL dead = entry IP blocked → switch client address
     to another reachable IP of the same server (Step 5b)
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

new client to add?
  ↓
macOS CLI    → scp xray from a proxied host, run directly (Path A)
macOS GUI    → ClashX Meta; original ClashX CANNOT do Reality;
               core needs one interactive helper authorization (Path B)

proxy on a low-end router (4MB flash / 32MB RAM)?
  ↓
xray on device is IMPOSSIBLE — don't try
  ↓
router ss-redir (aes-256-cfb) → mihomo SS listener on DOMESTIC relay →
  Reality upstream (unchanged)
  xray dropped stream ciphers; old ss clients have ONLY stream
  ciphers; mihomo's listeners: shadowsocks inbound bridges both
  TCP and UDP. ss-tunnel -L must target mihomo's dns module
  (127.0.0.1:1053) — ss-inbound UDP ignores rules and goes DIRECT.
  systemd-ize relay processes.
```

## When to Ask User vs Act

- If client-side is unambiguous and you can SSH upstream → **act, fix, verify**
- If you can't reach the upstream server → **stop, ask user for Vultr/console access**
- If the user provides a new working proxy URL/sub → **just regenerate client config**
