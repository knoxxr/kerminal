# Changelog

All notable changes to Kerminal are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions follow semver.

## [0.1.0] — Unreleased (MVP)

First feature-complete MVP: a cross-platform SSH/terminal client.

### Added
- **SSH terminal** — live shell over `dartssh2` rendered with `xterm`, password
  and SSH-key authentication, connection status (connecting/connected/failed/
  closed) with reconnect.
- **Host management** — create/edit/delete saved hosts with grouping and search;
  one-click connect. Secrets (passwords, private keys, passphrases) are stored in
  the OS-backed secure vault, never in the database.
- **SSH key generation** — generate Ed25519 keys in-app; copy the public key for
  `authorized_keys`.
- **known_hosts verification** — SHA256 host-key fingerprints with a trust prompt
  on first connect and a man-in-the-middle warning if a key changes.
- **Multi-session tabs** — multiple concurrent terminals with per-session
  reconnect; scrollback preserved when switching tabs.
- **Special-key toolbar** — Esc/Tab/^C/^D/^L/arrow keys (essential on mobile).
- **Settings** — theme (system/light/dark) and terminal font size, persisted.

### Platforms
- Windows, macOS, Linux, iOS, Android, Web (single Flutter codebase).

[0.1.0]: https://github.com/knoxxr/kerminal/releases/tag/v0.1.0
