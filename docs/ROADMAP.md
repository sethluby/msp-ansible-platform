---
# MSP Platform Roadmap

This document captures the current state of the repository, key gaps, and a pragmatic, phased plan to reach a runnable MVP with credible demos while protecting forward momentum on linting and quality.

## Current State (Truths)
- Strong repo scaffolding: Makefile, CI pipeline, Molecule, and comprehensive docs.
- Many roles and playbooks contain placeholders or missing files, with YAML indentation issues that currently fail yamllint.
- ansible-lint fails primarily because files are malformed (bad YAML) rather than rule strictness.

Primary failure types observed (yamllint):
- Indentation of sequence items under mapping keys (e.g., `tags:`, `that:`) is not deeper than the key.
- Task lists (`- name:`) not sufficiently indented under `pre_tasks:`/`tasks:`/`post_tasks:`.
- Minor style issues: extra spaces after commas; long lines (warnings only).

## Goals
- Provide a clean “demoable” path (client onboarding + minimal common/user-management) that passes CI.
- Enforce style on newly touched/added files while allowing a structured, incremental cleanup of legacy files.
- Incrementally implement role functionality (common, user-management, monitoring, backup, compliance, connectivity).

## Progress Update

As of now, the following items have been completed toward the MVP path:
- Added `.env.example` to support `make setup` and local runs.
- Consolidated to a single root `ansible.cfg` (removed `ansible/ansible.cfg`).
- Added minimal infra config stubs for `docker-compose` (AWX, Postgres, Redis, Vault) so CI can validate compose files.
- Client onboarding role: introduced `onboarding_minimal` gating to skip heavy steps in tests.
- Scaffolded a Molecule default scenario for `client-onboarding` and switched converge to include the role in minimal mode.
- Expanded Molecule verify to assert generated files (configs, inventories, docs) exist in minimal mode.
- Added OS matrix for onboarding scenario (Ubuntu 22.04, Rocky Linux 9) using role-local Dockerfiles.
- Implemented monitoring deployment step (config/status/doc generation) behind gating.
- Filled onboarding templates (inventory, tier configs, compliance/monitoring/backup configs, client playbooks, VPN/auth docs/scripts), enabling end‑to‑end role execution with minimal defaults.

Recent work:
- Hardened VPN tasks with OS guards, container-safe behavior, and idempotent key handling (reuse stored keys on reruns).
- Expanded onboarding Molecule verify with file permission/ownership and content assertions (ansible.cfg, client.env, inventories, reports).
- Added optional, gated node_exporter install (non-CI) with Debian + RedHat service handling and a reusable verify task.
- Implemented minimal common role (timezone, chrony/ntp, logrotate, minimal firewall no-op in containers) with Molecule converge/verify and OS images.
- Implemented user-management core (system groups, admin users, sudo drop-in, SSH authorized_keys) with Molecule converge/verify on Ubuntu 22.04 and Rocky 9.
- Updated CI Molecule matrix to include `client-onboarding`, `common`, and `user-management` on Ubuntu 22.04 and Rocky Linux 9; lint/syntax gating remains.

Tracking Issues: see docs/KNOWN_ISSUES.md

Next short-term targets:
- Ensure Molecule idempotence + verify are green in CI for onboarding/common/user-management.
- Add journald persistence tuning in `common` (gated) and extend verify for config/state.
- Improve RHEL node_exporter handling (fallback or explicit install path) and assert running service when enabled.
- Incrementally broaden CI Molecule coverage (other roles/OS) once stable; keep changed-file lint gating.
- Continue YAML/Ansible cleanup on touched files to reduce lint noise in PRs.

## Phased Plan

### Phase 1 — Stabilize Skeleton and Onboarding (1–2 weeks)
- [done] Fill missing templates for client-onboarding (client.env, onboarding report, authorized_keys, inventory helpers, etc.).
- [in progress] Ensure Molecule converge + idempotence + verify pass for onboarding + minimal common tasks (verify expanded; CI validation ongoing).
- [done] Consolidate Ansible config to the root `ansible.cfg` only.
- [done] Add `.env.example` to satisfy `make setup`.
- [done] CI policy present: changed-file linting in PRs; full-repo lint non-blocking on schedule.
- [done] Add infra config stubs for compose validation (AWX, Postgres, Redis, Vault).
- [done] Add `onboarding_minimal` gating to enable fast test runs.
- [done] Harden VPN tasks with OS guards, container-safe behavior, and idempotent key handling.
- [done] Optional, gated node_exporter flow for non-CI runs.
- [done] Onboarding Molecule verify includes permissions and content assertions.

### Phase 2 — MVP Role Implementations + Idempotence (2–4 weeks)
- [done] Common: minimal, safe tasks (timezone, NTP/chrony, logrotate, minimal firewall) with Molecule converge/verify and OS images.
- [done] User-management: core (system groups, admin users, sudo, SSH authorized_keys) with Molecule converge/verify and OS matrix.
- Monitoring: wrap cloudalchemy roles for a minimal Prometheus/Grafana/Alertmanager setup or config-only in containers.
- Backup: rsync-based local backups with cron + simple validation.
- Compliance frameworks: add required handlers/templates to support AC controls; expand families incrementally.

### Phase 3 — Connectivity + Disconnection (4–6 weeks)
- Implement bastion/client-pull/reverse-tunnel infrastructure roles (minimal configs + verification) with Alpine gating.
- Graceful disconnection: generate independence docs/scripts Molecule verifies (no-ops for intrusive steps in containers).

### Phase 4 — MSP Infrastructure + Integrations (2–4 weeks)
- Provide minimal `msp-infrastructure/configs/*` files referenced by docker-compose.
- Add a local “demo” path focused on Molecule + onboarding (avoid running heavy infra in CI).

### Phase 5 — Hardening & Compliance Increments (ongoing)
- Wrapper role for ansible-lockdown with controlled variable mapping.
- Expand compliance families; add validations and reports.
- Broaden Molecule OS coverage.

## Success Criteria (MVP)
- `make test-quick` and `make syntax-check` pass.
- Molecule/default converge + verify pass for onboarding and minimal common/user-management.
- CI gates changes based on linting and syntax for modified files; scheduled full lint reports but does not block merges.

## Transitional Lint Strategy
- Pre-commit enforces YAML/Ansible style on changed files (auto-fix YAML indent on `tags:`/`that:`/task lists; run yamllint + ansible-lint).
- CI: For PRs, lint only changed files; run full-repo lint on a schedule (or as a non-blocking job) until legacy content is remediated.
