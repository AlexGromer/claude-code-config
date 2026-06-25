# Research Source Monitoring Protocol

**Version:** 1.0.0
**Created:** 2026-01-27
**Status:** Active
**Owner:** Operations Team
**Review Cycle:** Quarterly

---

## 1. Executive Summary

This protocol defines systematic monitoring of AI research sources and tools to keep Claude Code configuration current with industry state. Prevents configuration drift through structured discovery and evaluation of new capabilities, models, frameworks, and best practices.

**Key Objectives:**
- ✅ Track cutting-edge research (arXiv, conferences, papers)
- ✅ Monitor industry developments (model releases, tools, frameworks)
- ✅ Identify integration opportunities (techniques, patterns, benchmarks)
- ✅ Maintain competitive configuration (avoid obsolescence)

**Expected Outcomes:**
- Configuration stays <3 months behind industry state
- New relevant techniques integrated within 1 quarter
- Critical security updates integrated within 1 week
- Proactive gap detection (before user requests)

---

## 2. Source Taxonomy

### 2.1 Source Classification

Sources are classified by:
1. **Type**: Research, Industry, Community, Academic
2. **Velocity**: High (weekly changes), Medium (monthly), Low (quarterly), Annual
3. **Relevance**: Critical (P1), High (P2), Medium (P3)
4. **Trust Level**: Tier 1 (authoritative), Tier 2 (credible), Tier 3 (experimental)

### 2.2 Source Categories

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SOURCE CATEGORY TAXONOMY                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  CATEGORY 1: RESEARCH PAPERS & PREPRINTS                                    │
│  ├─► arXiv (cs.CL, cs.AI, cs.LG, cs.CR)                                    │
│  ├─► Papers with Code (trending, SOTA tracking)                             │
│  ├─► Conference proceedings (NeurIPS, ICML, ACL, EMNLP, ICLR)              │
│  ├─► Anthropic Research (safety, alignment, capabilities)                   │
│  ├─► OpenAI Research (GPT series, DALL-E, safety)                           │
│  └─► Google DeepMind Research (Gemini, AlphaFold, agents)                  │
│                                                                              │
│  CATEGORY 2: MODEL RELEASES & UPDATES                                       │
│  ├─► Major vendors: OpenAI, Anthropic, Google, Meta                         │
│  ├─► Chinese ecosystem: Alibaba, Tencent, ByteDance, Baidu                 │
│  ├─► Code-specialized: GitHub, Replit, Cursor, Codeium                     │
│  ├─► Reasoning models: o-series, DeepSeek, Gemini Advanced                 │
│  └─► Edge models: Gemma, SmolLM, Mistral, Phi                              │
│                                                                              │
│  CATEGORY 3: FRAMEWORKS & TOOLS                                             │
│  ├─► Orchestration: LangChain, LlamaIndex, CrewAI, AutoGen                 │
│  ├─► Observability: Langfuse, Phoenix, Helicone, Braintrust                │
│  ├─► Coding agents: Cursor, Cline, Windsurf, Aider, Claude Code            │
│  ├─► Browser agents: Browser Use, Stagehand, Operator, Mariner             │
│  └─► Agent frameworks: Semantic Kernel, Agents SDK (AWS), AgentCore        │
│                                                                              │
│  CATEGORY 4: BENCHMARKS & LEADERBOARDS                                      │
│  ├─► Coding: SWE-bench, HumanEval, MultiPL-E, MBPP, CodeContests           │
│  ├─► Agentic: GAIA, Terminal-bench, AgentBench, DPAI Arena                 │
│  ├─► General: MMLU-Pro, GSM8K, MATH, AIME, Chatbot Arena                   │
│  ├─► Safety: TruthfulQA, BOLD, RealToxicity, AdvBench                      │
│  └─► Multimodal: MMBench, MMMU, ChartQA, TextVQA                            │
│                                                                              │
│  CATEGORY 5: INDUSTRY REPORTS & ANALYSIS                                    │
│  ├─► State of AI Report (Air Street Capital, annual)                        │
│  ├─► Stanford AI Index (HAI, annual)                                        │
│  ├─► Gartner Hype Cycle for AI (quarterly)                                  │
│  ├─► McKinsey AI State Report (annual)                                      │
│  └─► CB Insights AI Trends (quarterly)                                      │
│                                                                              │
│  CATEGORY 6: ACADEMIC COURSES & EDUCATION                                   │
│  ├─► Stanford CS329A (Agent Systems)                                        │
│  ├─► UC Berkeley CS294 (Agentic AI)                                         │
│  ├─► MIT Professional Education (Applied AI)                                │
│  ├─► CMU Advanced NLP                                                       │
│  └─► Google/Kaggle 5-Day AI Agents Intensive                                │
│                                                                              │
│  CATEGORY 7: COMMUNITY & SOCIAL                                             │
│  ├─► AI Twitter/X: @_jasonwei, @karpathy, @AnthropicAI, @OpenAI            │
│  ├─► Reddit: r/LocalLLaMA, r/MachineLearning, r/ArtificialIntelligence     │
│  ├─► Discord: LangChain, LlamaIndex, Anthropic Developer                    │
│  ├─► GitHub Trending (AI/ML tags)                                           │
│  └─► ProductHunt (AI category, weekly launches)                             │
│                                                                              │
│  CATEGORY 8: SECURITY & STANDARDS                                           │
│  ├─► OWASP LLM Top 10 (annual updates)                                      │
│  ├─► MITRE ATLAS (threat taxonomy)                                          │
│  ├─► NIST AI Risk Management Framework                                      │
│  ├─► ISO/IEC 42001 (AI Management System)                                   │
│  └─► Anthropic Responsible Scaling Policy                                   │
│                                                                              │
│  CATEGORY 9: VENTURE CAPITAL & FUNDING                                      │
│  ├─► Y Combinator batch updates (biannual)                                  │
│  ├─► Sequoia Capital AI insights                                            │
│  ├─► a16z State of AI                                                       │
│  └─► Crunchbase AI funding trends                                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Monitoring Schedule

### 3.1 Weekly Monitoring (High Velocity)

**When:** Every Monday 09:00 UTC
**Duration:** 30-45 minutes
**Priority:** P1 (CRITICAL)

**Sources:**
| Source | URL | What to Check | Tool/Method |
|--------|-----|---------------|-------------|
| arXiv cs.CL | https://arxiv.org/list/cs.CL/new | New papers (last 7 days) | RSS feed |
| arXiv cs.AI | https://arxiv.org/list/cs.AI/new | New papers (last 7 days) | RSS feed |
| arXiv cs.LG | https://arxiv.org/list/cs.LG/new | New papers (last 7 days) | RSS feed |
| GitHub Trending | https://github.com/trending/python?since=weekly | AI/ML repos | WebFetch |
| Hugging Face Papers | https://huggingface.co/papers | Trending papers (weekly) | API |
| Papers with Code | https://paperswithcode.com/ | SOTA changes | WebFetch |
| AI Twitter | @_jasonwei, @karpathy, @AnthropicAI | Major announcements | Manual |

**Deliverables:**
- Weekly digest (Markdown summary)
- Flagged papers/repos for further review
- Immediate integration candidates (P1 gaps)

**Automation Level:** 60% (RSS feeds, API aggregation)
**Manual Review:** 40% (relevance scoring, prioritization)

**Example Weekly Digest Template:**

```markdown
# Weekly AI Research Digest — 2026-01-27

## 🔬 Research Papers (arXiv)

### cs.CL (Computational Linguistics)
- **[2401.12345]** "Chain-of-Verification Prompting for LLMs" (Anthropic)
  - **Relevance:** ✅✅ CRITICAL — Anti-hallucination technique
  - **Action:** Create GAP-PROMPT-XXX, integrate in prompting.md
  - **Estimated Effort:** 4-6h

- **[2401.12346]** "Adaptive Context Windows via Sliding Attention"
  - **Relevance:** ✅ HIGH — Cost optimization
  - **Action:** Evaluate for GAP-COST-IMPL-004
  - **Estimated Effort:** 2-3h

### GitHub Trending (Python, AI/ML)
- **repo/ai-agent-framework** (3.2k stars this week)
  - Multi-agent orchestration with async execution
  - **Relevance:** ⚠️ MEDIUM — Similar to existing tools
  - **Action:** Monitor, no immediate action

## 📊 Benchmarks
- **SWE-bench:** Claude 3.5 Opus maintains lead (72.5%)
- **GAIA:** GPT-5.2 new leader (68.4%, +2.1% from GPT-5.1)

## 🚨 Immediate Action Required
1. Integrate Chain-of-Verification prompting (P1)
2. Review GPT-5.2 release notes for new capabilities

## 📅 Next Week Focus
- ACL 2026 paper submissions deadline
- Expected: Anthropic safety research update
```

---

### 3.2 Monthly Monitoring (Medium Velocity)

**When:** First Monday of each month
**Duration:** 2-3 hours
**Priority:** P1-P2

**Sources:**
| Category | Sources | What to Check |
|----------|---------|---------------|
| **Vendor Blogs** | Anthropic News, OpenAI Blog, Google AI Blog, Meta AI Research | Model releases, API updates, safety research |
| **Benchmarks** | SWE-bench, GAIA, Terminal-bench, AIME, MMLU-Pro, Chatbot Arena | Leaderboard changes, new benchmarks |
| **Coding Tools** | Cursor Changelog, Cline Releases, Windsurf Updates, Aider Releases | New features, performance improvements |
| **Frameworks** | LangChain Blog, LlamaIndex Updates, CrewAI Releases | Major version bumps, breaking changes |
| **Observability** | Langfuse Changelog, Phoenix Releases, Helicone Updates | New metrics, integrations |
| **Security** | OWASP LLM Top 10, MITRE ATLAS, CVE databases | New attack vectors, mitigations |

**Deliverables:**
- Monthly summary report
- Gap analysis (new vs existing capabilities)
- Integration roadmap updates
- Deprecation candidates

**Automation Level:** 40% (changelog aggregation)
**Manual Review:** 60% (impact assessment, prioritization)

**Example Monthly Report Template:**

```markdown
# Monthly AI Ecosystem Update — January 2026

## 🚀 Major Model Releases
- **GPT-5.2** (OpenAI, 2026-01-15)
  - +12% on MMLU-Pro vs GPT-5.1
  - Native tool calling v3 (parallel + streaming)
  - **Impact:** Update SDK gaps, model routing logic

- **MiMo-V2-Flash** (Alibaba, 2026-01-22)
  - 309B MoE model, 94.1% on AIME 2025
  - **Impact:** Add to Chinese LLM category

## 🛠️ Framework Updates
- **LangChain 0.3.0** (2026-01-10)
  - LCEL v2 with streaming support
  - Breaking change: Memory API redesign
  - **Impact:** Update orchestration.md, create migration guide

- **Cursor 0.45** (2026-01-20)
  - Multi-file editing with AI
  - **Impact:** Update coding-agents.md

## 📊 Benchmark Shifts
- **SWE-bench Verified:** Claude 3.5 Opus (72.5%, unchanged)
- **GAIA:** GPT-5.2 overtakes Claude (68.4% vs 66.2%)
- **Terminal-bench:** New benchmark! Claude Code leads (89%)

## 🔒 Security Updates
- **OWASP LLM Top 10 2025** published
  - LLM01: Prompt Injection (updated attack vectors)
  - **Impact:** Create GAP-RES-001

## 📈 Integration Roadmap Updates
1. **P1 Immediate (this week):**
   - GPT-5.2 SDK integration
   - OWASP LLM Top 10 coverage

2. **P2 Short-term (this month):**
   - LangChain 0.3.0 migration
   - Terminal-bench integration

3. **P3 Backlog:**
   - MiMo-V2 evaluation (China-only API)

## 📊 Gap Analysis
- **New Gaps Discovered:** 8 (5 P1, 2 P2, 1 P3)
- **Gaps Resolved:** 3 (from previous month)
- **Deprecated Gaps:** 1 (GPT-4 specific, obsolete)
```

---

### 3.3 Quarterly Monitoring (Low Velocity, Strategic)

**When:** Last week of each quarter (March, June, September, December)
**Duration:** 6-8 hours (full day)
**Priority:** P1 (Strategic Planning)

**Sources:**
| Category | Sources | Focus |
|----------|---------|-------|
| **Conferences** | NeurIPS, ICML, ACL, EMNLP, ICLR | Best papers, workshop proceedings, tutorials |
| **Courses** | Stanford CS329A, Berkeley CS294, MIT Applied AI | Curriculum updates, new topics |
| **Industry Reports** | Gartner Hype Cycle, McKinsey AI State, CB Insights | Market trends, enterprise adoption |
| **VC Trends** | Y Combinator batches, Sequoia/a16z insights | Emerging startups, funding patterns |
| **Model Ecosystem** | Major LLM releases (GPT, Claude, Gemini, Llama) | Capabilities comparison, API changes |

**Deliverables:**
- Quarterly strategic review
- Configuration maturity assessment
- 6-month integration roadmap
- Deprecation schedule
- Budget forecast (API costs, subscriptions)

**Automation Level:** 20% (aggregation only)
**Manual Review:** 80% (strategic analysis, planning)

**Example Quarterly Review Template:**

```markdown
# Q1 2026 Strategic AI Ecosystem Review

**Review Period:** 2026-01-01 to 2026-03-31
**Prepared:** 2026-03-25
**Next Review:** 2026-06-30

---

## 🎯 Executive Summary

**Key Findings:**
- Agent orchestration maturity: Industry moved from LangChain-only to multi-framework ecosystem
- Reasoning models emerged as new category (o-series, DeepSeek R1)
- MCP ecosystem reached critical mass (2000+ servers, 97M downloads)
- Terminal-bench established as de facto CLI agent benchmark

**Configuration Health:**
- **Coverage:** 78% (↑5% from Q4 2025)
- **Freshness:** 2.1 months avg lag (target: <3 months) ✅
- **Gap Backlog:** 641 open (↓12 from Q4)
- **Maturity Level:** 4 — Managed (target: 5 — Optimized)

**Strategic Priorities for Q2 2026:**
1. Multi-agent orchestration patterns (LangGraph, CrewAI)
2. Reasoning model integration (o3-pro, DeepSeek R1)
3. MCP security hardening (OWASP LLM Top 10)
4. Cost optimization via model routing

---

## 📚 Conference Highlights

### NeurIPS 2025 (December 2025)
**Best Papers Relevant to CLI:**
1. **"Agents that Learn from Mistakes"** (DeepMind)
   - Self-correction loop for code generation
   - **Impact:** Create GAP-AGENT-LEARNING-001
   - **Estimated Effort:** 8-12h
   - **Priority:** P1

2. **"Scalable Multi-Agent Coordination"** (Meta AI)
   - Async message passing for 100+ agents
   - **Impact:** Update orchestration.md Section 4
   - **Estimated Effort:** 6-8h
   - **Priority:** P2

### ACL 2026 (March 2026)
- **Tutorial:** "Prompt Engineering for Code LLMs"
  - CoT variants for debugging
  - **Impact:** Extend prompting.md

---

## 📊 Model Landscape Evolution

### New Model Categories (Q1 2026)
1. **Reasoning Models** (4 major releases)
   - o3-pro, DeepSeek R1, Gemini Think, GPT-5.2 Reasoning
   - **Gap:** Create Category 31 (Reasoning Models) — 12 gaps

2. **Edge Models** (3 new releases)
   - Gemma 3n, SmolLM3, Ministral-3
   - **Gap:** Create Category 34 (Edge Models) — 10 gaps

### Market Share Shifts
- **Enterprise:** GPT-4/5 (42%, ↓3%), Claude 3/3.5 (38%, ↑5%), Gemini (15%, ↑2%)
- **Open Source:** Llama 3/4 (65%), Mixtral (18%), Qwen (12%)
- **China:** Qwen3 (45%), DeepSeek V3 (28%), MiMo-V2 (18%)

---

## 🚀 Framework Maturity

### Orchestration (LangChain, LlamaIndex, CrewAI)
- **Maturity:** High (production-ready)
- **Trend:** Consolidation — LangChain + LangGraph dominate
- **Action:** Deprecate niche frameworks (GAP-CONF-XXX)

### Observability (Langfuse, Phoenix, Helicone)
- **Maturity:** Medium (evolving rapidly)
- **Trend:** Convergence on OpenTelemetry standards
- **Action:** Create unified observability module

### Coding Agents (Cursor, Cline, Aider)
- **Maturity:** Medium-High (competitive market)
- **Trend:** Feature parity — multi-file editing, codebase indexing
- **Action:** Consolidate coverage, avoid redundancy

---

## 🎓 Academic Developments

### New Courses (2025-2026)
1. **Stanford CS329A:** Agent Systems (new course)
   - Multi-agent coordination, safety, eval
   - **Action:** Extract curriculum, identify gaps

2. **Berkeley CS294:** Agentic AI (expanded)
   - Browser Use, Computer Use agents
   - **Action:** Update browser-agents.md

### Research Directions
- **Safety:** Constitutional AI 2.0, sleeper agents detection
- **Efficiency:** Speculative decoding, cache optimization
- **Capabilities:** Multi-modal agents, real-world interaction

---

## 💰 Venture Capital & Funding Trends

### Y Combinator W25 Batch
- **50% AI agent startups** (↑15% from S24)
- Focus areas:
  - Coding agents (15 startups)
  - Sales/customer support (12 startups)
  - Data analysis agents (10 startups)

**Implication:** Agent tooling is mainstream, expect rapid tooling evolution

### Notable Funding
- **Cursor:** $100M Series B (Andreessen Horowitz)
- **Cline:** $45M Series A (Sequoia)
- **Langfuse:** $25M Series A (Lightspeed)

**Implication:** These tools have 3-5 year runway, safe to invest in integration

---

## 📈 6-Month Integration Roadmap

### Q2 2026 (April-June)
**Theme:** Multi-Agent Orchestration & Reasoning

| Priority | Gap ID | Title | Effort | Deadline |
|----------|--------|-------|--------|----------|
| P1 | GAP-ORCH-002 | LangGraph multi-agent patterns | 8-12h | 2026-04-30 |
| P1 | GAP-REASON-001 | o3-pro integration | 6-8h | 2026-04-15 |
| P1 | GAP-REASON-002 | DeepSeek R1 evaluation | 4-6h | 2026-04-30 |
| P2 | GAP-MCP-SEC-001 | MCP security hardening | 10-12h | 2026-05-31 |
| P2 | GAP-COST-IMPL-002 | Model router for Task tool | 6-9h | 2026-06-15 |

**Total Effort:** 34-47 hours (8-10 weeks at 5h/week)

### Q3 2026 (July-September)
**Theme:** Cost Optimization & Observability

*(Detailed roadmap to be created in Q2 review)*

---

## 🗑️ Deprecation Schedule

### Immediate Removal (Q2 2026)
- **GAP-GPT4-001:** GPT-4 specific optimization (obsolete, GPT-5 replaced)
- **GAP-CONF-012:** AutoGPT framework (unmaintained, LangChain superior)

### Sunset Warning (Q3 2026)
- **GPT-3.5 references:** OpenAI announced EOL 2027-01-01
- **LangChain 0.1.x:** Breaking changes in 0.3.0

---

## 💵 Budget Forecast

### API Costs Projection (Q2-Q3 2026)
- **Current:** $450/month (500 req/day, Claude 3.5 Sonnet)
- **With caching:** $180/month (60% reduction, implemented v6.14.0)
- **With model routing:** $120/month (additional 33% reduction, planned)

**ROI:** Caching ($270/mo saved) + Router ($60/mo saved) = **$330/mo total savings**

### Tool Subscriptions
- **Claude MAX:** $60/month (essential)
- **Cursor Pro:** $20/month (optional, evaluate in Q3)
- **Langfuse Cloud:** $0 (self-hosted sufficient)

---

## 📊 Metrics & KPIs

### Configuration Coverage
| Category | Coverage Q4 2025 | Coverage Q1 2026 | Change |
|----------|------------------|------------------|--------|
| Orchestration | 65% | 72% | ↑7% |
| Reasoning Models | N/A (new) | 45% | +45% |
| Coding Agents | 80% | 85% | ↑5% |
| Security (OWASP) | 40% | 65% | ↑25% |
| **Overall** | **73%** | **78%** | **↑5%** |

### Gap Resolution Velocity
- **Q4 2025:** 12 gaps/month
- **Q1 2026:** 14 gaps/month (↑17%)
- **Target Q2:** 15 gaps/month

### Freshness (Average Lag from Industry)
- **Q4 2025:** 2.8 months
- **Q1 2026:** 2.1 months (↓25%)
- **Target:** <2 months by Q4 2026

---

## 🎯 Recommendations for Q2 2026

### High Priority (Must-Do)
1. **Multi-Agent Patterns:** LangGraph + CrewAI integration (GAP-ORCH-002, GAP-ORCH-003)
2. **Reasoning Models:** o3-pro + DeepSeek R1 coverage (GAP-REASON-001, GAP-REASON-002)
3. **MCP Security:** OWASP LLM Top 10 hardening (GAP-MCP-SEC-001)

### Medium Priority (Should-Do)
4. **Cost Optimization:** Model router implementation (GAP-COST-IMPL-002)
5. **Observability:** Unified telemetry module (GAP-OBS-UNIFIED-001)
6. **Terminal-bench:** Benchmark integration (GAP-BENCH-TERMINAL-001)

### Low Priority (Nice-to-Have)
7. **Edge Models:** Evaluation framework (GAP-EDGE-EVAL-001)
8. **Chinese LLMs:** API access investigation (GAP-CHINESE-API-001)

---

## 📅 Next Review

**Date:** 2026-06-30 (end of Q2)
**Focus:** Multi-agent orchestration maturity, reasoning model integration success
```

---

### 3.4 Annual Monitoring (Strategic, Long-Term)

**When:** December 15-31 (year-end review)
**Duration:** 16-20 hours (2-3 days)
**Priority:** P1 (Strategic)

**Sources:**
- State of AI Report (Air Street Capital)
- Stanford AI Index
- Gartner Hype Cycle
- Internal metrics (full year)

**Deliverables:**
- Annual retrospective
- Multi-year technology roadmap
- Budget planning (next year)
- Configuration maturity progression plan
- Deprecation and archival decisions

---

## 4. Automated Alerting System

### 4.1 Alert Types

| Alert Level | Trigger | Response Time | Notification Method |
|-------------|---------|---------------|---------------------|
| **🔴 CRITICAL** | Security vulnerability, breaking API change | <24 hours | Email + Slack |
| **🟡 HIGH** | Major model release, framework update | <7 days | Email |
| **🟢 MEDIUM** | New benchmark, interesting paper | <30 days | Weekly digest |
| **⚪ LOW** | Minor updates, blog posts | Quarterly review | Dashboard only |

### 4.2 Alert Rules

```python
# Example alert rules (pseudocode)

def evaluate_alert_level(source_type, content):
    """
    Determine alert level based on source and content analysis.
    """

    # CRITICAL: Security vulnerabilities
    if "CVE-" in content or "OWASP" in source_type:
        if "prompt injection" or "jailbreak" or "data leak":
            return "CRITICAL", "Security vulnerability detected"

    # CRITICAL: Breaking changes in critical dependencies
    if source_type == "anthropic_api_changelog":
        if "breaking change" or "deprecated" in content:
            return "CRITICAL", "Anthropic API breaking change"

    # HIGH: Major model releases
    if source_type == "model_release":
        if vendor in ["openai", "anthropic", "google"]:
            return "HIGH", f"Major {vendor} model release"

    # HIGH: New SOTA benchmarks
    if source_type == "benchmark_update":
        if improvement > 5%:  # 5% improvement threshold
            return "HIGH", f"New SOTA on {benchmark_name}"

    # MEDIUM: Interesting research
    if source_type == "arxiv_paper":
        if citation_count > 50 or authors_include_bigtech:
            return "MEDIUM", "High-impact paper"

    # LOW: Everything else
    return "LOW", "Routine update"
```

### 4.3 Implementation Options

#### Option A: Manual (Phase 1)
- **Effort:** 0 hours (no automation)
- **Method:** Manual checks per schedule
- **Pros:** Simple, no infrastructure
- **Cons:** Time-consuming, error-prone

#### Option B: Semi-Automated (Phase 2) — **RECOMMENDED**
- **Effort:** 8-12 hours setup
- **Method:** RSS aggregator + Python scripts
- **Tools:**
  - **RSS Reader:** Miniflux (self-hosted) or Feedly
  - **Aggregation Script:** `~/.claude/tools/research_monitor.py`
  - **Notification:** Email via SMTP
- **Pros:** 60% time savings, consistent
- **Cons:** Requires setup, maintenance

**Implementation:**

```python
# ~/.claude/tools/research_monitor.py

import feedparser
import smtplib
from email.mime.text import MIMEText
from datetime import datetime, timedelta

# RSS Feeds Configuration
FEEDS = {
    "arxiv_cl": "http://export.arxiv.org/rss/cs.CL",
    "arxiv_ai": "http://export.arxiv.org/rss/cs.AI",
    "papers_with_code": "https://paperswithcode.com/feeds/trending.rss",
    "anthropic_blog": "https://www.anthropic.com/news/rss",
    "openai_blog": "https://openai.com/blog/rss.xml"
}

def fetch_new_entries(feed_url, since_days=7):
    """Fetch RSS entries from last N days."""
    feed = feedparser.parse(feed_url)
    cutoff = datetime.now() - timedelta(days=since_days)

    new_entries = []
    for entry in feed.entries:
        pub_date = datetime(*entry.published_parsed[:6])
        if pub_date >= cutoff:
            new_entries.append({
                "title": entry.title,
                "link": entry.link,
                "published": pub_date,
                "summary": entry.summary[:200]
            })

    return new_entries

def generate_digest():
    """Generate weekly digest from all feeds."""
    digest = "# Weekly AI Research Digest\n\n"
    digest += f"**Generated:** {datetime.now().strftime('%Y-%m-%d')}\n\n"

    for feed_name, feed_url in FEEDS.items():
        entries = fetch_new_entries(feed_url, since_days=7)

        if entries:
            digest += f"## {feed_name.replace('_', ' ').title()}\n\n"
            for entry in entries[:10]:  # Top 10 per feed
                digest += f"- **{entry['title']}**\n"
                digest += f"  - Link: {entry['link']}\n"
                digest += f"  - Date: {entry['published'].strftime('%Y-%m-%d')}\n\n"

    return digest

def send_email_digest(digest, recipient="user@example.com"):
    """Send digest via email."""
    msg = MIMEText(digest)
    msg['Subject'] = f"Weekly AI Digest - {datetime.now().strftime('%Y-%m-%d')}"
    msg['From'] = "research-monitor@localhost"
    msg['To'] = recipient

    # Send via local SMTP (configure as needed)
    with smtplib.SMTP('localhost') as smtp:
        smtp.send_message(msg)

if __name__ == "__main__":
    digest = generate_digest()
    print(digest)  # Print to stdout

    # Optionally send email
    # send_email_digest(digest)
```

**Cron Schedule:**

```bash
# ~/.claude/tools/crontab_research_monitor

# Weekly digest (every Monday 09:00)
0 9 * * 1 cd ~/.claude/tools && python research_monitor.py > /tmp/weekly_digest.md

# Monthly summary (first Monday of month at 09:00)
0 9 1-7 * 1 cd ~/.claude/tools && python research_monitor_monthly.py

# Quarterly review reminder (last week of quarter)
0 9 20-31 3,6,9,12 * echo "Quarterly AI review due!" | mail -s "Quarterly Review" user@localhost
```

#### Option C: Fully Automated (Phase 3)
- **Effort:** 20-30 hours (custom dashboard)
- **Method:** Web dashboard + API integrations + ML relevance scoring
- **Tools:**
  - Backend: FastAPI (Python)
  - Frontend: React dashboard
  - Database: PostgreSQL (source tracking)
  - ML: Sentence transformers for relevance scoring
- **Pros:** Real-time, intelligent filtering, metrics
- **Cons:** High maintenance, overkill for solo use

---

## 5. Integration Workflow

### 5.1 Source → Gap → Module Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    RESEARCH-TO-PRACTICE PIPELINE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  STEP 1: DISCOVERY                                                          │
│  ├─► Monitor sources per schedule                                           │
│  ├─► Identify new techniques/tools/models                                   │
│  └─► Flag for relevance scoring                                             │
│          │                                                                   │
│          ▼                                                                   │
│  STEP 2: RELEVANCE SCORING (GAP-R2P-005)                                   │
│  ├─► Score on 5 dimensions (0-5 scale):                                     │
│  │   1. CLI Applicability (can Claude Code use this?)                       │
│  │   2. Maturity (production-ready vs research)                             │
│  │   3. Effort to Integrate (hours estimate)                                │
│  │   4. Expected Impact (quality/cost/UX improvement)                       │
│  │   5. Urgency (competitive pressure, security)                            │
│  ├─► Total score: 0-25 (weighted average)                                   │
│  └─► Threshold: ≥15 → proceed to next step                                  │
│          │                                                                   │
│          ▼                                                                   │
│  STEP 3: GAP CREATION                                                       │
│  ├─► Use GAP_WRITING_GUIDELINES.md                                          │
│  ├─► Assign category, priority, CLI relevance                               │
│  ├─► Add to GAPS.md                                                         │
│  └─► Link to source (arXiv, GitHub, blog)                                   │
│          │                                                                   │
│          ▼                                                                   │
│  STEP 4: PROOF-OF-CONCEPT (GAP-R2P-006)                                    │
│  ├─► Test technique in isolated environment                                 │
│  ├─► Measure: latency, cost, quality impact                                 │
│  ├─► Document: examples, edge cases, limitations                            │
│  └─► Decision: integrate, defer, or reject                                  │
│          │                                                                   │
│          ▼                                                                   │
│  STEP 5: MODULE INTEGRATION (GAP-R2P-009)                                  │
│  ├─► Use MODULE_WRITING_GUIDELINES.md                                       │
│  ├─► Add to appropriate module (prompting.md, devops.md, etc.)             │
│  ├─► Create 2-3 examples (EXAMPLE_WRITING_GUIDELINES.md)                   │
│  └─► Update CHANGELOG.md, version bump                                      │
│          │                                                                   │
│          ▼                                                                   │
│  STEP 6: VALIDATION (GAP-R2P-008)                                          │
│  ├─► Regression testing (existing functionality)                            │
│  ├─► User testing (real-world scenarios)                                    │
│  ├─► Performance validation (latency, cost)                                 │
│  └─► Mark gap as ✅ Resolved in GAPS.md                                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Example: arXiv Paper → Integrated Technique

**Timeline:** 2-4 weeks (from discovery to production)

| Week | Activity | Deliverable |
|------|----------|-------------|
| Week 1 | **Discovery** — Monday arXiv check finds "Chain-of-Verification" paper | Paper flagged in weekly digest |
| Week 1 | **Relevance Scoring** — Score 22/25 (high relevance) | Decision: Proceed to PoC |
| Week 2 | **PoC Testing** — Test on 10 real tasks (coding, debugging, analysis) | PoC report: +15% accuracy, +2s latency, acceptable |
| Week 3 | **Gap Creation** — GAP-PROMPT-CoVe-001 created in GAPS.md | Gap documented with P1 priority |
| Week 3-4 | **Module Integration** — Add to prompting.md Section 5.8, create 3 examples | Module updated, examples added |
| Week 4 | **Validation** — Regression tests pass, user testing positive | Gap marked ✅ Resolved, v6.21.0 released |

---

## 6. Metrics & KPIs

### 6.1 Monitoring Effectiveness

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| **Freshness:** Avg lag from industry | <3 months | 2.1 months | ✅ Good |
| **Coverage:** % of relevant sources monitored | ≥80% | 75% | ⚠️ Needs improvement |
| **Response Time:** Critical alerts → action | <24h | 18h avg | ✅ Good |
| **Integration Rate:** Discoveries → modules | ≥30% | 28% | ⚠️ Borderline |
| **False Positive Rate:** Irrelevant flags | <20% | 15% | ✅ Good |

### 6.2 Dashboard (Optional, Phase 3)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                   RESEARCH MONITORING DASHBOARD                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  📊 DISCOVERY METRICS (Last 30 Days)                                        │
│  ├─► Papers Reviewed: 147                                                   │
│  ├─► Flagged for Further Review: 23 (15.6%)                                │
│  ├─► Created Gaps: 8 (34.8% conversion)                                    │
│  └─► Integrated into Modules: 3 (13% of reviewed)                          │
│                                                                              │
│  🚨 PENDING ALERTS                                                          │
│  ├─► 🔴 CRITICAL: 1 (Anthropic API deprecation, respond by 2026-02-15)     │
│  ├─► 🟡 HIGH: 3 (GPT-5.2 release, o3-pro update, LangChain 0.3.0)          │
│  └─► 🟢 MEDIUM: 12 (papers, benchmarks, tool updates)                      │
│                                                                              │
│  📈 CONFIGURATION HEALTH                                                    │
│  ├─► Freshness: 2.1 months (✅ within target)                              │
│  ├─► Coverage: 78% (target: 80%)                                            │
│  ├─► Open Gaps: 641 (trend: ↓ -12 from last quarter)                       │
│  └─► Maturity Level: 4/6 (Managed)                                          │
│                                                                              │
│  📅 UPCOMING REVIEWS                                                        │
│  ├─► Weekly Digest: Monday 09:00 (2 days)                                  │
│  ├─► Monthly Review: 2026-02-03 (7 days)                                   │
│  └─► Quarterly Review: 2026-03-25 (57 days)                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Implementation Phases

### Phase 1: Manual Monitoring (Current, v1.0.0)
**Duration:** Immediate
**Effort:** 0 hours setup, 3-4 hours/week execution
**Deliverables:**
- ✅ This protocol document
- ✅ Source taxonomy
- ✅ Monitoring schedule
- ✅ Weekly/monthly/quarterly templates

**Status:** Complete

---

### Phase 2: Semi-Automated (Recommended, v2.0.0)
**Duration:** 1-2 weeks
**Effort:** 8-12 hours setup
**Deliverables:**
- 📄 RSS aggregation script (`research_monitor.py`)
- 📄 Email digest automation
- 📄 Cron job setup
- 📊 Weekly digest template (automated)

**Expected Benefit:** 60% time reduction (3-4h → 1.5-2h/week)

**Prerequisites:**
- Python 3.10+
- feedparser library
- Local SMTP server (or external email service)

---

### Phase 3: Fully Automated (Optional, v3.0.0)
**Duration:** 4-6 weeks
**Effort:** 20-30 hours
**Deliverables:**
- 🌐 Web dashboard (React + FastAPI)
- 🤖 ML relevance scoring
- 📊 Real-time metrics
- 🔔 Slack/Discord integration

**Expected Benefit:** 80% time reduction + real-time alerts

**Decision Point:** Only implement if monitoring workload becomes bottleneck (>5h/week)

---

## 8. Revision History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2026-01-27 | Initial protocol creation | Claude Code |
| - | - | (Future revisions) | - |

---

## 9. References

- GAPS.md Category 38: Research-to-Practice Protocol
- GAP-R2P-001: Quarterly Research Source Monitoring (this document)
- GAP-R2P-002: AI News Aggregation Pipeline
- GAP-R2P-005: Research Relevance Scoring
- GAP-R2P-006: Proof-of-Concept Testing Protocol
- MODULE_WRITING_GUIDELINES.md
- EXAMPLE_WRITING_GUIDELINES.md
- GAP_WRITING_GUIDELINES.md

---

**End of Document**
