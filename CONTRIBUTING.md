# Contributing

Thanks for improving `reality-handshake`.

## Repository layers

- `SKILL.md` is the short Agent entry and workflow router.
- `references/` contains detailed Agent runbooks loaded only when relevant.
- `scripts/` contains deterministic validators and safety checks.
- `docs/` and `README.md` are written for people.
- `agents/openai.yaml` is generated Codex interface metadata.

Keep operational detail in the appropriate reference instead of growing `SKILL.md` indefinitely. Human explanations and diagrams belong under `docs/`; do not make an Agent read them to perform a routine task.

## Safety requirements

1. Never commit subscription URLs, node URIs, UUIDs, passwords, REALITY keys, private domains, public household/server IPs, or unsanitized logs/screenshots.
2. Treat a subscription response as untrusted input and its URL as a bearer credential.
3. Every mutation workflow must stage a candidate, validate with the exact target binary, switch atomically, smoke-test, and roll back.
4. Do not recommend broad firewall flushes or unguarded `sed -i` edits of a live config.
5. Do not claim a Reality target is blocked from one log line; document evidence and alternative causes.
6. Technical field semantics should link to current official Xray documentation and mention version sensitivity.

If a secret has appeared in Git, rotate it immediately. Redacting the latest commit does not remove it from history.

## Test locally

```bash
chmod +x install.sh scripts/*.sh scripts/*.py tests/fake-xray.sh
./scripts/verify-repo.sh
./scripts/scan-secrets.sh --self-test
XRAY_BIN=./tests/fake-xray.sh \
  ./scripts/validate-xray-candidate.sh tests/fixtures/minimal-config.json

test_dir=$(mktemp -d)
SOURCE_DIR="$PWD" INSTALL_DIR="$test_dir/reality-handshake" ./install.sh
test -f "$test_dir/reality-handshake/references/router-deployment.md"
```

When the Codex `skill-creator` validator is available, also run:

```bash
python3 /path/to/skill-creator/scripts/quick_validate.py .
```

## What makes a useful contribution

- a reproducible diagnosis with evidence and counterexamples;
- a safer router recovery or rollback path;
- version-tested Xray/FreshTomato/OpenWrt behavior;
- a fixture or deterministic validator for a failure we have seen;
- clearer human diagrams or maintenance instructions;
- support for another client/core without weakening secret handling.

Use the pull-request template and describe both success and failure-path testing.

## Reporting bugs

Use the issue template. Provide only the relevant redacted lines and versions. Do not post a complete config, `x25519` input/output, subscription content, or server endpoint. Maintainers can ask targeted follow-up questions without receiving secrets.

By participating, you agree to the [Code of Conduct](./CODE_OF_CONDUCT.md).
