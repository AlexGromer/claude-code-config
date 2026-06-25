# Session Continuity Protocol
# Version: 1.0.0 | Updated: 2026-02-25

## Save Triggers

1. **PreCompact**: context >80% → automatic (pre_compact_hook.py)
2. **SessionEnd**: always → automatic (session_end_hook.py)
3. **Session health**: REOPEN RECOMMENDED → user-triggered
4. **MCP rotation**: before restart → mandatory

## Record Format (7 fields)

```json
{
  "session_id": "abc123",
  "task_description": "what we were doing",
  "files_modified": ["CLAUDE.md", "settings.json"],
  "progress": "Phase 1 complete, Phase 2 in progress",
  "next_steps": "Continue with Task 2.3",
  "git_state": {"branch": "main", "last_commit": "126f291", "uncommitted": true},
  "plan_file": "~/.claude/plans/binary-napping-pearl.md"
}
```

## Storage

- **Primary**: `~/.claude/evaluation/data/session_continuity.jsonl` (append, fcntl locked)
- **Backup**: `memory/MEMORY.md` → "In-Progress" section (quick access on start)

## Restore

- SessionStart hook reads last record from `session_continuity.jsonl`
- Injects: "Previous session worked on: {task}. Progress: {progress}. Next: {next_steps}."
- If plan_file exists → "Active plan: {plan_file}. Resume execution."

## Rules

- NEVER store working data in continuity record (only references/paths)
- File locking mandatory (fcntl.flock) for all writes
- Records expire after 7 days (don't inject stale context)
- On session break: save BEFORE exit
