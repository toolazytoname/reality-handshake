## What this PR does

<!-- 1–3 sentences. -->

## Area

- [ ] Handshake diagnosis
- [ ] Router / transparent proxy
- [ ] Split DNS / routing
- [ ] Resilience / subscription / rule updates
- [ ] Installer / validation
- [ ] Human documentation / translation

## Safety and sanitization

- [ ] Mutations use candidate validation, atomic switch, smoke tests, and rollback.
- [ ] No subscription URLs, node URIs, UUIDs, keys, tokens, private domains, or real household/server IPs.
- [ ] Examples use obvious placeholders and do not instruct unguarded edits of live JSON/firewall state.
- [ ] Logs and screenshots are absent or sanitized.
- [ ] Current Xray claims link to official documentation or are labeled as observations.

## Verification

- [ ] `./scripts/verify-repo.sh`
- [ ] Candidate validator exercised with the fixture fake binary.
- [ ] Local atomic installer exercised with `SOURCE_DIR="$PWD"`.
- [ ] New Mermaid/image links render and resolve.

## Related issue

<!-- Closes #___ or N/A. -->
