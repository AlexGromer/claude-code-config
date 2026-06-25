# Domain Lifecycle Protocol
# Version: 1.1.0 | Updated: 2026-02-25

## Naming Convention

Format: `XX-domainname.md`

| Range | Category |
|-------|----------|
| 00-09 | Core (architecture, maturity, compliance, security) |
| 10-19 | Technical domains (DevOps, Engineering) |
| 20-29 | Specialized (Education, Writing) |
| 30-39 | Advanced (Low-level, Research) |
| 40-49 | Integration (MCP, Skills, Orchestration) |

## CLI Relevance Scoring (required ≥60 to create)

```
CLI_SCORE = (
    direct_cli_usage * 40 +       # 0-40: Direct use in CLI tasks
    automation_potential * 25 +    # 0-25: Can be automated via hooks/skills
    cross_domain_value * 20 +      # 0-20: Benefits other domains
    user_demand * 15               # 0-15: Frequency of user requests
) / 100
```

| Score | Decision |
|-------|----------|
| ≥80   | Auto-approve, HIGH priority |
| 60-79 | Approve with review |
| 40-59 | Conditional (needs strong justification) |
| <40   | Reject |

## Creation Checklist

```
☐ CLI relevance score ≥60
☐ No overlap: grep -r "keyword" ~/.claude/modules/
☐ File: ~/.claude/modules/XX-name.md
☐ Examples: ~/.claude/examples/name/ (≥3 files)
☐ Cross-references added to related modules
☐ Add to CLAUDE.md module list
☐ Create skill if applicable
☐ GAPS.md updated
```

## Archival Thresholds

| Trigger | Threshold |
|---------|-----------|
| Staleness | >6 months no updates |
| Low usage | <5% for 3+ months |
| Superseded | New domain covers functionality |

Archival path: `~/.claude/archived/modules/XX-domainname.md.archived.YYYYMMDD`

Deprecation notice header:
```markdown
> DEPRECATED (since YYYY-MM-DD). Removed: YYYY-MM-DD. Use: [successor].
```

Removal requires: ≥3 month deprecation period + all cross-references removed + GAPS.md closed.
