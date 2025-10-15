---
# Known Issues and Workarounds

This document tracks issues encountered during local development and CI, with current impact and mitigations. Update as we find or fix items.

## Molecule + Ansible Compatibility
- Symptom: Molecule Docker playbooks fail with “Conditional result (True) was derived from value of type 'str'… Broken conditionals…”
- Context: molecule_docker playbooks use a truthy `when` on `lookup('env','HOME')` which ansible-core 2.16+ treats as invalid.
- Workaround: set `ANSIBLE_ALLOW_BROKEN_CONDITIONALS=True` when running Molecule locally. Consider pinning ansible-core to a compatible version or waiting for upstream fix.
- Impact: Local Molecule runs only; CI may be unaffected depending on versions.

## Callback Plugin Error on Python 3.13
- Symptom: `TypeError: function() argument 'code' must be code, not str` originating from `community.general` YAML callback plugin.
- Workaround: set `ANSIBLE_STDOUT_CALLBACK=default` for Molecule runs, or pin Python/collection versions that avoid the issue. Alternatively, use `ansible.builtin.yaml` callback if available.
- Impact: Local Molecule runs; CI using different pins may not hit it.

## Docker Networking Limitations in Sandbox
- Symptom: Docker create fails with “failed to add the host <=> sandbox veth pair interfaces: operation not supported”.
- Root Cause: Current environment lacks required kernel/network capabilities for Docker bridge networking.
- Workaround: Run Molecule on a host with Docker and proper privileges (rootless or rootful Docker with CAP_NET_ADMIN available).
- Impact: Prevents local container creation in restricted environments; not a code issue.

## ansible-lint Permission Errors
- Symptom: ansible-lint fails reading/writing temp under `~/.ansible/tmp` with PermissionError.
- Workaround: set `ANSIBLE_LOCAL_TEMP=.ansible/tmp` and `ANSIBLE_REMOTE_TEMP=.ansible/tmp` (already configured in CI; use locally when needed).
- Impact: Local lint runs; CI OK.

## YAML Line-Length Warnings
- Symptom: `yamllint` reports long lines in several playbooks (warnings).
- State: Non-blocking. Will clean up incrementally or relax rule for those files if needed.

## Multiple Collection Version Warnings
- Symptom: “Another version of collection X found installed…” during Molecule prerun.
- Workaround: Prefer a consistent, pinned set of collections in the virtualenv; remove user/global collection installs if noisy.
- Impact: Cosmetic; may cause subtle behavior differences across environments.

