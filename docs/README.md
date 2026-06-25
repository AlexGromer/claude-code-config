# Claude Evaluation Framework

Comprehensive evaluation and metrics tracking for Claude agent configurations.

## Features

- **Automatic Metrics Collection**: Track accuracy, hallucinations, tool errors, latency, cost
- **Regression Detection**: Baseline comparison with statistical alerts
- **A/B Testing**: Compare prompt strategies with statistical significance
- **Weekly Reports**: Automated reporting (manual or scheduled)
- **Few-Shot Integration**: Measure impact of examples on performance
- **Configurable Automation**: Cron, systemd, manual execution

## Quick Start

### 1. Installation

```bash
cd ~/.claude/evaluation
pip install -r requirements.txt
```

### 2. Configuration

Run the interactive setup wizard:

```bash
python setup.py
```

Or manually edit `config.yaml` with your preferences.

### 3. Basic Usage

**Collect metrics (automatic via hooks or manual):**
```bash
python metrics_tracker.py --collect
```

**Generate weekly report:**
```bash
python metrics_tracker.py --report weekly
```

**Run regression tests:**
```bash
python regression_suite.py --baseline baseline.json
```

**A/B testing:**
```bash
python ab_testing.py --variant-a baseline --variant-b optimized
```

## Configuration

Edit `config.yaml` to customize:

- **Metrics collection**: Automatic or manual
- **Reporting schedule**: Manual, weekly, daily, on-commit
- **Automation backend**: None, cron, systemd, launchd
- **Notifications**: Desktop, Telegram, Email
- **Few-shot mode**: Manual, assisted, semi-automated

## Directory Structure

```
~/.claude/evaluation/
├── config.yaml              # Configuration
├── requirements.txt         # Python dependencies
├── setup.py                 # Interactive wizard
├── metrics_tracker.py       # Core metrics engine
├── regression_suite.py      # Regression testing
├── ab_testing.py           # A/B testing framework
├── test_cases.json         # Test case library
├── data/                   # Metrics storage
│   ├── metrics.jsonl       # Raw metrics
│   └── baselines/          # Baseline snapshots
├── reports/                # Generated reports
└── hooks/                  # Automation hooks

## Metrics Tracked

| Metric | Description | Target |
|--------|-------------|--------|
| Accuracy | Correct responses / Total | ≥85% |
| Hallucinations | Fabricated facts / Total | ≤5% |
| Tool Errors | Failed tool calls / Total | ≤10% |
| Latency | Avg response time | <5s |
| Cost | API cost per request | Tracked |

## Automation Options

### Option 1: Manual Execution
```bash
python metrics_tracker.py --report weekly
```

### Option 2: Cron (Linux)
```bash
crontab -e
# Every Monday at 9:00
0 9 * * 1 /usr/bin/python3 ~/.claude/evaluation/metrics_tracker.py --report weekly
```

### Option 3: Systemd Timer (Modern Linux)
```bash
systemctl --user enable claude-metrics-weekly.timer
systemctl --user start claude-metrics-weekly.timer
```

### Option 4: Git Hooks
```bash
# .git/hooks/pre-commit
python3 ~/.claude/evaluation/metrics_tracker.py --quick-check
```

## Notifications

Configure in `config.yaml`:

**Desktop (Linux):**
```yaml
notifications:
  desktop:
    enabled: true
```

**Telegram:**
```yaml
notifications:
  telegram:
    enabled: true
    bot_token_env: TELEGRAM_BOT_TOKEN
    chat_id_env: TELEGRAM_CHAT_ID
```

**Email:**
```yaml
notifications:
  email:
    enabled: true
    smtp_host: localhost
    smtp_port: 25
```

## Development

**Run tests:**
```bash
pytest tests/
```

**Debug mode:**
```bash
python metrics_tracker.py --debug --report weekly
```

## Version

Current version: **1.0.0**

Part of Claude Configuration v9.1.0

## Documentation

- Changelog: `/opt/project/CHANGELOG.md`
- Research monitoring: `/opt/project/docs/RESEARCH_SOURCE_MONITORING.md`
- Documentation index: `/opt/project/docs/INDEX.md`

## Research & Knowledge Integration

**Automated Research Monitoring:**
- Weekly AI research digests (arXiv, Papers with Code, conferences)
- Monthly framework/model update reviews
- Quarterly strategic ecosystem analysis
- See: `docs/RESEARCH_SOURCE_MONITORING.md` for full protocol

**Latest Research Digest:** 2026-02-19
- Automated via research-digest agent + SessionStart hook notification

**Research-to-Practice Workflow:**
1. Discovery → Relevance scoring → Gap creation → PoC testing → Module integration
2. Automated workflow: `~/.claude/evaluation/research_workflow.md`
3. Validation criteria: `~/.claude/evaluation/validation_workflow.md`

## License

Part of Claude Configuration Project
