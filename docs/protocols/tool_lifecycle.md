# Tool Lifecycle Protocol
# Version: 1.1.0 | Updated: 2026-02-25

## Tool Types

- **CLI Tools** — Command-line utilities (nmap, terraform, etc.)
- **MCP Servers** — Model Context Protocol integrations (`~/.claude.json` LOCAL scope)
- **Internal Tools** — Python scripts in `~/.claude/tools/`
- **Skills** — Workflow templates in `~/.claude/skills/`

## Security Evaluation Matrix

| Grade | Score | Criteria |
|-------|-------|----------|
| A | 90-100 | No CVEs, minimal permissions, sandboxable |
| B | 70-89 | Minor issues, reasonable permissions |
| C | 50-69 | Some concerns, requires isolation |
| D | 30-49 | Significant risks, restricted use only |
| F | <30 | Reject — unacceptable security posture |

Security checks: `npm audit` / `pip-audit` / `trivy image` before any integration.

## Integration Requirements

Minimum to integrate any tool:
```
☐ CLI relevance ≥60/100
☐ Security grade ≥C (score ≥50)
☐ Actively maintained (commits <6 months)
☐ License: MIT / Apache / BSD preferred
☐ Documented in appropriate module:
    CLI  → modules/10-tech-stack.md
    MCP  → modules/11-mcp.md (+ ~/.claude.json LOCAL scope)
    Skill → modules/15-skills.md
☐ Authorization level assigned (see rules/authorization-levels.md)
☐ Example created in ~/.claude/examples/tools/
☐ GAPS.md updated
```

## MCP Server Config (LOCAL scope)

```bash
# Add via CLI (writes to ~/.claude.json projects."*".mcpServers)
claude mcp add server-name -- npx -y @package/mcp-server

# Verify
claude mcp list
```

## Internal Tool Template

```python
#!/usr/bin/env python3
"""
Tool Name - Description
Usage: python tool_name.py [options]
"""
import argparse
# Implementation
```

Path: `~/.claude/tools/tool_name.py`
Schedule if needed: `echo "1 5 tool_name python3 ~/.claude/tools/tool_name.py" >> ~/.anacron/anacrontab`

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Internal tools | `snake_case.py` | `staleness_checker.py` |
| Skills | `kebab-case.md` | `web-pentest.md` |
| MCP servers | `kebab-case` key | `mcp-github` |

## Deprecation Triggers

| Trigger | Action |
|---------|--------|
| Upstream deprecated | Begin deprecation immediately |
| Unpatched security vulnerability | Deprecate within 7 days |
| Better alternative available | Migrate over 1-3 months |
| Usage <5% for 3 months | Review for removal |

Removal requires: ≥30 day deprecation period + all references cleaned (modules, settings.json, examples, skills, hooks) + GAPS.md closed.

## Tool Categories Reference

| Category | Module |
|----------|--------|
| Security (nmap, nuclei, burp) | modules/02-security.md |
| DevOps (terraform, ansible, kubectl) | modules/03-devops.md |
| Development (git, npm, python) | modules/07-engineering.md |
| Low-level (gdb, ghidra, radare2) | modules/07-engineering.md |
| MCP Servers | modules/11-mcp.md |
| Internal tools | ~/.claude/tools/ |
