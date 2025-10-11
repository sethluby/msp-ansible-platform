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

## Phased Plan

### Phase 1 — Stabilize Skeleton and Onboarding (1–2 weeks)
- Fill missing templates for client-onboarding (client.env, onboarding report, authorized_keys, inventory helpers, etc.).
- Ensure molecule/default converge + verify pass for onboarding + minimal common tasks.
- Consolidate Ansible config to the root `ansible.cfg` only.
- Add `.env.example` to satisfy `make setup`.
- CI: gate PRs on linting only for changed files; keep full-repo lint on schedule/non-blocking until cleanup is complete.

### Phase 2 — MVP Role Implementations + Idempotence (2–4 weeks)
- Common: implement minimal, safe tasks (timezone, NTP, logrotate, essentials) with strong gating.
- User-management: implement core (groups, admin users, sudo) with Molecule.
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

