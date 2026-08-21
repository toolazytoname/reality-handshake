# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Always-on macOS/Linux Mihomo TUN client scenario (Tailscale coexistence, no daily `http_proxy`, display/lid power notes) in `docs/macos-always-on-client.zh-CN.md` and `references/macos-always-on-client.md`.

### Preserved OpenWrt and Mihomo work

- Travel-router bridge uses Mihomo's Shadowsocks listener (TCP+UDP) in place of a gost bridge; the companion `RUNBOOK-zh.md` documents the cipher and DNS constraints.
- Modern OpenWrt/fw4 guidance covers dnsmasq `nftset=`, procd, nftables includes, IPv4-only DNS handling, dropbear/scp compatibility, jffs2 degradation, and extroot recovery boundaries.
- Added the sanitized Chinese operational runbook for entry-IP changes, relay changes, reboot acceptance, and OpenWrt storage diagnosis.

### Added

- GPT Image 2 project-overview hero covering clients, router variants, split DNS, proxy/server paths, validation, health, and rollback
- FreshTomato/embedded-router transparent-proxy workflow with capability probing, Wi-Fi/LAN safety, TPROXY, boot recovery, FD/log health, and rollback
- GFW List blocked-only routing and dnsmasq conditional split-DNS guidance
- Separate data and DNS selectors so approved data fail-open cannot pollute GFW DNS
- Xray observatory/multi-node resilience and single-control-plane caveats
- Defensive airport subscription and geosite/GFW rule refresh transactions
- Chinese router architecture and operations guides with Mermaid diagrams
- Two GPT Image 2 architectural illustrations
- Exact-binary candidate validator, Markdown link checker, secret scanner, and GitHub Actions validation
- Codex `agents/openai.yaml` metadata and multi-file atomic installer

### Changed

- Reframed `SKILL.md` as a concise workflow router with progressive references
- Made all mutation guidance candidate-first, atomic, smoke-tested, and rollback-capable
- Replaced the definitive “target banned the IP” diagnosis with an evidence-based hypothesis workflow
- Corrected VLESS+REALITY Vision guidance to match current Xray documentation
- Updated contribution, issue, pull-request, and security guidance to avoid collecting credentials

### Removed

- Unguarded live `sed -i` configuration edits
- Claims that `handshakeStatus: false` alone identifies target blocking
- Claims that `xtls-rprx-vision` should not be used with REALITY

## [1.0.0] - 2026-06-26

### Added

- Initial release of `reality-handshake` skill
- Client-side audit (`.bashrc` aliases, `http_proxy` env vars, xray inbounds)
- Server-side audit (SSH to upstream, `config.json` inspection, publicKey derivation)
- "dest banned our IP" diagnosis flow (rotating `dest` + `serverNames`)
- Diagnostic command cheat sheet
- TL;DR flowchart
- Tested with xray-core 1.8.24, mihomo, clash, mihomo2

### Documented issues fixed

- "Microsoft bans your IP" — see [XTLS/Xray-core #2931](https://github.com/XTLS/Xray-core/issues/2931)
- "processed invalid connection" baseline — see [#2724](https://github.com/XTLS/Xray-core/issues/2724)

[Unreleased]: https://github.com/toolazytoname/reality-handshake/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/toolazytoname/reality-handshake/releases/tag/v1.0.0
