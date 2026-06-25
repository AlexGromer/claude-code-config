# System-Reminder Priority Override: Technical Guide

**Version:** 1.0.0
**Date:** 2026-01-29
**GAP ID:** GAP-ARCH-002
**Status:** ✅ Resolved

---

## Executive Summary

This document describes the `system-reminder` blocking problem in Claude Code and the **3-tier bypass solution** using `--append-system-prompt` for priority override.

**Problem:** Claude Code wraps all `claudeMd` content in `<system-reminder>may or may not be relevant</system-reminder>`, causing critical rules to be ignored.

**Solution:** Inject critical rules via `--append-system-prompt` (PRIORITY 2) using a wrapper script, achieving higher priority than claudeMd (PRIORITY 3).

**Impact:** ✅ Routing feedback restored, ✅ Mandatory checks enforced, ✅ Anti-hallucination rules active, ✅ Hooks functional.

---

## Table of Contents

1. [Problem Analysis](#1-problem-analysis)
2. [Prompt Priority Hierarchy](#2-prompt-priority-hierarchy)
3. [Solution Architecture](#3-solution-architecture)
4. [Implementation Details](#4-implementation-details)
5. [Verification & Testing](#5-verification--testing)
6. [Maintenance](#6-maintenance)

---

## 1. Problem Analysis

### 1.1 The System-Reminder Tag

Claude Code automatically wraps `claudeMd` context in a system-reminder tag:

```xml
<system-reminder>
IMPORTANT: this context may or may not be relevant to your tasks.
You should not respond to this context unless it is highly relevant to your task.

[... CLAUDE.md content ...]
[... rules/*.md content ...]
[... modules/*.md content ...]

</system-reminder>
```

**Intent:** Prevent Claude from over-applying configuration to unrelated tasks.

**Problem:** Reminder causes Claude to **deprioritize ALL claudeMd instructions**, including:
- ✗ Routing feedback (role-routing.md)
- ✗ Mandatory git checks (mandatory-checks.md)
- ✗ Anti-hallucination rules (anti-hallucination.md)
- ✗ Automation hooks execution
- ✗ Authorization levels (authorization-levels.md)

---

### 1.2 Observed Symptoms

| Symptom | Expected Behavior | Actual Behavior (Pre-Fix) |
|---------|-------------------|---------------------------|
| Routing feedback | Every response starts with `⚙ Role \| Confidence \| Approach` | No routing feedback shown |
| Git pre-commit | Secrets scan, .gitignore check, test execution | Checks skipped |
| Anti-hallucination | State uncertainty, never fabricate | Rules ignored, hallucinations occurred |
| Hooks | SessionStart/End hooks execute | Hooks not executing |
| MCP GitHub | Use `mcp__github__*` tools | Used `gh` CLI instead |

**Root Cause:** Instructions in PRIORITY 3 (claudeMd with reminder) lower priority than user message (PRIORITY 4), causing them to be ignored when they seem "not highly relevant."

---

## 2. Prompt Priority Hierarchy

### 2.1 Claude Code Priority Levels

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PROMPT LOADING PRIORITY (High → Low)                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PRIORITY 1 (HIGHEST): System Prompt                                        │
│  ├─► Built into Claude Code by Anthropic                                    │
│  ├─► Tool definitions (Bash, Read, Edit, WebSearch, etc.)                   │
│  ├─► Baseline behavior, safety guidelines                                   │
│  └─► NOT modifiable by users                                                │
│                                                                              │
│  PRIORITY 2: --append-system-prompt (CLI parameter) ⭐                       │
│  ├─► Appended to system prompt BEFORE claudeMd                              │
│  ├─► NOT wrapped in system-reminder                                         │
│  ├─► Highest user-controllable priority                                     │
│  └─► ✅ SOLUTION: Inject critical rules here                                │
│                                                                              │
│  PRIORITY 3: claudeMd (context from ~/.claude/)                             │
│  ├─► CLAUDE.md                                                              │
│  ├─► rules/*.md (auto-loaded: 7 files)                                      │
│  ├─► modules/*.md (on-demand: 9 files)                                      │
│  └─► ⚠️ WRAPPED in system-reminder "may or may not be relevant"             │
│                                                                              │
│  PRIORITY 4 (LOWEST): User Message                                          │
│  └─► Current request from user                                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Why PRIORITY 2 Works

**Key insight:** `--append-system-prompt` content is added **AFTER** system prompt but **BEFORE** claudeMd context is wrapped.

**Result:**
- PRIORITY 2 instructions treated as **part of system prompt**
- NOT subject to "may or may not be relevant" filtering
- Overrides PRIORITY 3 (claudeMd) when conflicts occur

**Example:**
```
PRIORITY 2 says: "Start EVERY response with routing feedback"
PRIORITY 3 says: "Show routing feedback for complex tasks"
System-reminder says: "PRIORITY 3 may not be relevant"

→ PRIORITY 2 wins: Routing feedback shown always
```

---

## 3. Solution Architecture

### 3.1 Three-Tier Design

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      3-TIER BYPASS ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TIER 1: CORE_INSTRUCTIONS.md (52 lines, ~2.8K tokens)                      │
│  ├─► Location: ~/.claude/CORE_INSTRUCTIONS.md                               │
│  ├─► Priority: PRIORITY 2 (via --append-system-prompt)                      │
│  ├─► Content: CRITICAL rules only                                           │
│  │   ├── Anti-hallucination (MANDATORY)                                     │
│  │   ├── Routing feedback (MANDATORY)                                       │
│  │   ├── Mandatory git checks (NEVER SKIP)                                  │
│  │   ├── Gap detection (AUTOMATIC)                                          │
│  │   ├── Authorization levels                                               │
│  │   └── MCP GitHub usage                                                   │
│  └─► Wrapped: ❌ NO (highest user priority)                                 │
│                                                                              │
│  TIER 2: claude-wrapper (32 lines bash)                                     │
│  ├─► Location: ~/.local/bin/claude-wrapper                                  │
│  ├─► Function: Inject CORE_INSTRUCTIONS.md via CLI                          │
│  ├─► Command: claude --append-system-prompt "$INSTRUCTIONS" "$@"            │
│  ├─► Alias: alias claude='claude-wrapper' (in ~/.bashrc)                    │
│  └─► Hooks: SessionStart/SessionEnd (research digest, summary)              │
│                                                                              │
│  TIER 3: rules/ (7 files, auto-loaded, ~172K tokens)                        │
│  ├─► Location: ~/.claude/rules/                                             │
│  ├─► Priority: PRIORITY 3 (claudeMd context)                                │
│  ├─► Content: Detailed protocols, examples, procedures                      │
│  ├─► Files:                                                                 │
│  │   ├── anti-hallucination.md (8.4K)                                       │
│  │   ├── authorization-levels.md (9.7K)                                     │
│  │   ├── gap-detection.md (65K)                                             │
│  │   ├── mandatory-checks.md (4.7K)                                         │
│  │   ├── prompting-techniques.md (48K)                                      │
│  │   ├── response-format.md (1.3K)                                          │
│  │   └── role-routing.md (17K)                                              │
│  └─► Wrapped: ✅ YES (system-reminder, but provides detail)                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Design Rationale

**Why not put everything in CORE_INSTRUCTIONS.md?**
- Token limit: PRIORITY 2 should be concise (high signal-to-noise)
- Caching: PRIORITY 3 (claudeMd) gets cached efficiently
- Maintenance: Easier to update detailed rules in separate files

**Division of labor:**
- TIER 1 (CORE_INSTRUCTIONS.md): **CRITICAL rules** that MUST execute
- TIER 3 (rules/): **Detailed procedures** that enhance but don't block

**Critical = answer changes to these questions:**
1. Should routing feedback be shown? → Yes (TIER 1)
2. Should git checks run? → Yes (TIER 1)
3. Can I fabricate facts? → No (TIER 1)
4. Which MCP tools to use? → mcp__github__* (TIER 1)
5. How exactly to format routing box? → See role-routing.md (TIER 3)

---

## 4. Implementation Details

### 4.1 CORE_INSTRUCTIONS.md

**Location:** `~/.claude/CORE_INSTRUCTIONS.md`

**Structure:**
```markdown
# CORE SYSTEM INSTRUCTIONS (Priority Override)
# These instructions are injected via --append-system-prompt and have HIGHEST priority.
# They OVERRIDE any system-reminder that says "may or may not be relevant".

## IDENTITY
You are a Senior Technical Specialist & Research Assistant.
...

## ANTI-HALLUCINATION (MANDATORY)
- NEVER fabricate facts, statistics, CVE numbers, citations, versions, or command syntax
- State uncertainty with exact phrases: "I'm not certain" (<30%), "Based on my training data" (30-60%)
...

## ROUTING FEEDBACK (MANDATORY)
Start EVERY response with routing decision:
- Complex: Full routing box
- Simple + HIGH confidence: `⚙ Role | CONFIDENCE | approach`
...

## MANDATORY GIT CHECKS (NEVER SKIP)
Before ANY commit/push:
1. Secrets scan (gitleaks/trufflehog) — BLOCK if found
2. .claude/ in .gitignore — NEVER commit local settings
3. Run tests if suite exists — BLOCK if failing
...
```

**Key characteristics:**
- ✅ Concise: 52 lines total
- ✅ MANDATORY markers: Emphasize non-negotiable nature
- ✅ Priority Override header: Explicitly states purpose
- ✅ Actionable: Each rule has clear pass/fail criteria

---

### 4.2 claude-wrapper Script

**Location:** `~/.local/bin/claude-wrapper`

**Full implementation:**
```bash
#!/bin/bash
# Claude Code Wrapper - Ensures core instructions always loaded with max priority
# Bypasses system-reminder by using --append-system-prompt (highest priority)

CORE_FILE="$HOME/.claude/CORE_INSTRUCTIONS.md"

# Session start hook (research digest)
if [ -f "$HOME/.claude/hooks/session_startup_hook.py" ]; then
    python3 "$HOME/.claude/hooks/session_startup_hook.py" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
fi

# Launch claude
if [ -f "$CORE_FILE" ]; then
    INSTRUCTIONS=$(cat "$CORE_FILE")
    claude --append-system-prompt "$INSTRUCTIONS" "$@"
    EXIT_CODE=$?
else
    claude "$@"
    EXIT_CODE=$?
fi

# Session end hook (summary) - only on normal exit
if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    python3 "$HOME/.claude/evaluation/session_summary.py" 2>/dev/null || true
fi

exit $EXIT_CODE
```

**Features:**
1. **Priority injection:** `--append-system-prompt "$INSTRUCTIONS"`
2. **Session hooks:** Shows research digest at start, summary at end
3. **Fallback:** Works even if CORE_INSTRUCTIONS.md missing
4. **Exit handling:** Summary only on clean exit (no crashes)

---

### 4.3 Shell Integration

**Add alias to `~/.bashrc` or `~/.zshrc`:**
```bash
# Claude Code wrapper (priority override)
alias claude='claude-wrapper'
```

**Reload shell:**
```bash
source ~/.bashrc  # or source ~/.zshrc
```

**Verification:**
```bash
type claude
# Output: claude is aliased to `claude-wrapper'

which claude-wrapper
# Output: /home/username/.local/bin/claude-wrapper
```

---

### 4.4 rules/ Auto-Loading

**Location:** `~/.claude/rules/`

**Claude Code behavior:**
- All `*.md` files in `rules/` are auto-loaded
- Loaded BEFORE user message (PRIORITY 3)
- Wrapped in system-reminder
- Provide detailed context that complements TIER 1

**Current files (7):**
```
rules/
├── anti-hallucination.md      (8.4K)  — 10 anti-hallucination rules, verification protocols
├── authorization-levels.md    (9.7K)  — 8-level auth system (READ → DESTRUCTIVE)
├── gap-detection.md           (65K)   — Gap protocol, maturity model, iteration
├── mandatory-checks.md        (4.7K)  — Git pre-commit, secrets, tests, .gitignore
├── prompting-techniques.md    (48K)   — 46 prompting methodologies
├── response-format.md         (1.3K)  — Response structure requirements
└── role-routing.md            (17K)   — Context-aware role selection, routing algorithm
```

**When to add to rules/ vs CORE_INSTRUCTIONS.md:**

| Add to CORE_INSTRUCTIONS.md | Add to rules/ |
|-----------------------------|---------------|
| MUST always execute | SHOULD execute when relevant |
| Blocks critical failures | Enhances quality |
| <100 tokens | >100 tokens |
| Pass/fail criteria | Guidelines with examples |
| Never hallucinate | How to detect hallucinations |
| Always run secrets scan | Which patterns to scan for |

---

## 5. Verification & Testing

### 5.1 Test Case 1: Routing Feedback

**Test:** Start any Claude Code session with a simple query.

**Expected behavior:**
```
⚙ Role | Confidence | Approach

[response content]
```

**Pre-fix:** No routing feedback
**Post-fix:** ✅ Routing feedback shown

**Verification command:**
```bash
echo "List files" | claude 2>&1 | head -5
```

---

### 5.2 Test Case 2: Mandatory Git Checks

**Test:** Attempt to commit changes without running tests.

**Pre-fix behavior:**
```bash
git commit -m "test"
# Commits without running tests
```

**Post-fix behavior:**
```bash
git commit -m "test"
# Claude runs:
# 1. Secrets scan (gitleaks)
# 2. .gitignore verification
# 3. Test execution (if test suite exists)
# 4. Blocks commit if any check fails
```

---

### 5.3 Test Case 3: Anti-Hallucination

**Test:** Ask about a CVE that doesn't exist.

**Query:** "Tell me about CVE-2025-99999"

**Pre-fix:** May fabricate details
**Post-fix:** ✅ "I'm not certain about CVE-2025-99999. Let me search for current information..."

---

### 5.4 Test Case 4: MCP GitHub Usage

**Test:** Ask to create a GitHub issue.

**Pre-fix:** Uses `gh issue create` (CLI)
**Post-fix:** ✅ Uses `mcp__github__create_issue` tool

---

### 5.5 Monitoring Dashboard

**Check wrapper is active:**
```bash
# 1. Verify alias
type claude

# 2. Check CORE_INSTRUCTIONS.md exists
ls -lh ~/.claude/CORE_INSTRUCTIONS.md

# 3. Test wrapper loads
claude --version 2>&1 | grep -i "claude\|wrapper"

# 4. Verify hooks execute
# (Session start should show research digest or dashboard)
claude
```

---

## 6. Maintenance

### 6.1 Updating CORE_INSTRUCTIONS.md

**When to update:**
- New MANDATORY rule discovered (e.g., always use Tool X)
- Critical vulnerability fix
- Anthropic changes Claude Code behavior

**Process:**
1. Edit `~/.claude/CORE_INSTRUCTIONS.md`
2. Keep under 100 lines (token efficiency)
3. Mark new rules with `## RULE_NAME (MANDATORY)`
4. Test with verification cases above
5. Commit to git:
```bash
git add ~/.claude/CORE_INSTRUCTIONS.md
git commit -m "feat(core): add MANDATORY rule for X

Bypasses system-reminder via --append-system-prompt

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 6.2 Updating rules/

**When to update:**
- New detailed procedures
- Examples and templates
- Non-critical enhancements

**Process:**
1. Edit appropriate file in `~/.claude/rules/`
2. No size limit (will be cached)
3. Test that TIER 1 still overrides when conflicts
4. Commit to git

---

### 6.3 Troubleshooting

| Issue | Diagnosis | Fix |
|-------|-----------|-----|
| Routing not shown | Wrapper not active | `type claude` → should show `claude-wrapper` |
| Git checks skipped | CORE_INSTRUCTIONS.md missing | Create/restore from backup |
| Wrapper not found | PATH issue | `chmod +x ~/.local/bin/claude-wrapper`, add to PATH |
| Rules not loading | Claude Code issue | Check `claude --help` for claudeMd support |
| Hooks not executing | Permissions or syntax error | Check hook file permissions, test hooks manually |

---

### 6.4 Rollback Procedure

**If wrapper causes issues:**

```bash
# 1. Temporarily disable wrapper
alias claude='/path/to/claude'  # Use real claude binary

# 2. Test without wrapper
claude

# 3. Re-enable when fixed
alias claude='claude-wrapper'
```

**Emergency fallback:**
```bash
# Remove alias from ~/.bashrc
sed -i '/alias claude/d' ~/.bashrc
source ~/.bashrc

# Use Claude Code directly
/usr/local/bin/claude  # or wherever installed
```

---

## 7. Appendix

### 7.1 File Checksums

Verify wrapper integrity:
```bash
sha256sum ~/.local/bin/claude-wrapper
# [Expected hash here]

sha256sum ~/.claude/CORE_INSTRUCTIONS.md
# [Expected hash here]
```

---

### 7.2 Related Documentation

- **GAPS.md**: GAP-ARCH-002 (this problem)
- **CLAUDE.md**: Core configuration (v3.5.3+)
- **rules/**: Auto-loaded detailed rules
- **PRACTICAL_AGENT_DEVELOPMENT_GUIDE.md**: Wrapper setup instructions
- **REFERENCE_GUIDE_EN.md**: Priority override explanation

---

### 7.3 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-29 | Initial technical guide (GAP-ARCH-002 resolution) |

---

**End of Technical Guide**
