---
# Changelog

All notable changes to this project will be documented in this file.
This project follows a pragmatic, incremental release process. Entries below
reflect material improvements to the repository, CI pipeline, and roles.

## [Unreleased]

### Added
- Client Onboarding: expanded Molecule verify with file permissions, ownership, and content checks for `ansible.cfg`, `client.env`, inventories, and reports.
- Client Onboarding: optional, gated `node_exporter` install for non-CI runs; Debian and RedHat service handling; reusable Molecule verify task for node_exporter.
- Common: minimal, safe tasks — timezone, chrony/NTP, logrotate policy, and a container-safe firewall (no-ops in containers).
- Common: Molecule converge/verify with Ubuntu 22.04 and Rocky Linux 9 platform images.
- User Management: core features — system groups, admin users, sudo drop-in (validated), and SSH authorized_keys management.
- User Management: Molecule converge/verify for Ubuntu 22.04 and Rocky Linux 9, including group membership and authorized_keys checks.
- CI: expanded Molecule matrix to `client-onboarding`, `common`, and `user-management` across Ubuntu 22.04 and Rocky Linux 9.

### Changed
- Client Onboarding: hardened VPN tasks with OS guards, container-safe behavior, and idempotent key handling (reuses stored keys).
- Molecule: stabilized callback/env in onboarding scenario to avoid stdout plugin issues.
- Roadmap: updated to reflect current progress and next targets.

### Notes
- CI still gates on lint/syntax for changed files; Molecule runs are scoped to the three roles above.
- Node exporter remains gated and is intentionally skipped in CI and minimal runs.

