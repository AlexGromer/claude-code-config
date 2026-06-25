# ADR-007 PoC — PPID-keyed criteria isolation

## Problem

`tools-mcp` (Go) and `user_prompt_submit_hook.py` (Python) both resolve the "current session" by reading a single global file:

```
~/.claude/evaluation/data/current_session_id     # one UUID for the whole machine
```

When two Claude Code sessions run concurrently:

1. Session A starts, writes its UUID into `current_session_id`.
2. Session B starts later, OVERWRITES `current_session_id` with its own UUID.
3. Both sessions' MCP calls and hook checks now resolve the same path:
   `/opt/agent_work_directory/<B-UUID>/scratchpad/frozen_criteria.json`.
4. Session A sees Session B's frozen criteria — and vice versa.

Reproducible at:
- `~/.claude/mcp-servers/tools-mcp/shared.go:17` — file location
- `~/.claude/mcp-servers/tools-mcp/shared.go:30` — read order in `resolveSessionID`
- `~/.claude/hooks/user_prompt_submit_hook.py:42` — same file in hook
- `~/.claude/hooks/user_prompt_submit_hook.py:184` — same read in `check_frozen_criteria`

## Solution: PPID + starttime as the session key

| Caller | `os.Getppid()` returns | Why correct |
|---|---|---|
| tools-mcp (stdio child of Claude) | Claude Code PID | spawned by Claude |
| UserPromptSubmit hook (child of Claude) | Claude Code PID | spawned by Claude |
| Task() subagent | same Claude Code PID | runs in same Claude process |
| TeamCreate teammate | same Claude Code PID | runs in same Claude process |
| Second Claude Code window | DIFFERENT PID | OS-level isolation |

Storage layout:
```
/opt/agent_work_directory/claude-<PPID>-<STARTTIME>/frozen_criteria.json
```

`STARTTIME` = field 22 of `/proc/<PPID>/stat` (process start time in clock ticks since boot). Two processes with the same PID at different boots — or after PID-rollover within one boot — get different start times, so the path is unique even on PID reuse.

No global file. No env-var dependency. No SessionStart hook coordination required.

## Files in this PoC

| File | Purpose |
|---|---|
| `ppid_isolator.go` | Standalone Go binary demonstrating the resolve scheme |
| `demo.sh` | Bash test driver: 3 scenarios, prints PASS/FAIL behavior |
| `patches/shared.go.diff` | Illustrative diff for `tools-mcp/shared.go` |
| `patches/criteria.go.diff` | Illustrative diff for `tools-mcp/criteria.go` |
| `patches/user_prompt_submit_hook.py.diff` | Illustrative diff for the Python hook |

## Run the PoC

```bash
cd /opt/project/poc/adr-007-ppid-isolation
./demo.sh
```

## Expected output (annotated, from real run)

```
========================================================================
TEST 1: two SEPARATE bash shells freeze independently — must NOT leak
========================================================================
FROZEN ppid=2512982 goal="Session A — analyze logs" path=/tmp/poc-adr-007/claude-2512982-4263776/frozen.json

Now a fresh bash (different PPID) does check — it should see NOT FROZEN:
NOT FROZEN (looked at /tmp/poc-adr-007/claude-2512989-4263777/frozen.json)
                                          ^^^^^^^ different PPID (2512989 vs 2512982)
                                                  ^^^^^^^ different starttime

Storage layout:
drwxr-xr-x  claude-2512982-4263776/   (only Session A — Session B's check did not write)

========================================================================
TEST 2: same bash freeze + check — must SEE the same data
========================================================================
FROZEN ppid=2512996 goal="Session B — review PR" ...
[same shell] check after freeze:
FROZEN ppid=2512996 goal="Session B — review PR"
        ^^^^^^^ same PPID → same path → data seen ✓

========================================================================
TEST 3: PPID+starttime path uniqueness
========================================================================
/tmp/poc-adr-007/claude-2513009-4263778/frozen.json
/tmp/poc-adr-007/claude-2513049-4263879/frozen.json
                ^^^^^^^         ^^^^^^^   different on every spawn
```

Test 1 PASSES if the second `check` reports `NOT FROZEN`.
Test 2 PASSES if both invocations show the same `ppid=` and `goal=`.
Test 3 PASSES if both paths differ.

### Bash quirk worth documenting

`bash -c '<single-command>'` will `exec`-replace the bash subshell with the command, so the command's PPID becomes whatever called `bash` (here: `demo.sh`), not the bash itself. This breaks the simulation — both "sessions" end up children of the same `demo.sh`.

Workaround in `demo.sh`: append `; :` after the target. Now the target isn't the last command, so bash forks normally, and the target's PPID is the bash subshell (unique per `bash -c` invocation).

In **production** this is irrelevant: `tools-mcp` is a long-running stdio child of Claude Code, spawned once per Claude session. It's never invoked via `bash -c`. The PPID seen by every `criteria_*` call is always the same — Claude Code's PID — for the lifetime of that MCP server.

## Production wiring (per `patches/`)

### `shared.go` — replace `resolveSessionID` with `resolveClaudePID`

```go
// before
func resolveSessionID(request mcp.CallToolRequest) string {
    if v := optStr(request, "session_id"); v != "" && isValidSessionID(v) { return v }
    if data, err := os.ReadFile(sessionIDFile); err == nil {
        id := strings.TrimSpace(string(data))
        if isValidSessionID(id) { return id }
    }
    if id := strings.TrimSpace(os.Getenv("CLAUDE_SESSION_ID")); isValidSessionID(id) { return id }
    return "unknown"
}

// after
func resolveClaudeKey() string {
    ppid := os.Getppid()
    return fmt.Sprintf("claude-%d-%s", ppid, readStartTime(ppid))
}

func readStartTime(pid int) string { /* read /proc/<pid>/stat field 22 */ }
```

### `criteria.go` — switch path constructor

```go
// before
func freezeFilePath(sessionID string) string {
    return filepath.Join(workDir, sessionID, "scratchpad", "frozen_criteria.json")
}

// after
func freezeFilePath(key string) string {
    return filepath.Join(workDir, key, "frozen_criteria.json")
}
```

All callers `resolveSessionID(request)` → `resolveClaudeKey()`.

### `user_prompt_submit_hook.py` — same key derivation in Python

```python
# before
SESSION_ID_FILE = Path.home() / ".claude" / "evaluation" / "data" / "current_session_id"
session_id = SESSION_ID_FILE.read_text().strip()
freeze_file = WORK_DIR / session_id / "scratchpad" / "frozen_criteria.json"

# after
def claude_key():
    ppid = os.getppid()
    with open(f"/proc/{ppid}/stat") as f:
        stat = f.read()
    fields = stat[stat.rindex(")") + 2:].split()
    starttime = fields[19] if len(fields) > 19 else "0"
    return f"claude-{ppid}-{starttime}"

freeze_file = WORK_DIR / claude_key() / "frozen_criteria.json"
```

### Cleanup of stale sessions

Add to `session_startup_hook.py`:

```python
import os, re, time
from pathlib import Path

WORK_DIR = Path("/opt/agent_work_directory")
PATTERN = re.compile(r"^claude-(\d+)-(\d+)$")

def cleanup_stale():
    for d in WORK_DIR.iterdir():
        m = PATTERN.match(d.name)
        if not m: continue
        pid = int(m.group(1))
        if not Path(f"/proc/{pid}").exists():
            # process gone — remove entire session dir
            shutil.rmtree(d, ignore_errors=True)
            continue
        # process exists — verify starttime matches (defeats PID reuse)
        try:
            with open(f"/proc/{pid}/stat") as f:
                stat = f.read()
            fields = stat[stat.rindex(")") + 2:].split()
            if fields[19] != m.group(2):
                shutil.rmtree(d, ignore_errors=True)
        except Exception:
            shutil.rmtree(d, ignore_errors=True)
```

### Migration order

1. Land patches behind feature flag `TOOLS_MCP_PPID_KEY=1` (env). When unset, fall back to legacy `current_session_id`.
2. Update hook same way (PPID branch when `TOOLS_MCP_PPID_KEY=1`).
3. Run for one week, confirm no regressions.
4. Remove legacy code path.
5. Delete `~/.claude/evaluation/data/current_session_id` and any writers.

## Known limitations

- Linux-only (`/proc/<pid>/stat`). For macOS/Windows portability use `gopsutil` (`process.Process.CreateTime()`).
- If MCP server is launched via systemd-run or under a wrapping reaper (e.g., `tini` PID 1 inside container), `Getppid()` returns the wrapper PID — still unique per session, but no longer "Claude Code PID". Behavior preserved (key is unique), only the audit interpretation changes.
- Subprocesses spawned by tools-mcp itself (e.g., a Bash tool call) would have a different PPID, but those are not making criteria_* calls — only the MCP server process does.

## Related

- `ARCHITECTURE.md` ADR-007
- `~/.claude/mcp-servers/tools-mcp/shared.go`
- `~/.claude/mcp-servers/tools-mcp/criteria.go`
- `~/.claude/hooks/user_prompt_submit_hook.py`
