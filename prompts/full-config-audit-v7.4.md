# Full Configuration Audit v7.4

Проведи полный аудит конфигурации Claude Code v7.4.0. Все 15 секций обязательны. Для каждой — вердикт PASS/FAIL/WARN + список находок. В конце — summary с action items.

Режим: bypassPermissions. Используй 3 параллельных агента (Explore). Не пиши файлы — только читай и проверяй. Результаты — в текстовом отчёте.

---

## Секция 1: Версионная консистентность

Проверь что ВСЕ источники показывают 7.4.0:
- `/opt/project/.claude-ver` (поле config-version)
- `~/.claude/CLAUDE.md` (Current version)
- `~/.claude/projects/-opt-your-project/memory/MEMORY.md` (Version)
- `~/.claude/hooks/session_start_reinforcement.py` (current_version)
- `/opt/project/CHANGELOG.md` (первый ## заголовок)

Ожидание: 5/5 = 7.4.0

## Секция 2: Счётчики компонентов

Подсчитай фактическое количество и сравни с CLAUDE.md и MEMORY.md:

| Компонент | Как считать | Ожидание |
|-----------|-------------|----------|
| Agents | `ls ~/.claude/agents/*.md \| wc -l` | 102 |
| Skills | `ls -d ~/.claude/skills/*/ \| wc -l` | 103 (fork: grep -rl "context: fork" \| wc -l → 97; без fork: 6) |
| Rules | `ls ~/.claude/rules/*.md \| wc -l` | 7 |
| Modules | `ls ~/.claude/modules/*.md \| grep -v _archived \| wc -l` | 17 active |
| Modules archived | `ls ~/.claude/modules/*_archived* \| wc -l` | 9 |
| Hooks | settings.json hooks → посчитай все command в hooks[] | 15 |
| Tools | `ls ~/.claude/tools/*.py \| wc -l` | 8 |
| Go MCP | `ls -d ~/.claude/mcp-servers/*/ \| wc -l` | 5 |
| Permission templates | `ls ~/.claude/templates/project-init/permissions/ \| wc -l` | 5 |
| Project-init templates | `ls ~/.claude/templates/project-init/ \| wc -l` | 9 (dirs count as 1) |

Сравни с CLAUDE.md (Architecture section) и MEMORY.md (Component Status). Все три источника должны совпадать.

## Секция 3: Permissions — глобальный уровень

Прочитай `~/.claude/settings.json` секцию permissions:

1. **allow** — подсчитай записи. Должно быть ~315
2. **ask** — подсчитай. Должно быть ~112
3. **deny** — подсчитай. Должно быть ~32
4. Проверь: НЕТ `Edit(/opt/**)` и `Write(/opt/**)` — эти wildcards убраны
5. Проверь: ЕСТЬ `Edit(/opt/work/osint/**)`, `Edit(/opt/work/pentest/**)`, `Edit(/opt/work/devops/**)`, `Edit(/opt/work/reverse/**)`, `Edit(/opt/project/**)` + аналогичные Write
6. Проверь: ЕСТЬ `Edit(~/.claude/**)`, `Write(~/.claude/**)`
7. Проверь: нет дубликатов в allow (python3: items.count(x) > 1)
8. Проверь: нет записи из allow в deny (конфликт)
9. Подсчитай MCP tool записи (начинаются с `mcp__`): profile-mcp=8, doctor-mcp=3, gc-mcp=3, score-mcp=3, backlog-mcp=8
10. Сверь groups count с PERMISSIONS.md (должно быть 30 групп)

## Секция 4: Permissions — проектный уровень

1. Прочитай `~/.claude/templates/project-init/settings.local.json.template` — должен содержать `{{project_path}}`, НЕ `/opt/**`
2. Прочитай все 5 файлов в `~/.claude/templates/project-init/permissions/` — каждый должен использовать `{{project_path}}`, НЕ `/opt/{{project}}`
3. Проверь: каждый JSON валиден (python3 json.load)
4. Проверь: mcp_profiles в каждом шаблоне ссылаются на реальные профили из profile-mcp
5. Прочитай `~/.claude/rules/authorization-levels.md` — должен описывать 4-tier hierarchy и НЕ содержать `Edit(/opt/**)`
6. Прочитай PERMISSIONS.md — НЕ должен содержать `Edit(/opt/**)`

## Секция 5: MCP серверы — регистрация и essential

1. Прочитай `~/.claude.json`, найди `projects."/opt/project".mcpServers` — 5 Go серверов должны быть: profile-mcp, doctor-mcp, gc-mcp, score-mcp, backlog-mcp
2. Проверь: Go серверы НЕ хардкодятся в других проектах (кроме ~/.claude, ~/.claude/evaluation/tests)
3. Прочитай `~/.claude/mcp-servers/profile-mcp/profiles.go` → essential profile — должен содержать ВСЕ 12 серверов: github, fetch, filesystem, memory, git, sequential-thinking, sqlite, backlog-mcp, profile-mcp, doctor-mcp, gc-mcp, score-mcp
4. Прочитай `~/.claude/tools/mcp_profile_manager.py` → PROFILES["essential"] — те же 12 серверов (Python fallback)
5. Прочитай `~/.claude/hooks/session_start_reinforcement.py` → функция ensure_essential_servers() — должна проверять и добавлять 12 essential серверов
6. Все 5 Go бинарников существуют и скомпилированы: `ls -la ~/.claude/mcp-servers/*/` (ищи исполняемые файлы)
7. Все 5 Go серверов в settings.json allow (17 mcp tool записей)

## Секция 6: Hooks — полнота и корректность

Прочитай settings.json → hooks. Ожидание: 15 hooks по 7 event types:

| Event | Count | Hooks |
|-------|-------|-------|
| SessionStart | 5 | session_start_reinforcement.py, session_startup_hook.py, session_startup_dashboard.py, session_health_check.py, garbage_collector.py |
| UserPromptSubmit | 1 | user_prompt_submit_hook.py |
| PreToolUse | 3 | (проверь какие) |
| PostToolUse | 3 | (проверь какие) |
| PostToolUseFailure | 1 | (проверь какой) |
| PreCompact | 1 | pre_compact_hook.py |
| SessionEnd | 1 | session_end_hook.py |

Для каждого hook:
1. Файл существует по указанному пути
2. Файл исполняемый (chmod +x) или вызывается через python3
3. Нет синтаксических ошибок (python3 -c "import ast; ast.parse(open('file').read())")

## Секция 7: GC (Garbage Collector) — targets и синхронизация

1. Прочитай `~/.claude/hooks/garbage_collector.py` — подсчитай cleanup функции. Ожидание: 11 targets
2. Прочитай `~/.claude/mcp-servers/gc-mcp/cleanup.go` — подсчитай targets в runAllCleanups. Ожидание: 11 targets
3. Сравни списки targets Python vs Go — должны совпадать:
   tasks, teams, spending_archive, spending_tracker, backlog, plans, session_env, python_caches, security_log, debug_files, empty_dirs
4. Запусти Go тесты: `cd ~/.claude/mcp-servers/gc-mcp && go test -count=1 ./...` — должны пройти
5. Проверь: garbage_collector.py имеет DEPRECATED header

## Секция 8: Rules — актуальность содержания

Для каждого из 7 rules/*.md:

1. **anti-hallucination.md** — есть, < 10 строк
2. **authorization-levels.md** — содержит 4-tier hierarchy, НЕ содержит `/opt/**` wildcard, содержит Tier 1-4 описания
3. **code-before-write.md** — содержит Read-Once Rule, File Map Usage
4. **mandatory-checks.md** — содержит gitleaks, .gitignore patterns, test requirements
5. **mcp-rules.md** — содержит LOCAL scope (#3), Profile Rotation, Restart Protocol
6. **task-execution.md** — содержит Post-Plan Workflow (Steps 1-6), Wave Scoring, Progressive Scope, ensure_essential упоминание (или MCP provisioning)
7. **working-directories.md** — пути /opt/work/osint, /opt/work/pentest, /opt/work/devops, /opt/work/reverse, /opt/project

Для каждого правила: нет устаревших ссылок (на /opt/**, на version 7.3 вместо 7.4).

## Секция 9: System Prompt Injection — CORE_INSTRUCTIONS + CLAUDE.md

1. Прочитай `~/.claude/CORE_INSTRUCTIONS.md` — это инжектируется через --append-system-prompt
2. Проверь: содержит ROUTING FEEDBACK, MANDATORY DELEGATION, PROGRESSIVE SCOPE TRACKING, POST-PLAN WORKFLOW, READ-ONCE RULE, FILEMAP, ANTI-HALLUCINATION
3. Проверь: НЕ дублирует rules/ (правила НЕ должны копироваться в CORE_INSTRUCTIONS)
4. Прочитай `~/.claude/CLAUDE.md` — загружается автоматически
5. Проверь: содержит Architecture, Post-Plan Workflow, Auto-Invocation, Agents, Memory Rules, Auto-Actions, Changelog
6. Суммарный размер всего что загружается в контекст:
   - CLAUDE.md (~69 строк)
   - 7 rules (~415 строк суммарно)
   - MEMORY.md (~63 строки)
   - CORE_INSTRUCTIONS.md (~3537 chars)
   - Итого должно быть < 15K chars
7. Между CLAUDE.md, CORE_INSTRUCTIONS и rules/ не должно быть дублирования правил

## Секция 10: Agent → Skill → Module маппинг

1. Выбери 15 random agents из `~/.claude/agents/`. Для каждого:
   a. Найди skill в `~/.claude/skills/*/SKILL.md` с полем `agent: <agent-name>` — должен существовать (кроме 5 system-only: research-digest, gap-manager, iterator, routing-orchestrator, agent-factory)
   b. Если agent имеет Module hint — проверь что модуль существует в `~/.claude/modules/`
2. Выбери 15 random skills. Для каждого fork skill:
   a. Поле `agent:` указывает на существующий файл в agents/
   b. Поле `context: fork` присутствует
3. Подтверди: 5 system-only agents НЕ имеют skills (и это by design — они вызываются через Task())

## Секция 11: Project-Init Pipeline

1. Прочитай `~/.claude/agents/project-init.md` — workflow steps 0-11
2. Проверь: step 5 (Permissions) описывает:
   a. Загрузку base template (settings.local.json.template)
   b. Загрузку per-type template
   c. Замену {{project_path}}, {{project_type}}, {{date}}
   d. MCP через ensure_essential hook (НЕ хардкод в ~/.claude.json)
3. Проверь: step 8 version = 7.4.0
4. Проверь все referenced templates существуют:
   - ONBOARDING.md, PERMISSIONS.md, BACKLOG.md.template, MEMORY_INIT.md.template
   - claude-ver.template, gitignore.template, FILEMAP.md.template
   - settings.local.json.template, permissions/*.json (5 файлов)
5. Проверь: `.mcp.json.template` существует

## Секция 12: Мусор и лишняя документация

**Удалить если найдено** (это единственная секция где агент ПИШЕТ):
1. `~/.claude/docs/` — директория НЕ должна существовать
2. `__pycache__/` рекурсивно в ~/.claude/ — удалить
3. `.pytest_cache/` рекурсивно — удалить
4. Пустые директории в `~/.claude/agent-memory/` — удалить
5. Пустая директория `~/.claude/commands/` — удалить если пустая
6. `~/.claude/plans/` — файлы старше 7 дней удалить
7. `~/.claude/session-env/` — директории старше 3 дней удалить
8. Проверь `/opt/project/.claude/settings.local.json` — если содержит stale auto-accumulated entries, показать но НЕ удалять
9. Проверь: нет .md файлов в ~/.claude/ кроме CLAUDE.md и CORE_INSTRUCTIONS.md
10. Проверь: MEMORY.md < 200 строк, BACKLOG.md active < 30 items

## Секция 13: BACKLOG.md и MEMORY.md

1. Прочитай `/opt/project/BACKLOG.md`:
   - Active: должно быть 0 или минимум
   - Completed Archive: < 50 items
   - Формат каждой записи: `- [x] [W#] description (P#) @agent — date ✓ date`
2. Прочитай MEMORY.md:
   - Version line = 7.4.0
   - Component Status counts совпадают с реальными (секция 2)
   - In-Progress = None
   - < 200 строк
   - MCP: описывает 12 essential + 5 Go серверов
   - Key Paths: `projects."*".mcpServers` — УБРАТЬ если есть, мы не используем wildcard

## Секция 14: Cross-Reference Integrity

1. Все ссылки из CLAUDE.md на rules/ — файлы существуют
2. Все ссылки из CLAUDE.md на tools/ — файлы существуют
3. Все ссылки из CORE_INSTRUCTIONS на rules/ — файлы существуют
4. Все ссылки из project-init agent на templates/ — файлы существуют
5. PERMISSIONS.md ссылки на per-type files — файлы существуют
6. working-directories.md пути — все /opt/* директории существуют (или могут быть созданы)

## Секция 15: Enforce-проверка (runtime)

1. Запусти session_start_reinforcement.py с stdin `{"sessionId":"test"}` и `CLAUDE_WORKING_DIRECTORY=/opt/project` — должен вернуть JSON с hookSpecificOutput
2. Запусти garbage_collector.py — не должен падать с ошибкой
3. Запусти `echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | ~/.claude/mcp-servers/gc-mcp/gc-mcp` — должен вернуть 3 tools
4. Запусти то же для profile-mcp — должен вернуть 8 tools
5. Запусти то же для doctor-mcp — 3 tools, score-mcp — 3 tools, backlog-mcp — 8 tools
6. Запусти go test для всех 5 Go серверов — все должны проходить
7. Проверь синтаксис всех Python hooks: `python3 -c "import ast; ast.parse(open('file').read())"` для каждого .py в hooks/

---

## Секция 16: Автономность субагентов (bypass + safety escalation)

Субагенты/агенты/команды (Task tool, TeamCreate teammates) должны работать БЕЗ запросов к пользователю — mode: "bypassPermissions" или "acceptEdits". Но опасные действия должны эскалироваться к главной сессии.

### 16.1: Проверка mode enforcement

1. Прочитай `~/.claude/rules/task-execution.md` — найди секцию "Subagents & Teams"
2. Проверь: содержит `ALWAYS mode: "acceptEdits"` или `bypassPermissions` для ALL subagents и teammates
3. Прочитай `~/.claude/CORE_INSTRUCTIONS.md` — найди MANDATORY DELEGATION
4. Проверь: содержит `mode: "acceptEdits"` enforcement

### 16.2: Проверка что субагенты НЕ спрашивают разрешений

1. Проверь settings.json: для path-dependent tools (Edit/Write) — покрыты ли все shared dirs?
   Ожидание: 16 dirs × 2 (Edit+Write) = 32 записи для /opt/* + 2 для ~/.claude/**
2. Для проектных dirs: субагент наследует permissions от parent session → settings.local.json даёт Edit/Write к {{project_path}}
3. Read/Grep/Glob = `Read(*)` → без ограничений
4. Bash = per-command allow → все рабочие команды (git, python, go, npm, make и т.д.) уже в allow
5. MCP tools = все 121 записей в allow → без запросов

### 16.3: Safety escalation для опасных действий

Субагенты должны НЕ выполнять автономно, а эскалировать к leader:

1. **Запись вне рабочих dirs**: Edit/Write к путям НЕ в shared dirs и НЕ в project path → должен вернуть ошибку (permission denied) или эскалировать через SendMessage к team lead
2. **Dangerous Bash commands**: commands в `ask` секции (nmap, docker run, terraform apply, kubectl apply, rm, sudo) → субагент получит permission denied → должен сообщить leader через SendMessage
3. **DESTRUCTIVE actions**: commands в `deny` секции (rm -rf /, dd, mkfs) → абсолютный блок, даже для bypass

### 16.4: Реализация и проверка

1. Проверь: `~/.claude/rules/task-execution.md` содержит правило эскалации:
   - Субагент получает permission denied → НЕ ретраит → отправляет SendMessage leader-у с описанием действия
   - Leader решает: выполнить самостоятельно или отклонить
2. Если правило отсутствует — **ДОБАВЬ** в task-execution.md секцию:

```markdown
## Subagent Safety Escalation

When a subagent/teammate hits a permission boundary:
1. Do NOT retry the blocked action
2. Send `SendMessage` to team lead with: action description, target path, reason needed
3. Team lead either: executes the action in main session, or denies with explanation
4. Subagent continues with the result

Actions that trigger escalation:
- Edit/Write outside shared dirs and project path
- Bash commands in `ask` tier (nmap, docker run, terraform apply, kubectl apply, rm, sudo)
- Any action returning permission denied

Actions that are absolute blocks (no escalation):
- Commands in `deny` tier (rm -rf /, dd, mkfs, shutdown, reboot)
- Read of secrets (.env, credentials, ssh keys)
```

3. Проверь: CORE_INSTRUCTIONS.md содержит или ссылается на это правило
4. Протестируй: запусти субагент с mode: "acceptEdits", попроси его `Edit(/etc/hosts)` — должен получить отказ, НЕ prompt пользователю

---

## Организация работы

Запусти 3 параллельных Explore-агента:

**auditor-1**: Секции 1, 2, 3, 4, 5 (versions, counts, permissions, MCP)
**auditor-2**: Секции 6, 7, 8, 9, 10 (hooks, GC, rules, system prompt, mappings)
**auditor-3**: Секции 11, 13, 14, 15, 16 (project-init, backlog/memory, cross-refs, runtime, subagent autonomy)

Секцию 12 (мусор) — выполни в main process после получения результатов от аудиторов.

## Формат отчёта

```
## Секция N: <название>
STATUS: PASS | FAIL | WARN
FINDINGS:
- [PASS] что проверено и ок
- [FAIL] что сломано + как починить
- [WARN] что подозрительно

## Summary
PASS: N/16
FAIL: N/16
WARN: N/16

### Action Items (FAIL)
1. ...

### Action Items (WARN)
1. ...
```
