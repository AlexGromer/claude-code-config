# External API Status Matrix

**Generated:** 2026-03-17
**Scope:** MCP profiles in `~/.claude/mcp-servers/profile-mcp/profiles.go` and active config `~/.claude/.mcp.json`

---

## External API Status Matrix

| API | MCP Profile | Env Var | Key Present in .mcp.json | Notes |
|-----|-------------|---------|--------------------------|-------|
| GitHub | essential | `GITHUB_PERSONAL_ACCESS_TOKEN` | No (injected from env at runtime) | `config.go:208` — env var injection; key not stored in .mcp.json |
| Shodan | security / .mcp.json | `SHODAN_API_KEY` | **YES — hardcoded** | Key in `.mcp.json` env block. Also hardcoded in `SHODAN_ECOSYSTEM.md` and `API_SERVICES_INVENTORY.md` |
| Brave Search | osint | `BRAVE_API_KEY` | **YES — hardcoded** | Key `<REDACTED>` in `.mcp.json` |
| VirusTotal | intel | `VIRUSTOTAL_API_KEY` | **YES — hardcoded** | Key present in `.mcp.json` env block |
| GreyNoise | intel | `GREYNOISE_API_KEY` | **YES — hardcoded** | Key present in `.mcp.json` env block |
| Censys ASM | osint / intel | `Authorization: Bearer ...` | **YES — hardcoded** | Bearer token in `.mcp.json` SSE headers (3 endpoints) |
| Censys Platform | osint / intel | `Authorization: Bearer ...` | **YES — hardcoded** | Same bearer token as Censys ASM |
| Censys Threat Hunting | intel | `Authorization: Bearer ...` | **YES — hardcoded** | Same bearer token as Censys ASM |
| AlienVault OTX | intel (threatintel) | `OTX_API_KEY` | **YES — hardcoded** | Key present in `.mcp.json` env block |
| AbuseIPDB | intel (threatintel) | `ABUSEIPDB_API_KEY` | **YES — hardcoded** | Key present in `.mcp.json` env block |
| IPInfo | intel | `IPINFO_TOKEN` | **YES — hardcoded** | Token `<REDACTED>` in `.mcp.json` |
| NVD (cve-intelligence) | security | `NVD_API_KEY` | **YES — hardcoded** | Key present in `.mcp.json` env block |
| Vulners | security | `VULNERS_API_KEY` | **YES — hardcoded** | Key present in `.mcp.json` env block |
| GitLab | devops | `GITLAB_TOKEN` | No (placeholder `<SET_ME>`) | Not yet configured |
| Grafana | devops | `GRAFANA_TOKEN` | No (placeholder `<SET_ME>`) | Not yet configured |
| HashiCorp Vault | devops | `VAULT_TOKEN` | No (placeholder `<SET_ME>`) | Not yet configured |
| Mikrotik | network | `MIKROTIK_PASSWORD` | No (placeholder `<SET_ME>`) | Not yet configured |
| OPNsense | network | `OPNSENSE_API_KEY` | No (placeholder `<SET_ME>`) | Not yet configured |
| SonarQube | — | `SONARQUBE_TOKEN` | No (placeholder `<SET_ME>`) | Not yet configured |
| DefectDojo | — | `DEFECTDOJO_API_KEY` | No (placeholder `<SET_ME>`) | Not yet configured |
| Elasticsearch | — | `ES_API_KEY` | No (placeholder `<SET_ME>`) | Not yet configured |
| Velociraptor | dfir | `VELOCIRAPTOR_API_KEY` | No (placeholder `<SET_ME>`) | Not yet configured |
| TheHive | case-mgmt | `THEHIVE_API_KEY` | No (placeholder `<SET_ME>`) | Not yet configured |
| MISP | case-mgmt | `MISP_API_KEY` | No (placeholder `<SET_ME>`) | Not yet configured |
| Wazuh | dfir | `WAZUH_PASSWORD` | No (placeholder `<SET_ME>`) | Not yet configured |
| HIBP | — | `HIBP_API_KEY` | No (placeholder `<SET_ME_OPTIONAL>`) | Optional — not required |
| WhoisXML | — | `WHOISXMLAPI_TOKEN` | No (placeholder `<SET_ME>`) | Not yet configured |
| PostgreSQL | — | `POSTGRES_URL` | No (placeholder `<SET_ME>`) | Not yet configured |

**No API key needed (MCP servers with no auth):**
- `fetch`, `git`, `sqlite`, `sequential-thinking`, `memory` — essential, no external APIs
- `maigret`, `pentest-mcp`, `mcp-kali-server`, `PentestAgent` — local tools
- `ghidra-mcp`, `yaraflux`, `volatility-mcp`, `WireMCP` — local tools
- `suricata`, `bbot`, `spiderfoot-mcp`, `abusech` — local tools / public APIs
- `wayback`, `playwright`, `puppeteer`, `browser` — no auth needed
- `kubernetes`, `terraform` — require kubeconfig/cloud creds but no central API key

---

## Runtime Env Var Injection (profile-mcp)

`config.go` (line 207-223) performs runtime injection for 3 servers only:

| Server | Env Var Checked at Runtime |
|--------|---------------------------|
| `github` | `GITHUB_PERSONAL_ACCESS_TOKEN` |
| `shodan` | `SHODAN_API_KEY` |
| `brave-search` | `BRAVE_API_KEY` |

All other API keys are read exclusively from `.mcp.json` — there is no runtime env injection for them.

---

## .gitignore Coverage

**Project repo** (`/opt/project/.gitignore`): Comprehensive, 1100+ patterns.

| Pattern | Covers | Status |
|---------|--------|--------|
| `.claude/` | Entire `~/.claude/` dir | PRESENT (line 12) |
| `.mcp.json` | MCP config with hardcoded keys | PRESENT (line 13) |
| `*_key`, `*_key.*` | Generic key files | PRESENT (lines 35-36) |
| `*_secret`, `*_token` | Token files | PRESENT (lines 37-40) |
| `credentials.json` | Credential files | PRESENT (line 55) |
| `GITHUB_TOKEN*` | GitHub token files | PRESENT (line 48) |

**Critical observation:** `.mcp.json` is excluded from the `/opt/project` git repo by `.gitignore` line 13. However, `SHODAN_ECOSYSTEM.md` and `API_SERVICES_INVENTORY.md` are in `~/.claude/` (not git-tracked there since `~/.claude/` is not a git repo).

**`~/.claude/` directory:** NOT a git repository — no `.gitignore`, no git tracking. The risk is not git exposure but direct file system access and any backup/sync tools that may copy these files.

---

## Security Assessment

### CRITICAL: Hardcoded Keys in Plain-Text Files

The following live API keys were found hardcoded in plain-text files under `~/.claude/`:

| File | Keys Exposed |
|------|-------------|
| `~/.claude/.mcp.json` | Shodan, Brave Search, VirusTotal, GreyNoise, Censys (Bearer), OTX, AbuseIPDB, IPInfo, NVD, Vulners |
| `~/.claude/SHODAN_ECOSYSTEM.md` | Shodan API key (in documentation prose and code example) |
| `~/.claude/API_SERVICES_INVENTORY.md` | Shodan API key (in documentation prose) |
| `~/.claude/tools/_archived/shodan_usage_tracker.py` | Shodan API key (hardcoded in Python source) |

**Note:** The Shodan API key `<REDACTED>` appears in at least 4 separate files.

### Positive Findings

- `.mcp.json` is listed in `/opt/project/.gitignore` — NOT committed to the your-project git repo
- `~/.claude/` is not a git repository — no risk of accidental git push
- MCP profile definitions in `profiles.go` contain NO hardcoded keys (they use empty `Env: map[string]string{}` with runtime injection for github/shodan/brave)
- Unconfigured services use `<SET_ME>` placeholders (safe)
- `score-mcp/api.go` checks `GITHUB_TOKEN` from env only — no hardcoding

### Risk Assessment

| Risk | Severity | Details |
|------|----------|---------|
| Keys in `~/.claude/SHODAN_ECOSYSTEM.md` | HIGH | Documentation file with live API key in body text |
| Keys in `~/.claude/API_SERVICES_INVENTORY.md` | HIGH | Same — live key in prose |
| Keys in `~/.claude/tools/_archived/shodan_usage_tracker.py` | HIGH | Archived script with hardcoded key |
| Keys in `~/.claude/.mcp.json` | MEDIUM | Expected location for MCP config, not git-tracked, but plain-text |
| Session history files (`.jsonl`) contain key | LOW | Internal Claude session logs — not git-tracked |

---

## Recommendations

1. **Rotate exposed keys immediately** — The Shodan, VirusTotal, GreyNoise, Censys, OTX, AbuseIPDB, and Vulners keys are all in plain text. Treat them as compromised and regenerate via each service's account portal.

2. **Remove keys from documentation files** — Replace the literal key in `SHODAN_ECOSYSTEM.md`, `API_SERVICES_INVENTORY.md`, and `shodan_usage_tracker.py` with `$SHODAN_API_KEY` or `<REDACTED>`.

3. **Migrate .mcp.json to env-var injection** — Extend the `InjectEnvTokens` function in `config.go` to cover all API-dependent servers (virustotal, greynoise, censys, otx, abuseipdb, etc.), and remove hardcoded values from `.mcp.json`. Store actual values in shell environment or a secrets manager.

4. **Add backup/sync exclusion** — If any cloud sync (Dropbox, rclone, rsync to remote) touches `~/.claude/`, ensure `.mcp.json`, `SHODAN_ECOSYSTEM.md`, and `API_SERVICES_INVENTORY.md` are excluded.

5. **Audit session history** — Files matching `~/.claude/projects/*/**.jsonl` contain the Shodan key in session transcripts (13+ files found). These are local-only but should be purged if the machine is ever shared or reimaged.

6. **GitHub MCP** — Confirm `GITHUB_PERSONAL_ACCESS_TOKEN` is present in the shell environment (injected at runtime via `config.go`). It is NOT stored in `.mcp.json` — this is correct behavior.
