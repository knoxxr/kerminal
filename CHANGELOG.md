# Changelog

All notable changes to Kerminal are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions follow semver.

## [0.1.3]

### Changed
- **Update check wired up** — the in-app update check now defaults to the GitHub
  "latest release" manifest, and each release publishes a `latest.json`. Older
  versions detect new releases automatically (Settings → About & Updates).

## [0.1.2]

### Added
- **Group autocomplete** — the group field suggests existing groups; hosts with
  no group fall under the default group ("기본").

### Changed
- **Optional account** — username may be left blank; it defaults to the current
  OS user on connect (like the `ssh` CLI).
- **App-private storage** — the database now lives in the app support directory
  instead of Documents, so it is removed on uninstall (a fresh install starts
  empty) and is no longer synced to OneDrive. Existing data is moved over once
  on first launch.

## [0.1.1]

### Changed
- Windows MSIX is now signed with a self-signed code-signing certificate
  (`CN=SMIC`). The public cert (`kerminal-codesign.cer`) ships with the release;
  trust it once ("Trusted People") to install without the unknown-publisher
  warning.

## [0.1.0] (MVP)

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

[0.1.3]: https://github.com/knoxxr/kerminal/releases/tag/v0.1.3
[0.1.2]: https://github.com/knoxxr/kerminal/releases/tag/v0.1.2
[0.1.1]: https://github.com/knoxxr/kerminal/releases/tag/v0.1.1
[0.1.0]: https://github.com/knoxxr/kerminal/releases/tag/v0.1.0
