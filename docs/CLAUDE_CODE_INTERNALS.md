# Claude Code Internals — Reference Documentation

**Version:** 1.0.0
**Date:** 2026-02-09
**Purpose:** Technical reference for Claude Code's internal architecture and configuration system
**Audience:** Advanced users, developers extending Claude Code functionality

---

## Table of Contents

1. [MCP Server Configuration](#1-mcp-server-configuration)
2. [Plugin System](#2-plugin-system)
3. [Agent Memory](#3-agent-memory)
4. [Hook System](#4-hook-system-complete-reference)
5. [Claude Agent SDK](#5-claude-agent-sdk-reference)
6. [Settings.json Schema](#6-settingsjson-schema)
7. [Context Token Optimization](#7-context-token-optimization)
8. [Configuration File Locations](#8-configuration-file-locations)

---

## 1. MCP Server Configuration

### Three Configuration Scopes

Claude Code loads MCP servers from **three distinct scopes**, each with different behavior:

| Scope | Location | Loaded Per-Project? | Use Case |
|-------|----------|---------------------|----------|
| **User** | Top-level `mcpServers` in `~/.claude.json` | ❌ No | Global servers (rarely used) |
| **Local** | `projects.<path>.mcpServers` in `~/.claude.json` | ✅ Yes | User's per-project configs |
| **Project** | `.mcp.json` at project root | ✅ Yes | Team-shared configs (git) |

### User Scope (Global)

```json
{
  "mcpServers": {
    "server-name": {
      "type": "stdio",
      "command": "uvx",
      "args": ["mcp-server-package"]
    }
  }
}
```

**Characteristics:**
- ❌ NOT loaded per-project
- Only used for `claude mcp add --scope user`
- Rarely used in practice

### Local Scope (Per-Project, Default)

```json
{
  "projects": {
    "/absolute/path/to/project": {
      "mcpServers": {
        "github": {
          "type": "stdio",
          "command": "uvx",
          "args": ["mcp-server-github"],
          "env": {
            "GITHUB_TOKEN": "ghp_xxxxx"
          }
        }
      }
    }
  }
}
```

**Characteristics:**
- ✅ Loaded when working in project directory
- **Default** when using `claude mcp add` (no `--scope` flag)
- Shown in `claude mcp list` output
- **MUST** include `"type": "stdio"` field

### Project Scope (Team-Shared)

**File:** `/project/.mcp.json`

```json
{
  "mcpServers": {
    "postgres": {
      "command": "uvx",
      "args": ["mcp-server-postgres"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://..."
      }
    }
  }
}
```

**Characteristics:**
- ✅ Loaded when working in project directory
- Can be committed to git (team sharing)
- ❌ **Known Issue #5963**: NOT shown in `claude mcp list` (but still loaded)
- No `"type"` field needed in project scope

### CLI Commands

```bash
# Add MCP server (default: local scope, current project)
claude mcp add github --command "uvx mcp-server-github"

# Add to user scope (global, not per-project)
claude mcp add --scope user github --command "uvx mcp-server-github"

# List active servers (shows LOCAL scope only)
claude mcp list

# Remove server
claude mcp remove github
```

### Dynamic Profile Management

**Tool:** `~/.claude/tools/mcp_profile_manager.py`

Manages MCP profiles dynamically by rewriting `~/.claude.json`:

```bash
# Switch to security profile (loads only security MCP servers)
python ~/.claude/tools/mcp_profile_manager.py --switch security

# List available profiles
python ~/.claude/tools/mcp_profile_manager.py --list

# Create custom profile
python ~/.claude/tools/mcp_profile_manager.py --create dev --servers github,postgres,redis
```

**Profiles reduce context bloat** from ~50K tokens (39 servers) to ~5K tokens (5-7 servers).

---

## 2. Plugin System

### Overview

Claude Code supports a **native plugin system** for extending functionality without modifying core configuration.

### Plugin Directory Structure

```
.claude-plugin/
├── plugin.json           # Plugin manifest
├── skills/
│   ├── reference/        # Auto-loaded skills (injected into context)
│   │   └── domain-knowledge.md
│   └── action/           # User-invoked skills (/skill-name)
│       └── deploy.skill.md
├── hooks/
│   └── custom-hook.py
└── mcp-servers/
    └── custom-server/
```

### Plugin Manifest (`plugin.json`)

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "Custom plugin for X",
  "author": "Your Name",
  "skills": [
    {
      "name": "domain-knowledge",
      "type": "reference",
      "path": "skills/reference/domain-knowledge.md"
    },
    {
      "name": "deploy",
      "type": "action",
      "path": "skills/action/deploy.skill.md",
      "command": "/deploy"
    }
  ],
  "hooks": [
    {
      "event": "PostToolUse",
      "type": "command",
      "command": "python hooks/custom-hook.py"
    }
  ],
  "mcpServers": {
    "custom": {
      "command": "node",
      "args": ["mcp-servers/custom-server/index.js"]
    }
  }
}
```

### Skill Types

| Type | Auto-Loaded? | Invocation | Context Impact |
|------|--------------|------------|----------------|
| **Reference** | ✅ Yes | Automatic | Injected into context on load |
| **Action** | ❌ No | `/skill-name` | Loaded on-demand when invoked |

**Reference Skills** — Domain knowledge, best practices, quick references:
```markdown
# Domain Knowledge (Reference)

Quick reference for X:
- Pattern A
- Pattern B
- Pattern C
```

**Action Skills** — Workflows, procedures, multi-step tasks:
```markdown
---
name: Deploy
description: Deploy application to production
trigger: /deploy
---

# Deploy Workflow

## Steps
1. Run tests
2. Build artifacts
3. Deploy to staging
4. Run smoke tests
5. Deploy to production
```

### Plugin Discovery

| Source | Command | Status |
|--------|---------|--------|
| **Local directory** | `claude plugin add ./my-plugin/` | ✅ Supported |
| **npm package** | `claude plugin add mcp-plugin-name` | ✅ Supported |
| **Marketplace** | `claude plugin search security` | 🚧 Future |

### Plugin vs Configuration

| Feature | Plugin | Config |
|---------|--------|--------|
| Portability | ✅ Self-contained | ❌ Scattered across files |
| Distribution | ✅ npm, git | ❌ Manual copy |
| Team sharing | ✅ Single directory | ❌ Multiple files |
| Versioning | ✅ Semantic versioning | ❌ No versioning |

**Recommendation:** Use plugins for reusable, shareable extensions. Use config for personal preferences.

---

## 3. Agent Memory

### Overview

Claude Code supports **cross-session learning** via agent memory, allowing agents to remember patterns, preferences, and project-specific knowledge.

### Memory Configuration

**Agent Definition Example:**

```json
{
  "agents": {
    "security-analyst": {
      "model": "claude-opus-4",
      "instructions": "You are a security analyst...",
      "memory": "project",
      "tools": ["Bash", "Read", "Grep"]
    }
  }
}
```

### Memory Scopes

| Scope | Storage Location | Use Case |
|-------|------------------|----------|
| **user** | `~/.claude/agent-memory/<name>/` | Personal preferences, cross-project patterns |
| **project** | `~/.claude/projects/<path>/memory/` | Project-specific knowledge, decisions |
| **local** | `/project/.claude/memory/` | Team-shared memory (git-committed) |

### Memory Structure

**File:** `MEMORY.md`

```markdown
# Agent Memory: security-analyst

## Key Learnings

### CVE-2023-12345 Analysis (2026-01-15)
- **Root cause**: Buffer overflow in libfoo
- **Fix**: Patch v1.2.3
- **Detection pattern**: Look for `strncpy` calls without bounds check

### Common False Positives
- Tool X always flags Y as high severity, but it's safe in our context
- Ignore warnings about deprecated API Z (still required for legacy support)

## User Preferences
- Preferred output format: JSON with severity levels
- Always run static analysis before dynamic analysis
- Notification threshold: CRITICAL and HIGH only

## Project Context
- Codebase uses custom authentication library (see `lib/auth.py`)
- Test environment: staging.example.com
- Production deployment: Saturdays 02:00 UTC
```

### Context Injection

**First 200 lines** of `MEMORY.md` are **automatically injected** into subagent context on creation:

```python
# Subagent invocation
Task(
    subagent_type="general-purpose",
    agent="security-analyst",  # ← Loads memory for this agent
    model="opus",
    prompt="Analyze vulnerability report..."
)
```

### Memory Management

**Update Memory:**

```bash
# Manual edit
vim ~/.claude/agent-memory/security-analyst/MEMORY.md

# Programmatic update (append learning)
echo "### New Learning ($(date +%Y-%m-%d))" >> memory/MEMORY.md
echo "- Pattern X observed in CVE Y" >> memory/MEMORY.md
```

**Clear Memory:**

```bash
# Archive old memory
mv memory/MEMORY.md memory/MEMORY.$(date +%Y%m%d).archive.md

# Start fresh
touch memory/MEMORY.md
```

### Our Configuration

**File:** `~/.claude/projects/-opt-your-project/memory/MEMORY.md`

Used for:
- Budget system learnings (lockout fixes, race conditions)
- Architecture notes (hook paths, config locations)
- Integrity audit findings
- Cross-session context (previous session IDs)

**Best Practices:**
- Document **root causes**, not just symptoms
- Include **reproduction steps** for bugs
- Note **decisions and rationale** (why X was chosen over Y)
- Keep entries **concise** (first 200 lines auto-loaded)

---

## 4. Hook System (Complete Reference)

### All 13 Hook Events

Claude Code supports **13 hook events** across the agent lifecycle:

| Event | Timing | Input Available | Our Coverage |
|-------|--------|-----------------|--------------|
| **PreToolUse** | Before tool execution | Tool name, args, prompt | ✅ 16 hooks |
| **PostToolUse** | After tool execution | Tool name, args, output, duration | ✅ 22 hooks |
| **PostToolUseFailure** | After tool fails | Tool name, args, error | ✅ 1 hook |
| **SessionStart** | Session begins | Session ID, project path | ✅ 4 hooks |
| **SessionEnd** | Session ends | Session ID, duration, tool count | ✅ 4 hooks |
| **UserPromptSubmit** | User sends message | Prompt text | ✅ 1 hook |
| **PreCompact** | Before context compression | Context size, tokens | ❌ Not used |
| **Stop** | Agent stops | Stop reason | ❌ Not used |
| **SubagentStop** | Subagent stops | Subagent ID, result | ❌ Not used |
| **TaskCompleted** | Task finishes | Task ID, status | ❌ Not used |
| **PermissionRequest** | Permission asked | Permission type | ❌ Not used |
| **Setup** | First-time setup | — | ❌ Not used |
| **TeammateIdle** | Teammate idle (multi-agent) | Teammate ID | ❌ Not used |

**Total:** 48 hook registrations across 42 hook files (some hooks registered for multiple events).

### Hook Types

| Type | Description | Return Format | Use Case |
|------|------------|---------------|----------|
| **command** | Run shell command | JSON on stdout | ✅ All our hooks |
| **prompt** | Inject text into context | Plain text on stdout | Not used |
| **agent** | Spawn subagent | Agent response | Not used |

### Hook Blocking Mechanism

**CRITICAL:** Hooks block operations via **JSON on stdout**, NOT exit codes.

```python
#!/usr/bin/env python3
import sys
import json

def check_budget():
    if budget_exceeded():
        # CORRECT: Block via JSON output
        print(json.dumps({
            "decision": "block",
            "reason": "Budget exceeded: $50/$45 daily limit"
        }))
        sys.exit(0)  # ← Exit 0 = hook processed successfully
    else:
        # Allow operation
        print(json.dumps({"decision": "allow"}))
        sys.exit(0)

if __name__ == "__main__":
    check_budget()
```

**Exit Code Semantics:**

| Exit Code | Meaning | Hook Output |
|-----------|---------|-------------|
| `0` | Hook executed successfully | JSON parsed by Claude Code |
| `1-255` | Hook error (Python exception, etc.) | Ignored, operation proceeds |

**Anti-Pattern:**

```python
# WRONG: This does NOT block the operation
if budget_exceeded():
    sys.exit(1)  # ← This signals hook ERROR, not intentional block!
```

### Hook Configuration (settings.json)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "python ~/.claude/hooks/unified_budget_hook.py \"$CLAUDE_TOOL_NAME\" \"$CLAUDE_TOOL_ARGS\"",
            "timeout": 2000,
            "blocking": true
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python ~/.claude/hooks/tool_execution_hook.py",
            "timeout": 1000,
            "blocking": false
          }
        ]
      }
    ]
  }
}
```

**Matcher Patterns:**

| Pattern | Matches | Example |
|---------|---------|---------|
| `"*"` | All tools | Budget checks |
| `"Bash"` | Specific tool | Bash command logging |
| `"mcp__*"` | Tool prefix | All MCP tools |
| `["Read", "Write"]` | Multiple tools | File operation tracking |

### Environment Variables Available to Hooks

| Variable | Available In | Content |
|----------|-------------|---------|
| `CLAUDE_TOOL_NAME` | PreToolUse, PostToolUse | Tool name (e.g., "Bash") |
| `CLAUDE_TOOL_ARGS` | PreToolUse, PostToolUse | Tool arguments (JSON) |
| `CLAUDE_TOOL_OUTPUT` | PostToolUse | Tool output (may be truncated) |
| `CLAUDE_SESSION_ID` | All | **NOT PROPAGATED** (sandbox isolation) |
| `CLAUDE_PROJECT_PATH` | All | Current project directory |

**CRITICAL:** `CLAUDE_SESSION_ID` env var is **NOT** propagated to hook subprocesses due to sandbox isolation.

**Workaround:** Wrapper writes session ID to file:

```python
# Wrapper (runs in main process)
with open("~/.claude/evaluation/data/current_session_id", "w") as f:
    f.write(os.environ["CLAUDE_SESSION_ID"])

# Hook (runs in subprocess)
with open("~/.claude/evaluation/data/current_session_id", "r") as f:
    session_id = f.read().strip()
```

### Hook Stdin (PostToolUse)

For **PostToolUse** hooks, full tool input/output available via **stdin** (not env vars, which are truncated):

```python
#!/usr/bin/env python3
import sys
import json

# Read full tool data from stdin
hook_data = json.loads(sys.stdin.read())

tool_name = hook_data.get("tool_name")
tool_input = hook_data.get("tool_input")   # Full input (not truncated)
tool_output = hook_data.get("tool_response")  # Full output

# Process data...
```

### Our Hook Architecture

**Consolidated Hooks (v3.7.3):**

| Hook | Event | Matcher | Functions |
|------|-------|---------|-----------|
| `unified_budget_hook.py` | PreToolUse | `*` | Budget check + usage limit |
| `unified_cost_hook.py` | PostToolUse | `*` | Cost tracking + optimization + cache analytics |
| `unified_safety_hook.py` | PostToolUse | `*` | CoT safety + hallucination detection + fact verification |
| `unified_tool_metrics_hook.py` | PostToolUse | `*` | Execution time + success rate + tool chains + multi-turn |

**Benefits:**
- Reduced from 21 to 13 wildcard hook registrations (−38% overhead)
- Single subprocess spawn per event instead of 3-4
- Shared imports and initialization

### Hook Performance

**Overhead per Tool Call:**

| Hook Count | Subprocess Spawns | Typical Latency |
|------------|-------------------|-----------------|
| 21 wildcards | 21 × (spawn + init) | ~500-1000ms |
| 13 wildcards | 13 × (spawn + init) | ~300-600ms |
| 4 consolidated | 4 × (spawn + init) | ~150-300ms |

**Monitoring:**

```bash
# View hook performance metrics
python ~/.claude/evaluation/metrics_tracker.py --report hook-performance
```

---

## 5. Claude Agent SDK (Reference)

### Overview

The **Claude Agent SDK** is a TypeScript/Python library for building custom AI agents using Claude API with tool_use for agentic loops.

**GitHub:**
- Python: [anthropics/anthropic-sdk-python](https://github.com/anthropics/anthropic-sdk-python)
- TypeScript: [anthropics/anthropic-sdk-typescript](https://github.com/anthropics/anthropic-sdk-typescript)

### Core Concepts

#### Agent Class

```typescript
import { Agent } from '@anthropics/agent-sdk';

const agent = new Agent({
  model: 'claude-opus-4',
  systemPrompt: 'You are a helpful assistant...',
  tools: [searchTool, calculatorTool],
  maxIterations: 10
});

const response = await agent.run('What is the weather in Paris?');
```

#### Tool Interface

```typescript
interface Tool {
  name: string;
  description: string;
  input_schema: JSONSchema;
  execute: (input: any) => Promise<ToolResult>;
}

const searchTool: Tool = {
  name: 'web_search',
  description: 'Search the web for information',
  input_schema: {
    type: 'object',
    properties: {
      query: { type: 'string', description: 'Search query' }
    },
    required: ['query']
  },
  execute: async (input) => {
    const results = await searchAPI(input.query);
    return { content: JSON.stringify(results) };
  }
};
```

#### Agentic Loop

```
USER PROMPT
    ↓
┌───────────────────────────────────────┐
│ Agent receives prompt                 │
└────────────┬──────────────────────────┘
             ↓
┌───────────────────────────────────────┐
│ Claude generates response             │
│ ├─► Text response → DONE              │
│ └─► tool_use block → CONTINUE         │
└────────────┬──────────────────────────┘
             ↓
┌───────────────────────────────────────┐
│ SDK executes tool                     │
│ └─► Returns tool_result               │
└────────────┬──────────────────────────┘
             ↓
┌───────────────────────────────────────┐
│ Claude continues with tool_result     │
│ ├─► More tool_use? → LOOP             │
│ └─► Final text → DONE                 │
└───────────────────────────────────────┘
```

### Multi-Agent Patterns

#### Sequential Pattern

```typescript
// Agent A → Agent B → Agent C
const dataAnalyst = new Agent({ /* ... */ });
const reportWriter = new Agent({ /* ... */ });

const analysisResult = await dataAnalyst.run('Analyze sales data');
const report = await reportWriter.run(
  `Write report based on: ${analysisResult}`
);
```

#### Parallel Pattern

```typescript
// Agent A, Agent B, Agent C run simultaneously
const [webResults, dbResults, apiResults] = await Promise.all([
  webSearchAgent.run('Search for X'),
  databaseAgent.run('Query database for Y'),
  apiAgent.run('Fetch data from Z')
]);

const aggregated = aggregateResults(webResults, dbResults, apiResults);
```

#### Orchestrator-Worker Pattern

```typescript
// Orchestrator delegates to specialists
const orchestrator = new Agent({
  tools: [
    {
      name: 'delegate_to_specialist',
      execute: async (input) => {
        const specialist = getSpecialist(input.domain);
        return await specialist.run(input.task);
      }
    }
  ]
});

const result = await orchestrator.run('Complex multi-domain task...');
```

#### Evaluator-Optimizer Pattern

```typescript
// Agent generates, evaluator critiques, agent refines
const generator = new Agent({ /* ... */ });
const evaluator = new Agent({ /* ... */ });

let output = await generator.run('Generate solution for X');
let score = await evaluator.run(`Rate this: ${output}`);

while (score < 0.8) {
  output = await generator.run(`Improve: ${output}. Issues: ${score.feedback}`);
  score = await evaluator.run(`Rate this: ${output}`);
}
```

### Model Context Protocol Integration

```typescript
import { MCPClient } from '@modelcontextprotocol/sdk';

// Connect to MCP server
const mcpClient = new MCPClient({
  serverCommand: 'npx',
  serverArgs: ['-y', 'mcp-server-github']
});

await mcpClient.connect();

// List available tools
const tools = await mcpClient.listTools();

// Create agent with MCP tools
const agent = new Agent({
  tools: tools.map(t => ({
    name: t.name,
    description: t.description,
    input_schema: t.inputSchema,
    execute: async (input) => {
      return await mcpClient.callTool(t.name, input);
    }
  }))
});
```

### Best Practices

| Practice | Rationale |
|----------|-----------|
| **Limit iterations** | Prevent infinite loops (maxIterations: 10-20) |
| **Validate tool output** | Catch errors early, provide fallbacks |
| **Log tool calls** | Debug agentic behavior, audit actions |
| **Use appropriate model** | Haiku (simple), Sonnet (standard), Opus (critical) |
| **Handle timeouts** | Tools may hang, set reasonable timeouts |
| **Sanitize inputs** | Prevent injection attacks via tool arguments |

---

## 6. Settings.json Schema

### Overview

`settings.json` defines **permissions**, **environment variables**, and **hooks** for Claude Code.

**Locations:**
- Global: `~/.claude/settings.json`
- Project: `/project/.claude/settings.local.json`

### Complete Schema

```json
{
  "env": {
    "KEY": "value",
    "PATH": "/custom/path:${PATH}"
  },
  "permissions": [
    {
      "tool": "Bash",
      "command": "rm -rf *",
      "allow": false,
      "reason": "Destructive operation"
    },
    {
      "tool": "Bash",
      "command": "git *",
      "allow": true
    }
  ],
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "python ~/.claude/hooks/budget_hook.py",
            "timeout": 2000,
            "blocking": true
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python ~/.claude/hooks/audit_hook.py",
            "timeout": 1000,
            "blocking": false
          }
        ]
      }
    ]
  }
}
```

### Environment Variables (`env`)

```json
{
  "env": {
    "GITHUB_TOKEN": "ghp_xxxxx",
    "OPENAI_API_KEY": "sk-xxxxx",
    "PATH": "/custom/bin:${PATH}",
    "MY_VAR": "${HOME}/mydir"
  }
}
```

**Variable Expansion:**
- `${VAR}` — Expand existing environment variable
- No expansion if variable not set

**Security Note:** Sensitive values should use external secret management, not hardcoded in settings.json.

### Permissions (`permissions`)

```json
{
  "permissions": [
    {
      "tool": "Bash",
      "command": "rm -rf *",
      "allow": false,
      "reason": "Destructive operation requires explicit approval"
    },
    {
      "tool": "Bash",
      "command": "git *",
      "allow": true
    },
    {
      "tool": "Write",
      "command": "/etc/*",
      "allow": "ask",
      "reason": "System files require confirmation"
    }
  ]
}
```

**Permission Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `tool` | string | Tool name (e.g., "Bash", "Write", "*" for all) |
| `command` | string (glob) | Command/path pattern (supports `*` wildcard) |
| `allow` | boolean or "ask" | `true` = allow, `false` = deny, `"ask"` = prompt user |
| `reason` | string | Explanation for the permission |

**Evaluation Order:**
1. First matching rule wins
2. If no rule matches, default behavior (typically "ask")

### Hooks (`hooks`)

See [Hook System](#4-hook-system-complete-reference) for complete reference.

**Hook Object Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `type` | "command" \| "prompt" \| "agent" | Hook type |
| `command` | string | Shell command to execute |
| `timeout` | number | Timeout in milliseconds (default: 5000) |
| `blocking` | boolean | Wait for hook to complete? (default: false) |

### MCP Servers (NOT in settings.json)

**IMPORTANT:** MCP servers are configured in `~/.claude.json`, NOT `settings.json`.

```json
// WRONG: This does NOT work
{
  "settings": {
    "mcpServers": { /* ... */ }
  }
}

// CORRECT: Use ~/.claude.json
{
  "projects": {
    "/path/to/project": {
      "mcpServers": { /* ... */ }
    }
  }
}
```

### Project vs Global Settings

| File | Scope | Typical Use |
|------|-------|-------------|
| `~/.claude/settings.json` | All projects | Personal preferences, global hooks |
| `/project/.claude/settings.local.json` | Single project | Project-specific permissions |

**Merging Behavior:**
- Project settings **override** global settings (no merge)
- Hooks from both files are **combined**

---

## 7. Context Token Optimization

### MCP Context Bloat Problem

Each active MCP server adds tool descriptions to context, causing significant overhead:

| MCP Servers Active | Approximate Token Overhead | Context Impact |
|-------------------|---------------------------|----------------|
| 5-7 (single domain) | ~5K tokens | ✅ Minimal |
| 10-15 (multi-domain) | ~15K tokens | ⚠️ Moderate |
| 30-40 (all servers) | ~50K tokens | ❌ Severe bloat |

**39 active servers ≈ ~50,000 tokens per request**

### Solution 1: Domain Profiles

**Tool:** `~/.claude/tools/mcp_profile_manager.py`

```bash
# Switch to security profile (7 servers)
python ~/.claude/tools/mcp_profile_manager.py --switch security

# Security profile: github, semgrep, trivy, wazuh, suricata, defectdojo, sonarqube
# Reduces context from ~50K to ~5K tokens (~90% reduction)
```

**Available Profiles:**

| Profile | Server Count | Domains | Token Overhead |
|---------|-------------|---------|----------------|
| `security` | 7 | Security scanning, SIEM, vuln management | ~5K |
| `devops` | 6 | Kubernetes, Ansible, ArgoCD, Docker | ~4K |
| `data` | 5 | Postgres, Redis, MongoDB, Elasticsearch | ~3K |
| `full` | 39 | All domains | ~50K |

### Solution 2: Advanced Tool Use / Lazy Loading

**Claude Code Feature:** On-demand tool discovery reduces overhead by **~85%**.

**How It Works:**

```
TRADITIONAL (Eager Loading):
├─► Load ALL tool descriptions in initial context → ~50K tokens
├─► Claude sees all tools upfront
└─► Overhead: FULL (even if tools not used)

LAZY LOADING (Advanced Tool Use):
├─► Load ONLY tool names initially → ~5K tokens
├─► Claude requests tool details when needed
├─► MCP server provides schema on-demand
└─► Overhead: INCREMENTAL (only used tools)
```

**Enable Lazy Loading:**

> **VERIFIED (2026-02-10): `advancedToolUse` is NOT a documented user-facing config option.**
> Server-side feature flag `tengu_mcp_tool_search: true` (in `cachedGrowthBookFeatures`)
> already enables lazy loading automatically. No user action required.
> Haiku excluded: `tengu_tool_search_unsupported_models: ["haiku"]`.

```json
// ~/.claude.json — cachedGrowthBookFeatures (server-controlled, read-only):
{
  "tengu_mcp_tool_search": true  // Already enabled — lazy loading active
}
```

**Token Savings (when lazy loading active):**

| Scenario | Eager Loading | Lazy Loading | Savings |
|----------|---------------|--------------|---------|
| 39 servers, 0 tools used | 50K tokens | 5K tokens | 90% |
| 39 servers, 3 tools used | 50K tokens | 8K tokens | 84% |
| 39 servers, 10 tools used | 50K tokens | 15K tokens | 70% |

### Solution 3: Prompt Caching

**Claude API Feature:** System prompt caching provides **90% cost savings** on cache hits.

**How It Works:**

```
REQUEST 1 (Cache Write):
├─► Send system prompt + rules (~10K tokens)
├─► API caches prompt content (TTL: ~5 min)
├─► Cost: 1.25x base rate (cache write overhead)
└─► Subsequent requests: read from cache

REQUEST 2+ (Cache Read):
├─► Same system prompt detected
├─► Load from cache (~5 min TTL)
├─► Cost: 0.1x base rate (10x cheaper)
└─► Savings: 90% on cached portion
```

**Cost Comparison:**

| Request | Input Tokens | Cached | Cost (Opus) | Savings |
|---------|-------------|--------|-------------|---------|
| 1st (cache write) | 10,000 | 0 | $0.1875 | — |
| 2nd (cache read) | 10,000 | 10,000 | $0.0375 | 80% |
| 3rd (cache read) | 10,000 | 10,000 | $0.0375 | 80% |

**Optimization Strategy:**

1. **Keep rules/ compact** (quick reference only, ~100 lines each)
2. **Move reference docs to modules/** (loaded on-demand)
3. **Consistent prompt prefixes** (maximize cache hits)
4. **Long sessions benefit most** (repeated cache reads)

**Monitoring:**

```bash
# View cache analytics
python ~/.claude/evaluation/costs/agent_cost_tracker.py --report cache
```

### Solution 4: MCP Server Selector Hook

**Hook:** `~/.claude/hooks/mcp_server_selector_hook.py` (future)

Automatically enable/disable MCP servers based on user prompt:

```python
# User prompt: "Scan Kubernetes cluster for vulnerabilities"
# Hook detects keywords: kubernetes, vulnerabilities
# → Enable: mcp-server-kubernetes, mcp-server-trivy
# → Disable: all other servers
# Result: Context reduced from 50K to 3K tokens
```

### Comparison of Solutions

| Solution | Token Reduction | Effort | Flexibility |
|----------|-----------------|--------|-------------|
| **Domain Profiles** | ~90% | Manual switch | Low (fixed profiles) |
| **Lazy Loading** | ~85% | Config flag | High (automatic) |
| **Prompt Caching** | 0% (but 90% cost savings) | Automatic | N/A |
| **Server Selector Hook** | ~95% | Hook development | Very High (dynamic) |

**Recommended Stack:**
1. **Lazy Loading** already active (server-side `tengu_mcp_tool_search: true`)
2. Use **Domain Profiles** for focused work sessions
3. Rely on **Prompt Caching** for cost optimization
4. Implement **Server Selector Hook** for fully automatic optimization

---

## 8. Configuration File Locations

### Complete Reference Table

| File | Purpose | Scope | Committed to Git? |
|------|---------|-------|-------------------|
| `~/.claude.json` | Main config (MCP servers, projects, preferences) | Global | ❌ No (personal) |
| `~/.claude/settings.json` | Permissions, hooks, env vars | Global | ❌ No (personal) |
| `/project/.claude/settings.local.json` | Project-specific permissions | Project | ❌ No (local overrides) |
| `/project/.mcp.json` | Project MCP servers (team sharing) | Project | ✅ Yes (team config) |
| `/project/CLAUDE.md` | Project-specific instructions | Project | ✅ Yes (team docs) |
| `~/.claude/CLAUDE.md` | Global personal instructions | Global | ❌ No (personal) |
| `~/.claude/rules/*.md` | Auto-loaded rules (all projects) | Global | ❌ No (personal) |
| `~/.claude/modules/*.md` | On-demand documentation modules | Global | ❌ No (personal) |
| `~/.claude/skills/*.skill.md` | Custom skills/workflows | Global | ❌ No (personal) |
| `~/.claude/hooks/*.py` | Custom hook scripts | Global | ❌ No (personal) |
| `~/.claude/evaluation/` | Metrics, logs, data | Global | ❌ No (personal data) |
| `~/.claude/agent-memory/<name>/` | Cross-session agent memory | Global | ❌ No (personal) |
| `~/.claude/projects/<path>/memory/` | Project-scoped agent memory | Project | ❌ No (personal) |
| `/project/.claude/memory/` | Team-shared agent memory | Project | ✅ Yes (team memory) |

### File Hierarchy

```
~/.claude/
├── CLAUDE.md                      # Global personal instructions
├── settings.json                  # Global permissions, hooks, env
├── .claude.json → ~/.claude.json  # Symlink to main config
├── rules/                         # Auto-loaded (all projects)
│   ├── anti-hallucination.md
│   ├── authorization-levels.md
│   ├── mandatory-checks.md
│   ├── response-format.md
│   ├── role-routing.md
│   ├── gap-detection.md
│   ├── prompting-techniques.md
│   ├── subagent-orchestration.md
│   └── code-before-write.md
├── modules/                       # On-demand (loaded by routing)
│   ├── 00-architecture.md
│   ├── 01-compliance.md
│   ├── 02-security.md
│   ├── 03-devops.md
│   └── ...
├── skills/                        # Custom workflows
│   ├── commit.skill.md
│   ├── pr.skill.md
│   └── security-audit.skill.md
├── hooks/                         # Custom hooks
│   ├── unified_budget_hook.py
│   ├── unified_cost_hook.py
│   └── ...
├── evaluation/                    # Metrics & logs
│   ├── costs/
│   │   ├── agent_cost_tracker.py
│   │   └── budget_manager.py
│   ├── data/
│   │   ├── budget_spending.jsonl
│   │   ├── current_session_id
│   │   └── ...
│   └── logs/
│       ├── security_audit.log
│       └── ...
├── agent-memory/                  # User-scoped memory
│   └── security-analyst/
│       └── MEMORY.md
└── projects/                      # Project-scoped data
    └── -opt-your-project/
        └── memory/
            └── MEMORY.md

/project/
├── .claude/
│   ├── settings.local.json        # Project permissions (local)
│   └── memory/                    # Team memory (git-committed)
│       └── MEMORY.md
├── .mcp.json                      # Project MCP servers (git-committed)
├── CLAUDE.md                      # Project instructions (git-committed)
└── ...

~/.claude.json                     # Main config file
```

### Configuration Precedence

**MCP Servers:**
1. Project scope (`.mcp.json`) — **highest priority**
2. Local scope (`~/.claude.json` → `projects.<path>.mcpServers`)
3. User scope (`~/.claude.json` → `mcpServers`) — lowest priority

**Instructions (CLAUDE.md):**
1. Project-specific (`/project/CLAUDE.md`) — **highest priority**
2. Global (`~/.claude/CLAUDE.md`)
3. Core instructions (injected via wrapper)

**Permissions (settings.json):**
1. Project-specific (`/project/.claude/settings.local.json`) — **overrides global**
2. Global (`~/.claude/settings.json`)

**Hooks:**
- Global hooks + Project hooks are **combined** (not overridden)

### Team Sharing Strategy

| File | Share via Git? | Rationale |
|------|----------------|-----------|
| `.mcp.json` | ✅ Yes | Team needs same MCP servers |
| `CLAUDE.md` | ✅ Yes | Project-specific instructions |
| `.claude/memory/MEMORY.md` | ✅ Yes | Team memory (decisions, patterns) |
| `.claude/settings.local.json` | ❌ No | Personal preferences |
| `~/.claude/*` | ❌ No | User-specific config |

**Example `.gitignore`:**

```gitignore
# Claude Code — Personal config
.claude/settings.local.json

# Claude Code — Team config (DO commit)
# .mcp.json
# CLAUDE.md
# .claude/memory/
```

---

## Appendix: Quick Reference

### Essential Commands

```bash
# MCP management
claude mcp list                              # List active MCP servers
claude mcp add <name> --command "..."        # Add MCP server (local scope)
claude mcp remove <name>                     # Remove MCP server

# Profile switching (custom tool)
python ~/.claude/tools/mcp_profile_manager.py --switch security

# Metrics & reporting
python ~/.claude/evaluation/metrics_tracker.py --report all
python ~/.claude/evaluation/costs/agent_cost_tracker.py --report cache

# Hook testing
python ~/.claude/hooks/unified_budget_hook.py "Bash" '{"command": "ls"}'
```

### Key File Paths

```bash
# Main configuration
~/.claude.json                              # MCP servers, projects, prefs
~/.claude/settings.json                     # Permissions, hooks, env

# Instructions & rules
~/.claude/CLAUDE.md                         # Global instructions
~/.claude/rules/                            # Auto-loaded rules
~/.claude/modules/                          # On-demand modules

# Evaluation & data
~/.claude/evaluation/data/budget_spending.jsonl
~/.claude/evaluation/data/current_session_id
~/.claude/evaluation/logs/security_audit.log

# Agent memory
~/.claude/projects/-opt-your-project/memory/MEMORY.md
```

### Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| MCP server not loaded | Added to user scope instead of local | Use `claude mcp add` without `--scope user` |
| `claude mcp list` shows nothing | Servers in project scope (`.mcp.json`) | Check `.mcp.json` directly (known issue #5963) |
| Budget lockout | `CLAUDE_SESSION_ID` not propagated | Wrapper writes to file, hooks read from file |
| Hook doesn't block | Using exit codes instead of JSON | Print `{"decision": "block"}` on stdout |
| Context bloat (50K tokens) | All 39 MCP servers active | Switch to domain profile or enable lazy loading |
| Prompt cache misses | Inconsistent system prompt | Keep rules/ compact, use modules/ for reference |

---

**End of Document**

**Version:** 1.0.0
**Date:** 2026-02-09
**Maintainer:** Claude Code configuration project
**License:** Internal reference documentation

For questions or corrections, see `/opt/project/GAPS.md` or update this file directly.
