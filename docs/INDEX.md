# Documentation Index

Documentation for the Claude Agent Configuration Framework (v9.1).

## Architecture

- **[CLAUDE_CODE_INTERNALS.md](CLAUDE_CODE_INTERNALS.md)** — MCP scopes, hook events, Agent SDK, settings schema, context optimization. Original research (~1200 lines).
- **[SYSTEM_REMINDER_BYPASS.md](SYSTEM_REMINDER_BYPASS.md)** — How `--append-system-prompt` bypasses the system-reminder wrapper and injects CORE_INSTRUCTIONS.md.

## Operations

- **[MONITORING_SYSTEM.md](MONITORING_SYSTEM.md)** — Monitoring dashboard: session health, budget tracking, GC status, MCP availability.
- **[CORE_METRICS_DEFINITION.md](CORE_METRICS_DEFINITION.md)** — Metrics definitions for budget, latency, usage statistics.
- **[API_STATUS.md](API_STATUS.md)** — External API availability matrix: Shodan, VirusTotal, and other MCP-integrated services.

## Security

- **[PERMISSION_ESCALATION_AUDIT.md](PERMISSION_ESCALATION_AUDIT.md)** — Audit of permission drift in settings.local.json across projects. Widening violations, remediation steps.
- **[hallucination_system_explained.md](hallucination_system_explained.md)** — Anti-hallucination architecture: detection, correction, confidence scoring.

## Development

- **[error_handling.md](error_handling.md)** — Hook error handling patterns: `except Exception:`, stdin JSON graceful degradation, fail-open protocol.
- **[RESEARCH_SOURCE_MONITORING.md](RESEARCH_SOURCE_MONITORING.md)** — R2P pipeline, source monitoring, relevance maintenance.
- **[VALIDATION_FRAMEWORK.md](VALIDATION_FRAMEWORK.md)** — Validation methodology for configuration changes and component upgrades.

## Guides

- **[guides/AGENT_WRITING_GUIDELINES.md](guides/AGENT_WRITING_GUIDELINES.md)** — Agent template, C1-C10 criteria.
- **[guides/MODULE_WRITING_GUIDELINES.md](guides/MODULE_WRITING_GUIDELINES.md)** — Module structure and lifecycle.
- **[guides/EXAMPLE_WRITING_GUIDELINES.md](guides/EXAMPLE_WRITING_GUIDELINES.md)** — Few-shot example standards.
- **[guides/GAP_WRITING_GUIDELINES.md](guides/GAP_WRITING_GUIDELINES.md)** — Gap documentation format.

## Reference / Legacy

- **[VSCODIUM_COMPATIBILITY.md](VSCODIUM_COMPATIBILITY.md)** — VS Codium / VS Code extension compatibility: CWD handling, workspace behavior, hook differences.
- **[WINDOWS_PORTING_V2.md](WINDOWS_PORTING_V2.md)** — Windows porting guide v2: path mapping, Go cross-compilation, minimal settings profile.

## Protocols

Lifecycle and maintenance protocols in `protocols/`:

- **[protocols/domain_lifecycle.md](protocols/domain_lifecycle.md)** — Domain module lifecycle management.
- **[protocols/relevance_maintenance.md](protocols/relevance_maintenance.md)** — Content relevance maintenance.
- **[protocols/session_continuity.md](protocols/session_continuity.md)** — Session continuity protocol.
- **[protocols/tool_lifecycle.md](protocols/tool_lifecycle.md)** — Tool lifecycle management.

## Examples (120+)

Few-shot examples organized by domain in `examples/` (23 categories):

| Domain | Topics |
|--------|--------|
| blue-purple-dfir | DFIR, blue/purple team exercises |
| business-analysis | Business analysis patterns |
| coding-agents | Agent coding patterns |
| common | Code review, debugging, documentation |
| compliance | GDPR, ISO 27001, PCI-DSS, FZ-152 |
| devops | Terraform, Kubernetes, CI/CD, Helm, monitoring |
| education | CTF, curriculum, tutorials, methodology |
| engineering | API design, TDD, refactoring, performance |
| implementation | Implementation patterns |
| lowlevel | Kernel modules, eBPF, Rust, assembly, Go |
| maturity | Gap detection, prompt optimization |
| mcp | MCP server patterns |
| network-infrastructure | Network and infrastructure patterns |
| orchestration | Multi-agent orchestration |
| osint | Domain recon, email OSINT, social media |
| planning | OKR, sprint, roadmap, risk, capacity |
| procurement | Procurement analysis |
| prompting | Prompt engineering patterns |
| security | SQL injection, XSS, pentest, container security |
| skills | Skill development patterns |
| tech-stack | Technology stack analysis |
| testing | Testing patterns and strategies |
| writing | API docs, research papers, blog posts |

## Patterns (research-derived)

Research patterns in `patterns/`:
- `architectural/` — scaling patterns, cognitive control
- `performance/` — prompt optimization, test-time reasoning
- `prompting/` — prefill-guided thinking, KV cache management
- `security/` — multi-agent swarms, demographic bias, guardrails
- `tool_ideas/` — AgentDog, CCA-based tools

## Claude Configuration (actual, in ~/.claude/)

| Component | Count | Path |
|-----------|-------|------|
| CLAUDE.md | v9.1 | `~/.claude/CLAUDE.md` |
| Output Styles | 7 (operator, learning, research, pair-programming, incident, architecture, documentation) | `~/.claude/output-styles/` |
| Agents | 102 | `~/.claude/agents/*.md` |
| Skills | 103 (96 fork + 6 utility + project-init) | `~/.claude/skills/*/SKILL.md` |
| Hooks | 25 registered commands | `~/.claude/hooks/` |
| Rules | 14 | `~/.claude/rules/*.md` |
| Modules | 13 active (13 archived) | `~/.claude/modules/*.md` |
| Domain Prompts | 12 | `~/.claude/prompts/` |
| Go MCP servers | 6 (profile, doctor, gc, score, backlog, tools) | `~/.claude/mcp-servers/` |
| Essential MCP | 13 servers (LOCAL scope) | `~/.claude.json` |
| MCP profiles | 23 | managed by profile-mcp |

---
**Version:** 9.1.0 | **Updated:** 2026-03-22
