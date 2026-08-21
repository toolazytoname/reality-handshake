# Always-on Mihomo client (macOS / Linux mini host)

Use when the user wants a long-running Mac or Linux box as a household proxy ingress: Mihomo TUN + rule split, Tailscale for admin, no daily `http_proxy` ritual. Read [docs/macos-always-on-client.zh-CN.md](../docs/macos-always-on-client.zh-CN.md) for the human-facing detail.

## Constraints

- Do not commit subscriptions, UUIDs, keys, or household public IPs.
- Do not diagnose the proxy with `ping`.
- Keep Tailscale and LAN reachable: exclude `192.168.0.0/16` and `100.64.0.0/10` from TUN auto-route.
- On macOS, user LaunchAgents cannot create `utun`. Prefer ClashX Meta's privileged helper, or a root LaunchDaemon running `mihomo`. Current ClashX Meta GUI may require a newer macOS than the host has.
- `caffeinate -d` prevents display sleep. Keep-awake helpers must use `-is` only.
- MacBooks cannot bypass the battery on AC. Use separate charger/battery `pmset` profiles: AC `sleep 0` + `displaysleep 1`; battery `sleep 15`. Closing the lid without an external display usually sleeps. `pmset -c disablesleep 1` is heat-risky; never bag a running closed Mac.
- VNC may listen on port 6900 if `/etc/services` maps `rfb` there. `vnc://host` without a port uses 5900 and will fail. Screen Sharing and Remote Management are mutually exclusive; ARD can steal the desktop path without opening RFB.

## Checks

| Layer | Read-only check | Pass looks like |
| --- | --- | --- |
| Process | `mihomo` as root/systemd, mixed-port listen | running, Restart=always |
| TUN | interface with `198.18.0.1` or equivalent | present when tun.enable |
| Routing | `100.64/10` more specific than Clash catch-alls | Tailscale SSH still works |
| Data | HTTP through TUN without env proxy | blocked site via proxy, CN direct |
| Admin | Tailscale IP + SSH 22 | reachable after TUN up |
| Power | `pmset -g custom`, `pmset -g assertions` | AC sleep=0, displaysleep=1, no caffeinate `-d` |
| Display/VNC | `netstat` / `nc` to RFB port; Sharing pane | listener on 5900 or 6900; Screen Sharing on, Remote Management off |

## Change transaction

Stage config → `mihomo -t -d <dir>` → stop user agent if switching to daemon → load LaunchDaemon/systemd → smoke tests → keep previous plist/yaml as backup.
