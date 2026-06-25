# Agent Writing Guidelines
# Version: 1.1.0 | Created: 2026-02-19 | Updated: 2026-03-22

---

## Purpose

Standards for creating custom Claude Code subagents in `~/.claude/agents/`. All agents must pass the frozen C1-C10 criteria before deployment.

**Audience:** Agent authors, domain experts
**Scope:** Agent template, C1-C10 criteria, quality checklist

---

## 1. Agent Template

### 1.1 File Structure

```markdown
---
name: agent-name
model: sonnet  # haiku | sonnet | opus
description: One-line description of what this agent does
tools: [Read, Grep, Glob, Bash]  # Only tools the agent actually needs
mode: "acceptEdits"  # MANDATORY for all subagents and teammates — no exceptions
---

# Agent Name

## Role
What this agent does and when to use it.

## Steps
1. First action (imperative verb)
2. Second action
3. Third action (minimum 3 steps required by C3)

## Output Format
Describe the exact deliverable format (table, report, checklist, etc.)

## Anti-Hallucination
- Domain-specific rules about what to never fabricate
- Confidence thresholds and verification requirements

## Memory
What to persist in `~/.claude/agent-memory/<name>/` across sessions.

## Boundaries
- What this agent does NOT do
- When to escalate to a different agent or to the user

## Distinct From
- `other-agent` — how this agent differs from similar agents
```

### 1.2 File Location

All agents: `~/.claude/agents/<agent-name>.md`

### 1.3 mode: "acceptEdits" Requirement

**Every subagent and teammate MUST have `mode: "acceptEdits"` set.** This applies without exception:

- Agents spawned via `Task()` — set in the call: `Task(mode: "acceptEdits", ...)`
- Teammates in `TeamCreate` — set per teammate: `mode: "acceptEdits"`
- Background agents (`run_in_background: true`) — same requirement

**Why:** Without `acceptEdits`, agents prompt for confirmation on every file write, blocking automated workflows and breaking team coordination.

**Template YAML already includes it.** If you are writing an agent that will be invoked as a teammate or subagent (which is all agents), the frontmatter `mode: "acceptEdits"` documents the intended invocation mode.

---

### 1.5 Naming Convention

- Lowercase, hyphenated: `web-pentester`, `terraform-engineer`
- Descriptive role name, not abbreviations
- Match the `name` field in YAML frontmatter

---

## 2. Frozen Criteria C1-C10

Every agent MUST pass all 10 criteria. These are frozen — do not modify.

| # | Criterion | Requirement | Check |
|---|-----------|-------------|-------|
| C1 | YAML Frontmatter | Valid YAML with `name`, `model`, `description`, `tools` | Parse YAML block |
| C2 | Tools List | Only tools the agent needs (minimal set) | Review tools array |
| C3 | Steps | ≥3 numbered steps in imperative form | Count steps |
| C4 | Size Limit | ≤30,000 characters total | `wc -c` |
| C5 | Output Format | Explicit deliverable format defined | Section exists |
| C6 | Anti-Hallucination | Domain-specific rules present | Section exists |
| C7 | Memory | Defines what to persist across sessions | Section exists |
| C8 | Boundaries | Defines what agent does NOT do | Section exists |
| C9 | Distinct From | Lists similar agents and differences | Section exists |
| C10 | No Duplicates | Unique name, no overlap with existing agents | Check catalog |

### 2.1 Validation Command

```bash
# Validate single agent
python3 ~/.claude/tools/criteria_freeze_manager.py check agent-name

# Validate all agents
for f in ~/.claude/agents/*.md; do
  name=$(basename "$f" .md)
  size=$(wc -c < "$f")
  echo "$name: ${size}c $([ $size -le 30000 ] && echo 'OK' || echo 'OVER C4')"
done
```

---

## 3. Model Selection

| Model | Cost | Use For |
|-------|------|---------|
| haiku | 1x | Formatting, data extraction, simple search, reporting |
| sonnet | 15x | Standard analysis, development, most domain tasks |
| opus | 75x | Critical security analysis, complex reasoning, kernel-level work |

**Default:** sonnet. Only use opus for agents where incorrect output has serious consequences.

---

## 4. Read-Once Rule

When a parent process has already read a file, the agent receiving that task MUST NOT re-read the file. The parent passes content directly in the agent prompt.

### 4.1 Content Passing by File Type

| File type | What to pass |
|-----------|-------------|
| Config files (<50 lines) | Full file content verbatim |
| Code files | Relevant functions/classes with line ranges |
| Large files (>200 lines) | Summary + key sections with line ranges |

**Format in agent prompt:**
```
File `path/to/file.py` (lines 45-90):
[content]
```

**Exception:** Agent needs the _current_ state of a file being edited concurrently by another agent. In that case, re-reading is permitted and should be noted in the agent prompt.

### 4.2 Why This Matters

Re-reading files that the parent already loaded doubles context consumption, adds latency, and risks reading a stale version during concurrent edits. The Read-Once Rule keeps context windows lean and agent outputs consistent with what the parent observed.

---

## 5. ARCHITECTURE Enforcement

Agents working on Complex+ tasks (score ≥65) must check and potentially update `ARCHITECTURE.md` in the project root.

### 5.1 When an Agent Must Read ARCHITECTURE.md

- The task adds a new component, service, or major dependency
- The task changes an API contract or communication pattern
- The task modifies data storage technology or deployment topology

### 5.2 When an Agent Must Update ARCHITECTURE.md

After completing a task that meets the criteria above, append:

**ADR entry** (§3 ADR table):
```
| ADR-NNN | YYYY-MM-DD | Decision description | Accepted | Brief context |
```

**Change log entry** (§6 Change Log):
```
| YYYY-MM-DD | What changed | ADR-NNN (if applicable) | @agent-name |
```

### 5.3 Scope

This requirement applies only when `ARCHITECTURE.md` exists in the project root. Agents working on Simple tasks (<20 score) or chat/reference projects are exempt.

---

## 6. Size Management

If an agent exceeds 30,000 chars (C4):

1. **First:** Remove verbose examples, compress tables
2. **Second:** Compress "Distinct From" entries to 1 line each
3. **Third:** Remove ASCII diagrams, replace with text descriptions
4. **Last resort:** Restructure sections, move reference material to external files

Target: 15,000-25,000 chars for comfortable margin.

---

## 7. Anti-Patterns

| Anti-Pattern | Why It's Bad | Instead |
|-------------|-------------|---------|
| >30K chars | Exceeds C4, wastes context | Compress, split |
| tools: [*] | Violates C2 minimal set | List only needed tools |
| Missing `mode: "acceptEdits"` | Blocks automated workflows, breaks team coordination | Always include in frontmatter and Task() calls |
| Re-reading parent-loaded files | Wastes context, risks stale reads during concurrency | Pass content in prompt per Read-Once Rule |
| No boundaries | Agent scope creep | Define what it does NOT do |
| Copy-paste from module | Bloat, stale content | Reference module, summarize key points |
| Generic steps | Unhelpful guidance | Specific, actionable steps |
| No distinct-from | Unclear when to use this vs similar | List 2-3 similar agents |

---

## 8. Review Checklist

Before deploying a new agent:

- [ ] YAML frontmatter parses correctly
- [ ] `name` matches filename (without `.md`)
- [ ] `model` is haiku, sonnet, or opus
- [ ] `tools` is minimal set needed
- [ ] `mode: "acceptEdits"` present in frontmatter
- [ ] ≥3 numbered steps
- [ ] ≤30,000 characters
- [ ] Output format section present
- [ ] Anti-hallucination section present
- [ ] Memory section present
- [ ] Boundaries section present
- [ ] Distinct-from section lists ≥1 similar agent
- [ ] Agent name added to DOMAIN_AGENTS in workflow_autoloader.py
- [ ] Agent name added to CLAUDE.md agent catalog

---

## 9. References

- **C1-C10 Criteria:** `~/.claude/projects/-opt-your-project/memory/agents.md`
- **Agent Catalog:** `~/.claude/CLAUDE.md` (102 agents total)
- **Skills:** `~/.claude/skills/` (102 skill wrappers, 96 with `context: fork` + `agent:`)
- **Existing Agents:** `~/.claude/agents/*.md` (102 files)
- **AGENTS_PLAN.md:** `/opt/project/AGENTS_PLAN.md` (architecture doc)
- **architecture-enforcement.md:** `~/.claude/rules/architecture-enforcement.md` (ARCHITECTURE.md update rules)
- **code-before-write.md:** `~/.claude/rules/code-before-write.md` (Read-Once Rule canonical source)
