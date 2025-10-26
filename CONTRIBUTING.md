# Contributing to ZeroTier Toolkit

Thank you for your interest in contributing to the ZeroTier Toolkit! This document provides guidelines for contributing to the project.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Features](#suggesting-features)

## 📜 Code of Conduct

This project follows a code of conduct that encourages respectful and collaborative interactions. Please be kind and professional in all communications.

## 🚀 Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/zerotier-toolkit.git
   cd zerotier-toolkit
   ```
3. **Create a branch** for your work:
   ```bash
   git checkout -b feature/my-feature
   ```

## 💻 Development Setup

### Prerequisites

- Linux system (Debian/Ubuntu, RHEL/CentOS, Fedora, or Arch)
- Bash 4.0 or later
- `shellcheck` for linting (recommended)
- Git

### Install ShellCheck

**Ubuntu/Debian:**
```bash
sudo apt-get install shellcheck
```

**RHEL/CentOS/Fedora:**
```bash
sudo yum install ShellCheck  # or dnf
```

**Arch:**
```bash
sudo pacman -S shellcheck
```

## 🤝 How to Contribute

### Types of Contributions

We welcome various types of contributions:

1. **Bug fixes** - Fix issues in existing scripts
2. **New features** - Add new scripts or functionality
3. **Documentation** - Improve or add documentation
4. **Examples** - Add configuration examples
5. **Tests** - Improve test coverage
6. **Performance** - Optimize existing code

### Before You Start

1. Check existing [issues](https://github.com/cywf/zerotier-toolkit/issues) to avoid duplicating effort
2. Open an issue to discuss major changes before implementing
3. Keep changes focused - one feature/fix per pull request

## 📝 Coding Standards

### Shell Script Guidelines

1. **Use strict mode:**
   ```bash
   set -euo pipefail
   ```

2. **Add header comments:**
   ```bash
   #!/bin/bash
   #####################################################################
   # Script Name
   # 
   # Description of what the script does
   #####################################################################
   ```

3. **Use functions for reusability:**
   ```bash
   function_name() {
       local arg1="$1"
       # function code
   }
   ```

4. **Use meaningful variable names:**
   ```bash
   # Good
   NETWORK_ID="a1b2c3d4e5f6a7b8"
   
   # Bad
   NID="a1b2c3d4e5f6a7b8"
   ```

5. **Quote variables:**
   ```bash
   # Good
   if [[ "$VAR" == "value" ]]; then
   
   # Bad
   if [[ $VAR == value ]]; then
   ```

6. **Use consistent formatting:**
   - 4 spaces for indentation (not tabs)
   - One command per line for complex pipelines
   - Use blank lines to separate logical sections

7. **Add helpful error messages:**
   ```bash
   error_exit() {
       log ERROR "$1"
       exit "${2:-1}"
   }
   ```

8. **Include usage help:**
   ```bash
   usage() {
       cat << EOF
   Usage: $SCRIPT_NAME [OPTIONS]
   
   Description
   
   OPTIONS:
       -h, --help    Show this help
   EOF
       exit 0
   }
   ```

### Logging Standards

Use the standard logging function:

```bash
log INFO "Information message"
log SUCCESS "Success message"
log WARN "Warning message"
log ERROR "Error message"
log DEBUG "Debug message"  # Only shown in verbose mode
```

### Error Handling

1. Always check command exit codes
2. Provide helpful error messages
3. Clean up on exit (use trap)
4. Never fail silently

Example:
```bash
trap cleanup EXIT INT TERM

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log ERROR "Script failed with exit code: $exit_code"
    fi
    exit "$exit_code"
}
```

## 🧪 Testing

### Running Tests

Before submitting your changes, run the test suite:

```bash
# Run all tests
./tests/test-scripts.sh

# Check syntax
bash -n scripts/your-script.sh

# Run shellcheck
shellcheck scripts/your-script.sh
```

### Writing Tests

When adding new functionality, add corresponding tests to `tests/test-scripts.sh`:

```bash
# Test X: Description
log_test INFO "Test X: Testing new feature..."
if test_condition; then
    log_test PASS "Feature works correctly"
else
    log_test FAIL "Feature failed"
fi
```

### Test Requirements

All tests must:
- Be idempotent (can run multiple times safely)
- Clean up after themselves
- Not require root privileges (where possible)
- Complete within reasonable time (<60 seconds total)

## 📤 Submitting Changes

### Commit Messages

Write clear, descriptive commit messages:

```
Add network health monitoring script

- Implement continuous monitoring with configurable intervals
- Add email and webhook alerting capabilities
- Include peer count tracking and status checks
- Add comprehensive logging support
```

Format:
- First line: Brief summary (50 chars or less)
- Blank line
- Detailed description with bullet points
- Reference issues: "Fixes #123" or "Closes #456"

### Pull Request Process

1. **Update documentation** for any new features
2. **Add tests** for new functionality
3. **Run the test suite** and ensure all tests pass
4. **Run shellcheck** on modified scripts
5. **Update README** if adding new scripts or major features
6. **Create pull request** with clear description

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement

## Testing
- [ ] Tests pass
- [ ] ShellCheck passes
- [ ] Tested on [distribution name]

## Checklist
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests pass
```

## 🐛 Reporting Bugs

### Before Reporting

1. Check [existing issues](https://github.com/cywf/zerotier-toolkit/issues)
2. Try the latest version
3. Run diagnostics: `./scripts/zerotier-diagnostics.sh --full`

### Bug Report Template

```markdown
**Describe the bug**
Clear description of the issue

**To Reproduce**
Steps to reproduce:
1. Run command '...'
2. See error

**Expected behavior**
What should happen

**Environment:**
 - OS: [e.g., Ubuntu 22.04]
 - Shell: [e.g., bash 5.1]
 - ZeroTier version: [e.g., 1.10.6]

**Additional context**
- Error messages
- Log files
- Screenshots (if applicable)
```

## 💡 Suggesting Features

We welcome feature suggestions! Please:

1. **Check existing issues** for similar requests
2. **Open a discussion** to gauge interest
3. **Describe the use case** - why is this useful?
4. **Consider implementation** - how might it work?

### Feature Request Template

```markdown
**Feature Description**
Clear description of the proposed feature

**Use Case**
Why is this feature needed? Who benefits?

**Proposed Implementation**
Ideas for how to implement (optional)

**Alternatives**
Other solutions you've considered

**Additional Context**
Any other relevant information
```

## 📚 Documentation

### Documentation Standards

- Clear, concise language
- Include examples
- Use proper markdown formatting
- Add code blocks with syntax highlighting
- Keep README up to date

### Areas Needing Documentation

- New scripts
- Configuration options
- Troubleshooting steps
- Usage examples
- Advanced features

## 🎯 Priority Areas

Currently looking for contributions in:

1. **Testing on different distributions** - Verify scripts work on various Linux distros
2. **Windows Subsystem for Linux (WSL) support** - Adapt scripts for WSL
3. **Configuration validation** - Improve input validation
4. **Performance optimization** - Speed up operations
5. **More topology examples** - Real-world configuration examples
6. **Ansible/Terraform integration** - Infrastructure as code support

## 🙏 Recognition

Contributors will be:
- Listed in project documentation
- Credited in release notes
- Acknowledged in commit messages

## 📞 Questions?

- 💬 [GitHub Discussions](https://github.com/cywf/zerotier-toolkit/discussions)
- 🐛 [Issue Tracker](https://github.com/cywf/zerotier-toolkit/issues)
- 📖 [Documentation](scripts/README.md)

## 📄 License

By contributing, you agree that your contributions will be licensed under the same license as the project (see [LICENSE](LICENSE) file).

---

Thank you for contributing to ZeroTier Toolkit! 🎉
