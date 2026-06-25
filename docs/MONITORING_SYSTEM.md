# Claude Code Monitoring System

Version: 1.0.0 | Created: 2026-03-22

## 1. Overview

This document describes the cross-session observability architecture for Claude Code.
It covers what to track, where to store, how to query, and how to surface anomalies
and feature adoption gaps.

### Problem Statement

The current metrics infrastructure operates per-session. `metrics.jsonl` captures raw
tool calls. `tool_usage_counts.json` tracks per-session counts. `spending_tracker.jsonl`
logs cost per session. None of these cross session boundaries or answer:

- Which of 102 agents has never been spawned?
- Is hook error rate trending up this week?
- What is the daily tool call volume trend over 30 days?
- Which rules were never enforced?

### Architecture Principle

**Do not add new data sources — aggregate and enrich existing ones.**

```
Raw Sources (existing)          Aggregation Layer           Query Layer
┌──────────────────────┐        ┌─────────────────────┐    ┌──────────────┐
│ metrics.jsonl        │──────►│ daily_agg.jsonl      │──►│ usage_       │
│ spending_tracker.jsonl│──────►│ feature_adoption.json│──►│ dashboard.py │
│ budget_spending.jsonl │──────►│ anomaly_state.json   │   └──────────────┘
│ tool_usage_counts.json│──────►│ health_status.json   │    MCP tools-mcp
│ session_continuity   │        └─────────────────────┘    (usage_trends)
└──────────────────────┘
```

---

## 2. What to Track

### 2.1 Three Signal Pillars

| Pillar | Signal | Source |
|--------|--------|--------|
| **Volume** | Tool calls/day, session count/day | metrics.jsonl |
| **Cost** | USD/day, USD/session, cost/project | spending_tracker.jsonl |
| **Feature Adoption** | Which agents/skills/hooks/rules called | metrics.jsonl + hooks |

### 2.2 Tool Metrics (Golden Signals)

- **Traffic**: calls per tool per day
- **Latency**: `dur_ms` p50/p95/p99 per tool (for slow tools: Bash, Task, WebSearch)
- **Errors**: tool call failures (where duration is 0 and tool is not a Read-type)
- **Saturation**: session depth (how many tools per session), Task nesting depth

### 2.3 Feature Adoption (102 agents, 103 skills, 14 rules, 25 hooks)

**Agents** — tracked via `Task` / `Agent` tool calls. The `subagent_type` field in the
hook stdin payload identifies which agent was spawned. The metrics hook currently does
NOT capture this. See Section 5 for enhancement.

**Skills** — tracked via `Skill` tool calls. The skill name appears in tool parameters.
Currently 2 Skill calls in 30d (from metrics.jsonl sample). Low adoption.

**Hooks** — each hook writes to stderr or a dedicated file on execution. Cross-session
health = hook fire count + error count per hook script name.

**Rules** — rules are passive markdown; they cannot be tracked directly. Proxy: track
rule-specific tool patterns (e.g., EnterPlanMode calls = Complex+ task compliance;
criteria_freeze calls = Standard+ criteria compliance).

### 2.4 Anomaly Signals

| Anomaly | Detection Method | Threshold |
|---------|-----------------|-----------|
| Tool volume drop | daily_count < mean - 2σ over 14d rolling | >2σ below |
| Cost spike | session_cost > daily_avg * 3 | >3x average |
| Hook error surge | error_count/fire_count > 0.05 for any hook | >5% error rate |
| Budget overrun | daily_cost > daily_budget * 0.9 | >90% consumed |
| Zero tool days | no entries in metrics.jsonl for calendar day | any gap > 1d |

### 2.5 Health Checks

Periodic verification (not real-time) that:
- All 25 hooks are registered in `settings.json` (static check)
- Essential MCP servers are responding (ping via tools-mcp)
- Session ID file exists and is non-empty (sanity check)
- metrics.jsonl was written in the last 24h (activity check)

---

## 3. Storage Architecture

### 3.1 Decision: Extend JSONL + Single SQLite for Aggregations

**Rationale**: JSONL is already working and append-safe. SQLite handles aggregations
efficiently without a server. Dashboard reads SQLite (fast); collector script populates
SQLite from JSONL (runs on demand or cron).

```
~/.claude/evaluation/data/
├── metrics.jsonl               (existing — raw tool events, ~800 rows/session)
├── spending_tracker.jsonl      (existing — per-session cost)
├── budget_spending.jsonl       (existing — per-tool budget events)
├── tool_usage_counts.json      (existing — per-session counts, 169 sessions)
├── monitoring.db               (NEW — SQLite aggregation database)
└── feature_adoption.json       (NEW — agent/skill/hook usage registry)
```

### 3.2 SQLite Schema

```sql
-- Daily tool call aggregations
CREATE TABLE daily_tool_stats (
    date        TEXT NOT NULL,          -- YYYY-MM-DD
    tool        TEXT NOT NULL,          -- tool name
    call_count  INTEGER NOT NULL,
    p50_ms      REAL,                   -- latency percentiles (NULL if no dur_ms)
    p95_ms      REAL,
    p99_ms      REAL,
    session_count INTEGER,
    PRIMARY KEY (date, tool)
);

-- Daily session summaries
CREATE TABLE daily_session_stats (
    date            TEXT PRIMARY KEY,
    session_count   INTEGER,
    total_calls     INTEGER,
    total_cost_usd  REAL,
    p50_session_cost REAL,
    p95_session_cost REAL
);

-- Feature adoption registry
CREATE TABLE feature_adoption (
    feature_type    TEXT NOT NULL,      -- 'agent', 'skill', 'hook', 'rule_proxy'
    feature_name    TEXT NOT NULL,      -- agent filename without .md, skill name, etc.
    first_seen      TEXT,               -- ISO timestamp
    last_seen       TEXT,
    total_calls     INTEGER DEFAULT 0,
    sessions_used   INTEGER DEFAULT 0,
    PRIMARY KEY (feature_type, feature_name)
);

-- Anomaly event log
CREATE TABLE anomaly_events (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ts          TEXT NOT NULL,
    anomaly_type TEXT NOT NULL,         -- 'volume_drop', 'cost_spike', 'hook_error', etc.
    metric_name TEXT,
    observed    REAL,
    expected    REAL,
    sigma       REAL,
    details     TEXT                    -- JSON blob
);

-- Hook health log
CREATE TABLE hook_health (
    date        TEXT NOT NULL,
    hook_name   TEXT NOT NULL,
    fire_count  INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    last_error  TEXT,
    PRIMARY KEY (date, hook_name)
);
```

### 3.3 Retention Policy

| Table | Retention | Rationale |
|-------|-----------|-----------|
| daily_tool_stats | 365 days | Year-over-year trends |
| daily_session_stats | 365 days | Year-over-year cost |
| feature_adoption | Permanent | Registry, not time-series |
| anomaly_events | 90 days | Incident lookback |
| hook_health | 90 days | Health trend window |
| metrics.jsonl | 30 days (existing GC) | Raw events, high volume |
| spending_tracker.jsonl | 90 days (existing) | Cost audit trail |

---

## 4. Cross-Session Aggregation

### 4.1 Aggregation Script

`/opt/project/tools/monitoring_collector.py` — runs on demand or via cron.

**Responsibilities**:
1. Read metrics.jsonl, detect new entries since last run (watermark in monitoring.db)
2. Bucket by day, compute per-tool stats, insert into `daily_tool_stats`
3. Read spending_tracker.jsonl, aggregate to `daily_session_stats`
4. Scan tool_usage_counts.json for agent/skill usage patterns
5. Detect anomalies by comparing current period vs 14-day rolling baseline
6. Write anomaly_events for detected deviations

**Watermark mechanism**: Store `last_processed_line` count in monitoring.db metadata table.
On next run, skip lines already processed. Prevents double-counting.

### 4.2 Trend Queries

```sql
-- 7-day tool volume trend
SELECT date, SUM(call_count) as total
FROM daily_tool_stats
WHERE date >= date('now', '-7 days')
GROUP BY date ORDER BY date;

-- Top 10 tools by 30-day volume
SELECT tool, SUM(call_count) as total
FROM daily_tool_stats
WHERE date >= date('now', '-30 days')
GROUP BY tool ORDER BY total DESC LIMIT 10;

-- Daily cost trend (30 days)
SELECT date, total_cost_usd, session_count
FROM daily_session_stats
WHERE date >= date('now', '-30 days')
ORDER BY date;

-- Unused features (0 calls in 30 days)
SELECT feature_type, feature_name
FROM feature_adoption
WHERE last_seen < date('now', '-30 days') OR last_seen IS NULL
ORDER BY feature_type, feature_name;
```

---

## 5. Feature Adoption Tracking

### 5.1 Agent Adoption

**Current gap**: `metrics.jsonl` records `Task` calls but not which `subagent_type`.

**Enhancement required**: Modify `unified_tool_metrics_hook.py` (PostToolUse) to extract
`subagent_type` from tool input when `tool_name == "Task"`:

```python
# In unified_tool_metrics_hook.py PostToolUse handler
if tool_name == "Task":
    tool_input = data.get("tool_input", {}) or {}
    subagent_type = tool_input.get("subagent_type", "")
    if subagent_type:
        # Write separate adoption entry
        adoption_entry = {"ts": ..., "feature": "agent", "name": subagent_type, ...}
```

Until this enhancement is in place, agent adoption can only be counted by `Task` call
volume (not which agent), which gives partial signal.

### 5.2 Skill Adoption

`Skill` tool call tracking is already possible from metrics.jsonl. Extract `skill_name`
from tool parameters in the hook stdin.

Current baseline (metrics.jsonl, ~30 days): 2 Skill calls total — critically low adoption.

### 5.3 Hook Adoption

Each hook file in `~/.claude/hooks/` represents a registered feature. The `subagent_context_hook.py`
(SubagentStart), `session_startup_hook.py` (SessionStart), etc. write to stderr on fire.
Capture hook fire/error rates by:

1. Reading hook_stdin.log if populated
2. Monitoring code_reviews.jsonl for code_review_hook evidence
3. Reading instructions_loaded.jsonl for InstructionsLoaded hook

### 5.4 Rule Proxy Metrics

Rules cannot be observed directly. Use these proxy tool patterns:

| Rule | Proxy Signal | Tool/Pattern |
|------|-------------|--------------|
| task-execution (Complex+) | EnterPlanMode call rate | `EnterPlanMode` in metrics |
| task-execution (criteria freeze) | criteria_freeze calls | `mcp__tools-mcp__criteria_freeze` |
| mandatory-checks (gitleaks) | gitleaks_precommit hook fires | hook_health table |
| architecture-enforcement | ARCHITECTURE.md edits | Edit on ARCHITECTURE.md |
| request-clarification | AskUserQuestion calls | `AskUserQuestion` in metrics |
| gc-maintenance | gc-mcp tool calls | `mcp__gc-mcp__*` in metrics |

---

## 6. Anomaly Detection

### 6.1 Algorithm

Rolling z-score over 14-day window for daily tool call volume:

```
baseline_mean = AVG(daily_call_count) over last 14 days (excluding today)
baseline_std  = STDEV(daily_call_count) over last 14 days
z_score = (today_count - baseline_mean) / baseline_std (if std > 0)

ANOMALY if abs(z_score) > 2.0
SEVERE  if abs(z_score) > 3.0
```

**Minimum data requirement**: At least 7 days of history before anomaly detection
activates. With fewer days, flag as "insufficient baseline".

### 6.2 Anomaly Types

| Type | Trigger | Severity |
|------|---------|----------|
| `volume_drop` | daily calls < mean - 2σ | WARNING |
| `volume_spike` | daily calls > mean + 3σ | INFO (could be valid heavy work) |
| `cost_spike` | session cost > 3x rolling_avg | WARNING |
| `hook_error_surge` | hook error_rate > 5% in day | CRITICAL |
| `zero_activity` | no entries for calendar day | WARNING (could be weekend) |
| `budget_overrun` | daily_cost > 90% of daily_budget | CRITICAL |
| `unused_agent_30d` | agent not called in 30 days | INFO |
| `skill_never_used` | skill total_calls == 0 | INFO |

### 6.3 Output

Anomalies are written to `anomaly_events` table and surfaced in the dashboard.
No alerting integration in v1. Future: write to Alertmanager webhook if available.

---

## 7. Health Checks

### 7.1 Static Checks (fast, no network)

Run at dashboard startup:

- **Hook registry**: count hooks in `~/.claude/settings.json` vs expected 25
- **MCP essential**: count essential MCP servers in `~/.claude.json`
- **Session file**: `~/.claude/evaluation/data/current_session_id` exists and non-empty
- **metrics.jsonl freshness**: last entry within 24h (active usage) or file exists
- **monitoring.db exists**: if not, suggest running `monitoring_collector.py`

### 7.2 Data Quality Checks

- JSONL files parseable (no truncated lines)
- Date gaps in daily_session_stats (missing days = collection gaps)
- tool_usage_counts.json sessions vs metrics.jsonl sessions (should correlate)

---

## 8. Dashboard Design

### 8.1 Sections (CLI output)

```
╔══════════════════════════════════════════════════════════════════╗
║  Claude Code Usage Dashboard  |  2026-03-22  |  v1.0            ║
╚══════════════════════════════════════════════════════════════════╝

[HEALTH]   hooks: 25/25  mcp: 13/13  session_id: ok  metrics: fresh (4m ago)

[ANOMALIES]  (last 7 days)
  ⚠ 2026-03-20: volume_drop  total=12 (expected=87, z=-2.4)

[TOP TOOLS]  (last 7 days)
  Rank  Tool              Calls   % of total   Avg dur_ms
  1     Bash              203     25%          -
  ...

[COST TREND]  (last 7 days)
  Date        Sessions  Total USD   Avg/session
  2026-03-22  3         $1.23       $0.41

[FEATURE ADOPTION]  (last 30 days)
  Agents:  12/102 used  (12%)  — 90 agents: NEVER CALLED
  Skills:  1/103 used   (1%)   — 102 skills: NEVER CALLED
  Hooks:   8/25 fired   (32%)  — hook data from code_reviews.jsonl
  Rules:   4/14 proxied (29%)  — by proxy tool patterns

[UNUSED FEATURES]  (0 calls in 30d, sample)
  agents: academic-writer, accountant, agent-factory ... (+87 more)
  skills: (all except project-init)
```

### 8.2 CLI Interface

```
usage_dashboard.py [--period 7d|30d|90d] [--section all|health|tools|cost|adoption|anomalies]
                   [--format table|json|csv] [--db PATH]
```

---

## 9. Implementation Plan

| Phase | Deliverable | Effort |
|-------|-------------|--------|
| P1 (done) | This document | - |
| P1 (done) | `usage_dashboard.py` — reads JSONL directly | Small |
| P2 | `monitoring_collector.py` — SQLite aggregation | Medium |
| P2 | Hook enhancement — capture subagent_type | Small |
| P3 | Cron/systemd timer for daily collection | Small |
| P3 | Anomaly detection with rolling z-score | Medium |

---

## 10. Integration with Existing Tools

### MCP tools-mcp (existing)

`usage_trends` in stats.go already buckets by day and returns count+cost per bucket.
It reads from `budget_spending.jsonl` + `usage-log.jsonl`. The dashboard can call
this via MCP for cost trends, avoiding re-reading the same files.

Gap: `usage_trends` does not read `metrics.jsonl` (tool call volume, dur_ms).
Extending stats.go to read metrics.jsonl would unify all usage queries under MCP.
That is a P2 enhancement for stats.go.

### GC Integration

`gc-maintenance` rule specifies metrics.jsonl is rotated. The `monitoring.db` must be
populated BEFORE rotation. Collector should run as part of the GC pre-hook or daily
cron before GC fires. Add to gc-mcp target list: "aggregate before rotate metrics.jsonl".
