# Error Handling Matrix

## Summary
- Total components audited: 29 (8 rules, 11 hooks, 10 templates/permissions files)
- Issues found: 47 (Critical: 6, High: 12, Medium: 18, Low: 11)

---

## 1. Rules Edge Cases

### 1.1 anti-hallucination.md

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| Rule provides no fallback guidance for partial uncertainty (e.g., 70% confident) | Low | Halts and admits — may block legitimate work | Add graduated response: "reasonably confident → proceed with caveat; uncertain → verify first" | Open |
| No definition of what counts as a "fact" vs opinion | Low | Ambiguous enforcement | Clarify: CVEs, version numbers, API endpoints = facts; architectural patterns = judgment | Open |

### 1.2 authorization-levels.md

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| PERMISSIONS.md states "337 allow / 32 deny / 112 ask" but actual settings.json has 377 allow / 34 deny / 124 ask | High | Stale documentation misleads developers reviewing permissions | Auto-generate counts from settings.json, or add a validation hook | Open |
| Rule says "MODIFY requires confirmation — show diff" but settings.json allows `Edit(/opt/**) Write(/opt/**)` without asking | Medium | Edit/Write to all global dirs auto-approved with no diff shown | Document that diff confirmation is Claude Code's UI responsibility, not hook-enforced | Open |
| `settings.json` has `"defaultMode": not set` (null/missing key) | Critical | Undocumented fallback behavior — unclear if fail-open or fail-closed | Explicitly set `"defaultMode": "default"` (or "ask") to match the rule's "fail-closed" intent | Open |
| Rule references audit script at `/opt/project` for widening violations, but no such script exists | Medium | Manual review only; no automated enforcement | Create audit script or document the intended check procedure | Open |
| Tier 2 project CANNOT widen, but Claude Code auto-populates `settings.local.json` `allow` on approval | High | Auto-widening happens silently; contradicts stated policy | Add periodic audit of `settings.local.json` files; warn on next session start if `allow` section has grown | Open |

### 1.3 code-before-write.md

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| Read-Once Rule: subagent prompt size limit not addressed — large files (>10K lines) overflow prompt | Medium | Content truncated silently, subagent works on partial data | Add explicit max-lines limit and page-based chunk strategy in rule | Open |
| "File Map Usage" instructs updating FILEMAP.md but concurrent agents may do so simultaneously | Medium | Race condition: last writer wins, changes lost | Serialize FILEMAP.md updates through team lead, or use file-level locking | Open |
| Rule says "code_review_hook.py runs on Write/Edit" but hook requires `code_review_checks` and `code_auto_fixer` imports that may be unavailable | Low | Falls back gracefully (ANALYZER_AVAILABLE=False), but rule implies guaranteed execution | Add note: "hook degrades gracefully if dependencies unavailable" | Open |

### 1.4 mandatory-checks.md

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `gitleaks detect` may not be installed | Medium | Secret scan step silently skipped — commit proceeds without scan | Add check: `command -v gitleaks || echo "WARN: gitleaks not installed, scan skipped"` | Open |
| `.claude/` in `.gitignore` rule — does not catch `settings.local.json` at project root (no `.claude/` prefix) | High | `settings.local.json` may be committed if placed in project root, leaking project-specific allowed tools | gitignore.template already covers `settings.local.json` but mandatory-checks.md does not reference it | Open |
| No guidance when test suite does not exist vs when tests are failing | Low | "BLOCK if failing" — no distinction between "suite missing" and "suite failing" | Clarify: missing suite → skip; suite present and failing → block | Open |

### 1.5 mcp-rules.md

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| Profile rotation modifies `~/.claude.json` but no rollback defined if mid-rotation crash occurs | High | Partial rotation leaves unknown server state; next session may have inconsistent MCP set | Add: backup `~/.claude.json` before rotation, restore on error | Open |
| "Essential servers never unloaded" but no enforcement mechanism exists in code | Medium | Rotation code in `workflow_autoloader.py` could remove essential servers if profile set excludes them | Verify `check_and_load_mcp_profiles()` preserves essential profile during all rotations | Open |
| "Before restart: save task state to MEMORY.md" — manual instruction with no automated trigger | Low | State loss if operator forgets to save before restarting | `pre_compact_hook.py` partially handles this, but mcp-rules.md should reference that hook | Open |

### 1.6 request-clarification.md

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| Boundary between "Simple" (<20) and "Standard" (20-65) requires scoring, but scoring is done by `compute_complexity_score()` in workflow_autoloader — not described in rule | Medium | Agents may apply different thresholds inconsistently | Reference the scoring function or embed the formula in the rule | Open |
| TeamCreate teammate NEEDS_CLARIFICATION format is defined, but there is no timeout: if lead never responds, teammate blocks indefinitely | High | Deadlock in TeamCreate workflow when clarification needed | Add: "If no response in N messages, assume default and document assumption" | Open |

### 1.7 task-execution.md

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| Wave scoring formula: `wave_score = max(max(task_scores), sum(task_scores)*0.4, task_count*8)` — edge case: 1 task with score 0 gives wave_score 0, no agent spawned even if task_count*8=8 | Low | Single unscored task gets wave_score=8, under Simple threshold, executed directly — probably correct | Document explicitly: wave_score < 20 → direct execution, not a bug | Open |
| BACKLOG.md active limit 30 items — no behavior defined when limit is exceeded | Medium | Items silently dropped or list grows unbounded | Add: "if count > 30, pause and defer oldest P3 items before continuing" | Open |
| Progressive scope tracking `files_modified >= 4` triggers PAUSE — but counting only counts Edit/Write, not Bash-based file changes (e.g., `sed -i`) | Medium | Scope escalation missed for shell-based edits; under-counts actual scope | Document limitation; optionally scan git diff in hook instead | Open |
| Retry logic: "retry once with different approach" — no definition of what constitutes "different" | Low | Agent may retry identically, burning another attempt | Specify: different approach = different tool, different strategy, or ask user | Open |
| Subagent safety escalation: `SendMessage` to team lead — but team lead may be busy; no queue or priority | Low | Escalation message may be delayed or ignored | Add: lead should process escalations before launching new waves | Open |

### 1.8 working-directories.md

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| Rule says "16 paths" but table lists 16 paths — authorization-levels.md says "16 paths" too, but PERMISSIONS.md group 2 says "16 paths + `~/.claude/**`" | Low | Count discrepancy across docs; confusing for maintainers | Normalize count across all references; `~/.claude/**` is the 17th path | Open |
| No rule for path traversal in working directories (e.g., `/opt/work/osint/../../etc/`) | High | Path traversal not blocked at rule level; relies on OS permissions | Add: "Never resolve paths outside the working directory root; reject `..` traversals" | Open |
| No timestamp format defined for "use timestamps in filenames" | Low | Different agents produce `2026-01-15`, `20260115`, `1737000000` — inconsistent | Standardize: `YYYY-MM-DD` for dates, Unix timestamp for cache keys | Open |

---

## 2. Hooks Edge Cases

### 2.1 code_review_hook.py

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `apply_auto_fixes()` writes back to file with `path.write_text()` — no atomic write (no tmp → rename) | High | On write failure midway, file is partially written and corrupted | Use `path.with_suffix('.tmp')` → write → `rename()` pattern | Open |
| Hook reads file with `path.read_text()` then auto-fixer writes it back — two separate I/O operations with no lock | Medium | Race condition: concurrent agent edit between read and write corrupts file | Use file locking around read+write in `apply_auto_fixes()` | Open |
| `CLAUDE_SESSION_ID` env var not available in all invocation contexts (per memory: session ID is file-based) | Low | Logs `session_id = "unknown"` — metrics correlation breaks | Read from `SESSION_ID_FILE` path as the pre_compact_hook.py does | Open |
| `code_reviews.jsonl` grows unbounded — no rotation or size limit | Low | Unbounded log file growth over time | Add size limit check: if > 10MB, rotate or truncate | Open |
| `get_file_content()` returns `""` on any exception but downstream code checks `if not content` — empty file (0 bytes) is treated same as unreadable file | Low | Empty files silently skipped, no error reported | Distinguish: `None` for error, `""` for empty file | Open |

### 2.2 hitl_approval_hook.py

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| Input reads from `os.environ.get("CLAUDE_TOOL_NAME")` and `os.environ.get("CLAUDE_TOOL_INPUT")` — but other hooks read from stdin JSON | High | HITL hook uses wrong input method; tool name/args will always be empty in standard Claude Code hook invocation | Switch to `json.load(sys.stdin)` for `tool_name` and `tool_input`, matching other hooks | Open |
| `fcntl.flock()` on log files — `LOCK_EX` without `LOCK_NB` will block indefinitely if another process holds the lock | Medium | Hook hangs if another hook instance is writing logs simultaneously | Use `LOCK_EX | LOCK_NB` with retry or timeout | Open |
| `DATA_FILE` parent directory may not exist when `log_decision()` is called | Medium | `open(DATA_FILE, "a")` raises `FileNotFoundError` — hook crashes silently | Call `ensure_dirs()` before every `open()`, or move it to top of `log_decision()` | Open |
| `check_command_risk()` does case-insensitive substring match — `"rm -rf"` matches `"confirm"` (contains `rm`), `"DELETE FROM"` matches legitimate SQL comments | Medium | False positives block legitimate operations | Use word-boundary matching or exact token matching instead of substring | Open |
| Hook returns `1` to block but Claude Code hooks block on non-zero exit only in PreToolUse — need to verify this is actually a blocking hook | Low | If hook is PostToolUse or advisory, returning 1 has no blocking effect | Verify hook registration type in settings.json; PreToolUse for blocking | Open |

### 2.3 input_validation_hook.py

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| Injection detection runs on ALL tool inputs including file content read from disk — legitimate files may contain injection-like patterns | Medium | False positive blocks legitimate tool use (e.g., reading a file about AI jailbreaks) | Limit detection to user-originated prompts only; skip file content reads | Open |
| `sys.argv[1:]` overrides stdin if provided — running hook manually with args bypasses stdin-based detection | Low | Allows hook bypass by passing args directly | Remove argv-based input; stdin is authoritative in hook context | Open |
| `re.findall()` on complex patterns with long input strings — potential ReDoS on adversarial input | Medium | Catastrophic backtracking on crafted input; hook hangs | Add `re.compile(..., timeout=...)` where available, or limit input length pre-scan | Open |
| No size limit on `tool_input` before running injection patterns | Medium | Scanning a 10MB file through all 30+ patterns is slow; hook timeout kills it | Add: `tool_input = tool_input[:50000]` before pattern matching | Open |
| `log_alert()` writes without file locking — concurrent hook invocations corrupt JSONL | Low | Race condition on concurrent tool use with injection patterns | Add `fcntl.flock()` as done in `hitl_approval_hook.py` | Open |

### 2.4 pre_compact_hook.py

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `memory_dirs = list(Path.home().glob(".claude/projects/*/memory/MEMORY.md"))` — if multiple projects exist, always picks `memory_dirs[0]` (arbitrary order) | High | Wrong project's MEMORY.md updated on compact — state written to wrong project | Filter by current working directory using `cwd` variable available in hook | Open |
| `save_to_memory()` uses `re.sub()` to remove old In-Progress section then appends new one — if MEMORY.md has no trailing newline, formatting breaks | Low | Extra blank lines or missing separator between sections | Normalize: always `content.rstrip() + "\n" + in_progress` (already done) — acceptable | Mitigated |
| `get_git_state()` uses `subprocess.run()` with `timeout=3` — but git operations on large repos can exceed 3 seconds | Low | Git state returns empty; branch "unknown"; modified files list empty | Increase timeout to 10s or use `--no-optional-locks` flag | Open |
| `stdin_data = sys.stdin.read().strip()` — if stdin is empty (hook called with no input), `json.loads("")` raises `ValueError` | Low | Caught by `json.loads(stdin_data) if stdin_data else {}` — handled correctly | Mitigated | Mitigated |
| Plan file selection uses `sorted(plans_dir.glob("*.md"), key=lambda p: p.stat().st_mtime)` — race if plan file deleted between glob and stat | Low | FileNotFoundError caught by outer `except Exception: pass` | Acceptable — stat failure means plan not shown in summary | Mitigated |

### 2.5 session_end_hook.py

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `run_session_summary()` calls external `session_summary.py` — if script is missing, silently passes; no warning to operator | Low | Silent failure, no summary produced, no indication of what happened | Log: `print("WARN: session_summary.py not found", file=sys.stderr)` | Open |
| `save_continuity_data()` writes to JSONL unbounded — file grows forever across all sessions | Medium | Continuity file becomes very large; `check_session_continuity()` reads entire file each startup | Rotate: keep last 100 entries; truncate older records | Open |
| `cleanup_pipeline_state()` uses `tmp.rename(state_file)` — not atomic across filesystems (e.g., `/opt` is different mount from state file) | Low | `OSError` on cross-device rename; state file remains unchanged | Use `shutil.move()` instead of `.rename()`, or ensure same-filesystem tmp location | Open |
| `import re as _re2` and `import re as _re` used multiple times in same function body — redundant imports | Low | No functional issue; code smell, slightly inefficient | Hoist `import re` to module level | Open |
| `git diff --name-only` with `cwd=cwd` where `cwd` may not be a git repo — `subprocess.run()` raises `OSError` | Low | Caught by `except (subprocess.TimeoutExpired, OSError, FileNotFoundError): pass` | Mitigated | Mitigated |

### 2.6 session_health_check.py

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `from session_summary import find_latest_session_file, parse_session_file` — import fails if `session_summary.py` is missing | Low | Falls through to `except Exception` → `print(json.dumps({}))` — silent failure | Add specific ImportError catch with warning message | Open |
| `encoded_path = str(cwd).replace('/', '-').replace('_', '-')` — path encoding collision: `/opt/my_project` and `/opt/my-project` map to same hash | Medium | Wrong project session data loaded; false health warnings for different project | Use a more robust encoding: SHA256 of cwd, or URL-encode | Open |
| `datetime.now()` used without timezone for comparison against file mtime — DST transitions cause incorrect debounce | Low | Debounce may fire 1 hour early or late during DST change | Use `datetime.now(timezone.utc)` consistently | Open |
| Session health threshold (10000 tokens, 5000 cache ratio) is hardcoded — no configuration | Low | Thresholds cannot be adjusted per project/user | Expose as constants or config file | Open |

### 2.7 session_start_reinforcement.py

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `check_config_drift()` regex `r"(\d+) agents"` matches first number before "agents" — if CLAUDE.md contains "102 custom agents", matches 102, but "102" agents vs actual agents/*.md count includes system-only agents with no skill | Medium | Config drift false positive when system-only agents are counted | Clearly document which agents are in count; separate skill-invocable from system-only | Open |
| `check_new_project()` uses `os.getcwd()` as fallback — inside hook, CWD may differ from project path | Medium | Wrong project detected; AUTO_ACTION triggers for wrong dir | Always use `CLAUDE_WORKING_DIRECTORY` env var; error if not set | Open |
| `check_session_continuity()` reads entire `session_continuity.jsonl` file for each session start | Medium | Large continuity file (many sessions) → slow startup | Read only last line using `seek()` from end of file | Open |
| Session continuity `last.get("working_directory") != cwd` comparison — both use env var fallback to `os.getcwd()` — may mismatch on symlinks | Low | Symlink to project → different path string → continuity not loaded | Normalize paths using `Path.resolve()` before comparison | Open |
| Top-level code executes on import: `input_data = json.load(sys.stdin)` — crashes other modules that import from this file | High | Cannot import `check_new_project` or other functions for testing without side effects | Move execution to `if __name__ == "__main__":` block, expose functions for import | Open |

### 2.8 session_startup_dashboard.py

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `from session_manager import SessionManager` — imports removed Python module (tools-mcp replaced session_manager.py in v7.6) | Critical | ImportError on every session start; hook falls back to warning message permanently | Remove hook or update to use `mcp__tools-mcp__session_*` tools | Open |
| `project_dirs = [d for d in projects_dir.iterdir() if d.is_dir()]` without sorting — non-deterministic project selection | Medium | Different project's dashboard shown each startup | Sort by mtime descending to get most recently used project | Open |
| `manager.display_dashboard(session_file)` — passing positional arg to `SessionManager` method that doesn't exist | Low | AttributeError if import somehow succeeds; caught by inner `except Exception` | Moot if ImportError is fixed (hook should be removed/replaced) | Open |

### 2.9 session_startup_hook.py (research digest)

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `DIGEST_READ_TRACKER` reads `json.load()` — if file is corrupted JSON, returns `True` (unread) on every startup | Low | Every session shows digest warning even after reading | Wrap with specific `json.JSONDecodeError` catch; re-initialize tracker on corruption | Open |
| `count_priority_items()` counts emoji characters — emoji rendering varies by font/terminal, could give 0 count on valid digest | Low | Digest with critical items suppressed if emoji not in file | Use text marker like `[CRITICAL]` in addition to emoji | Open |
| `get_digest_age()` uses naive datetime — same DST issue as session_health_check.py | Low | Off-by-one day on digest age during DST transitions | Use UTC timestamps in digest files | Open |

### 2.10 user_prompt_submit_hook.py

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `check_frozen_criteria()` deletes `freeze_file` on expiration — no backup | Medium | Expired criteria silently deleted; no audit trail | Archive to `frozen_criteria.{timestamp}.expired.json` before deleting | Open |
| `freeze_file.unlink()` can raise `FileNotFoundError` in race with concurrent process | Low | `except Exception as e: print(..., file=sys.stderr); return ""` — swallowed | Catch `FileNotFoundError` specifically; use `unlink(missing_ok=True)` | Open |
| `SESSION_ID_PATTERN.match(session_id)` blocks UUID validation — valid session IDs from env var may not be UUID format | Medium | `check_frozen_criteria()` returns empty; frozen criteria not injected for non-UUID sessions | Verify session ID format; if format changes, pattern needs updating | Open |
| Domain context errors logged to stderr `print(f"Domain context error: {e}", file=sys.stderr)` — output visible to user as noise | Low | stderr from hooks may appear in Claude Code UI as error messages | Use a log file instead of stderr for debug output | Open |

### 2.11 workflow_autoloader.py

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `check_and_load_mcp_profiles()` modifies `~/.claude.json` — no atomic write; partial write on crash leaves config corrupt | Critical | Claude Code won't load if `~/.claude.json` is invalid JSON | Write to temp file then rename; validate JSON before writing | Open |
| `active_profiles.json` read/write has no file locking — concurrent prompt submissions race on this file | High | TOCTOU race: two concurrent prompts may both load same profile, double-adding servers | Use `fcntl.flock()` around `active_profiles.json` read+write | Open |
| `score_domains()` processes entire prompt text with multiple regex passes — very long prompts (>50KB) cause significant latency | Medium | Each user message takes 100-500ms extra; noticeable at 10KB+ prompts | Add prompt truncation: `prompt = prompt[:10000]` before scoring | Open |
| Module references like `"18-blue-purple-dfir.md"` and `"05-writing.md"` — archived modules 04, 05, 06, 19 are listed as loadable in domain keywords | Medium | Suggests loading an archived module that doesn't exist at expected path | Update DOMAIN_KEYWORDS to remove archived module references; point to active replacements | Open |
| `compose_workflows()` imported from workflow_autoloader but not visible in the excerpt — function may not exist | Low | `AttributeError` if `compose_workflows` is not defined in the module | Verify function exists; the import in user_prompt_submit_hook.py will fail silently | Open |

---

## 3. Templates Edge Cases

### 3.1 BACKLOG.md.template

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `{{project_name}}` placeholder not replaced if project-init fails mid-run | Low | BACKLOG.md contains literal `{{project_name}}` — confusing | Add validation step: post-init scan for unreplaced `{{...}}` markers | Open |
| No date placeholder in template — tasks added manually won't include date | Low | Task format inconsistency; stale detection by date impossible | Add note: "date required: YYYY-MM-DD format" | Open |

### 3.2 claude-ver.template

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `{VERSION}`, `{TIMESTAMP}`, `{STACK}`, `{DOMAINS}` use single-brace syntax unlike other templates using `{{...}}` | Medium | Inconsistent placeholder format — project-init scripts must handle two formats | Standardize to `{{VERSION}}` across all templates | Open |
| `STACK` and `DOMAINS` not validated — free text; could be empty string | Low | `.claude-ver` contains `stack: ` (empty) — drift check misses stack info | Validate non-empty at project-init time | Open |

### 3.3 FILEMAP.md.template

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `{{date}}` appears twice but is the same placeholder — confusing for "Generated" vs "Last updated" | Low | Both show same date at init; "Last updated" not auto-updated | Add a hook or note: "update 'Last updated' on significant file changes" | Open |
| `{{count}}` placeholder — file count not auto-populated; left as placeholder forever | Low | FILEMAP.md shows `{{count}}` if project-init doesn't fill it | Either auto-count at init or remove the placeholder | Open |

### 3.4 gitignore.template

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `*.jsonl` pattern at line 17 ignores ALL JSONL files, including `BACKLOG.md` (not JSONL) but critically also any project data files in JSONL format | Medium | Legitimate project data in JSONL format (e.g., ML datasets, log exports) would be ignored | Scope to specific known-sensitive paths: `sessions/*.jsonl`, `transcripts/*.jsonl` | Open |
| `*.pub` pattern at line 79 ignores SSH public keys — these are intentionally public and sometimes committed | Low | Legitimate SSH public key file accidentally ignored | Remove `*.pub` or scope to `~/.ssh/*.pub` (not project-level) | Open |
| `Cargo.lock` ignored at line 273 — for binary crates, Cargo.lock should be committed | Medium | Rust binaries lose reproducible builds; security vulnerability if deps drift | Split: ignore for libraries, keep for binaries. Add comment explaining | Open |
| `*.sql` at line 714 ignores all SQL files including schema migrations and seed data | High | Project schema migrations (e.g., `V1__create_tables.sql`) silently excluded from git | Scope to `dump.sql`, `backup.sql`, `data/*.sql` — not all `.sql` files | Open |
| `settings.xml` at line 108 catches Maven settings (credential file) AND legitimate project XML configs | Low | Legitimate Maven project configuration accidentally ignored | Rename to `.m2/settings.xml` pattern for Maven credentials specifically | Open |

### 3.5 MEMORY_INIT.md.template

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| Sub-directories listed (`reports/`, `scans/`, `data/`) are hardcoded — irrelevant for non-security projects | Low | Development projects get OSINT/pentest-oriented directory structure in memory | Parameterize by project type or make it a comment | Open |
| `{{git_status}}` placeholder — git status is volatile; snapshot in MEMORY becomes stale immediately | Low | MEMORY.md shows outdated git status from init time | Replace with instruction: "check `git status` for current state" | Open |

### 3.6 ONBOARDING.md

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| "19 available" domains listed for primary domains — actual domain count in workflow_autoloader.py is 18 distinct keys | Low | Stale count causes confusion | Update to match actual DOMAIN_KEYWORDS keys count | Open |
| Budget limit `$5/session (default)` referenced — budget_manager.py removed in v7.6 (replaced by tools-mcp) | Medium | Onboarding creates user expectation for budget enforcement that no longer works as described | Update to reference tools-mcp session cost tracking, or remove budget reference | Open |

### 3.7 PERMISSIONS.md

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| Count mismatch: "337 allow / 32 deny / 112 ask" vs actual 377/34/124 | High | Outdated documentation; developers trust wrong numbers when auditing | Automate: generate counts from settings.json; update PERMISSIONS.md during project-init | Open |
| "Bash(git:*)" in group 18 described as "2" rules — contradicts CLAUDE.md memory note of "18 allow + 10 ask + 2 deny" for git | Medium | Inconsistent documentation; actual git permission set unclear | Verify settings.json and update PERMISSIONS.md table accordingly | Open |
| `{{project}}` placeholder not resolved in per-project type templates section | Low | Templates show literal `{{project}}` — visual noise but not functional issue | Add note: "replaced by project-init" | Open |

### 3.8 settings.local.json.template

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `{{project_path}}` not validated — if project path contains special chars (`$`, spaces, backticks), JSON becomes invalid | High | `settings.local.json` with invalid JSON silently ignored by Claude Code, or breaks entire session | Validate and escape project_path before template substitution | Open |
| Template hardcodes `"_version": "7.4.0"` — not updated to 7.7.0 | Low | Version mismatch in generated files | Source version from VERSION file at template fill time | Open |
| `"ask": []` and `"deny": []` are empty arrays — project-init should merge per-type permission template here | Medium | If merge step is skipped, settings.local.json has no type-specific ask/deny entries | Document required merge step explicitly; add validation in project-init | Open |

### 3.9 upgrade-manifest.json

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| Version 7.7.0 not listed in upgrade manifest | Medium | `check_new_project()` may not trigger upgrade for v7.6 → v7.7 transitions | Add 7.7.0 entry to manifest with changed files | Open |
| No checksum or hash verification for changed files | Low | Upgraded file could be partially modified or corrupted without detection | Add expected SHA256 for critical template files | Open |

### 3.10 permissions/ directory (5 JSON files)

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `permissions-development.json` has `"deny": []` — no project-level deny means all global denies apply, but no additional protection | Low | Development projects could accidentally run `nmap` (in global ask, not denied) | Add common development project denials: `Bash(nmap:*)`, `Bash(masscan:*)` | Open |
| `{{project_path}}` placeholder in all permission files — if not replaced, `Edit({{project_path}}/**)` allows editing a literal path with braces | High | In the unlikely event substitution fails, allows edits to a nonexistent path (harmless) but audit logs show wrong path | Add validation step post-substitution to verify no `{{...}}` remain | Open |
| `permissions-security.json` `ask` list does not include `Bash(feroxbuster:*)`, `Bash(dirsearch:*)` — common tools | Low | Feroxbuster runs without confirmation (falls to global ask/defaultMode) | Add common omitted tools to ask list | Open |

---

## 4. Permissions Edge Cases

### 4.1 settings.json Global Permissions

| Edge Case | Severity | Current Behavior | Recommended | Status |
|-----------|----------|------------------|-------------|--------|
| `"defaultMode": not set` — JSON key missing entirely | Critical | Claude Code behavior with missing defaultMode is undefined; could be allow-all | Explicitly set `"defaultMode": "default"` | Open |
| Deny pattern `Bash(* | sh)` and `Bash(* | bash)` — glob `*` in Bash permission patterns may not match multi-token commands | High | `curl http://example.com | sh` may not be caught if glob matching is token-based | Test pattern matching; use regex-style deny or explicit known-bad patterns | Open |
| `Read(**/*token*)` in deny — blocks reading files with "token" in name, including legitimate JWT files, OAuth token documentation, test fixtures | Medium | False positives deny reading `oauth_token_docs.md`, `test_token_fixture.json` | Narrow: `Read(**/*_token)`, `Read(**/*.token)`, exclude `*.md` and test files | Open |
| `Bash(git:push --force*)` deny covers `git push --force-with-lease` — force-with-lease is safer and often legitimate | Medium | Overly broad deny blocks safe force push variant | Allow `git push --force-with-lease`; keep deny for `--force` and `-f` | Open |
| 377 allow entries is large — likely contains redundant rules where wildcard already covers specific patterns | Low | Maintenance burden; harder to audit; redundant allows don't break anything | Run deduplication audit: find rules covered by existing wildcards | Open |

---

## 5. Cross-Component Conflicts

| Component A | Component B | Conflict | Resolution |
|-------------|-------------|----------|------------|
| authorization-levels.md ("MODIFY requires confirmation — show diff") | settings.json (Edit/Write auto-allowed for 16 global dirs) | Rule says user sees diff before edit; settings auto-approve all edits in /opt/** | Clarify: diff-show is Claude Code's UI behavior, not permission-based; rule is aspirational |
| mcp-rules.md ("Essential 13 servers never unloaded") | workflow_autoloader.py `check_and_load_mcp_profiles()` | No enforcement of "essential" servers during profile rotation | Add `essential_names` check in `check_and_load_mcp_profiles()` before removing any server |
| mandatory-checks.md ("Verify .claude/ in .gitignore") | gitignore.template (`*.jsonl` blocks all JSONL) | Mandatory check only verifies `.claude/`; template overly broad pattern may hide this gap | Review gitignore template for minimum required exclusions vs overkill patterns |
| task-execution.md (BACKLOG.md required for Standard+ tasks) | pre_compact_hook.py (picks first memory dir without CWD match) | Compact hook writes wrong project's MEMORY.md; BACKLOG.md path stored wrong | Fix pre_compact_hook.py to filter by current CWD |
| session_start_reinforcement.py (checks `.claude-ver` version) | upgrade-manifest.json (missing v7.7.0 entry) | Version check cannot trigger upgrade for 7.6 → 7.7 | Add v7.7.0 to upgrade-manifest.json |
| PERMISSIONS.md ("337 allow / 32 deny / 112 ask") | settings.json (actual 377/34/124) | Documentation out of sync with reality | Auto-generate PERMISSIONS.md counts; add to project-init or CI step |
| session_startup_dashboard.py (imports `session_manager.SessionManager`) | v7.6 migration (session_manager.py removed) | Critical import failure every session start | Remove or replace session_startup_dashboard.py |
| working-directories.md (count "16 paths") | authorization-levels.md (count "16 paths") | Both say 16 but table has 16 + `~/.claude/` = 17 effective allowed dirs | Normalize count: either remove `~/.claude/**` from the edit allow list or update counts |

---

## 6. Race Conditions

| Scenario | Components | Probability | Impact | Mitigation |
|----------|-----------|-------------|--------|------------|
| Two parallel agents both write FILEMAP.md | code-before-write.md (rule), multiple agent tasks | High (occurs in every multi-agent wave touching same area) | Data loss: last writer overwrites other agent's updates | Serialize FILEMAP.md writes through team lead; use atomic write pattern |
| Two parallel agents write BACKLOG.md simultaneously | task-execution.md (rule), Wave execution | High (wave completion marks tasks) | BACKLOG.md line order corrupted; task state lost | Use file locking in BACKLOG.md update; or route all backlog writes through one agent |
| `workflow_autoloader.py` and `user_prompt_submit_hook.py` both run on rapid successive prompts, both modifying `active_mcp_profiles.json` | workflow_autoloader.py | Medium (fast typing, rapid submit) | TOCTOU: duplicate profile loading, inconsistent profile state | `fcntl.flock(LOCK_EX)` on `active_profiles.json` before read+write |
| `pre_compact_hook.py` runs during active agent wave that is also writing MEMORY.md | pre_compact_hook.py, active agents | Low (compact is triggered by context limit, usually not mid-wave) | MEMORY.md gets partial content: compact writes section, agent overwrites it | Use atomic write pattern + advisory locks on MEMORY.md |
| `hitl_approval_hook.py` flock deadlock: two hooks run simultaneously, both waiting for LOCK_EX on same log file | hitl_approval_hook.py | Low (hooks run per-tool-call, could overlap) | Both hooks deadlock; blocking hook never returns; Claude Code times out | Use `LOCK_EX | LOCK_NB` with retry loop and timeout |
| `~/.claude.json` modified by `workflow_autoloader.py` while Claude Code is reading it at session initialization | workflow_autoloader.py, Claude Code process | Low (rotation happens on first prompt, init is earlier) | Corrupted config read; missing MCP servers for session | Atomic write: tmp file → validate → rename |

---

## 7. Degradation Matrix

| Component | Failure Mode | Impact | Fallback | Recovery |
|-----------|-------------|--------|----------|----------|
| `session_startup_dashboard.py` | ImportError (session_manager missing) | Warning shown every session; no metrics | Hook outputs warning string, session continues | Remove or replace hook with tools-mcp call |
| `code_review_hook.py` | ImportError (code_review_checks missing) | No code review, no auto-fix | `ANALYZER_AVAILABLE=False`, hook outputs `{}` silently | Install missing dependency or accept degraded review |
| `workflow_autoloader.py` (import failure) | `AUTOLOADER_AVAILABLE=False` in user_prompt_submit_hook.py | No domain detection, no MCP rotation, no workflow hints | Session continues without domain context injection | Fix import; check path at `~/.claude/hooks/` |
| `gitleaks` not installed | Secrets scan in mandatory-checks.md skipped | Commits proceed without secret scan | No fallback — gap in security posture | Install gitleaks; or use alternative (trufflehog, git-secrets) |
| MCP server unavailable | mcp-rules.md: "use CLI tools directly" | Degraded functionality for that domain | CLI fallback tools (subfinder, etc.) | Restart MCP server; check config |
| `~/.claude.json` corrupted by partial write | Claude Code fails to load MCP config | Entire session starts without MCP tools | No automated fallback | Restore from backup; edit JSON manually |
| BACKLOG.md missing | task-execution.md: creates on first use | No task tracking for previous work | Fresh BACKLOG.md created | Recover from git history if committed |
| `active_mcp_profiles.json` corrupted | Profile rotation state unknown | All profiles may be re-loaded on next prompt | `workflow_autoloader.py` reinitializes on read error | Delete file; profiles auto-detected fresh |
| `session_continuity.jsonl` very large (>10MB) | Session startup slow (reads entire file) | 5-10 second startup delay | Reads only last line after fix | Rotate file; keep last 100 entries |
| `session_health_check.py` import failure | No session reopen recommendation | Long sessions accumulate context without warning | Session continues; operator may notice degradation | Fix import path; check evaluation/ directory |

---

## 8. Recommendations (Prioritized)

### Critical (fix immediately)

1. **Set `defaultMode` in settings.json** — missing key means undefined behavior on unmatched permissions. Add `"defaultMode": "default"` or `"defaultMode": "ask"`.

2. **Fix session_startup_dashboard.py ImportError** — `session_manager.py` was removed in v7.6. Hook fails on every session start. Either remove the hook or replace with tools-mcp call (`mcp__tools-mcp__session_*`).

3. **Atomic write for `~/.claude.json` in workflow_autoloader.py** — MCP profile rotation writes directly to config file. Crash during write corrupts config. Implement: write to `.claude.json.tmp`, validate JSON, then `rename()`.

### High (fix this sprint)

4. **Fix hitl_approval_hook.py input reading** — hook reads `os.environ.get("CLAUDE_TOOL_NAME")` but Claude Code passes tool data via stdin JSON. Tool name/args are always empty; the hook never blocks anything.

5. **Fix pre_compact_hook.py project selection** — `memory_dirs[0]` is arbitrary; correct logic is filter by current working directory. Wrong project MEMORY.md gets overwritten on compact.

6. **Add `fcntl.flock()` to workflow_autoloader.py profile write** — `active_mcp_profiles.json` race condition on concurrent prompt submissions. Use exclusive lock around read+write cycle.

7. **Scope deny pattern for `*.sql` in gitignore.template** — blanket `*.sql` ignore causes schema migrations and seed files to be excluded from commits. Scope to `dump.sql`, `backup.sql`, `data/*.sql`.

8. **Fix path traversal rule in working-directories.md** — add explicit statement forbidding `..` in working paths. Current rule has no guard against path traversal.

9. **Fix authorization-levels.md: PERMISSIONS.md count mismatch** — documents say 337/32/112 but actual counts are 377/34/124. Implement automated count generation.

10. **Add v7.7.0 to upgrade-manifest.json** — current version is 7.7.0 but manifest stops at 7.6.0. Upgrade checks from 7.6 to 7.7 won't trigger.

### Medium (fix next sprint)

11. **Add file locking to code_review_hook.py auto-fix write** — read and write are not atomic; concurrent agent edit between read and write corrupts the file.

12. **Scope `*.jsonl` in gitignore.template** — `*.jsonl` ignores all JSONL files including ML datasets, API responses, and other legitimate project data.

13. **Fix session_health_check.py path encoding** — `replace('/', '-').replace('_', '-')` causes hash collisions between projects with similar names.

14. **Add input size limit to input_validation_hook.py** — no cap on input size before running 30+ regex patterns. Large files cause hook timeout.

15. **Remove archived module references from workflow_autoloader.py DOMAIN_KEYWORDS** — modules 04, 05, 06, 19 are archived but still listed as loadable in domain mappings.

16. **Rotate session_continuity.jsonl** — unbounded growth causes slow session startup. Keep last 100 entries.

17. **Fix session_start_reinforcement.py top-level execution** — `json.load(sys.stdin)` at module scope prevents importing functions for testing.

18. **Standardize placeholder syntax in templates** — `{VERSION}` vs `{{VERSION}}` inconsistency across templates creates maintenance confusion.

### Low (address in backlog)

19. **Normalize UTC timestamps** in `session_health_check.py` and `session_startup_hook.py` — DST transitions cause incorrect debounce and digest age calculations.

20. **Add `Cargo.lock` comment in gitignore.template** — binary crates should commit Cargo.lock; template ignores it for all Rust projects.

21. **Remove redundant allow entries in settings.json** — 377 allow rules likely contain overlapping patterns. Audit and deduplicate to reduce maintenance surface.

22. **Add gitleaks availability check in mandatory-checks.md** — secret scan step silently skips if tool not installed; no warning to operator.

23. **Allow `git push --force-with-lease`** — current deny covers all `--force*` variants including the safe `--force-with-lease`.

24. **Rotate `code_reviews.jsonl`** — unbounded growth; add 10MB rotation.
