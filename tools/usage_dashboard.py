#!/usr/bin/env python3
"""
Claude Code Usage Dashboard

Cross-session monitoring tool that reads metrics.jsonl and spending_tracker.jsonl
to show tool usage trends, feature adoption, hook health, and anomalies.

Usage:
    python3 usage_dashboard.py [--period 7|30|90] [--section all|health|tools|cost|adoption|anomalies]
    python3 usage_dashboard.py --period 30 --section adoption
    python3 usage_dashboard.py --format json

Version: 1.0.0 (2026-03-22)
"""

import argparse
import json
import math
import os
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

HOME = Path.home()
DATA_DIR = HOME / ".claude" / "evaluation" / "data"
CLAUDE_DIR = HOME / ".claude"

METRICS_FILE = DATA_DIR / "metrics.jsonl"
SPENDING_FILE = DATA_DIR / "spending_tracker.jsonl"
BUDGET_FILE = DATA_DIR / "budget_spending.jsonl"
USAGE_COUNTS_FILE = DATA_DIR / "tool_usage_counts.json"
SESSION_ID_FILE = DATA_DIR / "current_session_id"
SETTINGS_FILE = HOME / ".claude" / "settings.json"
CLAUDE_JSON = HOME / ".claude.json"
AGENTS_DIR = HOME / ".claude" / "agents"
SKILLS_DIR = HOME / ".claude" / "skills"
RULES_DIR = HOME / ".claude" / "rules"
HOOKS_DIR = HOME / ".claude" / "hooks"

# ---------------------------------------------------------------------------
# ANSI colors (stripped when output is not a TTY)
# ---------------------------------------------------------------------------

USE_COLOR = sys.stdout.isatty()


def c(text: str, code: str) -> str:
    if not USE_COLOR:
        return text
    codes = {
        "bold": "\033[1m",
        "dim": "\033[2m",
        "red": "\033[91m",
        "yellow": "\033[93m",
        "green": "\033[92m",
        "cyan": "\033[96m",
        "blue": "\033[94m",
        "reset": "\033[0m",
    }
    return f"{codes.get(code, '')}{text}{codes['reset']}"


# ---------------------------------------------------------------------------
# Data loading helpers
# ---------------------------------------------------------------------------


def load_jsonl(path: Path, max_age_days: int = 365) -> list[dict]:
    """Load JSONL file, filter to records within max_age_days."""
    if not path.exists():
        return []
    cutoff = datetime.now(timezone.utc) - timedelta(days=max_age_days)
    records = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            # Parse timestamp
            ts_str = rec.get("ts") or rec.get("timestamp") or rec.get("created_at", "")
            if ts_str:
                try:
                    ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
                    if ts.tzinfo is None:
                        ts = ts.replace(tzinfo=timezone.utc)
                    if ts < cutoff:
                        continue
                    rec["_ts"] = ts
                except ValueError:
                    pass
            records.append(rec)
    return records


def records_in_period(records: list[dict], days: int) -> list[dict]:
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    result = []
    for r in records:
        ts = r.get("_ts")
        if ts is None or ts >= cutoff:
            result.append(r)
    return result


def to_date_str(ts: datetime) -> str:
    return ts.strftime("%Y-%m-%d")


# ---------------------------------------------------------------------------
# Inventory (static feature counts)
# ---------------------------------------------------------------------------


def load_inventory() -> dict[str, list[str]]:
    """Return lists of agent/skill/rule/hook names from filesystem."""
    inv: dict[str, list[str]] = {
        "agents": [],
        "skills": [],
        "rules": [],
        "hooks": [],
    }
    if AGENTS_DIR.exists():
        inv["agents"] = sorted(
            p.stem for p in AGENTS_DIR.glob("*.md")
            if not p.name.startswith("_")
        )
    if SKILLS_DIR.exists():
        # Skills are stored as skills/<name>/SKILL.md subdirectories
        skill_dirs = [
            p.parent.name for p in SKILLS_DIR.glob("*/SKILL.md")
            if not p.parent.name.startswith("_")
        ]
        # Also check for flat .md files (older layout)
        skill_flat = [
            p.stem for p in SKILLS_DIR.glob("*.md")
            if not p.name.startswith("_")
        ]
        inv["skills"] = sorted(set(skill_dirs + skill_flat))
    if RULES_DIR.exists():
        inv["rules"] = sorted(
            p.stem for p in RULES_DIR.glob("*.md")
        )
    if HOOKS_DIR.exists():
        inv["hooks"] = sorted(
            p.name for p in HOOKS_DIR.glob("*.py")
            if not p.name.startswith("_") and p.name != "pretool_diag.py"
        )
    return inv


# ---------------------------------------------------------------------------
# Section: Health
# ---------------------------------------------------------------------------


def check_health() -> list[tuple[str, str, str]]:
    """
    Returns list of (check_name, status, detail).
    status: 'ok', 'warn', 'error'
    """
    results = []

    # 1. Session ID file
    if SESSION_ID_FILE.exists():
        sid = SESSION_ID_FILE.read_text().strip()
        if sid:
            results.append(("session_id", "ok", sid[:8] + "..."))
        else:
            results.append(("session_id", "warn", "file empty"))
    else:
        results.append(("session_id", "warn", "file missing"))

    # 2. metrics.jsonl freshness
    if METRICS_FILE.exists():
        mtime = datetime.fromtimestamp(METRICS_FILE.stat().st_mtime, tz=timezone.utc)
        age_min = int((datetime.now(timezone.utc) - mtime).total_seconds() / 60)
        if age_min < 60:
            results.append(("metrics.jsonl", "ok", f"modified {age_min}m ago"))
        elif age_min < 1440:
            results.append(("metrics.jsonl", "ok", f"modified {age_min // 60}h ago"))
        else:
            results.append(("metrics.jsonl", "warn", f"stale ({age_min // 1440}d ago)"))
    else:
        results.append(("metrics.jsonl", "error", "file not found"))

    # 3. spending_tracker.jsonl
    if SPENDING_FILE.exists():
        results.append(("spending_tracker", "ok", f"{SPENDING_FILE.stat().st_size // 1024}KB"))
    else:
        results.append(("spending_tracker", "warn", "file not found"))

    # 4. Hooks registered in settings.json
    hook_count = 0
    if SETTINGS_FILE.exists():
        try:
            settings = json.loads(SETTINGS_FILE.read_text())
            hooks = settings.get("hooks", {})
            # Count hook commands across all events
            for event_hooks in hooks.values():
                if isinstance(event_hooks, list):
                    hook_count += len(event_hooks)
                elif isinstance(event_hooks, dict):
                    hook_count += 1
            if hook_count >= 15:
                results.append(("hooks_registered", "ok", f"{hook_count} commands"))
            else:
                results.append(("hooks_registered", "warn", f"only {hook_count} (expected 25+)"))
        except Exception:
            results.append(("hooks_registered", "warn", "could not parse settings.json"))
    else:
        results.append(("hooks_registered", "error", "settings.json not found"))

    # 5. Essential MCP servers — find max mcpServers across all project entries
    mcp_count = 0
    if CLAUDE_JSON.exists():
        try:
            cfg = json.loads(CLAUDE_JSON.read_text())
            # Top-level mcpServers
            top_mcp = cfg.get("mcpServers", {})
            max_count = len(top_mcp)
            # Check all projects entries (per-project MCP configs)
            for proj_cfg in cfg.get("projects", {}).values():
                if isinstance(proj_cfg, dict):
                    proj_mcp = proj_cfg.get("mcpServers", {})
                    if len(proj_mcp) > max_count:
                        max_count = len(proj_mcp)
            mcp_count = max_count
            expected = 13
            if mcp_count >= expected:
                results.append(("mcp_essential", "ok", f"{mcp_count} servers (max per project)"))
            else:
                results.append(("mcp_essential", "warn", f"{mcp_count}/{expected} servers"))
        except Exception:
            results.append(("mcp_essential", "warn", "could not parse .claude.json"))
    else:
        results.append(("mcp_essential", "warn", ".claude.json not found"))

    # 6. monitoring.db (optional, created by monitoring_collector.py)
    monitoring_db = DATA_DIR / "monitoring.db"
    if monitoring_db.exists():
        results.append(("monitoring_db", "ok", f"{monitoring_db.stat().st_size // 1024}KB"))
    else:
        results.append(("monitoring_db", "warn", "not found — run monitoring_collector.py to create"))

    return results


# ---------------------------------------------------------------------------
# Section: Top Tools
# ---------------------------------------------------------------------------


def top_tools(metrics: list[dict], period_days: int, top_n: int = 15) -> list[dict]:
    filtered = records_in_period(metrics, period_days)
    counts: dict[str, dict] = defaultdict(lambda: {"calls": 0, "dur_ms_sum": 0, "dur_count": 0})
    total = 0
    for r in filtered:
        tool = r.get("tool", "unknown")
        counts[tool]["calls"] += 1
        total += 1
        dur = r.get("dur_ms", 0)
        if isinstance(dur, (int, float)) and dur > 0:
            counts[tool]["dur_ms_sum"] += dur
            counts[tool]["dur_count"] += 1

    result = []
    for tool, stats in sorted(counts.items(), key=lambda x: -x[1]["calls"]):
        avg_ms = None
        if stats["dur_count"] > 0:
            avg_ms = stats["dur_ms_sum"] / stats["dur_count"]
        result.append({
            "tool": tool,
            "calls": stats["calls"],
            "pct": stats["calls"] / total * 100 if total else 0,
            "avg_dur_ms": avg_ms,
        })

    return result[:top_n]


# ---------------------------------------------------------------------------
# Section: Cost trend
# ---------------------------------------------------------------------------


def cost_trend(spending: list[dict], period_days: int) -> list[dict]:
    """
    spending_tracker.jsonl writes a running cumulative session cost on each tool call.
    To avoid double-counting, we de-duplicate by session ID and keep the LAST (max) value
    per session, which represents the final cost for that session.
    """
    filtered = records_in_period(spending, period_days)

    # Collect last-seen cost per session (cumulative total, not per-record delta)
    session_last: dict[str, dict] = {}  # sid -> {date, cost}
    for r in filtered:
        ts = r.get("_ts")
        date = to_date_str(ts) if ts else "unknown"
        sid = r.get("sid") or r.get("session_id") or "?"
        cost = r.get("cost", 0.0)
        if not isinstance(cost, (int, float)):
            try:
                cost = float(cost)
            except Exception:
                cost = 0.0
        # Keep latest record per session (highest cumulative cost = final cost)
        if sid not in session_last or cost >= session_last[sid]["cost"]:
            session_last[sid] = {"date": date, "cost": cost}

    # Aggregate de-duplicated session costs by date
    by_date: dict[str, dict] = defaultdict(lambda: {"sessions": 0, "cost": 0.0})
    for sid, info in session_last.items():
        date = info["date"]
        by_date[date]["sessions"] += 1
        by_date[date]["cost"] += info["cost"]

    result = []
    for date in sorted(by_date.keys()):
        d = by_date[date]
        sessions = d["sessions"]
        total_cost = d["cost"]
        result.append({
            "date": date,
            "sessions": sessions,
            "total_usd": total_cost,
            "avg_usd": total_cost / sessions if sessions else 0,
        })
    return result


# ---------------------------------------------------------------------------
# Section: Feature Adoption
# ---------------------------------------------------------------------------


def feature_adoption(metrics: list[dict], period_days: int) -> dict[str, Any]:
    """
    Determine which features from inventory are used.
    Returns adoption stats per feature type.
    """
    inv = load_inventory()
    filtered = records_in_period(metrics, period_days)

    # Collect tool names seen
    tools_seen: set[str] = set()
    skill_calls = 0
    agent_calls = 0
    enter_plan_calls = 0
    ask_user_calls = 0

    for r in filtered:
        tool = r.get("tool", "")
        tools_seen.add(tool)
        if tool == "Skill":
            skill_calls += 1
        if tool in ("Task", "Agent"):
            agent_calls += 1
        if tool == "EnterPlanMode":
            enter_plan_calls += 1
        if tool == "AskUserQuestion":
            ask_user_calls += 1

    # Agent adoption: we can only tell if Task/Agent was called (not which agent)
    # until the hook enhancement from MONITORING_SYSTEM.md §5.1 is implemented
    # We report agent_calls as a total, note individual tracking requires hook patch
    agent_identified: set[str] = set()  # will populate if usage_counts has agent names

    # Check tool_usage_counts.json for mcp__*-mcp__* patterns (MCP feature adoption)
    mcp_tools_seen: set[str] = set()
    for tool in tools_seen:
        if tool.startswith("mcp__"):
            mcp_tools_seen.add(tool)

    # Hooks: check code_reviews.jsonl and other hook output files for evidence
    hooks_seen: set[str] = set()
    code_reviews_file = DATA_DIR / "code_reviews.jsonl"
    if code_reviews_file.exists():
        hooks_seen.add("code_review_hook.py")
    instructions_file = DATA_DIR / "instructions_loaded.jsonl"
    if instructions_file.exists():
        hooks_seen.add("session_startup_hook.py")
    if METRICS_FILE.exists():
        hooks_seen.add("unified_tool_metrics_hook.py")
    # budget hook evidence: budget_spending.jsonl written = hook fired
    if BUDGET_FILE.exists() and BUDGET_FILE.stat().st_size > 0:
        hooks_seen.add("unified_budget_hook.py")

    # Rule proxy checks
    rules_proxied: dict[str, int] = {
        "task-execution (PlanMode)": enter_plan_calls,
        "request-clarification (AskUser)": ask_user_calls,
    }
    # criteria freeze calls
    criteria_calls = sum(
        1 for r in filtered
        if r.get("tool", "").startswith("mcp__tools-mcp__criteria")
    )
    if criteria_calls > 0:
        rules_proxied["task-execution (criteria_freeze)"] = criteria_calls

    gc_calls = sum(
        1 for r in filtered
        if r.get("tool", "").startswith("mcp__gc-mcp")
    )
    if gc_calls > 0:
        rules_proxied["gc-maintenance"] = gc_calls

    return {
        "agents": {
            "total": len(inv["agents"]),
            "task_calls": agent_calls,
            "identified": len(agent_identified),
            "note": "Individual agent tracking requires hook enhancement (see MONITORING_SYSTEM.md §5.1)",
        },
        "skills": {
            "total": len(inv["skills"]),
            "calls": skill_calls,
            "pct": 100 * skill_calls / len(inv["skills"]) if inv["skills"] else 0,
        },
        "hooks": {
            "total": len(inv["hooks"]),
            "seen": sorted(hooks_seen),
            "pct": 100 * len(hooks_seen) / len(inv["hooks"]) if inv["hooks"] else 0,
        },
        "rules": {
            "total": len(inv["rules"]),
            "proxied": rules_proxied,
        },
        "mcp_tools_seen": sorted(mcp_tools_seen),
        "inventory": inv,
    }


# ---------------------------------------------------------------------------
# Section: Anomaly Detection
# ---------------------------------------------------------------------------


def detect_anomalies(metrics: list[dict], spending: list[dict], period_days: int = 30) -> list[dict]:
    """
    Rolling z-score anomaly detection on daily tool call volume.
    Uses up to period_days of history to build baseline.
    Requires at least 7 data points.
    """
    filtered = records_in_period(metrics, period_days)

    # Build daily call counts
    daily: dict[str, int] = defaultdict(int)
    for r in filtered:
        ts = r.get("_ts")
        date = to_date_str(ts) if ts else "unknown"
        if date != "unknown":
            daily[date] += 1

    if not daily:
        return []

    dates = sorted(daily.keys())
    counts = [daily[d] for d in dates]

    anomalies = []

    # Need at least 7 days of history for meaningful baseline
    if len(counts) < 7:
        return [{
            "type": "insufficient_baseline",
            "detail": f"Only {len(counts)} days of data (need 7+). Anomaly detection not yet active.",
            "severity": "info",
        }]

    # For each day (starting from day 7), compare to prior 14-day rolling window
    window = 14
    for i in range(min(window, len(counts) - 1), len(counts)):
        start = max(0, i - window)
        baseline = counts[start:i]
        n = len(baseline)
        if n < 3:
            continue
        mean = sum(baseline) / n
        variance = sum((x - mean) ** 2 for x in baseline) / n
        std = math.sqrt(variance) if variance > 0 else 0
        observed = counts[i]
        date = dates[i]

        if std == 0:
            continue

        z = (observed - mean) / std

        if abs(z) > 2.0:
            severity = "critical" if abs(z) > 3.0 else "warning"
            atype = "volume_drop" if z < 0 else "volume_spike"
            anomalies.append({
                "date": date,
                "type": atype,
                "severity": severity,
                "observed": observed,
                "expected_mean": round(mean, 1),
                "z_score": round(z, 2),
                "detail": f"Daily calls={observed}, mean={mean:.0f}, z={z:.1f}",
            })

    # Cost spike detection from spending_tracker (de-duplicated per session)
    spending_filtered = records_in_period(spending, period_days)
    session_last_cost: dict[str, dict] = {}
    for r in spending_filtered:
        sid = r.get("sid") or r.get("session_id") or "?"
        cost = r.get("cost", 0.0)
        if not isinstance(cost, (int, float)):
            try:
                cost = float(cost)
            except Exception:
                cost = 0.0
        if sid not in session_last_cost or cost >= session_last_cost[sid]["cost"]:
            session_last_cost[sid] = {"cost": cost, "ts": r.get("_ts")}

    session_costs = [v["cost"] for v in session_last_cost.values() if v["cost"] > 0]
    if len(session_costs) >= 5:
        mean_cost = sum(session_costs) / len(session_costs)
        # Flag sessions > 3x average
        for sid, info in session_last_cost.items():
            cost = info["cost"]
            if cost > mean_cost * 3:
                ts = info.get("ts")
                anomalies.append({
                    "date": to_date_str(ts) if ts else "unknown",
                    "type": "cost_spike",
                    "severity": "warning",
                    "observed": round(cost, 4),
                    "expected_mean": round(mean_cost, 4),
                    "z_score": None,
                    "detail": f"Session cost ${cost:.4f} = {cost / mean_cost:.1f}x avg (${mean_cost:.4f})",
                })

    return anomalies


# ---------------------------------------------------------------------------
# Rendering: Table
# ---------------------------------------------------------------------------


def table(headers: list[str], rows: list[list[str]], col_widths: list[int] | None = None) -> str:
    if not rows:
        return "  (no data)\n"
    if col_widths is None:
        col_widths = [len(h) for h in headers]
        for row in rows:
            for i, cell in enumerate(row):
                if i < len(col_widths):
                    col_widths[i] = max(col_widths[i], len(str(cell)))

    fmt = "  " + "  ".join(f"{{:<{w}}}" for w in col_widths)
    lines = []
    header_line = fmt.format(*[h.ljust(col_widths[i]) for i, h in enumerate(headers)])
    lines.append(c(header_line, "dim"))
    lines.append("  " + "  ".join("-" * w for w in col_widths))
    for row in rows:
        padded = [str(row[i]) if i < len(row) else "" for i in range(len(headers))]
        lines.append(fmt.format(*padded))
    return "\n".join(lines) + "\n"


def bar_chart(value: float, max_value: float, width: int = 20) -> str:
    if max_value <= 0:
        return " " * width
    filled = int(value / max_value * width)
    return "█" * filled + "░" * (width - filled)


# ---------------------------------------------------------------------------
# Render Sections
# ---------------------------------------------------------------------------


def render_header(period_days: int) -> str:
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    title = f"Claude Code Usage Dashboard  |  {now}  |  period: {period_days}d"
    width = len(title) + 4
    return (
        c("=" * width, "cyan") + "\n"
        + c(f"  {title}  ", "bold") + "\n"
        + c("=" * width, "cyan") + "\n"
    )


def render_health(checks: list[tuple[str, str, str]]) -> str:
    lines = [c("\n[HEALTH]\n", "bold")]
    status_icons = {"ok": c("ok   ", "green"), "warn": c("warn ", "yellow"), "error": c("ERROR", "red")}
    for name, status, detail in checks:
        icon = status_icons.get(status, status)
        lines.append(f"  {icon}  {name:<22}  {detail}")
    return "\n".join(lines) + "\n"


def render_anomalies(anomalies: list[dict]) -> str:
    lines = [c("\n[ANOMALIES]\n", "bold")]
    if not anomalies:
        lines.append(c("  No anomalies detected.", "green"))
        return "\n".join(lines) + "\n"
    for a in anomalies[-10:]:  # show last 10
        sev = a.get("severity", "info")
        color = {"critical": "red", "warning": "yellow", "info": "dim"}.get(sev, "dim")
        z_str = f"  z={a['z_score']:.1f}" if a.get("z_score") is not None else ""
        lines.append(c(f"  [{sev.upper():8}]  {a['date']}  {a['type']:<20}  {a['detail']}{z_str}", color))
    return "\n".join(lines) + "\n"


def render_top_tools(tools_data: list[dict], period_days: int) -> str:
    lines = [c(f"\n[TOP TOOLS]  (last {period_days}d)\n", "bold")]
    if not tools_data:
        lines.append("  (no data)")
        return "\n".join(lines) + "\n"
    max_calls = tools_data[0]["calls"] if tools_data else 1
    headers = ["Rank", "Tool", "Calls", "%", "Bar", "Avg ms"]
    rows = []
    for i, t in enumerate(tools_data, 1):
        avg_ms = f"{t['avg_dur_ms']:.0f}" if t["avg_dur_ms"] else "-"
        bar = bar_chart(t["calls"], max_calls, 15)
        rows.append([str(i), t["tool"], str(t["calls"]), f"{t['pct']:.1f}%", bar, avg_ms])
    lines.append(table(headers, rows))
    return "\n".join(lines)


def render_cost_trend(trend_data: list[dict], period_days: int) -> str:
    lines = [c(f"\n[COST TREND]  (last {period_days}d)\n", "bold")]
    if not trend_data:
        lines.append("  (no spending data found)")
        return "\n".join(lines) + "\n"

    total_cost = sum(d["total_usd"] for d in trend_data)
    total_sessions = sum(d["sessions"] for d in trend_data)
    lines.append(f"  Total: ${total_cost:.4f}  |  Sessions: {total_sessions}  |  Days: {len(trend_data)}\n")

    # Show last 14 days max
    show = trend_data[-14:]
    max_cost = max((d["total_usd"] for d in show), default=1)
    headers = ["Date", "Sessions", "Total USD", "Avg/Session", "Bar"]
    rows = []
    for d in show:
        bar = bar_chart(d["total_usd"], max_cost, 12)
        rows.append([
            d["date"],
            str(d["sessions"]),
            f"${d['total_usd']:.4f}",
            f"${d['avg_usd']:.4f}",
            bar,
        ])
    lines.append(table(headers, rows))
    return "\n".join(lines)


def render_feature_adoption(adoption: dict, period_days: int) -> str:
    lines = [c(f"\n[FEATURE ADOPTION]  (last {period_days}d)\n", "bold")]

    # Agents
    ag = adoption["agents"]
    lines.append(f"  Agents:  Task/Agent calls={ag['task_calls']}  total_registered={ag['total']}")
    lines.append(f"           {c(ag['note'], 'dim')}")

    # Skills
    sk = adoption["skills"]
    pct_str = f"{sk['pct']:.0f}%"
    color = "green" if sk["pct"] > 20 else ("yellow" if sk["pct"] > 5 else "red")
    lines.append(f"  Skills:  {c(str(sk['calls']), color)} calls  /  {sk['total']} registered")

    # Hooks
    hk = adoption["hooks"]
    pct_str = f"{hk['pct']:.0f}%"
    color = "green" if hk["pct"] > 50 else ("yellow" if hk["pct"] > 20 else "red")
    lines.append(f"  Hooks:   {c(str(len(hk['seen'])), color)}/{hk['total']} with evidence  ({pct_str})")
    if hk["seen"]:
        seen_str = ", ".join(hk["seen"][:5])
        if len(hk["seen"]) > 5:
            seen_str += f" (+{len(hk['seen']) - 5} more)"
        lines.append(f"           seen: {c(seen_str, 'dim')}")

    # Rules (proxy)
    rl = adoption["rules"]
    proxied = rl["proxied"]
    lines.append(f"  Rules:   {len(proxied)}/{rl['total']} rule proxies observed")
    for rule, count in proxied.items():
        lines.append(f"           {c(rule, 'dim')}: {count} calls")

    # MCP tools
    mcp = adoption["mcp_tools_seen"]
    if mcp:
        lines.append(f"\n  MCP tools seen ({len(mcp)}):")
        for m in mcp[:10]:
            lines.append(f"    {c(m, 'dim')}")
        if len(mcp) > 10:
            lines.append(f"    ... +{len(mcp) - 10} more")

    return "\n".join(lines) + "\n"


def render_unused_features(adoption: dict, period_days: int) -> str:
    lines = [c(f"\n[UNUSED FEATURES]  (0 calls in {period_days}d)\n", "bold")]

    inv = adoption["inventory"]

    # Skills: if Skill calls == 0, all skills are unused
    sk = adoption["skills"]
    if sk["calls"] == 0:
        lines.append(c(f"  Skills: ALL {sk['total']} skills have 0 recorded calls", "red"))
        lines.append(c("  NOTE: Skill tool usage is low — consider if skills are being invoked correctly", "yellow"))
    else:
        lines.append(f"  Skills: {sk['calls']} calls recorded (individual tracking limited)")

    # Hooks not seen
    hk = adoption["hooks"]
    hooks_not_seen = [h for h in inv["hooks"] if h not in hk["seen"]]
    if hooks_not_seen:
        lines.append(c(f"\n  Hooks with no observed evidence ({len(hooks_not_seen)}):", "yellow"))
        for h in hooks_not_seen[:10]:
            lines.append(f"    {h}")
        if len(hooks_not_seen) > 10:
            lines.append(f"    ... +{len(hooks_not_seen) - 10} more")

    # Agents: no individual tracking yet
    ag = adoption["agents"]
    lines.append(c(f"\n  Agents: {ag['total']} registered, individual adoption tracking requires hook enhancement", "dim"))
    lines.append(c("  See MONITORING_SYSTEM.md §5.1 for implementation plan", "dim"))

    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# JSON output
# ---------------------------------------------------------------------------


def output_json(
    health: list,
    anomalies: list,
    tools_data: list,
    trend_data: list,
    adoption: dict,
    period_days: int,
) -> str:
    # Clean adoption: remove non-serializable sets
    clean_adoption = {
        "agents": adoption["agents"],
        "skills": adoption["skills"],
        "hooks": {
            "total": adoption["hooks"]["total"],
            "seen": adoption["hooks"]["seen"],
            "pct": adoption["hooks"]["pct"],
        },
        "rules": adoption["rules"],
        "mcp_tools_seen": adoption["mcp_tools_seen"],
    }
    out = {
        "generated": datetime.now(timezone.utc).isoformat(),
        "period_days": period_days,
        "health": [{"check": c[0], "status": c[1], "detail": c[2]} for c in health],
        "anomalies": anomalies,
        "top_tools": tools_data,
        "cost_trend": trend_data,
        "feature_adoption": clean_adoption,
    }
    return json.dumps(out, indent=2, default=str)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Claude Code cross-session usage dashboard",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 usage_dashboard.py
  python3 usage_dashboard.py --period 30
  python3 usage_dashboard.py --section adoption
  python3 usage_dashboard.py --section tools --period 7
  python3 usage_dashboard.py --format json > report.json
        """,
    )
    parser.add_argument(
        "--period", type=int, default=7,
        help="Analysis window in days (default: 7)",
    )
    parser.add_argument(
        "--section",
        choices=["all", "health", "tools", "cost", "adoption", "anomalies"],
        default="all",
        help="Which section to show (default: all)",
    )
    parser.add_argument(
        "--format",
        choices=["table", "json"],
        default="table",
        help="Output format (default: table)",
    )
    parser.add_argument(
        "--top", type=int, default=15,
        help="Top N tools to show (default: 15)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    period = args.period
    section = args.section
    fmt = args.format

    # Load data (max 90 days for anomaly baseline)
    load_days = max(period, 90)
    metrics = load_jsonl(METRICS_FILE, max_age_days=load_days)
    spending = load_jsonl(SPENDING_FILE, max_age_days=load_days)

    # Compute all sections
    health = check_health()
    anomalies = detect_anomalies(metrics, spending, period_days=load_days)
    # Filter anomalies to requested period
    period_cutoff = (datetime.now(timezone.utc) - timedelta(days=period)).strftime("%Y-%m-%d")
    anomalies_filtered = [a for a in anomalies if a.get("date", "0") >= period_cutoff]
    tools_data = top_tools(metrics, period, top_n=args.top)
    trend_data = cost_trend(spending, period)
    adoption = feature_adoption(metrics, period)

    if fmt == "json":
        print(output_json(health, anomalies_filtered, tools_data, trend_data, adoption, period))
        return

    # Table output
    out_parts = []

    if section == "all":
        out_parts.append(render_header(period))
        out_parts.append(render_health(health))
        out_parts.append(render_anomalies(anomalies_filtered))
        out_parts.append(render_top_tools(tools_data, period))
        out_parts.append(render_cost_trend(trend_data, period))
        out_parts.append(render_feature_adoption(adoption, period))
        out_parts.append(render_unused_features(adoption, period))
    elif section == "health":
        out_parts.append(render_health(health))
    elif section == "anomalies":
        out_parts.append(render_anomalies(anomalies_filtered))
    elif section == "tools":
        out_parts.append(render_top_tools(tools_data, period))
    elif section == "cost":
        out_parts.append(render_cost_trend(trend_data, period))
    elif section == "adoption":
        out_parts.append(render_feature_adoption(adoption, period))
        out_parts.append(render_unused_features(adoption, period))

    print("".join(out_parts))


if __name__ == "__main__":
    main()
