# Windows Porting Guide v2

Claude Code configuration porting from Linux (Kali) to Windows.

**Previous analysis**: `docs/WINDOWS_PORTING.md` (2026-03-17) — covers path mapping, shell commands, hook inventory.
**This document**: complete line-level audit, v9.0 hooks (added after v8.0), Go server source issues, compat module, PowerShell wrapper, priority order.
**Analysis date**: 2026-03-22
**Config version scanned**: v9.0.0

---

## 1. Complete File Audit — Files Needing Changes

### 1.1 Python hooks with fcntl usage

| File | Import line | flock call lines | Issue category |
|------|-------------|------------------|----------------|
| `hooks/hitl_approval_hook.py` | 14 | 106, 109, 113, 116 | fcntl.flock LOCK_EX/LOCK_UN (×4) |
| `hooks/pre_compact_hook.py` | 10 | 145, 147 | fcntl.flock LOCK_EX/LOCK_UN (×2) |
| `hooks/session_end_hook.py` | 19 | 165, 168, 223, 231, 241 | fcntl.flock LOCK_EX/LOCK_UN (×5) |
| `hooks/workflow_autoloader.py` | 686 (local import) | 691, 700 | fcntl.flock in lock-file guard (×2) |
| `evaluation/hooks/unified_tool_metrics_hook.py` | 15 | 53, 55 | fcntl.flock LOCK_EX/LOCK_UN (×2) |
| `evaluation/hooks/tool_failure_hook.py` | 13 | 46, 48 | fcntl.flock LOCK_EX/LOCK_UN (×2) |
| `evaluation/hooks/unified_budget_hook.py` | 22 | 106, 129 | fcntl.flock LOCK_EX/LOCK_UN (×2) |
| `statusline.sh` (inline Python heredoc) | line 12 (heredoc) | 100, 102 | fcntl in bash heredoc + bash wrapper |

**Total: 8 files, 20 fcntl.flock call sites.**

### 1.2 Python hooks with hardcoded /opt/ or /home/user/ paths

| File | Line | Hardcoded value | Fix |
|------|------|-----------------|-----|
| `hooks/session_end_hook.py` | 29 | `Path("/opt/agent_work_directory")` | `workspace_dir("agent_work_directory")` |
| `hooks/session_end_hook.py` | 40 | `["python3", ...]` | `[python_cmd(), ...]` |
| `hooks/session_end_hook.py` | 63 | `["python3", ...]` | `[python_cmd(), ...]` |
| `hooks/user_prompt_submit_hook.py` | 35 | `Path("/opt/agent_work_directory")` | `workspace_dir("agent_work_directory")` |
| `hooks/workflow_autoloader.py` | 65-72 | `"/opt/work/pentest/"` ... `"/opt/work/ml/"` (8 paths) | `str(workspace_dir("pentest")) + os.sep` etc. |
| `statusline.sh` | 283 | `display_proj.startswith("/opt/")` (strip prefix) | platform-aware strip |

**Note**: `hooks/scope_tracking_hook.py` line 16 was already fixed to use `Path.home() / ".claude" / ...`. No action needed there.

### 1.3 Go MCP servers with hardcoded Unix paths (source changes required before Windows build)

| File | Line(s) | Hardcoded value | Fix |
|------|---------|-----------------|-----|
| `mcp-servers/gc-mcp/cleanup.go` | 492, 494, 540 | `filepath.Glob("/tmp/claude-*")` (×2) | `filepath.Glob(filepath.Join(os.TempDir(), "claude-*"))` |
| `mcp-servers/tools-mcp/scope.go` | 23-33 | `/opt/work/pentest/` ... `/opt/templates/` (11 entries) | Build path map from `os.UserHomeDir() + "/claude-workspaces/..."` on Windows |
| `mcp-servers/tools-mcp/scope.go` | 49 | `fmt.Sprintf("/tmp/claude_scope_%s.json", sessionID)` | `filepath.Join(os.TempDir(), fmt.Sprintf("claude_scope_%s.json", sessionID))` |
| `mcp-servers/tools-mcp/shared.go` | 19 | `workDir = "/opt/agent_work_directory"` | `os.UserHomeDir() + "/claude-workspaces/agent_work_directory"` (Windows conditional) |
| `mcp-servers/doctor-mcp/checks.go` | 397 | `mcpFile = "/opt/project/.mcp.json"` | `filepath.Join(os.UserHomeDir(), "claude-workspaces", "your-project", ".mcp.json")` or env var |

**Note**: `profile-mcp/profiles.go` contains 15+ `/opt/` paths for security domain MCP servers (vulners, spiderfoot, PentestAgent, etc.). These are Kali-specific tools that **do not exist on Windows** — the entire security/pentest/dfir/network/reverse/osint MCP profiles should be marked as Linux-only in the profile registry. No source fix needed; document as out-of-scope for Windows.

### 1.4 settings.json hook command lines needing change

| Line | Current command | Windows issue | Fix |
|------|-----------------|---------------|-----|
| 562 | `~/.claude/hooks/session_start_reinforcement.py 2>/dev/null \|\| true` | `2>/dev/null`, `\|\| true` | See §3 |
| 567 | `~/.claude/hooks/session_startup_hook.py 2>/dev/null \|\| true` | same | See §3 |
| 572 | `~/.claude/hooks/session_startup_dashboard.py 2>/dev/null \|\| true` | same | See §3 |
| 577 | `~/.claude/hooks/session_health_check.py 2>/dev/null \|\| true` | same | See §3 |
| 582 | `~/.claude/mcp-servers/gc-mcp/gc-mcp --quick` | binary needs `.exe` suffix | `gc-mcp.exe --quick` |
| 593 | `~/.claude/hooks/session_end_hook.py 2>/dev/null \|\| true` | same | See §3 |
| 605 | `python3 ~/.claude/hooks/settings_backup_hook.py 2>/dev/null \|\| true` | `python3` → `python` | See §3 |
| 615 | `python3 ~/.claude/hooks/input_validation_hook.py ...` | `python3` → `python` | See §3 |
| 625 | `python3 ~/.claude/hooks/hitl_approval_hook.py ...` | `python3` → `python` + fcntl | See §3 |
| 635 | `python3 ~/.claude/hooks/gitleaks_precommit_hook.py ...` | `python3` → `python` | See §3 |
| 645 | `python3 ~/.claude/evaluation/hooks/unified_budget_hook.py ...` | `python3` → `python` + fcntl | See §3 |
| 657 | `python3 ~/.claude/evaluation/hooks/unified_tool_metrics_hook.py ...` | `python3` → `python` + fcntl | See §3 |
| 667 | `python3 ~/.claude/evaluation/hooks/unified_cost_hook.py ...` | `python3` → `python` | See §3 |
| 677 | `python3 ~/.claude/hooks/code_review_hook.py ...` | `python3` → `python` | See §3 |
| 687 | `python3 ~/.claude/hooks/filemap_update_hook.py ...` | `python3` → `python` | See §3 |
| 697 | `python3 ~/.claude/hooks/scope_tracking_hook.py ...` | `python3` → `python` | See §3 |
| 708 | `python3 ~/.claude/evaluation/hooks/tool_failure_hook.py ...` | `python3` → `python` + fcntl | See §3 |
| 719 | `~/.claude/hooks/user_prompt_submit_hook.py 2>/dev/null \|\| true` | shebang exec, /opt/ path | See §3 |
| 730 | `~/.claude/hooks/pre_compact_hook.py 2>/dev/null \|\| true` | shebang exec, fcntl | See §3 |
| 741 | `python3 ~/.claude/hooks/stop_check_hook.py ...` | `python3` → `python` | See §3 |
| 752 | `python3 ~/.claude/hooks/subagent_context_hook.py ...` | `python3` → `python` | See §3 |
| 763 | `python3 ~/.claude/hooks/task_quality_gate_hook.py ...` | `python3` → `python` | See §3 |
| 774 | `python3 ~/.claude/hooks/instructions_audit_hook.py ...` | `python3` → `python` | See §3 |
| 785 | `python3 ~/.claude/hooks/auto_permission_hook.py ...` | `python3` → `python` | See §3 |
| 796 | `python3 ~/.claude/hooks/post_compact_hook.py ...` | `python3` → `python` | See §3 |
| 805 | `bash ~/.claude/statusline.sh` | `bash` not available | See §3 |

### 1.5 settings.json permission paths needing change (Edit/Write)

Lines 16-31 and 32-47: all `/opt/*/` Edit/Write permissions → replace with `%USERPROFILE%\claude-workspaces\*\`.
Lines 48-49: `/home/user/.claude/**` → replace with the Windows-expanded equivalent.

---

## 2. fcntl Replacement Strategy

### 2.1 Recommended approach: compat.py context manager

The file `~/.claude/hooks/compat.py` (created alongside this document) provides the `file_lock()` context manager that handles both platforms transparently.

**Before (Linux-only):**
```python
import fcntl

with open(log_file, 'a') as f:
    fcntl.flock(f.fileno(), fcntl.LOCK_EX)
    f.write(line)
    fcntl.flock(f.fileno(), fcntl.LOCK_UN)
```

**After (cross-platform):**
```python
import sys
sys.path.insert(0, str(Path.home() / ".claude" / "hooks"))
from compat import file_lock

with file_lock(log_file) as f:
    f.write(line)
```

### 2.2 How compat.py file_lock works per OS

| OS | Mechanism | Semantics | Notes |
|----|-----------|-----------|-------|
| Linux/macOS | `fcntl.flock(LOCK_EX)` | Advisory whole-file lock | Cooperative, inherited by child processes |
| Windows | `msvcrt.locking(LK_NBLCK, 1)` on byte 0 | Mandatory byte-range lock on 1 byte | Retries up to `timeout` seconds, then fail-open |

Windows `msvcrt.locking` semantics differ from `flock`: it locks a byte range, not the whole file. For append-only log files (all current hook usage) this is functionally equivalent.

### 2.3 Per-file replacement plan

**hitl_approval_hook.py** (lines 106, 109, 113, 116):
```python
# Remove: import fcntl (line 14)
# Add at top:
import sys
sys.path.insert(0, str(Path.home() / ".claude" / "hooks"))
from compat import file_lock

# Replace open()+flock pattern with:
with file_lock(approval_log_path) as f:
    f.write(json.dumps(record) + "\n")
```

**pre_compact_hook.py** (lines 145, 147):
```python
# Remove: import fcntl (line 10)
# Add compat import
# Replace:
with file_lock(lock_file_path) as f:
    f.write(data)
```

**session_end_hook.py** (lines 165, 168, 223, 231, 241):
```python
# Remove: import fcntl (line 19)
# Add compat import
# Three separate flock blocks → three file_lock contexts
```

**workflow_autoloader.py** (lines 686-700 — local import inside function):
```python
# The try: import fcntl block at line 686 is inside a function.
# Replace the entire try/except block with:
from compat import file_lock
with file_lock(lock_path) as lf:
    lf.write("locked\n")
# Remove the separate unlock call
```

**evaluation/hooks/unified_tool_metrics_hook.py** (lines 53, 55):
```python
# Remove: import fcntl (line 15)
# Single flock pair → one file_lock context
```

**evaluation/hooks/tool_failure_hook.py** (lines 46, 48):
```python
# Remove: import fcntl (line 13)
# Single flock pair → one file_lock context
```

**evaluation/hooks/unified_budget_hook.py** (lines 106, 129):
```python
# Remove: import fcntl (line 22)
# Note: lines 106 and 129 are lock/unlock for the SAME file object (lf).
# Pattern: lf opened externally, flock called separately.
# Replace with file_lock context wrapping the entire critical section.
```

---

## 3. settings.json Changes for Windows

### 3.1 Hook command patterns

Three patterns in current settings.json need changing on Windows:

**Pattern A — shebang-executed scripts (no explicit python):**
```json
// Current (Linux — relies on #!/usr/bin/env python3 shebang):
"command": "~/.claude/hooks/session_startup_hook.py 2>/dev/null || true"

// Windows equivalent:
"command": "python %USERPROFILE%\\.claude\\hooks\\session_startup_hook.py 2>NUL"
```

**Pattern B — explicit python3:**
```json
// Current:
"command": "python3 ~/.claude/hooks/settings_backup_hook.py 2>/dev/null || true"

// Windows:
"command": "python %USERPROFILE%\\.claude\\hooks\\settings_backup_hook.py 2>NUL"
```

**Pattern C — Go binary (no extension):**
```json
// Current:
"command": "~/.claude/mcp-servers/gc-mcp/gc-mcp --quick"

// Windows:
"command": "%USERPROFILE%\\.claude\\mcp-servers\\gc-mcp\\gc-mcp.exe --quick"
```

**Pattern D — statusline (bash script):**
```json
// Current:
"command": "bash ~/.claude/statusline.sh"

// Windows:
"command": "python %USERPROFILE%\\.claude\\hooks\\statusline.py"
// (requires statusline.sh → statusline.py rewrite; see §5)
```

### 3.2 Null redirect and error suppression

| Linux | Windows cmd | Windows PowerShell |
|-------|-------------|-------------------|
| `2>/dev/null` | `2>NUL` | `2>$null` |
| `\|\| true` | (omit — cmd ignores non-zero by default) | (omit or `; $true`) |
| `2>/dev/null \|\| true` | `2>NUL` | `2>$null` |

Claude Code on Windows executes hook commands via `cmd.exe`. Use `2>NUL`.

### 3.3 Path separator in settings.json

Claude Code on Windows: `~` is NOT expanded in hook command strings by Claude Code itself — the command string is passed to `cmd.exe`, which does not expand `~`. Use either:
- `%USERPROFILE%` (expanded by cmd.exe)
- Full absolute path: `C:\Users\Alice\.claude\...`

For the `permissions.allow` paths (Edit/Write), Claude Code's permission resolver on Windows uses forward slashes internally. Use forward slashes or test both:
```json
"Edit(/home/user/.claude/**)"   // Linux
"Edit(C:/Users/Alice/.claude/**)"  // Windows — absolute path required
```

### 3.4 python3 → python mapping

All 17 occurrences of `python3` in settings.json hook commands change to `python`.

If both Python 2 and Python 3 are present (rare on modern Windows), use `py -3` (Windows Python Launcher) instead:
```json
"command": "py -3 %USERPROFILE%\\.claude\\hooks\\settings_backup_hook.py 2>NUL"
```

---

## 4. Go MCP Server Cross-Compilation

### 4.1 Source fixes required BEFORE building for Windows

**gc-mcp/cleanup.go** — fix both /tmp hardcodes:
```go
// Lines 494 and 540 — replace:
matches, _ := filepath.Glob("/tmp/claude-*")

// With:
matches, _ := filepath.Glob(filepath.Join(os.TempDir(), "claude-*"))
```

**tools-mcp/scope.go** — fix path map (lines 23-33) and temp path (line 49):
```go
// Lines 23-33: replace static map with runtime-built map
import "os/user"

func buildWorkspacePaths() map[string]string {
    home, _ := os.UserHomeDir()
    if runtime.GOOS == "windows" {
        ws := filepath.Join(home, "claude-workspaces")
        return map[string]string{
            filepath.Join(ws, "pentest")   + string(filepath.Separator): "security",
            filepath.Join(ws, "osint")     + string(filepath.Separator): "osint",
            filepath.Join(ws, "devops")    + string(filepath.Separator): "devops",
            filepath.Join(ws, "reverse")   + string(filepath.Separator): "reverse_engineering",
            filepath.Join(ws, "dfir")      + string(filepath.Separator): "dfir",
            filepath.Join(ws, "compliance")+ string(filepath.Separator): "compliance",
            filepath.Join(ws, "business")  + string(filepath.Separator): "business_analysis",
            filepath.Join(ws, "ml")        + string(filepath.Separator): "orchestration",
        }
    }
    return map[string]string{
        "/opt/work/pentest/":    "security",
        "/opt/work/osint/":      "osint",
        "/opt/work/devops/":     "devops",
        "/opt/work/reverse/":    "reverse_engineering",
        "/opt/work/dfir/":       "dfir",
        "/opt/work/compliance/": "compliance",
        "/opt/work/business/":   "business_analysis",
        "/opt/work/ml/":         "orchestration",
        "/opt/go/":         "engineering",
        "/opt/cargo/":      "engineering",
        "/opt/templates/":  "engineering",
    }
}

// Line 49 — replace:
return fmt.Sprintf("/tmp/claude_scope_%s.json", sessionID)
// With:
return filepath.Join(os.TempDir(), fmt.Sprintf("claude_scope_%s.json", sessionID))
```

**tools-mcp/shared.go** — fix workDir (line 19):
```go
// Replace:
workDir = "/opt/agent_work_directory"

// With:
func initWorkDir() string {
    if runtime.GOOS == "windows" {
        home, _ := os.UserHomeDir()
        return filepath.Join(home, "claude-workspaces", "agent_work_directory")
    }
    return "/opt/agent_work_directory"
}
var workDir = initWorkDir()
```

**doctor-mcp/checks.go** — fix mcpFile (line 397):
```go
// Replace:
mcpFile = "/opt/project/.mcp.json"

// With:
if runtime.GOOS == "windows" {
    home, _ := os.UserHomeDir()
    mcpFile = filepath.Join(home, "claude-workspaces", "your-project", ".mcp.json")
} else {
    mcpFile = "/opt/project/.mcp.json"
}
```

**profile-mcp/profiles.go** — do NOT fix the `/opt/` paths. These are Kali-specific tool installations (vulners-mcp, PentestAgent, Volatility, etc.) that have no Windows equivalent. The security/pentest/dfir profiles should be excluded from Windows profile loading entirely. Mark them with a `PlatformLinuxOnly: true` flag or guard the profile definitions with a runtime OS check.

### 4.2 Cross-compile commands (from Linux build host)

```bash
export GOOS=windows GOARCH=amd64

# Fix source files first (see 4.1), then:

cd ~/.claude/mcp-servers

# backlog-mcp (no source changes needed)
(cd backlog-mcp && go build -ldflags="-s -w" -o backlog-mcp.exe .)

# doctor-mcp (fix checks.go:397 first)
(cd doctor-mcp && go build -ldflags="-s -w" -o doctor-mcp.exe .)

# gc-mcp (fix cleanup.go:494,540 first)
(cd gc-mcp && go build -ldflags="-s -w" -o gc-mcp.exe .)

# profile-mcp (no changes to essential binary needed; Linux-only profiles compile fine)
(cd profile-mcp && go build -ldflags="-s -w" -o profile-mcp.exe .)

# score-mcp (no source changes needed)
(cd score-mcp && go build -ldflags="-s -w" -o score-mcp.exe .)

# tools-mcp (fix scope.go and shared.go first)
(cd tools-mcp && go build -ldflags="-s -w" -o tools-mcp.exe .)
```

Build on Windows natively (PowerShell):
```powershell
$env:GOOS = "windows"
$env:GOARCH = "amd64"

$servers = @("backlog-mcp","doctor-mcp","gc-mcp","profile-mcp","score-mcp","tools-mcp")
foreach ($srv in $servers) {
    Push-Location "$env:USERPROFILE\.claude\mcp-servers\$srv"
    go build -ldflags="-s -w" -o "$srv.exe" .
    Pop-Location
}
```

Place binaries in: `%USERPROFILE%\.claude\mcp-servers\<name>\<name>.exe`

### 4.3 MCP server registration in ~/.claude.json

```json
{
  "projects": {
    "*": {
      "mcpServers": {
        "backlog-mcp": {
          "command": "C:\\Users\\<USERNAME>\\.claude\\mcp-servers\\backlog-mcp\\backlog-mcp.exe",
          "args": [],
          "env": {}
        },
        "tools-mcp": {
          "command": "C:\\Users\\<USERNAME>\\.claude\\mcp-servers\\tools-mcp\\tools-mcp.exe",
          "args": [],
          "env": {}
        },
        "gc-mcp": {
          "command": "C:\\Users\\<USERNAME>\\.claude\\mcp-servers\\gc-mcp\\gc-mcp.exe",
          "args": [],
          "env": {}
        }
      }
    }
  }
}
```

`%USERPROFILE%` is NOT expanded in `.claude.json` by Claude Code — use full absolute path or PowerShell to generate the file:

```powershell
$base = "$env:USERPROFILE\.claude\mcp-servers"
# Then substitute paths programmatically
```

---

## 5. PowerShell Wrapper for bash wrapper

The current architecture uses `--append-system-prompt-file CORE_INSTRUCTIONS.md` as a bash wrapper flag. On Windows the `claude` binary is invoked directly from PowerShell or cmd — no bash wrapper exists.

### 5.1 Current bash wrapper pattern (Linux)
```bash
#!/usr/bin/env bash
exec claude \
  --append-system-prompt-file ~/.claude/CORE_INSTRUCTIONS.md \
  "$@"
```

### 5.2 PowerShell equivalent

Save as `%USERPROFILE%\.claude\claude-wrapper.ps1`:
```powershell
#!/usr/bin/env pwsh
# claude-wrapper.ps1 — Windows equivalent of bash claude wrapper
# Usage: claude-wrapper.ps1 [claude-args...]

$CoreInstructions = Join-Path $env:USERPROFILE ".claude\CORE_INSTRUCTIONS.md"

if (-not (Test-Path $CoreInstructions)) {
    Write-Error "CORE_INSTRUCTIONS.md not found at $CoreInstructions"
    exit 1
}

& claude --append-system-prompt-file $CoreInstructions @args
```

Register as a PowerShell alias or add to PATH. In PowerShell profile (`$PROFILE`):
```powershell
function claude-code {
    $CoreFile = "$env:USERPROFILE\.claude\CORE_INSTRUCTIONS.md"
    & claude --append-system-prompt-file $CoreFile @args
}
Set-Alias -Name cc -Value claude-code
```

### 5.3 statusline.sh → statusline.py rewrite

`statusline.sh` is a bash heredoc that embeds Python with fcntl. Full rewrite to pure Python:

Key changes needed:
- Remove bash wrapper (`#!/usr/bin/env bash`, heredoc `python3 - <<'PYEOF'`)
- Remove `import fcntl` (line 12 of heredoc); replace lock with `compat.file_lock`
- Line 283: `display_proj.startswith("/opt/")` — replace with:
  ```python
  from compat import workspace_dir, IS_WINDOWS
  _WS_PREFIX = str(Path.home() / "claude-workspaces") + os.sep if IS_WINDOWS else "/opt/"
  if display_proj.startswith(_WS_PREFIX):
      display_proj = display_proj[len(_WS_PREFIX):]
  ```
- Register in settings-windows.json: `"command": "python %USERPROFILE%\\.claude\\statusline.py"`

---

## 6. Path Conversion Strategy Summary

### 6.1 Python: use compat.py

```python
# Add to each hook that uses hardcoded paths:
import sys
from pathlib import Path
sys.path.insert(0, str(Path.home() / ".claude" / "hooks"))
from compat import workspace_dir, python_cmd, tmp_dir, mcp_binary

# /opt/agent_work_directory  →
WORK_DIR = workspace_dir("agent_work_directory")

# /opt/work/pentest/, /opt/work/osint/, ...  →
WORKSPACE_PATHS = {
    str(workspace_dir("pentest")) + os.sep: "security",
    str(workspace_dir("osint"))   + os.sep: "osint",
    # ...
}

# python3 subprocess calls  →
subprocess.run([python_cmd(), script_path], ...)

# /tmp/claude_*  →
tmp_file = tmp_dir("claude_scope_abc.json")
```

### 6.2 Go: use os.TempDir() and runtime.GOOS

```go
// /tmp/  →  os.TempDir()
filepath.Join(os.TempDir(), "claude-*")

// /opt/<name>/  →  runtime check
if runtime.GOOS == "windows" {
    home, _ := os.UserHomeDir()
    base = filepath.Join(home, "claude-workspaces", name)
} else {
    base = filepath.Join("/opt", name)
}
```

### 6.3 settings.json permissions

No automated mapping possible — create a separate `settings-windows.json`:
- Replace all `Edit(/opt/**)`  → `Edit(C:/Users/<USER>/claude-workspaces/**)` (or omit)
- Replace `Edit(/home/user/.claude/**)` → `Edit(C:/Users/<USER>/.claude/**)`
- Replace `Bash(python3:*)` — keep; also add `Bash(python:*)`, `Bash(py:*)` (already present at line 200-201)
- Remove all Linux-only Bash permissions (see WINDOWS_PORTING.md §5)

---

## 7. Priority Porting Order

### P0 — Blockers (hooks crash on Windows without these)

| # | Task | File | Line(s) | Effort |
|---|------|------|---------|--------|
| 1 | Replace fcntl with compat.file_lock | `hooks/hitl_approval_hook.py` | 14, 106-116 | 15 min |
| 2 | Replace fcntl with compat.file_lock | `hooks/pre_compact_hook.py` | 10, 145-147 | 10 min |
| 3 | Replace fcntl + fix /opt/ path | `hooks/session_end_hook.py` | 19, 29, 40, 63, 165-241 | 30 min |
| 4 | Replace fcntl with compat.file_lock | `hooks/workflow_autoloader.py` | 686-700 | 15 min |
| 5 | Fix /opt/ path map in workflow_autoloader | `hooks/workflow_autoloader.py` | 65-72 | 20 min |
| 6 | Fix /opt/ path | `hooks/user_prompt_submit_hook.py` | 35 | 5 min |
| 7 | Replace fcntl with compat.file_lock | `evaluation/hooks/unified_tool_metrics_hook.py` | 15, 53-55 | 10 min |
| 8 | Replace fcntl with compat.file_lock | `evaluation/hooks/tool_failure_hook.py` | 13, 46-48 | 10 min |
| 9 | Replace fcntl with compat.file_lock | `evaluation/hooks/unified_budget_hook.py` | 22, 106-129 | 15 min |
| 10 | Fix gc-mcp /tmp (×2) | `mcp-servers/gc-mcp/cleanup.go` | 494, 540 | 10 min |
| 11 | Fix tools-mcp /tmp + /opt/ paths | `mcp-servers/tools-mcp/scope.go`, `shared.go` | 23-49, 19 | 30 min |
| 12 | Fix doctor-mcp /opt/project | `mcp-servers/doctor-mcp/checks.go` | 397 | 5 min |
| 13 | Cross-compile all 6 Go binaries (.exe) | all mcp-servers | — | 20 min |

### P1 — Required for full function (session broken without these)

| # | Task | File | Effort |
|---|------|------|--------|
| 14 | Create settings-windows.json (python3→python, paths, remove Linux perms) | new file | 1 h |
| 15 | Create PowerShell wrapper claude-wrapper.ps1 | new file | 30 min |
| 16 | Rewrite statusline.sh → statusline.py | new file | 2 h |
| 17 | install portalocker (fallback if compat.py not used) | — | 5 min |

### P2 — Quality of life

| # | Task | Effort |
|---|------|--------|
| 18 | setup_windows.ps1 installer script (dirs, copy files, pip install) | 1 h |
| 19 | Mark Linux-only profiles in profile-mcp with PlatformLinuxOnly guard | 45 min |
| 20 | Add CI job: go vet + go build GOOS=windows for all MCP servers | 30 min |

### P3 — Optional / low priority

| # | Task | Effort |
|---|------|--------|
| 21 | Convert evaluation/.sh scripts to Python (systemd_setup.sh, run.sh) | 2 h |
| 22 | Windows-native notifications in session_startup_dashboard.py | 1 h |

---

## 8. New Hooks in v9.0 — Windows Compatibility Status

Hooks added after v8.0 (not in WINDOWS_PORTING.md):

| Hook | Status | Notes |
|------|--------|-------|
| `stop_check_hook.py` | Compatible | No fcntl, no hardcoded paths |
| `subagent_context_hook.py` | Compatible | No fcntl, no hardcoded paths |
| `task_quality_gate_hook.py` | Compatible | No fcntl, no hardcoded paths |
| `instructions_audit_hook.py` | Compatible | No fcntl, no hardcoded paths |
| `auto_permission_hook.py` | Compatible | No fcntl, no hardcoded paths |
| `post_compact_hook.py` | Compatible | No fcntl, no hardcoded paths |
| `pretool_diag.py` | Compatible | No fcntl, no hardcoded paths |

All 7 new v9.0 hooks are Windows-compatible as-is. Only the `python3` → `python` rename in settings.json commands is needed.

---

## 9. Verification Checklist

After completing porting:

```powershell
# 1. Verify compat.py self-test
python $env:USERPROFILE\.claude\hooks\compat.py

# 2. Test each ported hook manually
python $env:USERPROFILE\.claude\hooks\hitl_approval_hook.py
python $env:USERPROFILE\.claude\evaluation\hooks\unified_budget_hook.py

# 3. Verify Go binaries run
& $env:USERPROFILE\.claude\mcp-servers\tools-mcp\tools-mcp.exe --version
& $env:USERPROFILE\.claude\mcp-servers\gc-mcp\gc-mcp.exe --quick

# 4. Check no fcntl imports remain in active hooks
Select-String -Path $env:USERPROFILE\.claude\hooks\*.py -Pattern "import fcntl"
Select-String -Path $env:USERPROFILE\.claude\evaluation\hooks\*.py -Pattern "import fcntl"

# 5. Check no /home/user hardcodes remain
Select-String -Path $env:USERPROFILE\.claude\hooks\*.py -Pattern "/home/user|/opt/"
```

---

## 10. Differences from WINDOWS_PORTING.md v1

| Area | v1 (2026-03-17) | v2 (2026-03-22) |
|------|-----------------|-----------------|
| Hook inventory | 21 hooks analyzed | +7 new v9.0 hooks (all compatible) |
| fcntl sites | 20 listed | 20 confirmed with exact line numbers |
| Go server issues | gc-mcp /tmp only | gc-mcp + tools-mcp scope/shared + doctor-mcp |
| compat.py | Proposed as Strategy B/C | Created at `~/.claude/hooks/compat.py` |
| settings.json lines | Pattern description | Exact line numbers for all 26 affected commands |
| scope_tracking_hook | Listed as needing fix | Already fixed (Path.home() used) — no action needed |
| profile-mcp /opt/ paths | Not analyzed | Identified as Linux-only profiles — exclude from Windows |
| PowerShell wrapper | Mentioned | Full implementation provided |
