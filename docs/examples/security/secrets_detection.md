# Example: Secrets Detection Pre-Commit Hook

## User Request

```
Настрой автоматическое обнаружение secrets перед commit:
- API keys, tokens, passwords
- AWS credentials
- Private keys
- Database connection strings
```

## Reasoning

**Domain:** Security + DevOps (secrets management)
**Complexity:** Simple (tool configuration)
**Model:** Haiku (standard setup)

## Response

### Setup with gitleaks + trufflehog

```bash
# Install tools
brew install gitleaks trufflehog

# Or via Go
go install github.com/gitleaks/gitleaks/v8@latest
go install github.com/trufflesecurity/trufflehog/v3@latest
```

### Pre-commit Hook Configuration

```bash
# .git/hooks/pre-commit
#!/bin/bash

echo "🔍 Scanning for secrets..."

# Run gitleaks
gitleaks protect --staged --verbose

if [ $? -ne 0 ]; then
    echo "❌ SECRETS DETECTED! Commit blocked."
    echo "Fix: Remove secrets, then commit again."
    exit 1
fi

echo "✅ No secrets detected"
exit 0
```

### Custom .gitleaks.toml

```toml
title = "Custom Secrets Detection Rules"

[[rules]]
id = "aws-access-key"
description = "AWS Access Key ID"
regex = '''(A3T[A-Z0-9]|AKIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASIA)[A-Z0-9]{16}'''
tags = ["aws", "credentials"]

[[rules]]
id = "aws-secret-key"
description = "AWS Secret Access Key"
regex = '''(?i)aws(.{0,20})?['"][0-9a-zA-Z\/+]{40}['"]'''
tags = ["aws", "credentials"]

[[rules]]
id = "github-token"
description = "GitHub Personal Access Token"
regex = '''ghp_[0-9a-zA-Z]{36}'''
tags = ["github", "token"]

[[rules]]
id = "anthropic-api-key"
description = "Anthropic API Key"
regex = '''sk-ant-api03-[a-zA-Z0-9\-_]{95}'''
tags = ["anthropic", "api-key"]

[[rules]]
id = "private-key"
description = "Private Key"
regex = '''-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY-----'''
tags = ["key", "pem"]

[[rules]]
id = "database-url"
description = "Database Connection String"
regex = '''(?i)(postgres|mysql|mongodb):\/\/[^\s]+'''
tags = ["database", "credentials"]

[allowlist]
paths = [
    '''\.env\.example$''',
    '''\.env\.template$''',
    '''README\.md$''',
]
```

### GitHub Actions Integration

```yaml
# .github/workflows/secrets-scan.yml
name: Secrets Detection

on: [push, pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0  # Full history for comprehensive scan

      - name: Run gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}

      - name: Run TruffleHog
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
```

### Remediation Script

```python
#!/usr/bin/env python3
"""Remove accidentally committed secrets."""

import subprocess
import sys

def remove_secret_from_history(file_path: str, secret_pattern: str):
    """
    Remove secret from git history using filter-branch.
    WARNING: Rewrites history - coordinate with team!
    """
    print(f"⚠️  Removing secret from {file_path}")
    print("This will rewrite git history!")

    confirm = input("Continue? [yes/NO]: ")
    if confirm.lower() != 'yes':
        sys.exit(1)

    # Use git filter-branch to remove secret
    cmd = [
        'git', 'filter-branch', '--force', '--index-filter',
        f"git rm --cached --ignore-unmatch {file_path}",
        '--prune-empty', '--tag-name-filter', 'cat', '--', '--all'
    ]

    subprocess.run(cmd, check=True)

    print("✅ Secret removed from history")
    print("⚠️  Force push required: git push --force --all")
    print("⚠️  Rotate the leaked secret immediately!")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: ./remediate.py <file_path> <secret_pattern>")
        sys.exit(1)

    remove_secret_from_history(sys.argv[1], sys.argv[2])
```

---

## Key Takeaways

1. **Prevention > Detection** — block secrets before commit
2. **Multi-layer defense** — pre-commit hook + CI/CD scan
3. **Custom rules** for project-specific patterns
4. **Immediate rotation** if secret leaked
5. **History rewrite** only as last resort (coordinate with team)

**Tools:** gitleaks, trufflehog, git-secrets
**Best Practice:** Use .env files + .gitignore, never hardcode secrets
