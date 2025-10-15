# Contributing to MSP Ansible Infrastructure Management Platform

Thank you for your interest in contributing to this comprehensive testing and validation platform for MSP automation! This project provides testing frameworks and validation tools for MSP infrastructure management concepts.

## ⚠️ Important: Testing Platform Context

**This is a testing and validation platform**, not production-ready software. Contributions should focus on:
- Improving testing frameworks and validation tools
- Enhancing documentation and testing procedures
- Adding support for additional testing scenarios
- Improving security scanning and quality assurance

## How to Contribute

### 1. Testing and Validation
- **Test the automation**: Run the comprehensive test suite and report issues
- **Validate compliance frameworks**: Test CMMC, DISA STIG, and CIS benchmark implementations
- **Multi-OS testing**: Validate compatibility across RHEL, Ubuntu, and Rocky Linux
- **Security testing**: Run security scans and report vulnerabilities

### 2. Documentation Improvements
- **Testing guides**: Improve testing procedures and validation documentation
- **Architecture documentation**: Enhance technical architecture explanations
- **Pilot testing procedures**: Contribute to pilot program guidelines and best practices

### 3. Code Contributions
- **Ansible role improvements**: Enhance existing roles with better testing coverage
- **Playbook enhancements**: Improve enterprise playbooks with additional validation
- **Testing framework expansion**: Add new Molecule test scenarios and validation
- **CI/CD improvements**: Enhance GitHub Actions workflows and quality gates

## Getting Started

### Development Environment Setup

1. **Clone the repository**:
```bash
git clone https://github.com/sethluby/msp-ansible-platform.git
cd msp-ansible-platform
```

2. **Install development dependencies**:
```bash
pip install -r requirements-dev.txt
ansible-galaxy install -r requirements.yml
```

3. **Setup development environment**:
```bash
make setup
```

4. **Run the test suite**:
```bash
make test
```

### Testing Requirements

All contributions must include:
- **Ansible lint compliance**: `make lint` must pass
- **Syntax validation**: `make syntax-check` must pass
- **Role testing**: Relevant Molecule tests must pass
- **Security scanning**: `make security-scan` must pass
- **Documentation updates**: Update relevant documentation

## Development Workflow

### 1. Create a Feature Branch
```bash
git checkout -b feature/your-feature-name
```

### 2. Make Your Changes
- Follow existing code patterns and conventions
- Add comprehensive testing for new features
- Update documentation as needed
- Ensure all tests pass locally

### 3. Test Your Changes
```bash
# Run full test suite
make test

# Run specific role tests
make test-client-onboarding
make test-common

# Run security scanning
make security-scan

# Validate configurations
make validate
```

### 4. Submit a Pull Request
- Provide clear description of changes and testing performed
- Include test results and validation evidence
- Reference any related issues or discussions
- Ensure CI/CD pipeline passes

## Code Style and Standards

### Ansible Best Practices
- Use fully qualified collection names (e.g., `ansible.builtin.copy`)
- Implement idempotency for all tasks
- Use `ansible-vault` for sensitive data
- Follow YAML formatting with 2-space indentation
- Tag all tasks appropriately for selective execution

### Testing Standards
- All roles must include Molecule tests
- Test scenarios should cover multiple operating systems
- Include both positive and negative test cases
- Validate configuration changes and rollback scenarios

### Documentation Standards
- Update README.md for significant changes
- Include inline documentation for complex logic
- Provide examples for new features
- Maintain testing procedure documentation

## Issue Reporting

### Known Issues Log
- Before filing a new issue for environment/toolchain quirks (e.g., Molecule, Docker, Ansible version pinning), check `docs/KNOWN_ISSUES.md`.
- If you encounter a new reproducible issue, add a concise entry with: symptom, environment, root cause (if known), workaround, and impact. Keep it factual and brief.
- When submitting a PR that addresses or depends on a workaround, link to the corresponding entry in `docs/KNOWN_ISSUES.md`.

### Security Issues
For security vulnerabilities, please use GitHub's security advisory feature rather than public issues.

### Bug Reports
When reporting bugs, please include:
- **Environment details**: OS, Ansible version, Python version
- **Steps to reproduce**: Clear step-by-step instructions
- **Expected behavior**: What should happen
- **Actual behavior**: What actually happened
- **Test output**: Relevant logs and error messages

### Feature Requests
For new features, please provide:
- **Use case description**: Why this feature is needed
- **Proposed implementation**: High-level approach
- **Testing considerations**: How the feature should be validated
- **Documentation requirements**: What documentation would be needed

## Testing Scenarios

### Primary Testing Areas
1. **Multi-tenant isolation**: Ensure complete client separation
2. **Compliance automation**: Validate CMMC, DISA STIG, CIS implementations
3. **Graceful disconnection**: Test MSP independence scenarios
4. **Cross-platform compatibility**: Validate across multiple Linux distributions
5. **Security hardening**: Test security framework implementations

### Pilot Testing Program
Contributors interested in pilot testing:
- **MSP partners**: Controlled testing in isolated environments
- **Security validation**: Compliance framework testing and validation
- **Performance testing**: Scale and performance validation
- **Documentation feedback**: Testing procedure improvement

## Community Guidelines

### Code of Conduct
- Be respectful and inclusive in all communications
- Focus on constructive feedback and improvement
- Provide helpful and detailed information in issues and PRs
- Collaborate openly and transparently

### Communication Channels
- **GitHub Issues**: Bug reports, feature requests, and general discussion
- **GitHub Discussions**: Community questions and broader discussions
- **Pull Requests**: Code contributions and documentation improvements

### Review Process
1. **Automated validation**: CI/CD pipeline must pass
2. **Code review**: Maintainer review for code quality and standards
3. **Testing validation**: Comprehensive testing results review
4. **Documentation review**: Ensure proper documentation updates
5. **Security review**: Security scanning and vulnerability assessment

## Recognition

Contributors will be recognized in:
- **CONTRIBUTORS.md file**: List of all contributors
- **Release notes**: Significant contributions highlighted
- **GitHub contributor recognition**: Standard GitHub contribution tracking

## License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

## Questions and Support

- **General questions**: Use GitHub Discussions
- **Bug reports**: Use GitHub Issues
- **Security concerns**: Use GitHub Security Advisories
- **Documentation issues**: Create issues or submit PRs

## Additional Resources

### Testing Documentation
- **Molecule Testing Guide**: `docs/testing/molecule-guide.md`
- **CI/CD Pipeline**: `.github/workflows/ci.yml`
- **Testing Procedures**: `docs/testing/`

### Development Tools
- **Makefile commands**: `make help` for all available commands
- **Quality tools**: ansible-lint, yamllint, security scanning
- **Documentation tools**: MkDocs, ansible-doc

---

**Thank you for contributing to the advancement of MSP automation testing and validation!**

Your contributions help build better, more secure, and more reliable automation frameworks for the MSP industry.
