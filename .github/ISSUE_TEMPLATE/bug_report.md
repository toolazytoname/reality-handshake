---
name: Bug report
about: A workflow, document, installer, or validator did not work
title: "[BUG] "
labels: bug
assignees: ""
---

## What happened

<!-- Describe the expected and actual result. Never paste a full subscription or config. -->

## Workflow and step

- Workflow: handshake / router / DNS / subscription / rule update / installer
- Document heading or script:

## Sanitized evidence

<!-- Keep only the few relevant lines. Replace addresses, UUIDs, keys, SNI and URLs. -->

```text
REDACTED
```

## Environment

- Xray version:
- Router/client software:
- OS/firmware and architecture:
- Install method and branch:

## Safety checklist

- [ ] I did not include a subscription URL or node URI.
- [ ] I removed UUIDs, keys, tokens, server/household public IPs, and private domains.
- [ ] I did not paste a complete Xray/Mihomo/Clash configuration.
- [ ] I tested with an HTTP request, not only `ping`.
- [ ] I identified whether the failure is data, DNS, process, or handshake related.
