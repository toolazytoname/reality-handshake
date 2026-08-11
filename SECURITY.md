# Security Policy

## Authorized use

This project supports proxy systems and routers the operator owns or is authorized to administer. Follow local law and network policy. The workflows are designed for operational privacy and reliability, not unauthorized access.

## Secrets in this domain

Treat all of these as credentials or sensitive infrastructure metadata:

- airport/subscription URLs and decoded subscription bodies;
- VLESS UUIDs, passwords, REALITY private/public keys and short IDs;
- node URIs, endpoints, private SNI/hostnames, and server public IPs;
- household public IPs, router backups, logs, screenshots, and complete configs.

A subscription URL is usually a bearer credential: anyone holding it may be able to retrieve the account's node set. Store it in a `0600` file, never in a command line, cron entry, log, screenshot, issue, or Git repository.

Public keys and short IDs may not be secret cryptographically, but they identify infrastructure when combined with an endpoint. This project redacts them from public artifacts by default.

## If a secret leaks

1. Rotate or revoke it immediately; do not wait for repository cleanup.
2. Remove it from the current tree and Git history using an appropriate history-rewrite tool.
3. Invalidate cached subscription URLs and node credentials where the provider allows it.
4. Review Actions logs, forks, releases, issue notifications, screenshots, and local clones.
5. Replace affected router/server configs through the candidate-and-rollback workflow.

Deleting a file or force-pushing does not recall copies already fetched.

## Reporting a repository vulnerability

Do not open a public issue for a credential leak, command injection, unsafe update path, or rollback failure. Contact the maintainer privately using the security contact configured for the repository. Include only:

- affected path and line/commit;
- sanitized reproduction steps;
- impact and whether credentials were exposed;
- suggested containment.

Do not attach the leaked value itself unless a secure channel is explicitly established.

## Repository controls

- `scripts/scan-secrets.sh` catches several common credential shapes before commit/CI.
- candidate config validation runs with the target Xray command shape;
- the installer stages all files and switches only after validation;
- examples use placeholders and documentation excludes real endpoints;
- updates are expected to validate digest/shape/behavior and retain one rollback copy.

Pattern scanning is defense in depth, not proof that a tree is clean. Human review remains required, especially for encoded/base64 data and images.

## Operational safety

- Start read-only unless a change is authorized.
- Preserve a wired/console recovery path before router firewall changes.
- Do not flush unrelated firewall rules.
- Keep data fail-open and DNS fallback policies separate.
- Never evaluate decoded subscription text as shell.
- Use temporary private files, locks, exact-binary validation, atomic rename, smoke tests, and rollback.
- Restore normal log levels after diagnosis and bound logs on flash storage.
