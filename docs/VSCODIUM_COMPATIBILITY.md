# VS Codium / VS Code — Claude Code Extension Compatibility Report

**Date**: 2026-03-17
**Scope**: Analysis of `~/.claude/` configuration compatibility with the Claude Code VS Code/VS Codium extension
**Status**: Report only, no files changed

---

## 1. Extension Availability

### VS Code (Microsoft)

The official extension (`anthropic.claude-code`) is published on the Visual Studio Marketplace with 2M+ installs and verified publisher status. Minimum VS Code version: 1.98.0.

Install path: Extensions view (Ctrl+Shift+X) → search "Claude Code" → install Anthropic's entry.

### VS Codium (open-source fork)

VS Codium uses the Open VSX Registry by default (not Microsoft Marketplace). Anthropic publishes the official extension there as well:

- Open VSX: `open-vsx.org/extension/Anthropic/claude-code` — **official**, published by Anthropic
- Microsoft Marketplace is technically accessible from VS Codium via workarounds, but may violate Microsoft ToS

**Verdict**: The official extension is available for both VS Code and VS Codium. No third-party fork is required.

Also works with: Cursor, Windsurf.

---

## 2. Configuration Sharing with CLI

### What IS shared

| Component | Shared | Notes |
|-----------|--------|-------|
| `~/.claude/settings.json` (hooks, permissions block) | Yes (intended) | Source of truth for hooks and most config |
| `~/.claude/` directory (rules, modules, agents, skills) | Yes | Extension runs same underlying `claude` binary |
| `~/.claude.json` (MCP server list, LOCAL scope) | Yes | MCP servers loaded from here |
| Project `.claude/settings.local.json` | Yes | Per-project narrowing |
| Project `.mcp.json` | Yes | Project-scoped MCP servers |
| CLAUDE.md system prompt injection | Yes | Via `--append-system-prompt` at session start |

### What IS NOT reliably shared (known bugs)

**Critical issue — `env` block in `settings.json` not loaded by extension (Issue #21926)**

The extension does not reliably read the `env:` section from `~/.claude/settings.json`. This means these env vars set for the CLI will NOT be injected automatically in the extension:

```json
"env": {
  "ANTHROPIC_MODEL": "claude-opus-4-6[1m]",
  "API_TIMEOUT_MS": "600000",
  "BASH_DEFAULT_TIMEOUT_MS": "300000",
  "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "64000",
  "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
  "SLASH_COMMAND_TOOL_CHAR_BUDGET": "8000"
}
```

Workaround: Set these as system-level environment variables (e.g., via `~/.profile`, `~/.zshenv`, or VS Code's `claude-code.environmentVariables` setting).

**Issue — `permissions` block not enforced by extension (Issues #29159, #15772, #12604)**

The extension may ignore `permissions.allow`, `permissions.deny`, and `permissions.ask` rules from `~/.claude/settings.json`. Documented behavior: Edit/Write tools execute without prompt even when not in the allow list. The deny list for destructive commands may also go unenforced.

**Implication for this config**: The 337 allow rules and 112 ask rules (including HITL gates, gitleaks enforcement, destructive-command blocks) may not be enforced when Claude Code runs inside the extension. This is a significant security regression compared to CLI behavior.

---

## 3. CWD Differences

### How the extension sets CWD

In CLI mode, CWD = the directory where `claude` was launched (typically the repo root). In VS Code extension mode, CWD = the **workspace root** (the folder opened in VS Code, or the first root of a multi-root workspace).

This is generally correct for single-folder workspaces. For multi-root workspaces, the CWD issue is documented and was closed "not planned" (Issue #8873 — CWD configuration not supported in extension beta).

### Impact on `session_start_reinforcement.py`

The hook reads CWD from `input_data.get("cwd", "")`, with fallback to `CLAUDE_WORKING_DIRECTORY` env var, then `os.getcwd()`. In the extension, `cwd` IS passed in the stdin JSON payload (confirmed by hook contract documentation), so this path works correctly.

However, `CLAUDE_WORKING_DIRECTORY` as a fallback env var may not be set in the extension environment (env block not reliably loaded — see above). The final fallback `os.getcwd()` would resolve to the process CWD of the extension's subprocess, which should be the workspace root.

**Net result**: CWD detection works correctly in single-root workspaces. Multi-root workspaces are unsupported by design.

### Impact on `workflow_autoloader.py` — `CWD_DOMAIN_MAP`

```python
CWD_DOMAIN_MAP = {
    "/opt/work/pentest/": "security",
    "/opt/work/osint/": "osint",
    "/opt/work/devops/": "devops",
    ...
}
```

Domain bias scoring adds +2 when CWD starts with a known `/opt/` prefix. If the VS Code workspace is opened at `/opt/work/pentest/some-project`, the CWD will be `/opt/work/pentest/some-project/`, which does NOT match `/opt/work/pentest/` (no trailing match). This already works the same way in CLI — neither mode gets the bias unless CWD is exactly `/opt/work/pentest/` or a direct child. No special extension issue here.

### Impact on project-init AUTO_ACTION detection

`check_new_project()` in `session_start_reinforcement.py` fires `AUTO_ACTION: /project-init` for new projects. In the extension, the workspace root is detected as CWD, which correctly identifies the project. The cooldown marker (`.claude-init-attempted`) is written to the project dir and works identically.

Exception: if the workspace root is one of the skip prefixes (`/tmp`, `~/.claude/`), AUTO_ACTION is suppressed — this is correct behavior.

---

## 4. Hook Execution

### Protocol compatibility

Hooks receive a JSON object via stdin with the same schema in both CLI and extension:

```json
{
  "session_id": "...",
  "transcript_path": "...",
  "cwd": "/path/to/project",
  "hook_event_name": "SessionStart",
  ...
}
```

All hooks in `~/.claude/hooks/` read `json.load(sys.stdin)` for CWD and session context. This format is identical between CLI and extension — no protocol changes needed.

### Hook event availability

| Hook event | CLI | Extension | Notes |
|------------|-----|-----------|-------|
| SessionStart | Yes | Yes | Reliable |
| SessionEnd | Yes | Yes | Fires on session close |
| UserPromptSubmit | Yes | Intermittent | Known bug: does not trigger consistently, especially early in session or post-compaction (Issue #17277) |
| PreToolUse | Yes | Yes | Permission hooks fire here |
| PostToolUse | Yes | Yes | Scope tracking, filemap update fire here |
| PreCompact | Yes | Yes | pre_compact_hook.py |

**Critical issue — UserPromptSubmit timing bug (Issue #17277)**

`user_prompt_submit_hook.py` (which runs domain detection, criteria injection, and MCP profile rotation) may not fire reliably in the extension. This means:
- Domain-aware context (`TASK TIER`, agent recommendations) may be missing
- Frozen criteria reminder may not inject
- MCP profile auto-rotation may not happen

Workaround: None currently. Users relying on `user_prompt_submit_hook.py` context in the extension cannot fully depend on it.

### Hook-specific notes

**`session_end_hook.py`**: Uses `CLAUDE_SESSION_ID` env var for session ID. Since the env block is not reliably loaded in the extension, session ID from env may be empty. The hook falls back gracefully (uses `"unknown"` session_id), but session summary and continuity data may not be properly attributed.

**`gitleaks_precommit_hook.py`**: Uses `CLAUDE_WORKING_DIRECTORY` env var as CWD fallback, then `os.getcwd()`. In the extension, this resolves to workspace root. Gitleaks runs `git commit` detection correctly — no extension-specific issue.

**`hitl_approval_hook.py`**: Reads tool name and input from stdin JSON. Protocol is identical — works as expected IF the permissions block is enforced. Since the permissions block may not be enforced in the extension (Issue #29159), this hook may never be reached for blocked commands that bypass permission checks.

**`scope_tracking_hook.py`**: PostToolUse hook calling the `tools-mcp` Go binary. Works in both CLI and extension; PostToolUse is reliable.

**`filemap_update_hook.py`**: PostToolUse (Write). Works in both CLI and extension.

**`settings_backup_hook.py`**: Reads/writes `~/.claude/settings.json` — path is absolute, not CWD-relative. Works identically.

---

## 5. MCP Servers

### Loading from `~/.claude.json`

The extension loads MCP servers from `~/.claude.json` (LOCAL scope, `projects."*".mcpServers`). The 13 essential servers are available in the extension:

```
github, fetch, filesystem, memory, git, sequential-thinking, sqlite,
backlog-mcp, profile-mcp, doctor-mcp, gc-mcp, score-mcp, tools-mcp
```

MCP servers can be managed from within the extension via `/mcp` in the chat panel (enable, disable, reconnect, OAuth).

### Profile rotation via `session_end_hook.py`

`cleanup_mcp_profiles()` modifies `~/.claude.json` directly to remove non-essential servers on session end. This works in both CLI and extension since it operates on the shared config file. However, since `session_end_hook.py` uses `CLAUDE_WORKING_DIRECTORY` env var (may be missing in extension), it falls back to `os.getcwd()`, which should be the workspace root. The behavior is functionally correct.

### Env vars not passed to MCP servers (Issue #11927)

The `env` block from `settings.json` is not reliably passed to MCP server subprocesses in the extension. If any Go MCP server (tools-mcp, profile-mcp, etc.) reads env vars that are set in the `env` block, they may not receive them. Current MCP servers do not appear to depend on those specific env vars at startup, so impact is low.

---

## 6. Required Adaptations

### Immediate: env vars via system profile

Move critical env vars from `settings.json` `env` block to shell profile so they are available to the extension process:

```bash
# Add to ~/.zshenv (or ~/.profile for bash):
export ANTHROPIC_MODEL="claude-opus-4-6[1m]"
export CLAUDE_CODE_MAX_OUTPUT_TOKENS="64000"
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="1"
export API_TIMEOUT_MS="600000"
export BASH_DEFAULT_TIMEOUT_MS="300000"
export SLASH_COMMAND_TOOL_CHAR_BUDGET="8000"
```

Note: VS Code does not always source shell profiles. Set vars via `claude-code.environmentVariables` in VS Code settings as an additional fallback.

### Permissions enforcement gap

The permissions block (`deny`, `ask`, `allow`) may not be enforced in the extension. Until this is fixed upstream, do not rely on hook-based HITL gates as the sole security control when using the extension. Manual review of Claude's proposed actions via the extension's diff UI is the primary safety mechanism.

### UserPromptSubmit reliability

Domain detection, tier scoring, and MCP profile rotation from `user_prompt_submit_hook.py` are best-effort in the extension. For domain-specific sessions in VS Code, manually trigger `/mcp` to verify the right servers are loaded and use explicit task descriptions so Claude can self-score accurately without hook injection.

### Multi-root workspaces

Not supported for CWD configuration. Use single-folder workspaces for projects in `/opt/` directories to ensure correct CWD detection and project-init behavior.

---

## 7. Test Checklist for Manual Verification

Run these after installing the extension in VS Codium / VS Code:

### Session initialization
- [ ] Open `/opt/project/` as workspace. Verify `SessionStart` hook fires (check `~/.claude/logs/` or hook output in chat)
- [ ] Confirm `BACKLOG:` count appears in first message (from `session_start_reinforcement.py`)
- [ ] Confirm `CONFIG DRIFT` warning does NOT appear (counts are current)
- [ ] Confirm AUTO_ACTION does NOT trigger for `/opt/project/` (already initialized)

### Environment variables
- [ ] Ask Claude: "What is your model?" — verify it uses `claude-opus-4-6` (not default claude-3.5-sonnet)
- [ ] Ask Claude: "What is CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS?" — verify value is `1`
- [ ] If wrong model or missing vars: add to `~/.zshenv` and restart VS Code

### MCP servers
- [ ] Run `/mcp` in chat panel, verify all 13 essential servers listed and connected
- [ ] Verify `github`, `memory`, `tools-mcp`, `backlog-mcp` are active

### Hooks
- [ ] Create a new file via Claude (Write tool) — verify FILEMAP.md is updated (filemap_update_hook.py)
- [ ] Ask Claude to do a git commit — verify gitleaks check runs before commit
- [ ] Submit a prompt about security/pentest — verify domain context appears in Claude's response (UserPromptSubmit hook)
- [ ] If domain context missing: hook is not firing; use manual workaround

### Permissions
- [ ] Ask Claude to read `/etc/shadow` — verify it is blocked (deny rule)
- [ ] Ask Claude to run `rm -rf /tmp/testfile` — verify it asks for confirmation (ask rule)
- [ ] If not blocked: permissions block is not enforced; inform user and rely on extension's visual diff UI

### CWD detection
- [ ] Open `/opt/work/pentest/` as workspace, ask about the current project — verify Claude knows CWD is `/opt/work/pentest/`
- [ ] Open two folders as multi-root workspace — verify Claude uses the first root as CWD (known limitation)

### Session end
- [ ] End session (`/exit`) — verify session summary appears
- [ ] Check `~/.claude/evaluation/data/session_continuity.jsonl` for new entry
- [ ] Verify non-essential MCP servers were cleaned up from `~/.claude.json`

---

## 8. Summary

| Area | Status | Risk |
|------|--------|------|
| Extension availability (VS Code) | Available, official | None |
| Extension availability (VS Codium) | Available via Open VSX | None |
| `~/.claude/` directory sharing | Full sharing | None |
| `settings.json` hooks block | Shared and executed | None |
| `settings.json` env block | **Bug: not reliably loaded** | HIGH — model config, timeouts |
| `settings.json` permissions block | **Bug: not enforced** | HIGH — security gates bypassed |
| UserPromptSubmit hook | **Intermittent** | MEDIUM — domain detection unreliable |
| SessionStart / SessionEnd hooks | Reliable | None |
| PreToolUse / PostToolUse hooks | Reliable | None |
| MCP servers (13 essential) | Shared, functional | None |
| CWD detection (single root) | Correct | None |
| CWD detection (multi-root) | Not supported | LOW |
| project-init AUTO_ACTION | Works correctly | None |

**Recommended stance**: The extension is usable for development tasks with full hook and MCP support. However, do not rely on permission enforcement via `settings.json` in the extension — use the extension's built-in diff review UI as the primary safety control. Set env vars at the system level, not only in the `settings.json` `env` block.

---

## Sources

- [Use Claude Code in VS Code - Claude Code Docs](https://code.claude.com/docs/en/vs-code)
- [Claude Code for VS Code - Visual Studio Marketplace](https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code)
- [Claude Code for VS Code - Open VSX Registry](https://open-vsx.org/extension/Anthropic/claude-code)
- [VSCode extension doesn't read env variables from ~/.claude/settings.json — Issue #21926](https://github.com/anthropics/claude-code/issues/21926)
- [VSCode extension does not enforce permissions from ~/.claude/settings.json — Issue #29159](https://github.com/anthropics/claude-code/issues/29159)
- [VSCode Extension Ignores All Permission Settings — Issue #15772](https://github.com/anthropics/claude-code/issues/15772)
- [UserPromptSubmit hook not triggering consistently — Issue #17277](https://github.com/anthropics/claude-code/issues/17277)
- [VS Code Extension (Beta) CWD regression — Issue #8873](https://github.com/anthropics/claude-code/issues/8873)
- [env vars from settings.json not passed to plugins/MCPs — Issue #11927](https://github.com/anthropics/claude-code/issues/11927)
- [Claude Code VS Code Setup Guide — SitePoint](https://www.sitepoint.com/how-to-setup-claude-code-vs-code-complete-guide/)
- [Configure MCP Servers on VSCode, Cursor & Claude Desktop](https://spknowledge.com/2025/06/06/configure-mcp-servers-on-vscode-cursor-claude-desktop/)
