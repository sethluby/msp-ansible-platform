---
# Engineering Standards

This guide defines coding, formatting, and linting standards for the MSP Ansible Platform. The goals are simple: predictable structure, idempotent tasks, and zero lint regressions on newly touched files.

## YAML Style
- Indentation: 2 spaces; no tabs.
- Start documents with `---`.
- Indent sequence items under mapping keys (indent-sequences = true):
  - Correct:
    - key:
        - item1
        - item2
  - Incorrect (current failures):
    - key:
      - item1
      - item2
- Typical places this applies: `tags:`, `that:` (assert), `when:` (list form), `loop:` and other list keys.
- Limit line length to 180 characters where practical (warnings only).
- Avoid extra spaces after commas inside flow sequences or inline lists.

## Ansible Style
- Use FQCN modules: `ansible.builtin.copy`, `ansible.posix.authorized_key`, etc.
- Prefer modules over `shell`/`command`; when using `shell`, include `set -o pipefail` for pipelines.
- Idempotence first: use `creates:`, `removes:`, `changed_when`, `failed_when` appropriately.
- Handlers for service restarts; don’t restart on every run.
- Tags present and meaningful; use `kebab-case`.
- Variables use `snake_case` and reside in `defaults/` or `group_vars/` as appropriate.

## Pre-commit and Linting
- Pre-commit is mandatory locally and in CI for changed files.
- Hooks:
  - trailing-whitespace, end-of-file-fixer, check-yaml
  - yamllint (configured in `.yamllint.yml`)
  - ansible-lint (profile `production` in `.ansible-lint.yml`)
  - yaml-indent-fix (local hook; auto-fixes the common indent mistakes for `tags:`/`that:` and task lists)
- Run locally:
  - `make dev-setup` (installs pre-commit)
  - `pre-commit run --all-files` for a full pass

## Transitional Policy (Legacy vs New Changes)
- CI for PRs: lint only changed files; block if they fail.
- Full-repo lint runs on a schedule/non-blocking while legacy files are progressively remediated.
- When touching legacy files, fix nearby lint issues opportunistically (especially YAML indentation) but avoid large, unrelated churn.

## File Layout Expectations
- Roles
  - `defaults/main.yml`, `tasks/main.yml`, `handlers/main.yml` (if handlers used), `molecule/default/` scenario.
  - Avoid includes to non-existent files; gate optional includes with booleans.
- Playbooks
  - Use consistent structure: `pre_tasks` → `tasks` → `post_tasks`.
  - Keep `- name:` entries indented two spaces under the section.
- Inventory and vars
  - Centralize cross-role paths in `ansible/group_vars/all/`.

## Makefile Targets
- `make lint` — yamllint + ansible-lint.
- `make test-quick` — faster lint/syntax pass.
- `make fmt` — run pre-commit fixers on all files.
- `make fix-yaml` — run YAML indentation fixers on the repo.

## Breaking Glass
- For complex or intentionally long lines, accept yamllint warnings (line-length).
- For unavoidable `shell`, annotate with `# noqa` only as a last resort and justify in the task `name:`.

