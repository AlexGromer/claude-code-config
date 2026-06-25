# Relevance Maintenance Protocol
# Version: 1.1.0 | Updated: 2026-02-25

## Automated Schedule (anacron)

```bash
# ~/.anacron/anacrontab
7   10  staleness_weekly    python3 ~/.claude/tools/staleness_checker.py --mode weekly
30  15  staleness_monthly   python3 ~/.claude/tools/staleness_checker.py --mode monthly --report
90  20  staleness_quarterly python3 ~/.claude/tools/staleness_checker.py --mode quarterly --full-audit
```

## Staleness Score Actions

| Score | Status | Action |
|-------|--------|--------|
| 0-20  | Healthy | None |
| 21-40 | Attention | Schedule review |
| 41-60 | Stale | Update within 2 weeks |
| 61-80 | Critical | Update within 1 week |
| 81-100 | Dangerous | Immediate action |

Score formula (0-100, higher = more stale):
- Time: 0-40 pts (>3mo=15, >6mo=30, >12mo=40)
- Version drift: min(major_diff * 10, 30)
- Usage <10%: +10, <5%: +20
- Security issues / upstream deprecated: +10 each

## Actions by Level

**Score 21-40** — Minor: update version numbers, fix links, bump patch version, no review needed.

**Score 41-60** — Moderate: rewrite affected sections, update examples, bump minor version, self-review.

**Score 61-80** — Major: full rewrite + update all dependencies + bump major version + review + GAPS.md entry.

**Score 81-100** — Critical: add deprecation notice immediately, create migration guide, follow domain_lifecycle archival process.

## staleness_checker.py Usage

```bash
python ~/.claude/tools/staleness_checker.py --mode weekly
python ~/.claude/tools/staleness_checker.py --mode quarterly --full-audit
python ~/.claude/tools/staleness_checker.py --file modules/03-devops.md
```

Reports saved to: `~/.claude/logs/staleness_monthly_YYYYMM.md`
GAPS entries auto-created: `GAP-STALE-XXX`

## Security Update SLAs (CVE)

| Severity | CVSS | SLA |
|----------|------|-----|
| CRITICAL | 9.0-10.0 | Same day |
| HIGH | 7.0-8.9 | 48 hours |
| MEDIUM | 4.0-6.9 | 1 week |
| LOW | 0.1-3.9 | Next maintenance cycle |

Sources: NVD, GitHub Security Advisories, CISA alerts.
GAPS entry: `GAP-SEC-XXX` for each CVE affecting documented tools.
