# MSP Platform Development Makefile
# Provides common development, testing, and deployment tasks
#
# Copyright (c) 2025 Seth Luby
# Licensed under the MIT License - see LICENSE file for details

# Use virtual environment if available
VENV := venv
PYTHON := $(VENV)/bin/python3
PIP := $(VENV)/bin/pip
MOLECULE := $(VENV)/bin/molecule
ANSIBLE_LINT := $(VENV)/bin/ansible-lint
YAMLLINT := $(VENV)/bin/yamllint

# Fallback to system binaries if venv doesn't exist
ifeq ($(wildcard $(VENV)/bin/python3),)
	PYTHON := python3
	PIP := pip
	MOLECULE := molecule
	ANSIBLE_LINT := ansible-lint
	YAMLLINT := yamllint
endif

.PHONY: help install lint test test-roles test-integration clean setup docs deploy precommit check venv

# Default target
help: ## Show this help message
	@echo "MSP Platform Development Commands:"
	@echo "=================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Virtual environment setup
venv: ## Create Python virtual environment
	@if [ ! -d "$(VENV)" ]; then \
		echo "Creating virtual environment..."; \
		python3 -m venv $(VENV); \
		echo "✅ Virtual environment created at $(VENV)/"; \
	else \
		echo "Virtual environment already exists at $(VENV)/"; \
	fi

# Installation and setup
install: venv ## Install all dependencies
	@echo "Installing Python dependencies..."
	$(PIP) install -r requirements-dev.txt
	@echo "Installing Ansible collections and roles..."
	ansible-galaxy install -r requirements.yml --force
	@echo "✅ Installation complete"

setup: install ## Setup development environment
	@echo "Setting up development environment..."
	@mkdir -p logs reports backups
	@mkdir -p .ansible/tmp
	@echo "Creating local configuration files..."
	@cp -n .env.example .env 2>/dev/null || true
	@echo "✅ Development environment ready"

# Code quality and linting
lint: ## Run all linting checks
	@echo "Running YAML lint..."
	$(YAMLLINT) .
	@echo "Running Ansible lint..."
	@mkdir -p .ansible/tmp
	ANSIBLE_LOCAL_TEMP=.ansible/tmp ANSIBLE_REMOTE_TEMP=.ansible/tmp $(ANSIBLE_LINT) -j 1 ansible/playbooks/ ansible/roles/
	@echo "✅ Linting complete"

lint-changed: ## Lint only changed YAML/Ansible files (staged)
	@echo "Linting changed files..."
	@FILES=$$(git diff --name-only --cached | tr ' ' '\n' | grep -E '^(ansible/|molecule/).*(\.yml|\.yaml)$$' || true); \
	if [ -n "$$FILES" ]; then \
		echo "YAML files:"; echo "$$FILES" | tr '\n' ' '; echo; \
		$(YAMLLINT) $$FILES; \
		mkdir -p .ansible/tmp; \
		ANSIBLE_LOCAL_TEMP=.ansible/tmp ANSIBLE_REMOTE_TEMP=.ansible/tmp $(ANSIBLE_LINT) -j 1 $$FILES; \
	else \
		echo "No changed YAML files to lint."; \
	fi

syntax-check: ## Check Ansible playbook syntax
	@echo "Checking playbook syntax..."
	@mkdir -p .ansible/tmp
	@for playbook in ansible/playbooks/*.yml; do \
		echo "Checking $$playbook..."; \
		ANSIBLE_LOCAL_TEMP=.ansible/tmp ANSIBLE_REMOTE_TEMP=.ansible/tmp ansible-playbook --syntax-check "$$playbook"; \
	done
	@echo "✅ Syntax check complete"

# Testing
test: lint syntax-check test-roles ## Run all tests
	@echo "✅ All tests completed successfully"

test-roles: ## Test all roles with Molecule
	@echo "Testing roles with Molecule..."
	@for role in ansible/roles/*/; do \
		if [ -f "$$role/molecule/default/molecule.yml" ]; then \
			echo "Testing role: $$(basename $$role)"; \
			cd "$$role" && molecule test && cd - > /dev/null; \
		fi \
	done
	@echo "✅ Role testing complete"

test-integration: ## Run integration tests
	@echo "Running integration tests..."
	molecule test --scenario-name integration
	@echo "✅ Integration testing complete"

test-quick: ## Run quick tests (syntax + lint only)
	@echo "Running quick tests..."
	$(YAMLLINT) . --format parsable
	$(ANSIBLE_LINT) ansible/playbooks/ ansible/roles/ --format brief
	@echo "✅ Quick tests complete"

# Individual role testing
test-client-onboarding: ## Test client-onboarding role
	cd ansible/roles/client-onboarding && molecule test

test-graceful-disconnection: ## Test graceful-disconnection role
	cd ansible/roles/graceful-disconnection && molecule test

test-common: ## Test common role
	cd ansible/roles/common && molecule test

test-monitoring: ## Test monitoring role
	cd ansible/roles/monitoring && molecule test

test-backup: ## Test backup role
	cd ansible/roles/backup && molecule test

test-user-management: ## Test user-management role
	cd ansible/roles/user-management && molecule test

test-network-security: ## Test network-security role
	cd ansible/roles/network-security && molecule test

# Documentation
docs: ## Generate documentation
	@echo "Generating role documentation..."
	@for role in ansible/roles/*/; do \
		role_name=$$(basename $$role); \
		echo "Documenting role: $$role_name"; \
		ansible-doc -t role "$$role" > "docs/roles/$$role_name.md" 2>/dev/null || true; \
	done
	@echo "✅ Documentation generated in docs/roles/"

docs-serve: ## Serve documentation locally
	@if [ -f mkdocs.yml ]; then \
		mkdocs serve; \
	else \
		echo "mkdocs.yml not found. Run 'make docs-init' first."; \
	fi

docs-init: ## Initialize documentation structure
	@echo "Initializing documentation..."
	@mkdir -p docs/roles docs/playbooks docs/architecture
	@echo "✅ Documentation structure created"

# Deployment and operations
deploy-msp: ## Deploy MSP infrastructure
	@echo "Deploying MSP infrastructure..."
	cd msp-infrastructure && docker-compose up -d
	@echo "✅ MSP infrastructure deployed"

deploy-test: ## Deploy test environment
	@echo "Deploying test environment..."
	ansible-playbook ansible/playbooks/deploy-msp-infrastructure.yml -e deployment_mode=test
	@echo "✅ Test environment deployed"

onboard-client: ## Onboard a new client (interactive)
	@echo "Starting client onboarding..."
	ansible-playbook ansible/playbooks/onboard-client.yml

disconnect-client: ## Gracefully disconnect a client (interactive)
	@echo "Starting client disconnection..."
	ansible-playbook ansible/playbooks/prepare-disconnection.yml

# Maintenance and cleanup
clean: ## Clean up temporary files and containers
	@echo "Cleaning up temporary files..."
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name ".pytest_cache" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "Cleaning up Docker containers..."
	docker system prune -f
	@echo "Cleaning up Molecule artifacts..."
	@for role in ansible/roles/*/; do \
		if [ -d "$$role/molecule" ]; then \
			cd "$$role" && molecule cleanup 2>/dev/null || true && cd - > /dev/null; \
		fi \
	done
	@echo "✅ Cleanup complete"

clean-all: clean ## Clean everything including installed dependencies
	@echo "Removing all generated files..."
	rm -rf .ansible/
	rm -rf logs/ reports/ backups/
	rm -rf docs/roles/
	@echo "✅ Deep cleanup complete"

# Security and validation
security-scan: ## Run security scans
	@echo "Running security scans..."
	@if command -v trivy > /dev/null; then \
		trivy fs .; \
	else \
		echo "Trivy not installed. Install with: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -"; \
	fi
	@echo "✅ Security scan complete"

validate: syntax-check lint ## Validate all configurations
	@echo "Validating Docker configurations..."
	@for compose in */docker-compose.yml; do \
		if [ -f "$$compose" ]; then \
			echo "Validating $$compose"; \
			docker-compose -f "$$compose" config > /dev/null; \
		fi \
	done
	@echo "✅ Validation complete"

# Release and versioning
release-check: test security-scan ## Check if ready for release
	@echo "Checking release readiness..."

version: ## Show current version information
	@echo "MSP Platform Version Information:"
	@echo "================================"
	@grep -E "version|Version" README.md || echo "Version not found in README.md"
	@git describe --tags --always --dirty 2>/dev/null || echo "No git tags found"

# Development helpers
dev-setup: setup ## Setup development environment with all tools
	@echo "Installing development tools..."
	pip install pre-commit
	pre-commit install
	@echo "✅ Development environment fully configured"

ansible-vault-create: ## Create a new Ansible vault file
	@read -p "Enter vault file name: " vault_file; \
	ansible-vault create "$$vault_file"

# Local helpers
precommit: ## Run pre-commit hooks on all files
	@echo "Running pre-commit hooks..."
	pre-commit run --all-files || true

check: lint syntax-check ## Lint + syntax + pre-commit hooks
	@echo "Running pre-commit checks..."
	pre-commit run --all-files || true

ansible-vault-edit: ## Edit an existing Ansible vault file
	@read -p "Enter vault file name: " vault_file; \
	ansible-vault edit "$$vault_file"

# CI/CD helpers
ci-local: ## Run CI tests locally
	@echo "Running CI tests locally..."
	make test
	make security-scan
	make validate
	@echo "✅ Local CI tests complete"

# Formatting helpers
fmt: ## Format repo with pre-commit fixers
	pre-commit run --all-files || true

fix-yaml: ## Fix common YAML indent issues across changed files
	@echo "Fixing YAML indentation for staged files..."
	@git diff --name-only --cached | grep -E '\\.(yml|yaml)$$' | xargs -r python3 scripts/yaml_indent_fix.py || true
	@echo "Run 'git add -p' to review changes"

# Platform management
platform-status: ## Show platform status
	@echo "MSP Platform Status:"
	@echo "==================="
	@echo "Roles: $$(ls -1 ansible/roles/ | wc -l)"
	@echo "Playbooks: $$(ls -1 ansible/playbooks/*.yml | wc -l)"
	@echo "Collections: $$(ansible-galaxy collection list | grep -c "^[a-z]" || echo "0")"
	@if [ -f msp-infrastructure/docker-compose.yml ]; then \
		echo "MSP Infrastructure: $$(cd msp-infrastructure && docker-compose ps -q | wc -l) containers"; \
	fi
	@echo "Documentation: $$(find docs/ -name "*.md" 2>/dev/null | wc -l) files"
quickstart-demo: ## Run a quick local demo (Molecule converge + verify)
	@echo "Starting quickstart demo with Molecule (default scenario)..."
	$(MOLECULE) converge -s default
	$(MOLECULE) verify -s default || true
	@echo "\nDemo complete. To clean up: make quickstart-destroy"

quickstart-destroy: ## Destroy quickstart Molecule resources
	$(MOLECULE) destroy -s default
	@echo "Cleaned up Molecule resources."

# Bootstrap for new users
bootstrap: ## First-time setup for new contributors (creates venv, installs everything)
	@echo "🚀 Bootstrapping MSP Platform development environment..."
	@echo ""
	@echo "Step 1/4: Creating Python virtual environment..."
	@python3 -m venv $(VENV)
	@echo "✅ Virtual environment created"
	@echo ""
	@echo "Step 2/4: Installing Python dependencies (this may take a few minutes)..."
	@$(PIP) install --upgrade pip setuptools wheel
	@$(PIP) install -r requirements-dev.txt
	@echo "✅ Python dependencies installed"
	@echo ""
	@echo "Step 3/4: Installing Ansible collections and roles..."
	@ansible-galaxy install -r requirements.yml --force
	@echo "✅ Ansible dependencies installed"
	@echo ""
	@echo "Step 4/4: Setting up project directories..."
	@mkdir -p logs reports backups .ansible/tmp
	@echo "✅ Project structure ready"
	@echo ""
	@echo "🎉 Bootstrap complete! Your environment is ready."
	@echo ""
	@echo "Quick start commands:"
	@echo "  make help          - Show all available commands"
	@echo "  make lint          - Run code quality checks"
	@echo "  make test-quick    - Run fast tests (syntax + lint)"
	@echo "  make test          - Run full test suite"
	@echo ""
	@echo "💡 Note: All commands automatically use the virtual environment in ./$(VENV)/"
