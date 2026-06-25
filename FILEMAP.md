# FILEMAP — your-project

<!-- Claude Code configuration project — public repo mirror of ~/.claude/ -->
<!-- Purpose: avoid redundant file searches, provide context to subagents. -->
<!-- Update: on file create/delete/major refactor. -->

## Quick Reference

| Path | Purpose | Key Contents |
|------|---------|-------------|
| CHANGELOG.md | Version history | All versions from v1.0 to v9.1 |
| BACKLOG.md | Task tracking | Active/Deferred/Archive |
| GAPS.md | Gap tracking | Missing agents, features, coverage |
| ARCHITECTURE.md | Architecture doc | ADR table, component overview, change log |
| ARCHITECTURE_FIXES.md | Architecture fixes | Identified issues and corrections |
| ARCHITECTURE_REDESIGN.md | Redesign notes | Path C redesign (v9.0) |
| .claude-ver | Project version | 9.1.0 |
| README.md | Public repo docs | Setup, architecture overview |
| AUTHORITATIVE_SOURCES.md | Trusted info sources | Per-domain source lists |
| MASTER_PROMPT.md | Master prompt doc | Prompt structure reference |
| TEST_METHODOLOGY.md | Test methodology | 12-part manual test suite (A-L) |
| PRACTICAL_AGENT_DEVELOPMENT_GUIDE.md | Agent dev guide | Practical patterns for agent development |
| VENDOR_INDEPENDENT_AGENT_GUIDE.md | Vendor guide (EN) | Vendor-independent agent patterns |
| VENDOR_INDEPENDENT_AGENT_GUIDE_RU.md | Vendor guide (RU) | Russian translation |
| настройка_агентов_claude_статья.md | Article (RU) | Claude agent setup article |
| docs/ | Documentation | Guides, patterns, internals |
| docs/API_STATUS.md | API status | Claude API feature status |
| docs/VSCODIUM_COMPATIBILITY.md | VS Codium compat | VS Codium integration notes |
| docs/WINDOWS_PORTING.md | Windows porting | Cross-platform setup (v1) |
| docs/WINDOWS_PORTING_V2.md | Windows porting v2 | Updated compat layer (8 files) |
| docs/MONITORING_SYSTEM.md | Monitoring | Cross-session monitoring architecture |
| docs/PERMISSION_ESCALATION_AUDIT.md | Permission audit | Subagent permission escalation protocol |
| data/ | Working data | Samples, rules, results |
| prompts/ | Test prompts | Prompt templates for testing |
| templates/ | Config templates | settings-windows.json |
| tools/ | CLI tools | usage_dashboard.py |
| memory/MEMORY.md | Project memory | Quick reference, architecture status |
| install.sh | Linux installer | Go build, MCP, VS Codium setup |
| install.ps1 | Windows installer | PowerShell installer (11 sections) |
| setup-vscodium.sh | VS Codium setup | Cross-platform VS Codium config |
| setup_opt_dirs.sh | Dir setup | Creates /opt/ working directories |
| migrate_to_windows.py | Windows migration | Cross-platform migration script |
| sync_to_windows.sh | Windows sync | Sync script for Windows |

| poc/adr-007-ppid-isolation/ppid_isolator.go | Go source | — |
| poc/adr-007-ppid-isolation/demo.sh | Shell script | — |
| poc/adr-007-ppid-isolation/README.md | Project documentation | — |
| poc/adr-007-ppid-isolation/patches/shared.go.diff | Project file | — |
| poc/adr-007-ppid-isolation/patches/criteria.go.diff | Project file | — |
| poc/adr-007-ppid-isolation/patches/user_prompt_submit_hook.py.diff | Project file | — |
| docs/ECOSYSTEM_AUDIT_2026-05.md | Documentation | — |
| docs/SECRET_ROTATION_CHECKLIST.md | Documentation | — |
| docs/ECOSYSTEM_AUDIT_2026-06.md | Audit (Jun) | June-2026 ecosystem audit: TeamCreate removal, ALL-CAPS overtrigger, hierarchy, RLM |
| docs/guides/AUDIT-06_PHASE2_REFACTOR.md | Guide | Config refactor: TeamCreate→implicit-team, De-CAPS (safety-firm), hierarchy |
| docs/guides/RLM_IMPLEMENTATION.md | Guide | Recursive Language Models — paper → impl at /opt/project; how-to (CC/DeepSeek/ChatGPT) |
| /opt/project (external) | RLM project | Model-agnostic Recursive Language Models reference impl (arXiv:2512.24601); separate git repo |
## Directory Structure

```
/opt/project/
├── .claude/                  # Project-local Claude settings
│   └── settings.local.json   # Project permissions (9.1.0)
├── .claude-ver               # Project version (9.1.0)
├── .gitignore                # Security-focused gitignore (v4.0)
├── .mcp.json                 # Project MCP server config
├── docs/                     # Documentation
│   ├── API_STATUS.md
│   ├── VSCODIUM_COMPATIBILITY.md
│   ├── WINDOWS_PORTING.md
│   ├── WINDOWS_PORTING_V2.md
│   ├── MONITORING_SYSTEM.md
│   └── PERMISSION_ESCALATION_AUDIT.md
├── data/                     # Working data
├── examples/                 # Usage examples
├── memory/                   # Project memory
│   └── MEMORY.md
├── prompts/                  # Test prompts
├── templates/                # Config templates
├── tools/                    # CLI tools
│   └── usage_dashboard.py
├── ARCHITECTURE.md           # Architecture doc
├── BACKLOG.md                # Task tracking
├── CHANGELOG.md              # Version history
├── FILEMAP.md                # This file
└── TEST_METHODOLOGY.md       # Manual test suite
```

## Metadata

- Generated: 2026-02-26
- Last updated: 2026-03-25
- Project type: Claude Code configuration (public mirror)
- Version: 9.1.0
