# Reality handshake diagnosis

Use this runbook for a local Xray/Mihomo/Clash proxy that is unreachable, connects but transfers no data, or reports a REALITY handshake failure.

## 1. Preserve evidence

Do not enable verbose logging indefinitely and do not paste complete configurations into tickets. Capture a narrow time window, redact client/server addresses and credentials, and return logging to `warning` after diagnosis.

Record these timestamps in one timezone:

- client request start;
- corresponding client error;
- corresponding server log entries;
- server clock and client clock.

## 2. Establish a direct baseline

Use HTTP, not ICMP:

```bash
curl -fsS --max-time 10 https://api.ipify.org >/dev/null
curl -fsS --max-time 10 -x http://127.0.0.1:10809 https://api.ipify.org >/dev/null
curl -fsS --max-time 10 --socks5-hostname 127.0.0.1:10810 https://api.ipify.org >/dev/null
```

Interpretation:

- direct fails: fix WAN, DNS, clock, or local firewall first;
- direct passes but no listener exists: fix service startup or inbound address/port;
- listener exists but proxy request fails: inspect client logs and upstream reachability;
- proxy request passes: the core path works; investigate application-specific DNS/rules instead.

`--socks5-hostname` resolves the target through the SOCKS path. Plain `--socks5` can accidentally test local DNS instead.

## 3. Read-only client audit

```bash
ps w | grep -E '[x]ray|[m]ihomo|[c]lash'
ss -lntup 2>/dev/null | grep -E '10809|10810|7890|7891|12345|1053'
env | grep -iE '^(http|https|all|no)_proxy='
date -u
```

Locate the active configuration from the process arguments or service definition. Do not assume the file a user remembers is the file the process loaded.

Check for:

- inbound address and port matching the application;
- another core already owning the port;
- proxy environment variables pointing at a stale port;
- DNS mode differences between the application and command-line test;
- a client clock outside the server's accepted range.

## 4. Read-only server audit

On a systemd server, adapt paths as needed:

```bash
systemctl status xray --no-pager
ss -lntup
journalctl -u xray --since '-5 min' --no-pager
date -u
```

Check from the client whether the configured server port is reachable. A successful TCP connection does not prove that UUID, REALITY keys, short ID, SNI, or transport settings match.

Check server egress to its configured REALITY `target`/legacy `dest`, including TLS/SNI behavior, not only whether port 443 opens.

## 5. Compare credentials without exposing them

The following must be consistent:

| Client | Server | Requirement |
| --- | --- | --- |
| user UUID | allowed client UUID | exact match |
| `password`/legacy `publicKey` | derived server public key | exact match |
| `shortId` | one of `shortIds` | exact even-length hex value |
| `serverName` | one of `serverNames` | permitted SNI |
| transport/security/flow | inbound support | compatible combination |

Derive the public key locally on the server and compare hashes or boolean equality. Never place the private key on a command line that will be retained in shell history. Use protected input or a short-lived root-only script when derivation is necessary.

Current Xray documentation allows `flow: "xtls-rprx-vision"` for compatible VLESS TCP with TLS/REALITY. Do not remove it merely because REALITY is in use. Conversely, do not add it without confirming both ends and the installed version support it.

## 6. Interpret REALITY logs conservatively

`handshakeStatus: false` or `processed invalid connection` says that a connection did not complete as an authenticated REALITY session. It can result from unrelated internet scans, wrong credentials, clock skew, SNI/short-ID mismatch, incompatible client fingerprints, transport mismatch, client cancellation, or upstream target behavior.

To attribute a failure:

1. trigger exactly one client request at a known time;
2. correlate its source and timestamp with server logs;
3. confirm the port, UUID, key, short ID, SNI, transport, and clock;
4. reproduce with a known-good client if available;
5. test the configured target from the server with the intended SNI;
6. change only one variable in a validated candidate.

Treat “the target banned this server IP” as a hypothesis, not a default diagnosis. Confirm it only when the same credentials and client work after changing only the target/SNI pair, and the old target fails repeatably from the same server.

## 7. Safe target/SNI rotation

Do not use a hard-coded public list as a promise that a site is suitable forever. Target suitability changes, and REALITY's unauthenticated fallback behavior has operational and abuse implications.

Before rotation:

- verify the target is lawful and appropriate for the deployment;
- verify TLS 1.3, SNI, certificate chain, latency, and reachability from the server;
- understand that unauthenticated traffic may be forwarded to the target;
- prefer infrastructure under the operator's control where practical;
- retain the last working server and client configurations.

Then:

1. build server and client candidates;
2. test both with their exact binaries;
3. change the server first only when an overlap strategy keeps existing clients working, otherwise coordinate a maintenance window;
4. perform one proxied HTTPS request;
5. roll back both ends if the test fails.

Never use an unguarded `sed -i` against production JSON.

## 8. Other frequent causes

- WAN or DNS is down before Xray starts.
- Server port is closed or forwarded to the wrong host.
- Server listens on IPv6 while the client reaches IPv4, or the reverse.
- Credentials were partially rotated.
- `xver` sends PROXY protocol to a target that does not accept it.
- Client fingerprint or transport differs from the server expectation.
- A stale service instance still owns the inbound port.
- File descriptor exhaustion causes intermittent accepts or dials.
- The application retained a polluted DNS answer after the proxy was fixed.

## 9. Completion evidence

Do not declare success until:

- direct baseline passes;
- proxy request returns through the intended egress;
- client and server logs have no corresponding error;
- one ordinary application request succeeds;
- the result survives a service restart;
- logging has been returned to its normal level.
