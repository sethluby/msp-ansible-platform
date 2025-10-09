# Repository Guidelines

## Project Structure & Module Organization
- `ansible/roles/` — reusable roles (each with `molecule/default/`).
- `ansible/playbooks/` — enterprise playbooks (e.g., `onboard-client.yml`).
- `ansible/group_vars/`, `ansible/inventory/` — variables and inventory.
- `molecule/` — multi-host Docker scenario for integration testing.
- `docs/`, `client-templates/`, `bootstrap/`, `msp-infrastructure/`, `compliance/` — docs, templates, helpers, and infra.

## Build, Test, and Development Commands
- `make install` — install Python deps and Ansible collections/roles.
- `make setup` — create local dirs (`logs/`, `reports/`) and `.env`.
- `make lint` — run `yamllint` and `ansible-lint` (production profile).
- `make syntax-check` — `ansible-playbook --syntax-check` for all playbooks.
- `make test` / `make test-roles` — lint + Molecule tests for roles.
- `make test-quick` — fast lint/syntax pass; `make security-scan` — Trivy.
- `make docs` / `make docs-serve` — generate/serve role docs.

## Coding Style & Naming Conventions
- YAML: 2-space indent, start docs with `---`, no tabs (see `.yamllint.yml`).
- Ansible: use FQCN (e.g., `ansible.builtin.copy`), idempotent tasks, prefer modules over `command`/`shell`.
- Naming: roles and tags `kebab-case` (e.g., `network-security`), variables `snake_case`.
- Linting: `ansible-lint` (profile `production`, see `.ansible-lint.yml`) and `yamllint` must pass.

## Testing Guidelines
- Framework: Molecule (+ Docker). Default scenario in `molecule/default/` per role.
- Run all: `make test`. Per-role: `cd ansible/roles/<role> && molecule test`.
- Integration: `make test-integration` or `molecule test` in top-level `molecule/`.
- New roles must include converge/idempotence/verify steps and OS coverage where applicable.

## Commit & Pull Request Guidelines
- Commits: imperative, focused, and well-scoped. Include `[release]` in the commit message when intentionally triggering the release job on `main`.
- Branches: `feature/<slug>`, `fix/<slug>` (e.g., `feature/client-onboarding-vault`).
- PRs: clear description, linked issues (e.g., `#123`), testing evidence (Molecule/logs), and docs updates when behavior changes. CI must be green.

## Security & Configuration Tips
- Secrets: store with Ansible Vault; create via `make ansible-vault-create`. Never commit decrypted secrets.
- Config: copy `.env.example` to `.env`; keep client-specific vars in `group_vars/`.
- Dependencies: manage via `requirements.yml` (`ansible-galaxy install -r requirements.yml`).

