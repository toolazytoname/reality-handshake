# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Low-end OpenWrt travel router section: transparent proxy when xray can't run on the device (4MB flash / 32MB RAM) — `ss-redir` + gost bridge on a domestic relay VPS, the cipher gap (xray dropped stream ciphers vs old ss clients), systemd hardening, dropbear/flash gotchas, per-leg verification commands, reboot acceptance test
- `RUNBOOK-zh.md` — Chinese ops runbook: changing servers (upstream IP burned / new relay), three-step troubleshooting, optional own-domain upgrade path

### Planned

- Chinese translation (`SKILL.zh-CN.md`)
- sing-box adapter (parallel `SKILL-singbox.md`)
- More dest site workarounds as the community discovers them

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
