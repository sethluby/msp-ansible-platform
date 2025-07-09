# MSP Platform Development Makefile
# Provides common development, testing, and deployment tasks

.PHONY: help install lint test test-roles test-integration clean setup docs deploy

# Default target
help: ## Show this help message
	@echo "MSP Platform Development Commands:"
	@echo "=================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Installation and setup
install: ## Install all dependencies
	@echo "Installing Python dependencies..."
	pip install -r requirements-dev.txt
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
	yamllint .
	@echo "Running Ansible lint..."
	ansible-lint ansible/playbooks/ ansible/roles/
	@echo "✅ Linting complete"

syntax-check: ## Check Ansible playbook syntax
	@echo "Checking playbook syntax..."
	@for playbook in ansible/playbooks/*.yml; do \
		echo "Checking $$playbook..."; \
		ansible-playbook --syntax-check "$$playbook"; \
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
	yamllint . --format parsable
	ansible-lint ansible/playbooks/ ansible/roles/ --format brief
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
	@git status --porcelain | grep -q . && echo "❌ Uncommitted changes found" && exit 1 || true
	@echo "✅ Ready for release"

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