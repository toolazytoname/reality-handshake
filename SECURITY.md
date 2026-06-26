# Security Policy

## Authorized use only

This skill helps diagnose **legitimate proxy setups** that the user owns and operates. It is **not** a tool for bypassing corporate firewalls, evading law enforcement, or accessing networks you're not authorized to use.

Use of this skill is governed by the laws of your jurisdiction. The maintainers take no responsibility for misuse.

## Reporting vulnerabilities in this repo

If you find a real credential leak, an injection vector, or any other security issue in **this repository** (the `SKILL.md`, `README.md`, examples, etc.):

1. **Do not** open a public GitHub issue
2. Email `security@toolazytoname.dev` (or your maintainer's preferred contact)
3. Include: file path, line number, what was leaked, how to reproduce

We'll respond within 72 hours and coordinate disclosure.

## Reporting a real credential leak elsewhere

If you accidentally committed real credentials to **another** project while using this skill (and they ended up in a public repo):

1. **Rotate the credentials immediately** (treat as compromised)
2. Use [`git-filter-repo`](https://github.com/newren/git-filter-repo) or BFG to remove from history
3. Force-push and notify any forks/clones
4. See [GitHub's guide on removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)

## What this skill does NOT do

- It does **not** exfiltrate credentials from any system
- It does **not** make outbound connections to attacker-controlled servers
- All example commands are read-only diagnostics OR explicit, user-confirmed fixes

## Sanitization

This repo is **scrubbed** of any real credentials, IPs, UUIDs, or domains. Examples use:

- `127.0.0.1`, `YOUR.UPSTREAM.IP` for IPs
- `<UUID>`, `xxxxxxxx-xxxx-...` for UUIDs
- Public domains (`api.ipify.org`, `www.samsung.com`) where safe

If you find an actual leak (real IP, real privateKey, real publicKey), please report it per above.
