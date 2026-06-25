# Core Metrics Definition
# Version: 1.0.0 | Created: 2026-01-27

---

## Purpose

This document defines the comprehensive metric taxonomy for evaluating Claude Code agent performance. It provides standardized measurement methods, baselines, and reporting protocols to quantify agent quality, efficiency, coverage, and reliability.

**Audience:** Metrics engineers, configuration maintainers, evaluation framework developers

**Scope:** Metric definitions, measurement protocols, baseline targets, reporting formats

---

## Table of Contents

1. [Metric Taxonomy](#1-metric-taxonomy)
2. [Quality Metrics](#2-quality-metrics)
3. [Efficiency Metrics](#3-efficiency-metrics)
4. [Coverage Metrics](#4-coverage-metrics)
5. [Reliability Metrics](#5-reliability-metrics)
6. [Measurement Methods](#6-measurement-methods)
7. [Baselines & Targets](#7-baselines--targets)
8. [Reporting Protocol](#8-reporting-protocol)
9. [Implementation Integration](#9-implementation-integration)

---

## 1. Metric Taxonomy

### 1.1 Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AGENT PERFORMANCE METRICS TAXONOMY                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TIER 1: QUALITY METRICS (User-Facing)                                      │
│  ├─► Task Success Rate (%)           — Completed as requested               │
│  ├─► First-Attempt Success (%)       — No iterations needed                 │
│  ├─► Factual Accuracy (%)            — Verified against ground truth        │
│  └─► User Satisfaction (1-5 scale)   — Explicit feedback                    │
│                                                                              │
│  TIER 2: EFFICIENCY METRICS (Resource Usage)                                │
│  ├─► Tokens per Task (avg)           — Input + output tokens               │
│  ├─► Latency (ms)                    — Time to first token, total time      │
│  ├─► Cost per Task ($)               — API cost                             │
│  ├─► Cache Hit Rate (%)              — Cached vs fresh tokens               │
│  └─► Tool Call Count (avg)           — Tools invoked per task               │
│                                                                              │
│  TIER 3: COVERAGE METRICS (Configuration Completeness)                      │
│  ├─► Feature Coverage (%)            — Implemented features / total         │
│  ├─► Example Coverage (%)            — Examples per domain                  │
│  ├─► Test Coverage (%)               — Tested code / total code             │
│  └─► Gap Resolution Rate (gaps/week) — Gaps closed per time period          │
│                                                                              │
│  TIER 4: RELIABILITY METRICS (System Health)                                │
│  ├─► Uptime (%)                      — Availability SLA                     │
│  ├─► Error Rate (%)                  — Failed requests / total              │
│  ├─► Hallucination Rate (%)          — Fabricated facts detected            │
│  └─► Tool Failure Rate (%)           — Failed tool calls / total            │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Metric Categories

| Category | Focus | Primary Stakeholder | Update Frequency |
|----------|-------|---------------------|------------------|
| **Quality** | User experience, correctness | End users | Per task |
| **Efficiency** | Resource optimization | Cost managers | Per request |
| **Coverage** | Configuration completeness | Developers | Weekly |
| **Reliability** | System stability | Operations | Continuous |

### 1.3 Metric Priority

**P1 (Critical):** Quality, Efficiency (cost/latency)
**P2 (High):** Efficiency (cache, tools), Reliability (errors, hallucinations)
**P3 (Medium):** Coverage, Reliability (uptime)

---

## 2. Quality Metrics

### 2.1 Task Success Rate

**Definition:** Percentage of tasks completed successfully as requested by user.

**Measurement:**
```python
task_success_rate = (successful_tasks / total_tasks) * 100

# Success criteria:
# - User confirms completion (explicit "thanks", "looks good", etc.)
# - No error messages in response
# - No user correction needed
```

**Baseline Target:** ≥ 90%

**Data Collection:**
- Manual annotation (user feedback signals)
- Automated: absence of error keywords
- CLI flag: `claude --feedback success/fail`

**Reporting:**
```
Task Success Rate: 92.3%
├─ Total tasks: 850
├─ Successful: 785
├─ Failed: 45
└─ Incomplete: 20
```

---

### 2.2 First-Attempt Success

**Definition:** Percentage of tasks completed on first attempt without iterations.

**Measurement:**
```python
first_attempt_success = (tasks_completed_first_try / total_tasks) * 100

# First-attempt success:
# - User accepts output immediately
# - No "fix this", "update", "change" follow-ups
# - Single assistant response completes task
```

**Baseline Target:** ≥ 75%

**Data Collection:**
- Track conversation turns per task
- If task completes in 1 turn → success
- If requires 2+ turns → iteration

**Reporting:**
```
First-Attempt Success: 78.4%
├─ One-shot: 667 tasks
├─ Iterations (2-3 turns): 150 tasks
└─ Long iterations (4+ turns): 33 tasks
```

---

### 2.3 Factual Accuracy

**Definition:** Percentage of factual claims that are correct (no hallucinations).

**Measurement:**
```python
factual_accuracy = (correct_facts / total_facts_stated) * 100

# Verification methods:
# 1. Manual fact-checking (sample)
# 2. Automated: command execution validation
# 3. User correction detection ("actually", "no, it's", "wrong")
```

**Baseline Target:** ≥ 95%

**Data Collection:**
- Manual review: 10% random sample per week
- Automated: detect user corrections
- Cross-reference with authoritative sources

**Reporting:**
```
Factual Accuracy: 96.2%
├─ Total facts stated: 1,240
├─ Verified correct: 1,193
├─ Hallucinations detected: 22
└─ Unverified: 25
```

**Hallucination Categories:**
- Command syntax errors
- Package version errors
- API endpoint errors
- Statistics/numbers errors
- Citation errors (fake papers)

---

### 2.4 User Satisfaction

**Definition:** Average user rating on 1-5 scale.

**Measurement:**
```python
user_satisfaction = sum(ratings) / len(ratings)

# Rating scale:
# 5 - Excellent (exceeded expectations)
# 4 - Good (met expectations)
# 3 - Acceptable (minor issues)
# 2 - Poor (major issues)
# 1 - Terrible (unusable)
```

**Baseline Target:** ≥ 4.0

**Data Collection:**
- Explicit: `/rate <1-5>` command
- Implicit: sentiment analysis of feedback
- Periodic surveys (monthly)

**Reporting:**
```
User Satisfaction: 4.2 / 5.0
├─ 5 stars: 45%
├─ 4 stars: 38%
├─ 3 stars: 12%
├─ 2 stars: 4%
└─ 1 star: 1%

Average by domain:
├─ Security: 4.5
├─ DevOps: 4.3
├─ Engineering: 4.1
└─ Education: 4.0
```

---

## 3. Efficiency Metrics

### 3.1 Tokens per Task

**Definition:** Average tokens consumed per completed task.

**Measurement:**
```python
tokens_per_task = total_tokens / completed_tasks

# Token breakdown:
# - Input tokens (cached + fresh)
# - Output tokens
# - History tokens (conversation context)
```

**Baseline Target:** ≤ 15,000 tokens/task (average)

**Data Collection:**
- Parse API responses for token counts
- Aggregate by task type
- Track trends over time

**Reporting:**
```
Tokens per Task: 12,450 avg
├─ Input tokens: 10,200 avg
│  ├─ Cached: 9,500 (93%)
│  └─ Fresh: 700 (7%)
├─ Output tokens: 2,250 avg
└─ Total cost: $0.42 avg

By task complexity:
├─ Simple: 3,200 tokens
├─ Medium: 11,500 tokens
└─ Complex: 28,700 tokens
```

---

### 3.2 Latency

**Definition:** Time to complete response.

**Measurement:**
```python
latency_metrics = {
    "time_to_first_token": end_time - start_time,  # ms
    "total_response_time": completion_time - start_time,  # ms
    "streaming_throughput": output_tokens / (total_time / 1000)  # tokens/sec
}
```

**Baseline Target:**
- Time to first token: ≤ 1,500 ms
- Total response time: ≤ 8,000 ms (average)

**Data Collection:**
- Client-side timing hooks
- Server-side API response headers
- Network latency separate tracking

**Reporting:**
```
Latency Metrics:
├─ Time to first token: 950 ms avg (p95: 1,800 ms)
├─ Total response time: 6,200 ms avg (p95: 12,400 ms)
├─ Streaming throughput: 42 tokens/sec avg
└─ Network overhead: 120 ms avg

By model:
├─ Haiku: 450 ms / 2,100 ms
├─ Sonnet: 950 ms / 6,200 ms
└─ Opus: 1,400 ms / 11,800 ms
```

---

### 3.3 Cost per Task

**Definition:** API cost to complete task.

**Measurement:**
```python
cost_per_task = (input_cost + output_cost) / tasks_completed

# Pricing (example):
# Sonnet: $3/1M input, $15/1M output
# Haiku: $0.25/1M input, $1.25/1M output
# Opus: $15/1M input, $75/1M output
```

**Baseline Target:** ≤ $0.50/task (average)

**Data Collection:**
- Calculate from token usage
- Apply current pricing
- Track by model

**Reporting:**
```
Cost per Task: $0.42 avg
├─ Input cost: $0.31 (73%)
├─ Output cost: $0.11 (27%)
└─ Monthly projection: $252 (600 tasks)

Cost distribution:
├─ <$0.10: 15% (Haiku tasks)
├─ $0.10-$0.50: 68% (Sonnet tasks)
├─ $0.50-$2.00: 14% (complex Sonnet)
└─ >$2.00: 3% (Opus tasks)
```

---

### 3.4 Cache Hit Rate

**Definition:** Percentage of input tokens served from cache.

**Measurement:**
```python
cache_hit_rate = (cached_tokens / total_input_tokens) * 100
```

**Baseline Target:** ≥ 85%

**Data Collection:**
- API response metadata
- Aggregate by time period
- Track by content type (CLAUDE.md, modules, examples)

**Reporting:**
```
Cache Hit Rate: 92.3%
├─ Cached tokens: 8,760k
├─ Fresh tokens: 730k
├─ Total input: 9,490k
└─ Cost savings: $262/month (-78%)

By content:
├─ CLAUDE.md: 98% (stable)
├─ Modules: 94% (occasional updates)
├─ Examples: 87% (new examples)
└─ User queries: 0% (always fresh)
```

---

### 3.5 Tool Call Count

**Definition:** Average tool invocations per task.

**Measurement:**
```python
tool_call_count = total_tool_calls / completed_tasks
```

**Baseline Target:** ≤ 8 calls/task (average)

**Data Collection:**
- Hook-based tracking
- Count by tool type
- Analyze efficiency patterns

**Reporting:**
```
Tool Call Count: 6.2 avg per task
├─ Total calls: 5,270
├─ Tasks completed: 850
└─ Efficiency: 87% (low overhead)

By tool:
├─ Read: 2.1 avg
├─ Edit: 1.4 avg
├─ Bash: 1.2 avg
├─ Write: 0.8 avg
├─ Grep: 0.5 avg
└─ Glob: 0.2 avg

Outliers:
├─ <3 calls: 25% (simple tasks)
├─ 3-10 calls: 60% (typical)
└─ >10 calls: 15% (complex multi-file)
```

---

## 4. Coverage Metrics

### 4.1 Feature Coverage

**Definition:** Percentage of planned features implemented.

**Measurement:**
```python
feature_coverage = (implemented_features / total_planned_features) * 100
```

**Baseline Target:** ≥ 80%

**Data Collection:**
- Roadmap tracking
- Gap resolution tracking
- UNIFIED_IMPLEMENTATION_ROADMAP.md status

**Reporting:**
```
Feature Coverage: 85.2%
├─ Total planned: 682 gaps
├─ Implemented: 581 features
├─ In progress: 25
└─ Remaining: 76

By category:
├─ Cost optimization: 92% (23/25)
├─ Evaluation: 78% (16/21)
├─ Documentation: 95% (19/20)
└─ Orchestration: 45% (8/18)
```

---

### 4.2 Example Coverage

**Definition:** Examples per domain normalized to domain size.

**Measurement:**
```python
example_coverage = (examples_count / domain_complexity) * 100

# Domain complexity:
# - Security: 15 examples needed (high complexity)
# - DevOps: 12 examples needed
# - Engineering: 10 examples needed
# - Education: 8 examples needed
```

**Baseline Target:** ≥ 70% (all domains)

**Data Collection:**
- Count files in ~/.claude/examples/
- Categorize by domain and task type
- Quality-weight (score ≥4.0 counts 100%, <4.0 counts 50%)

**Reporting:**
```
Example Coverage: 73.5% avg
├─ Security: 80% (12/15)
├─ DevOps: 75% (9/12)
├─ Engineering: 70% (7/10)
└─ Education: 69% (5.5/8, 1 low-quality)

Gap analysis:
├─ Missing: Kubernetes security, Terraform patterns
├─ Low quality: Ansible review (score: 3.8)
└─ Recommendations: Create 5 examples (Security +2, DevOps +2, Education +1)
```

---

### 4.3 Test Coverage

**Definition:** Percentage of code covered by tests.

**Measurement:**
```python
test_coverage = (tested_lines / total_code_lines) * 100
```

**Baseline Target:** ≥ 80% (critical: ≥95%)

**Data Collection:**
- pytest --cov for Python code
- Manual verification for bash scripts
- Track by module

**Reporting:**
```
Test Coverage: 84.2%
├─ Tested lines: 4,210
├─ Total lines: 5,000
└─ Untested: 790

By component:
├─ metrics_tracker.py: 92% (critical)
├─ session_token_tracker.py: 88%
├─ caching_analytics.py: 85%
├─ context_tracker.py: 78%
└─ hooks/: 65% (needs improvement)

Critical gaps:
├─ Error handling: 72%
└─ Edge cases: 68%
```

---

### 4.4 Gap Resolution Rate

**Definition:** Gaps closed per week.

**Measurement:**
```python
gap_resolution_rate = gaps_closed / weeks_elapsed
```

**Baseline Target:** ≥ 3 gaps/week

**Data Collection:**
- Parse GAPS.md for resolved gaps
- Track resolution dates
- Calculate velocity

**Reporting:**
```
Gap Resolution Rate: 4.2 gaps/week
├─ Last 4 weeks: 17 gaps closed
├─ Trend: +15% vs previous month
└─ Projection: 218 gaps/year

By priority:
├─ P1: 1.5 gaps/week (target: 2)
├─ P2: 2.1 gaps/week (target: 3)
└─ P3: 0.6 gaps/week (target: 1)

Velocity by TIER:
├─ TIER 1: 9 gaps in 2 weeks (4.5/week)
├─ TIER 2: Projected 3.5/week
└─ TIER 3+: TBD
```

---

## 5. Reliability Metrics

### 5.1 Uptime

**Definition:** Percentage of time system is available.

**Measurement:**
```python
uptime = ((total_time - downtime) / total_time) * 100
```

**Baseline Target:** ≥ 99.5% (SLA)

**Data Collection:**
- Health check pings (every 5 min)
- API status monitoring
- User-reported outages

**Reporting:**
```
Uptime: 99.8%
├─ Total uptime: 29.94 days
├─ Downtime: 0.06 days (1.4 hours)
├─ MTBF: 720 hours
└─ MTTR: 42 minutes avg

Incidents (last month):
├─ 2026-01-15: API outage (35 min)
├─ 2026-01-22: Network issue (28 min)
└─ 2026-01-25: MCP server restart (19 min)
```

---

### 5.2 Error Rate

**Definition:** Percentage of requests that fail.

**Measurement:**
```python
error_rate = (failed_requests / total_requests) * 100
```

**Baseline Target:** ≤ 2%

**Data Collection:**
- API error responses
- Client-side exceptions
- Hook failure logs

**Reporting:**
```
Error Rate: 1.4%
├─ Total requests: 5,270
├─ Successful: 5,196
├─ Failed: 74
└─ Error types:
   ├─ API timeout: 28 (0.5%)
   ├─ Tool failure: 22 (0.4%)
   ├─ Permission denied: 15 (0.3%)
   └─ Rate limit: 9 (0.2%)

Trend: -0.3% vs last month (improving)
```

---

### 5.3 Hallucination Rate

**Definition:** Percentage of responses containing fabricated facts.

**Measurement:**
```python
hallucination_rate = (hallucinated_responses / total_responses) * 100
```

**Baseline Target:** ≤ 1%

**Data Collection:**
- Manual review (sample 5% weekly)
- User correction detection
- Fact-checking automation

**Reporting:**
```
Hallucination Rate: 0.8%
├─ Total responses: 850
├─ Hallucinations detected: 7
└─ Categories:
   ├─ Command syntax: 3
   ├─ Version numbers: 2
   ├─ Statistics: 1
   └─ Citations: 1

Mitigation:
├─ Uncertainty expressions used: 42% of responses
├─ Sources cited: 78% of factual claims
└─ Manual verification: 5% sample (target: 10%)
```

---

### 5.4 Tool Failure Rate

**Definition:** Percentage of tool calls that fail.

**Measurement:**
```python
tool_failure_rate = (failed_tool_calls / total_tool_calls) * 100
```

**Baseline Target:** ≤ 3%

**Data Collection:**
- Hook-based tracking
- Exit code monitoring
- Error log analysis

**Reporting:**
```
Tool Failure Rate: 2.1%
├─ Total tool calls: 5,270
├─ Successful: 5,159
├─ Failed: 111
└─ Failure breakdown:
   ├─ Bash (exit code ≠0): 45 (0.9%)
   ├─ Read (file not found): 28 (0.5%)
   ├─ Edit (pattern not found): 22 (0.4%)
   ├─ Write (permission denied): 12 (0.2%)
   └─ Grep (no matches): 4 (0.1%)

Recovery:
├─ Automatic retry: 68% success
├─ Fallback strategy: 22% success
└─ User intervention: 10%
```

---

## 6. Measurement Methods

### 6.1 Automated Collection

**Infrastructure:**
```python
# hooks/metric_collection_hook.py
def on_tool_execution(tool_name, args, result, duration_ms):
    """Automatically collect metrics on every tool call."""
    metrics_tracker.collect_metric(
        metric_type="tool_execution",
        value={
            "tool": tool_name,
            "success": result.exit_code == 0,
            "duration_ms": duration_ms
        },
        metadata={
            "session_id": current_session_id,
            "timestamp": datetime.now().isoformat()
        }
    )

def on_response_complete(input_tokens, output_tokens, cached_tokens, latency_ms):
    """Collect efficiency metrics."""
    metrics_tracker.collect_efficiency_metrics(
        tokens_total=input_tokens + output_tokens,
        tokens_cached=cached_tokens,
        latency_ms=latency_ms,
        cost_usd=calculate_cost(input_tokens, output_tokens, cached_tokens)
    )
```

**Integration points:**
- Pre-request hook: Start timing
- Post-request hook: Collect tokens, latency, cost
- Tool execution hook: Track tool calls, failures
- User feedback hook: Capture satisfaction ratings

---

### 6.2 Manual Measurement

**Weekly review protocol:**

```markdown
## Weekly Metrics Review Checklist

**Quality Assessment (30 min):**
- [ ] Review 10 random tasks for success rate
- [ ] Check 20 factual claims for accuracy
- [ ] Analyze 5 user corrections for hallucinations
- [ ] Calculate first-attempt success from conversation logs

**Coverage Assessment (15 min):**
- [ ] Update feature coverage from GAPS.md
- [ ] Count new examples created
- [ ] Review test coverage report
- [ ] Calculate gap resolution velocity

**Reporting (15 min):**
- [ ] Generate weekly report: `python metrics_tracker.py --report weekly`
- [ ] Identify top 3 improvement areas
- [ ] Create action items for low metrics
```

---

### 6.3 Baseline Calibration

**Initial baseline (first month):**
1. Collect metrics without targets
2. Calculate percentiles (p50, p75, p95)
3. Set targets based on:
   - p75 for quality metrics (achievable)
   - p50 for efficiency metrics (median)
   - Industry benchmarks where available

**Target adjustment (quarterly):**
- If consistently exceeding target → raise by 5%
- If consistently missing target → analyze root cause, adjust if needed
- Document target changes in CHANGELOG.md

---

## 7. Baselines & Targets

### 7.1 Target Summary

| Metric | Baseline Target | Stretch Goal | Current (Example) |
|--------|----------------|--------------|-------------------|
| **QUALITY** | | | |
| Task Success Rate | ≥90% | ≥95% | 92.3% |
| First-Attempt Success | ≥75% | ≥85% | 78.4% |
| Factual Accuracy | ≥95% | ≥98% | 96.2% |
| User Satisfaction | ≥4.0 | ≥4.5 | 4.2 |
| **EFFICIENCY** | | | |
| Tokens per Task | ≤15k | ≤10k | 12.4k |
| Time to First Token | ≤1.5s | ≤1.0s | 0.95s |
| Total Response Time | ≤8s | ≤5s | 6.2s |
| Cost per Task | ≤$0.50 | ≤$0.30 | $0.42 |
| Cache Hit Rate | ≥85% | ≥90% | 92.3% |
| Tool Call Count | ≤8 | ≤5 | 6.2 |
| **COVERAGE** | | | |
| Feature Coverage | ≥80% | ≥90% | 85.2% |
| Example Coverage | ≥70% | ≥85% | 73.5% |
| Test Coverage | ≥80% | ≥90% | 84.2% |
| Gap Resolution Rate | ≥3/week | ≥5/week | 4.2/week |
| **RELIABILITY** | | | |
| Uptime | ≥99.5% | ≥99.9% | 99.8% |
| Error Rate | ≤2% | ≤1% | 1.4% |
| Hallucination Rate | ≤1% | ≤0.5% | 0.8% |
| Tool Failure Rate | ≤3% | ≤1.5% | 2.1% |

### 7.2 Performance Bands

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PERFORMANCE RATING BANDS                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  ⭐⭐⭐⭐⭐ EXCELLENT (95-100% of stretch goals)                            │
│  ├─► All critical metrics exceed stretch goals                              │
│  ├─► Consistent high performance                                            │
│  └─► Industry-leading quality                                               │
│                                                                              │
│  ⭐⭐⭐⭐ GOOD (85-94% of stretch goals)                                    │
│  ├─► Most metrics at or above baseline                                      │
│  ├─► Some metrics exceed stretch goals                                      │
│  └─► Production-ready quality                                               │
│                                                                              │
│  ⭐⭐⭐ ACCEPTABLE (75-84% of baseline targets)                             │
│  ├─► Core metrics meet baseline                                             │
│  ├─► Some gaps in coverage or efficiency                                    │
│  └─► Usable but needs improvement                                           │
│                                                                              │
│  ⭐⭐ NEEDS IMPROVEMENT (60-74% of baseline targets)                        │
│  ├─► Multiple metrics below baseline                                        │
│  ├─► Quality or reliability concerns                                        │
│  └─► Action plan required                                                   │
│                                                                              │
│  ⭐ CRITICAL (<60% of baseline targets)                                     │
│  ├─► Severe performance issues                                              │
│  ├─► Immediate intervention needed                                          │
│  └─► Not production-ready                                                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Reporting Protocol

### 8.1 Report Types

| Report | Frequency | Audience | Content |
|--------|-----------|----------|---------|
| **Dashboard** | Real-time | Operations | Current metrics, alerts |
| **Daily** | Daily | Team | Key metrics snapshot |
| **Weekly** | Weekly | Team + Manager | Trends, top issues |
| **Monthly** | Monthly | Leadership | Strategic metrics, ROI |
| **Quarterly** | Quarterly | Executives | Business impact, roadmap |

### 8.2 Weekly Report Template

```markdown
# Weekly Metrics Report
**Week:** 2026-01-20 to 2026-01-27
**Generated:** 2026-01-27 14:00 UTC

## Executive Summary
Overall Performance: ⭐⭐⭐⭐ GOOD (89% of stretch goals)

**Highlights:**
- ✅ Cache hit rate: 92.3% (+2% vs last week)
- ✅ Gap resolution: 9 gaps closed (TIER 1 complete)
- ⚠️ Tool failure rate: 2.1% (target: <3%, acceptable)

## Quality Metrics
| Metric | Current | Target | Trend | Status |
|--------|---------|--------|-------|--------|
| Task Success | 92.3% | ≥90% | +1.2% | ✅ GOOD |
| First-Attempt | 78.4% | ≥75% | -0.5% | ✅ ACCEPTABLE |
| Factual Accuracy | 96.2% | ≥95% | +0.3% | ✅ EXCELLENT |
| Satisfaction | 4.2/5 | ≥4.0 | +0.1 | ✅ GOOD |

## Efficiency Metrics
| Metric | Current | Target | Trend | Status |
|--------|---------|--------|-------|--------|
| Tokens/Task | 12.4k | ≤15k | -800 | ✅ GOOD |
| Latency | 6.2s | ≤8s | -0.3s | ✅ GOOD |
| Cost/Task | $0.42 | ≤$0.50 | -$0.03 | ✅ EXCELLENT |
| Cache Hit | 92.3% | ≥85% | +2% | ✅ EXCELLENT |

## Coverage Metrics
- Feature Coverage: 85.2% (581/682 gaps)
- Example Coverage: 73.5% avg
- Test Coverage: 84.2%
- Gap Resolution: 4.2/week

## Reliability Metrics
- Uptime: 99.8%
- Error Rate: 1.4%
- Hallucination Rate: 0.8%
- Tool Failure Rate: 2.1%

## Top Issues
1. **First-Attempt Success declining** (-0.5%): Complex tasks requiring iteration
2. **Example Coverage gaps**: Security (need 3 more), Education (need 2.5 more)
3. **Tool failures**: Bash exit codes (45 failures, investigate)

## Action Items
- [ ] Investigate first-attempt failures (analyze 10 multi-turn conversations)
- [ ] Create missing examples (Security: K8s audit, Terraform; Education: CTF design)
- [ ] Review Bash tool usage (45 failures, most common: permission issues)

## Next Week Focus
- Complete TIER 2 Tasks 10-12 (metrics definition, R2P protocols)
- Improve first-attempt success to 80%
- Reduce tool failure rate to <2%
```

### 8.3 CLI Integration

```bash
# Generate reports
python ~/.claude/evaluation/metrics_tracker.py --report daily
python ~/.claude/evaluation/metrics_tracker.py --report weekly
python ~/.claude/evaluation/metrics_tracker.py --report monthly --format pdf

# Query specific metrics
python ~/.claude/evaluation/metrics_tracker.py --metric task_success_rate --days 7
python ~/.claude/evaluation/metrics_tracker.py --metric cache_hit_rate --compare last_month

# Set baselines
python ~/.claude/evaluation/metrics_tracker.py --set-baseline task_success_rate 90
```

---

## 9. Implementation Integration

### 9.1 File Structure

```
~/.claude/evaluation/
├── CORE_METRICS_DEFINITION.md          # This file
├── metrics_tracker.py                  # Main collection engine (UPDATED)
├── metrics/
│   ├── quality_metrics.py              # Quality metric collection (NEW)
│   ├── efficiency_metrics.py           # Efficiency metrics (EXISTS, extend)
│   ├── coverage_metrics.py             # Coverage metrics (NEW)
│   └── reliability_metrics.py          # Reliability metrics (NEW)
├── baselines/
│   ├── quality_baselines.json
│   ├── efficiency_baselines.json
│   ├── coverage_baselines.json
│   └── reliability_baselines.json
├── reports/
│   ├── daily/
│   ├── weekly/
│   └── monthly/
└── hooks/
    ├── metric_collection_hook.py       # Automated collection
    └── user_feedback_hook.py           # Satisfaction ratings
```

### 9.2 Integration with metrics_tracker.py

**Extend existing MetricsTracker class:**
```python
class MetricsTracker:
    # ... existing methods ...

    # NEW: Quality metrics
    def collect_quality_metric(self, task_id, success, first_attempt, satisfaction=None):
        """Collect quality metrics for a task."""
        pass

    # NEW: Coverage metrics
    def collect_coverage_metric(self, coverage_type, value, metadata=None):
        """Collect coverage metrics."""
        pass

    # NEW: Reliability metrics
    def collect_reliability_metric(self, metric_type, value, metadata=None):
        """Collect reliability metrics."""
        pass

    # NEW: Generate comprehensive report
    def generate_comprehensive_report(self, period='weekly', output_format='markdown'):
        """Generate report with all 4 metric categories."""
        pass
```

### 9.3 Backwards Compatibility

**Existing metrics preserved:**
- `collect_cache_metric()` → maps to Efficiency > Cache Hit Rate
- `collect_model_routing_metric()` → maps to Efficiency > Cost per Task
- `collect_session_token_metric()` → maps to Efficiency > Tokens per Task
- `collect_context_budget_metric()` → maps to Coverage > Feature Coverage

**No breaking changes** to existing code.

---

## References

### Industry Standards
- **Google SRE Book:** Monitoring metrics, SLIs, SLOs
- **DORA Metrics:** Deployment frequency, lead time, MTTR
- **SWE-bench:** Coding agent benchmarks

### Academic Research
- **Stanford HAI AI Index:** Industry metrics
- **Anthropic Model Cards:** Accuracy, bias metrics

### Tools
- **metrics_tracker.py:** Implementation
- **pytest-cov:** Test coverage
- **scipy.stats:** Statistical analysis

---

## Enforcement

**Violations of metric targets:**
- **P1 metrics below baseline**: Immediate investigation, action plan within 24h
- **P2 metrics below baseline**: Review in weekly meeting, action plan within 1 week
- **P3 metrics below baseline**: Track, address in monthly review

**Gap tracking:**
- Low metrics → GAP-EVAL-XXX in GAPS.md
- Tracked until resolved

---

**Version:** 1.0.0
**Created:** 2026-01-27
**Resolves:** GAP-OP-014 (P1, Core Metrics Definition)
**Related:** metrics_tracker.py, GAPS.md Category 24 (Evaluation)
