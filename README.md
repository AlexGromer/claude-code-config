# Claude Agent Configuration Framework

[![Version](https://img.shields.io/badge/version-v9.1-blue.svg)](CHANGELOG.md)
[![Agents](https://img.shields.io/badge/agents-102%20custom-purple.svg)](docs/guides/AGENT_WRITING_GUIDELINES.md)
[![Skills](https://img.shields.io/badge/skills-103%20(96%20fork%20%2B%206%20util%20%2B%201)-orange.svg)](CHANGELOG.md)
[![Hooks](https://img.shields.io/badge/hooks-25%20commands-yellow.svg)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Production-ready framework for configuring Claude Code CLI agents with modular architecture, 102 specialized agents, automated context enrichment, and cross-session memory.

## Architecture (v9.1)

The system runs entirely inside `~/.claude/` and is injected into Claude Code via Output Styles, hooks, rules, skills, and `--append-system-prompt-file`.

```
User prompt
  │
  ├─→ Output Style (system prompt level — PRIMARY behavioral control)
  │     7 styles: operator, learning, research, pair-programming,
  │     incident, architecture, documentation
  │     Active style loaded via Wrapper v3 --append-system-prompt-file
  │
  ├─→ Rules (14 .md files, auto-loaded every request)
  │     authorization-levels, task-execution, code-before-write,
  │     mandatory-checks, anti-hallucination, mcp-rules, working-directories,
  │     re-evaluation, agent-routing, request-clarification,
  │     architecture-enforcement, gc-maintenance, file-templates, auto-action
  │
  ├─→ Managed CLAUDE.md (/etc/claude-code/CLAUDE.md)
  │     Immutable policy: routing format, PlanMode trigger, anti-hallucination
  │
  ├─→ Wrapper v3 (banner, bootstrap, --append-system-prompt-file)
  │     On session start: creates .claude-ver, BACKLOG.md, .gitignore, MCP config
  │
  ├─→ Hooks (25 commands across 13 event types)
  │     SessionStart → reinforcement, dashboard, health, GC quick-check
  │     UserPromptSubmit → domain detection (12 prompts), tier scoring, MCP rotation
  │     PreToolUse → validation, approval, budget
  │     PostToolUse → metrics, cost, code review
  │     PreCompact → save state to MEMORY.md
  │     PostCompact, Stop, SubagentStart, TaskCompleted,
  │     InstructionsLoaded, PermissionRequest,
  │     SessionEnd, PostToolUseFailure
  │
  ├─→ Skills (103 total: 96 fork + 6 utility + project-init)
  │     User prompt → keyword match → Skill → fork → Agent → result
  │
  ├─→ Agents (102 custom, defined in ~/.claude/agents/*.md)
  │     Invoked via Task tool with subagent_type parameter
  │     Models: haiku (formatting), sonnet (development), opus (critical)
  │
  ├─→ Modules (13 active, 13 archived, loaded via Read tool when needed)
  │     Domain knowledge: security, devops, compliance, engineering, etc.
  │
  └─→ MCP Servers (LOCAL scope, profile-based rotation)
        Essential: 13 servers (github, fetch, filesystem, memory, git,
          sequential-thinking, sqlite, backlog-mcp, profile-mcp, doctor-mcp,
          gc-mcp, score-mcp, tools-mcp)
        Go servers: 6 (backlog, doctor, gc, profile, score, tools)
        Domain profiles: 23 on-demand via profile-mcp Go server
```

### Why it works this way

- **Output Style** at system prompt level is the primary behavioral override — 7 pre-built personas, switchable via `/config`
- **Rules** auto-load on every request (Claude Code feature) — zero overhead to inject behavioral constraints
- **Managed CLAUDE.md** in `/etc/claude-code/` applies immutable policy across all projects
- **Wrapper v3** bootstraps each session: creates project scaffolding and injects the active Output Style via `--append-system-prompt-file`
- **25 hook commands across 13 event types** cover the full session lifecycle including new events: Stop, SubagentStart, TaskCompleted, InstructionsLoaded, PermissionRequest, PostCompact
- **Skills with `context: fork`** spawn isolated subagents — prevents context pollution in main conversation
- **MCP profile rotation** via profile-mcp Go server — only loads domain-relevant servers (avoids 50K+ token bloat)
- **Modules NOT auto-loaded** — on-demand via Read tool to keep base context under 15K chars

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Output Style as PRIMARY control | System prompt level — overrides all other behavioral instructions |
| Rules (14) over one big CLAUDE.md | Auto-loaded, no manual Read needed, modular |
| `--append-system-prompt-file` for Output Style | Bypasses system-reminder wrapper, highest priority injection point |
| Managed /etc/claude-code/CLAUDE.md | Immutable policy cannot be overridden by project-level config |
| LOCAL MCP scope (not USER) | USER scope not loaded in sessions (Claude Code limitation) |
| profile-mcp Go server (not Python script) | Faster, concurrent-safe, no interpreter startup cost |
| 96 fork skills + 6 utility + project-init | Fork = isolated execution, utility = runs in main context |
| Session ID via file, not env var | Sandbox isolation prevents env var propagation |
| MEMORY.md < 200 lines | Auto-loaded into context, must stay concise |
| Topic files for details | `architecture.md`, `debugging.md` etc. — read on demand |

## Components

| Component | Count | Location | Auto-loaded? |
|-----------|-------|----------|-------------|
| Output Styles | 7 | `~/.claude/output-styles/*.md` | Active style only (via Wrapper v3) |
| Rules | 14 | `~/.claude/rules/*.md` | Yes (every request) |
| Hook commands | 25 (13 event types) | `~/.claude/hooks/*.py` | Yes (event-driven) |
| Agents | 102 | `~/.claude/agents/*.md` | No (invoked via Task) |
| Skills | 103 (96 fork + 6 util + 1) | `~/.claude/skills/*/SKILL.md` | Yes (skill descriptions) |
| Modules | 13 active, 13 archived | `~/.claude/modules/*.md` | No (Read on demand) |
| Domain prompts | 12 | `~/.claude/prompts/*.md` | On domain detection (UserPromptSubmit) |
| MCP profiles | 23 | managed by profile-mcp Go server | On rotation |
| Go MCP servers | 6 | `~/.claude/mcp-servers/` | Yes (essential: always loaded) |
| MCP tools | 15 | via tools-mcp Go server | No (invoked explicitly) |
| CLI tools | 2 | `~/.claude/tools/` | No (invoked explicitly) |

## Task Execution Model

Every response starts with routing: `⚙ Role | CONFIDENCE | approach`

| Score | Tier | What happens |
|-------|------|-------------|
| <20 | Simple | Execute directly, 1-line routing |
| 20-65 | Standard | Goal/Result/Criteria, freeze criteria, verify |
| 65-80 | Complex | EnterPlanMode + TeamCreate (coordinated agents) |
| >80 | Critical | EnterPlanMode + user approval + TeamCreate |

**Agent Reporting**: When agents are launched, always report who's running what. On completion — summary from each agent.

**Complexity scoring**: Automated via UserPromptSubmit hook — analyzes prompt keywords, multi-domain overlap, action verb density, scope indicators.

## Context Enrichment Pipeline

### On session start (SessionStart hooks):
1. `session_start_reinforcement.py` — injects rules reminder, config drift detection, project init instructions, session continuity data
2. `session_startup_dashboard.py` — research digest alerts
3. `session_health_check.py` — session health metrics
4. GC quick-check via gc-mcp

### On every prompt (UserPromptSubmit hook):
1. Domain detection → injects one of 12 domain prompts (or general fallback)
2. Complexity scoring → tier assignment
3. Agent recommendations (top 5 per domain)
4. MCP profile rotation if domain changed
5. Frozen criteria injection if active
6. `TEAM REQUIRED` hint for Complex+ tasks

### New lifecycle events (v9.0+):
- **SubagentStart** — context injection for subagents
- **TaskCompleted** — post-task reporting hook
- **Stop** — session stop handler
- **InstructionsLoaded** — post-load validation
- **PermissionRequest** — permission audit hook
- **PostCompact** — state save after context compaction

**Overhead**: ~5-8 lines per prompt (normal), ~15-20 lines (frozen criteria active)

## Cross-Session Memory

```
PreCompact hook → saves In-Progress to MEMORY.md + session_summary.md
SessionEnd hook → appends to session_continuity.jsonl (git state, plan, backlog)
SessionStart hook → reads continuity data, injects PREVIOUS SESSION context
```

- **Project MEMORY.md**: quick references, <200 lines, auto-loaded
- **Topic files**: `architecture.md`, `debugging.md`, `patterns.md` — read on demand
- **Agent memory**: `~/.claude/agent-memory/<name>/MEMORY.md` — cross-project, reusable patterns
- **BACKLOG.md**: task tracking per project (P1/P2/P3 priorities)

## Project Initialization

When a project has no `.claude-ver` file, the SessionStart hook injects instructions to run `project-init` agent which:
- Detects stack (package.json, go.mod, pyproject.toml, Cargo.toml)
- Asks contextual questions (type, domains, stack)
- Creates `.claude-ver`, `BACKLOG.md`, configures MCP
- For existing projects without `.claude-ver`: migration mode (preserves MEMORY.md)
- For Go projects: optionally runs `/opt/templates/go-repo/generate.sh`

## Repository Structure

```
/opt/project/                          # Public repository (synced from ~/.claude/)
├── README.md                              # This file
├── CHANGELOG.md                           # Version history (v1.0 → v9.1)
├── BACKLOG.md                             # Current task tracking
├── GAPS.md                                # Gap backlog (~700 gaps, 519 resolved)
├── LICENSE                                # MIT
├── .gitignore                             # Security patterns
│
├── install.sh                             # Automated Linux/macOS installer (Go build, MCP setup)
├── install.ps1                            # Windows PowerShell installer (11 sections)
├── setup-vscodium.sh                      # Cross-platform VS Codium configuration
├── sync.sh                                # Sync utility v4 (agents/, mcp-servers/, output-styles/)
├── setup_opt_dirs.sh                      # Initial /opt/ directory setup
│
├── ARCHITECTURE_REDESIGN.md               # v9.0 Path C architecture decisions
├── MASTER_PROMPT.md                       # Output Style primary control documentation
├── MONITORING_SYSTEM.md                   # Cross-session monitoring architecture
├── PERMISSION_ESCALATION_AUDIT.md         # Subagent permission gap analysis (9 gaps)
│
├── PRACTICAL_AGENT_DEVELOPMENT_GUIDE.md   # 10-part tutorial with questionnaires (RU)
├── VENDOR_INDEPENDENT_AGENT_GUIDE.md      # Provider-agnostic guide (EN)
├── VENDOR_INDEPENDENT_AGENT_GUIDE_RU.md   # Provider-agnostic guide (RU)
├── AUTHORITATIVE_SOURCES.md               # 150+ curated sources registry
├── настройка_агентов_claude_статья.md     # Full methodology article (~12K lines, RU)
│
├── docs/
│   ├── guides/                            # Writing guidelines for agents, modules, skills, gaps
│   ├── examples/                          # 80+ few-shot examples (11 domains)
│   ├── patterns/                          # Research-derived patterns
│   ├── API_STATUS.md                      # 10 API keys verified and documented
│   ├── VSCODIUM_COMPATIBILITY.md          # VS Codium compatibility report
│   ├── WINDOWS_PORTING.md                 # Windows compatibility guide
│   ├── CLAUDE_CODE_INTERNALS.md           # Claude Code reverse-engineering research
│   └── ...                                # Reference documentation
│
└── tools/
    └── usage_dashboard.py                 # CLI monitoring (health, tools, adoption, cost, anomalies)
```

## Guides

| Guide | Audience | Content |
|-------|----------|---------|
| [Practical Guide](PRACTICAL_AGENT_DEVELOPMENT_GUIDE.md) | Developers starting from scratch | 10-part interactive tutorial (RU) |
| [Vendor-Independent (EN)](VENDOR_INDEPENDENT_AGENT_GUIDE.md) | Any LLM developer | Provider-agnostic methodology |
| [Vendor-Independent (RU)](VENDOR_INDEPENDENT_AGENT_GUIDE_RU.md) | Same, in Russian | |
| [Main Article (RU)](настройка_агентов_claude_статья.md) | Researchers, architects | Complete methodology (~12K lines) |
| [Agent Writing](docs/guides/AGENT_WRITING_GUIDELINES.md) | Agent authors | Template, C1-C10 criteria |
| [Module Writing](docs/guides/MODULE_WRITING_GUIDELINES.md) | Module authors | Structure, linking |
| [Claude Code Internals](docs/CLAUDE_CODE_INTERNALS.md) | Power users | MCP scopes, hooks, SDK |

## Quick Start

### Linux / macOS

```bash
# Clone
git clone git@github.com:<your-org>/claude-code-config.git ~/.claude

# Run automated installer
bash ~/.claude/install.sh

# Verify
ls ~/.claude/rules/           # 14 rule files
ls ~/.claude/agents/          # 102 agent files
ls ~/.claude/output-styles/   # 7 output style files
ls ~/.claude/hooks/           # Hook scripts
cat ~/.claude/CLAUDE.md       # Core prompt (v9.1)

# Build Go MCP servers (requires Go 1.21+)
cd ~/.claude/mcp-servers && make all

# Check health (MCP tool — run inside Claude Code session)
# mcp__doctor-mcp__doctor_check
```

### Windows

```powershell
# Run PowerShell installer (11 sections, requires PowerShell 5.1+)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\install.ps1
```

### VS Codium

```bash
# Cross-platform VS Codium configuration
bash ~/.claude/setup-vscodium.sh
```

### Output Style switching

```
/config                   # Show current style and available options
/config learning          # Switch to learning style (explanations, analogies)
/config documentation     # Switch to documentation style (Diátaxis framework)
```

### MCP profile management (via Claude Code session)

```
mcp__profile-mcp__profile_list
mcp__profile-mcp__profile_load {"name": "devops"}
```

## Version History (recent)

| Version | Date | Key Changes |
|---------|------|-------------|
| 9.1 | 2026-03-22 | Domain prompts 19→12 (enhanced), usage_dashboard.py, MONITORING_SYSTEM.md, install.ps1, install.sh v2, setup-vscodium.sh, sync.sh v4 |
| 9.0 | 2026-03-22 | Architecture Redesign: Output Styles PRIMARY (7 styles), Wrapper v3, Managed CLAUDE.md, 14 rules, 25 hooks, 19 domain prompts, 6 new event types |
| 8.0 | 2026-03-17 | Reliability + cross-platform: 7 CRITICAL fixes, 1.1GB→561MB, race condition fixes, 7 domain prompts, Windows porting, install.sh, API_STATUS.md |
| 7.8 | 2026-03-04 | ARCHITECTURE templates (10 types), permissions 5→12, ONBOARDING +6 Qs, 10 workflow YAMLs, edge audit (47 issues) |
| 7.7 | 2026-03-02 | VERSION file, MCP 12→13 essential, GC CLI mode, project upgrade system, git permissions (18+10+2) |
| 7.6 | 2026-03-01 | tools-mcp Go server (13 tools), removed 3 Python CLI tools |
| 7.5 | 2026-03-01 | plugins/ removed (10 toolkits, 7.2MB), 56 dead tests removed, GC targets 13 |
| 7.2 | 2026-02-26 | Ecosystem audit: project-init auto-instructions, agent reporting rules, TeamCreate enforcement |

See [CHANGELOG.md](CHANGELOG.md) for full history.

---

**Version:** 9.1.0 | **Last Updated:** 2026-03-22 | **License:** MIT
