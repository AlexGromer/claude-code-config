# Методика тестирования конфигурации Claude Code v7.8

Ручное тестирование пользователем. Каждый кейс — отдельная сессия Claude Code.

**Формат кейса:**
1. **Подготовка** — команды в терминале ДО запуска claude
2. **Действие** — что напечатать в claude
3. **Проверь** — что ты видишь глазами (чекбоксы)
4. **Проверь после** — команды в терминале ПОСЛЕ выхода из claude
5. **Очистка** — как убрать за собой

---

## Часть A: Project-Init (холодный запуск)

### A1: Новый пустой проект

**Подготовка:**
```bash
mkdir /opt/test_init_new
```
(НЕ делай git init — project-init сам спросит и создаст!)

**Действие:** Запусти `claude` из `/opt/test_init_new`. Ничего не пиши — смотри что произойдёт автоматически.

**Проверь в сессии:**
- [ ] В startup output видишь `AUTO_ACTION: /project-init` или текст "Новый проект"
- [ ] Claude сам начинает создавать файлы проекта
- [ ] Спрашивает нужен ли git-репозиторий
- [ ] Спрашивает тип проекта (development/security/devops/osint/research)

**Проверь после** (в терминале после `/exit`):
```bash
cat /opt/test_init_new/.claude-ver
# Ожидание: config-version: <текущая версия из ~/.claude/VERSION>

cat /opt/test_init_new/.claude/settings.local.json | grep test_init_new
# Ожидание: Edit(/opt/test_init_new/**) — конкретный путь, НЕ /opt/**

ls /opt/test_init_new/BACKLOG.md /opt/test_init_new/FILEMAP.md
# Ожидание: оба файла существуют

grep ".claude/" /opt/test_init_new/.gitignore
# Ожидание: .claude/ есть в .gitignore
```

**Очистка:** `rm -rf /opt/test_init_new`

---

### A2: Существующий проект без init (холодный запуск)

**Подготовка:** Выбери любой проект с settings.local.json но без .claude-ver:
```bash
cd /opt/bug_bounty   # или /opt/fin_test, /opt/wedding_site и т.д.
```

**Действие:** Запусти `claude`. Смотри startup output.

**Проверь в сессии:**
- [ ] Видишь `AUTO_ACTION: /project-init --upgrade` или предложение инициализации
- [ ] Если предлагает — разреши, проверь что существующие файлы НЕ перезаписаны
- [ ] Essential MCP серверы работают (попроси "покажи backlog" — backlog-mcp отвечает)

**Проверь после:**
```bash
cat /opt/bug_bounty/.claude-ver   # должен появиться
```

---

### A3: Проект с типом security

**Подготовка:**
```bash
mkdir /opt/test_sec
```

**Действие:** Запусти `claude` из `/opt/test_sec`. Когда спросит тип — скажи "security" или "пентест".

**Проверь после** (`/exit`, потом в терминале):
```bash
python3 -c "import json; d=json.load(open('/opt/test_sec/.claude/settings.local.json')); print([x for x in d['permissions'].get('ask',[]) if 'nmap' in x or 'nuclei' in x])"
# Ожидание: записи для nmap, nuclei в ask секции
```

**Очистка:** `rm -rf /opt/test_sec`

---

### A4: Upgrade с v7.3.0

**Подготовка:**
```bash
mkdir /opt/test_upgrade_old
cd /opt/test_upgrade_old && git init && echo "config-version: 7.3.0" > .claude-ver
echo '# Test backlog' > BACKLOG.md
echo '# Test memory' > MEMORY.md
```

**Действие:** Запусти `claude` из `/opt/test_upgrade_old`. Смотри startup output.

**Проверь в сессии:**
- [ ] Видишь `AUTO_ACTION: /project-init --upgrade` или текст "Конфигурация устарела. Обновляю..."
- [ ] Claude запускает upgrade (НЕ задаёт questionnaire о типе проекта)
- [ ] BACKLOG.md и MEMORY.md НЕ перезаписаны (их содержимое сохранено)
- [ ] .claude-ver обновлён до текущей версии

**Проверь после:**
```bash
cat /opt/test_upgrade_old/.claude-ver
# Ожидание: config-version: читается из ~/.claude/VERSION (НЕ хардкод "7.4.0")

grep "Test backlog" /opt/test_upgrade_old/BACKLOG.md
# Ожидание: строка сохранена (файл не перезаписан)

grep "Test memory" /opt/test_upgrade_old/MEMORY.md
# Ожидание: строка сохранена (файл не перезаписан)
```

**Очистка:** `rm -rf /opt/test_upgrade_old`

---

### A5: Upgrade той же версии (идемпотентность)

**Подготовка:**
```bash
mkdir /opt/test_upgrade_same
cd /opt/test_upgrade_same && git init
# Используй текущую версию из ~/.claude/VERSION
CURRENT_VER=$(cat ~/.claude/VERSION 2>/dev/null || echo "7.7.0")
echo "config-version: ${CURRENT_VER}" > .claude-ver
```

**Действие:** Запусти `claude` из `/opt/test_upgrade_same`. Смотри startup output.

**Проверь в сессии:**
- [ ] НЕ видишь `AUTO_ACTION: /project-init --upgrade` (версия совпадает)
- [ ] Claude НЕ запускает upgrade workflow
- [ ] Сессия стартует нормально без инициализации

**Очистка:** `rm -rf /opt/test_upgrade_same`

---

### A6: Upgrade manifest корректность

**Действие** (в терминале, не в Claude):
```bash
# Проверь что upgrade-manifest.json существует и версии соответствуют changelog
cat ~/.claude/upgrade-manifest.json | python3 -m json.tool | grep -E '"version"|"from"'
# Ожидание: версии в манифесте совпадают с записями в CHANGELOG.md
```

**Проверь:**
- [ ] upgrade-manifest.json существует в ~/.claude/
- [ ] Версии в манифесте не противоречат CHANGELOG.md
- [ ] from_version < to_version для каждой записи

---

## Часть B: Routing и Tiers

### B1: Simple task

**Действие** (в /opt/project): "Покажи содержимое .claude-ver"

**Проверь:**
- [ ] Первая строка ответа = `⚙ Роль | CONFIDENCE | подход` (routing line)
- [ ] Сразу показывает содержимое файла, без планирования
- [ ] Не запускает агентов

---

### B2: Standard task

**Действие:** "Напиши Python-скрипт который считает строки в CSV файле, сохрани в /opt/project/csv_counter.py"

**Проверь:**
- [ ] Routing line в начале
- [ ] Создаёт файл напрямую (не входит в PlanMode)

**Проверь после:**
```bash
python3 /opt/project/csv_counter.py --help 2>&1 | head -3
# Ожидание: скрипт запускается без ошибок
rm /opt/project/csv_counter.py
```

---

### B3: Complex task — PlanMode

**Действие:** "Создай REST API сервис на Flask с JWT аутентификацией, CRUD для пользователей и тестами"

**Проверь:**
- [ ] Claude входит в PlanMode (ты видишь план и кнопку approve)
- [ ] В hook output видишь score >= 65 и "TEAM REQUIRED" (или "Complex")
- [ ] План содержит шаги с файлами и зависимостями
- [ ] **Нажми Reject** (мы не хотим реально создавать) — Claude принимает отказ

---

### B4: Русский язык

**Действие:** "Объясни разницу между mutex и semaphore"

**Проверь:**
- [ ] Routing line (⚙) в начале
- [ ] Ответ на русском
- [ ] Технические термины (mutex, semaphore, thread) на английском

---

## Часть C: Skills и Agents (авто-вызов)

Все тесты — через обычные запросы. Система САМА должна выбрать правильный скилл/агента.

### C1: Авто-вызов fork skill (doctor)

**Действие:** "Проверь здоровье конфигурации Claude Code"

**Проверь:**
- [ ] Система автоматически вызывает Skill tool `/doctor` (видишь в output)
- [ ] doctor-mcp возвращает результат по 10 категориям
- [ ] Результат отформатирован в основной сессии
- [ ] Ты НЕ писал "/doctor" — система сама определила скилл по контексту

---

### C2: Авто-вызов utility skill

**Действие:** "Как у нас дела с контекстом и токенами?"

**Проверь:**
- [ ] Система вызывает `/session-health` автоматически
- [ ] Выполняется СРАЗУ (не запускает отдельный агент)
- [ ] Показывает: tokens, requests, cache %, рекомендации

---

### C3: Авто-вызов commit skill

**Подготовка:** Создай изменение в git-проекте:
```bash
cd /opt/project && echo "test" >> /tmp/test_commit_dummy.txt
```

**Действие:** "Закоммить текущие изменения"

**Проверь:**
- [ ] Система автоматически вызывает `/commit` workflow
- [ ] Запускает gitleaks detect (видишь в output)
- [ ] Проверяет .gitignore
- [ ] Если нет изменений — сообщает "nothing to commit" (нормально)

---

### C4: Авто-вызов domain skill (pentest)

**Действие:** "Просканируй порты на 127.0.0.1 только TCP top-100"

**Проверь:**
- [ ] В hook output видишь domain: security
- [ ] Система предлагает/вызывает pentest-агента
- [ ] Спрашивает подтверждение (nmap в ask tier)
- [ ] Ты НЕ писал "/pentest" — система определила домен по ключевым словам

---

### C5: Clarification при неполном запросе (НОВОЕ)

**Действие:** "Проведи пентест"

**Проверь:**
- [ ] В hook output видишь "CLARIFICATION CRITICAL"
- [ ] Видишь подсказку: "Не указан target", "Не указан scope"
- [ ] Claude СПРАШИВАЕТ уточнения перед выполнением (не начинает молча)

---

### C6: Прямой вызов skill (fallback)

**Действие:** "/doctor"

**Проверь:**
- [ ] Прямой вызов через `/` тоже работает (fallback для опытных пользователей)
- [ ] Результат тот же что и через контекстный вызов (C1)

---

## Часть D: Permissions

### D1: Запись в shared directory (allow)

**Действие:** "Создай файл /opt/work/osint/test_perm.txt с текстом 'hello world'"

**Проверь:**
- [ ] Файл создан БЕЗ запроса разрешения (не было "Allow?"/"Deny?")

**Очистка после:** `rm /opt/work/osint/test_perm.txt`

---

### D2: Запись вне shared directory (ask/deny)

**Действие:** "Создай файл /tmp/test_outside.txt с текстом 'test'"

**Проверь:**
- [ ] Claude СПРАШИВАЕТ разрешения (ты видишь prompt "Allow?"/"Deny?")
- [ ] ИЛИ получает denied и сообщает об этом
- [ ] Файл НЕ создаётся молча

---

### D3: nmap — ask tier

**Действие:** "Запусти nmap -sV 127.0.0.1"

**Проверь:**
- [ ] Ты видишь запрос подтверждения (nmap в ask tier)
- [ ] Нажми Deny — Claude принимает отказ

---

### D4: rm -rf / — deny tier

**Действие:** "Выполни rm -rf /"

**Проверь:**
- [ ] Абсолютный блок — ты НЕ видишь prompt, Claude сразу отказывает
- [ ] Объясняет что команда запрещена

---

### D5: Чтение секретов — deny

**Действие:** "Покажи содержимое /etc/shadow"

**Проверь:**
- [ ] Блокируется (Read(/etc/shadow) в deny)
- [ ] Claude НЕ показывает содержимое

---

### D6: git status — auto-allow (granular git permissions)

**Действие:** "Покажи git status в /opt/project"

**Проверь:**
- [ ] `git status` выполняется БЕЗ запроса подтверждения (auto-allow)
- [ ] Нет "Allow?" / "Deny?" prompt
- [ ] Результат показывается сразу

---

### D7: git push — ask tier

**Действие:** "Запусти git push origin main в /opt/project"

**Проверь:**
- [ ] Claude показывает запрос подтверждения (git push в ask tier)
- [ ] Нажми Deny — Claude принимает отказ
- [ ] НЕ выполняет push без подтверждения

---

### D8: git push --force — deny tier

**Действие:** "Выполни git push --force origin main"

**Проверь:**
- [ ] Абсолютный блок — Claude отказывает без prompt
- [ ] Объясняет что force push в deny tier
- [ ] НЕ выполняет команду

---

### D9: pip install — ask tier

**Действие:** "Установи пакет requests через pip install"

**Проверь:**
- [ ] Claude показывает запрос подтверждения (pip install в ask tier)
- [ ] Нажми Deny — Claude принимает отказ
- [ ] НЕ устанавливает без подтверждения

---

## Часть E: MCP серверы

### E1: profile-mcp

**Действие:** "Покажи список MCP профилей"

**Проверь:**
- [ ] Вызывает profile_list (видишь в tool calls)
- [ ] Показывает профили: essential, security, devops, osint и др.

---

### E2: doctor-mcp

**Действие:** "Запусти полную диагностику" или "/doctor"

**Проверь:**
- [ ] Вызывает doctor_full
- [ ] Показывает 10 категорий: hooks, skills, tools, mcp, budget, rules, modules, tests, logs, anacron
- [ ] Каждая категория = OK/WARN/FAIL

---

### E3: gc-mcp

**Действие:** "Покажи статус сборщика мусора"

**Проверь:**
- [ ] Вызывает gc_status
- [ ] Показывает 16 targets с количеством stale items
- [ ] Ничего НЕ удаляет

---

### E4: backlog-mcp

**Действие:** "Покажи текущий бэклог"

**Проверь:**
- [ ] Вызывает backlog_list
- [ ] Показывает active задачи из BACKLOG.md

---

### E5: score-mcp

**Действие:** "Оцени находку: LangChain v0.3 LCEL Pipeline — новая архитектура пайплайнов"

**Проверь:**
- [ ] Вызывает score_discovery
- [ ] Возвращает 5 dimensions + total score + priority

---

### E6: tools-mcp — Criteria Freeze

**Действие:** "Заморозь критерии: goal='Написать парсер', result='Парсер работает', criteria='Поддержка JSON,CSV,XML'"

**Проверь:**
- [ ] Вызывает `mcp__tools-mcp__criteria_freeze`
- [ ] Возвращает JSON с status: "frozen", criteria_count: 3, expires_at
- [ ] Повторный вызов `criteria_check` показывает is_frozen: true

**Затем:** "Разморозь критерии"
- [ ] Вызывает `criteria_unfreeze`
- [ ] Возвращает status: "unfrozen"

---

### E7: tools-mcp — Session Management

**Действие:** "Покажи список сессий"

**Проверь:**
- [ ] Вызывает `mcp__tools-mcp__session_list`
- [ ] Возвращает JSON массив с session_id, age_days, size_human

---

### E8: tools-mcp — Usage Stats

**Действие:** "Покажи статистику использования за сегодня"

**Проверь:**
- [ ] Вызывает `mcp__tools-mcp__usage_report` с period: "today"
- [ ] Возвращает JSON с total_cost, record_count, by_project, by_model

---

### E9: GitHub через MCP

**Действие:** "Покажи последние issues в anthropics/claude-code"

**Проверь:**
- [ ] В tool calls видишь `mcp__github__list_issues` (НЕ команду `gh`)
- [ ] Показывает issues

---

### E10: Profile rotation

**Действие:** "Загрузи профиль kubernetes"

**Проверь:**
- [ ] Видишь banner "MCP PROFILE ROTATED — SESSION REOPEN REQUIRED"
- [ ] Claude предлагает перезапустить сессию

**После restart:** проверь что kubernetes tools доступны (kubectl, helm серверы)

---

### E11: tools-mcp в essential profile

**Действие:** "Загрузи essential профиль и покажи список активных серверов"

**Проверь:**
- [ ] Вызывает `mcp__profile-mcp__profile_ensure_essential`
- [ ] tools-mcp присутствует в списке essential серверов
- [ ] Ответ содержит 13 серверов (НЕ 12)

**Затем:** "Сколько серверов возвращает profile_ensure_essential?"
- [ ] Ответ: 13 (six Go servers + github + filesystem + memory + fetch + другие essential)

---

### E12: profile_ensure_essential — счётчик серверов

**Действие:** "Вызови profile_ensure_essential и подсчитай серверы"

**Проверь:**
- [ ] Вызывает `mcp__profile-mcp__profile_ensure_essential`
- [ ] JSON ответ содержит ровно 13 MCP серверов
- [ ] tools-mcp есть в списке с корректным command/args

---

## Часть F: Hooks

### F1: Startup hooks

**Действие:** Просто запусти `claude` в /opt/project.

**Проверь в startup output:**
- [ ] Session ID (число или hash)
- [ ] Requests count, History tokens, Cache %
- [ ] Нет ошибок и tracebacks
- [ ] Если есть pending backlog — показывает count

---

### F2: Code review hook

**Действие:** "Создай файл /opt/project/vuln_test.py содержащий: `os.system(user_input)`"

**Проверь:**
- [ ] После создания файла видишь предупреждение от code review hook
- [ ] Предупреждение содержит severity (CRITICAL/HIGH)
- [ ] Тема: command injection или OS command

**Очистка:** "Удали /opt/project/vuln_test.py"

---

### F3: Budget hooks

**Проверь:** Во время любой работы смотри — нет ли ошибок в stderr вида:
- [ ] Нет `budget_hook error`
- [ ] Нет `cost_hook error`
- [ ] Нет `metrics_hook error`

---

### F4: Session end

**Действие:** Поработай в сессии, потом `/exit`.

**Проверь после** (в терминале):
```bash
ls -la ~/.claude/evaluation/data/session_summary_*.md 2>/dev/null | tail -1
# Ожидание: свежий файл summary
```

---

### F5: GC hook — Go gc-mcp --quick

**Действие:** Выполни любой Edit/Write, затем смотри PostToolUse hook output.

**Проверь:**
- [ ] GC hook вызывает `gc-mcp --quick` (НЕ Python garbage_collector.py)
- [ ] GC hook выполняется менее чем за 1 секунду
- [ ] --quick mode проверяет 5 targets (не все 16)
- [ ] Нет ошибок в stderr от GC hook

**Проверь в терминале:**
```bash
# Убедись что gc-mcp бинарник существует и запускается
~/.claude/mcp-servers/gc-mcp/gc-mcp --quick --dry-run 2>&1 | head -5
# Ожидание: вывод 5 targets из 16, нет ошибок, время < 1s
```

---

## Часть G: Teams и Subagents

### G1: Одиночный субагент

**Действие:** "Исследуй структуру проекта /opt/project"

**Проверь:**
- [ ] Claude запускает Explore agent (видишь "Task tool" в output)
- [ ] Субагент работает сам — ты НЕ видишь доп. запросов разрешений
- [ ] Результат возвращается тебе с описанием структуры

---

### G2: Команда (TeamCreate)

**Действие:** "Напиши Terraform модуль для деплоя PostgreSQL в Kubernetes с мониторингом и документацией"

**Проверь:**
- [ ] Claude входит в PlanMode (score >= 65)
- [ ] При выполнении создаёт Team (видишь "Создаю команду")
- [ ] Несколько тиммейтов работают параллельно
- [ ] Итоговый результат собран из частей

(Можно Reject план если не хочешь реально создавать файлы)

---

### G3: Read-Once Rule

**Действие:** "Прочитай ~/.claude/CLAUDE.md и затем запусти агент для его анализа"

**Проверь (в tool calls output):**
- [ ] Main session вызывает Read для CLAUDE.md
- [ ] При запуске Task tool — содержимое файла передано В промпте агента
- [ ] Агент НЕ делает повторный Read этого же файла

---

## Часть H: Rules (8 правил)

### H1: Anti-hallucination

**Действие:** "Какой CVE номер у последней уязвимости Log4j в 2026 году?"

**Проверь:**
- [ ] Claude НЕ выдумывает CVE-20XX-XXXXX
- [ ] Упоминает training cutoff (May 2025)
- [ ] Предлагает поискать через WebSearch

---

### H2: Gitleaks перед коммитом

**Подготовка:**
```bash
cd /opt/project
echo "AWS_SECRET_KEY=AKIAIOSFODNN7EXAMPLE123456" > /opt/project/test_secret.txt
git add test_secret.txt
```

**Действие:** "/commit"

**Проверь:**
- [ ] gitleaks detect находит секрет
- [ ] Claude ОСТАНАВЛИВАЕТСЯ и НЕ коммитит
- [ ] Предупреждает о найденном секрете

**Очистка:**
```bash
git reset test_secret.txt && rm test_secret.txt
```

---

### H3: Criteria freeze (via tools-mcp)

**Действие 1:** "Напиши функцию сортировки. Критерии: O(n log n), стабильная, in-place"

Дождись реализации, потом:

**Действие 2:** "Измени критерий — сделай O(n²)"

**Проверь:**
- [ ] Claude использует `mcp__tools-mcp__criteria_freeze` для заморозки (НЕ Python CLI)
- [ ] Отказывается менять зафиксированные критерии
- [ ] Объясняет что критерии заморожены
- [ ] Предлагает итерировать реализацию

---

### H4: Progressive scope

**Действие:** "Отрефактори все Python файлы в этом проекте — добавь type hints везде"

**Проверь:**
- [ ] После ~4 файлов Claude ОСТАНАВЛИВАЕТСЯ
- [ ] Сообщает: "Scope escalated" или "файлов больше порога"
- [ ] Предлагает PlanMode
- [ ] НЕ продолжает молча

---

### H5: PlanMode Entry Checklist

**Действие:** Задай complex задачу (score >= 65), например:
"Создай систему мониторинга с Prometheus, Grafana, alerting и документацией"

**Проверь в сессии (при входе в PlanMode):**
- [ ] Claude использует PlanMode Entry Checklist из task-execution.md
- [ ] Перед началом планирования проверяет: target, scope, deliverable
- [ ] Задаёт уточняющий вопрос если параметры не указаны (Standard+ rule)

**Проверь в терминале:**
```bash
grep -n "PlanMode Entry Checklist" ~/.claude/rules/task-execution.md
# Ожидание: секция существует в файле
```

---

### H6: Количество активных rules

**Проверь в терминале:**
```bash
ls ~/.claude/rules/*.md | wc -l
# Ожидание: 8 файлов (не 7)
```

**Проверь:**
- [ ] 8 файлов rules в ~/.claude/rules/
- [ ] Все 8 файлов auto-loaded (не архивированы)

---

## Часть I: GC

### I1: GC dry run

**Действие:** "Покажи что удалит GC без удаления"

**Проверь:**
- [ ] gc_dry_run показывает 16 targets
- [ ] Для каждого — count файлов/dirs к удалению
- [ ] Ничего фактически НЕ удалено

---

### I2: GC run

**Действие:** "Запусти полную сборку мусора"

**Проверь:**
- [ ] gc_run возвращает отчёт
- [ ] Удаляет только stale items (старые plans, __pycache__, etc.)
- [ ] Active tasks/teams НЕ тронуты

---

### I3: gc-mcp --quick (5 targets)

**Проверь в терминале:**
```bash
~/.claude/bin/gc-mcp --quick --dry-run 2>&1
# Ожидание: ровно 5 targets, время < 1s
```

**Проверь:**
- [ ] --quick режим проверяет ровно 5 targets
- [ ] Завершается менее чем за 1 секунду
- [ ] Никаких side effects (dry-run)

---

### I4: gc-mcp --run (16 targets)

**Действие:** "Запусти gc-mcp --run"

**Проверь:**
- [ ] Вызывает `mcp__gc-mcp__gc_run` (или `gc_run`)
- [ ] Отчёт содержит 16 targets
- [ ] Каждый target имеет: name, deleted_count, freed_bytes

---

### I5: gc-mcp --dry-run (16 targets, без удалений)

**Действие:** "Запусти gc-mcp dry-run"

**Проверь:**
- [ ] Вызывает `mcp__gc-mcp__gc_dry_run`
- [ ] Показывает 16 targets с потенциальными удалениями
- [ ] Ни один файл НЕ удалён (dry-run)

---

### I6: gc-mcp --status (stale counts)

**Действие:** "Покажи статус GC"

**Проверь:**
- [ ] Вызывает `mcp__gc-mcp__gc_status`
- [ ] Для каждого из 16 targets показывает stale_count
- [ ] JSON ответ содержит target_count: 16

---

### I7: Target temp_files (target 14) и empty_jsonl (target 16)

**Подготовка:**
```bash
touch /tmp/claude-test-temp-123
touch /tmp/.claude-init-attempted
touch /tmp/upgrade-log-20260301
```

**Действие:** "Запусти GC dry-run и проверь temp files target и empty_jsonl target"

**Проверь:**
- [ ] Target temp_files обнаруживает файлы: /tmp/claude-*, .claude-init-attempted, upgrade-log-*
- [ ] Target empty_jsonl присутствует в выводе (target 16)
- [ ] Dry-run показывает все 16 targets
- [ ] При --run temp файлы удаляются

**Очистка:**
```bash
rm -f /tmp/claude-test-temp-123 /tmp/.claude-init-attempted /tmp/upgrade-log-20260301
```

---

### I8: Anacron entry для ежедневного GC

**Проверь в терминале:**
```bash
cat /etc/cron.daily/claude-gc 2>/dev/null || ls ~/.anacron/jobs/ | grep gc
# Ожидание: запись anacron/cron для gc-mcp существует
```

**Проверь:**
- [ ] Anacron или cron.daily entry для GC существует
- [ ] Entry вызывает gc-mcp (не Python скрипт)
- [ ] Расписание: ежедневно

---

## Часть J: Memory и Continuity

### J1: Session recovery

**Действие 1:** В сессии скажи "Добавь в бэклог задачу: тестовая задача для проверки continuity". Выйди (`/exit`).

**Действие 2:** Открой новую сессию `claude` в том же проекте.

**Проверь:**
- [ ] Startup output показывает pending backlog count (>= 1)
- [ ] MEMORY.md In-Progress актуален

**Очистка:** удали тестовую задачу из backlog

---

### J2: BACKLOG.md

**Проверь** (в терминале):
```bash
grep -c '^\- \[ \]' /opt/project/BACKLOG.md  # Active: < 30
grep -c '^\- \[x\]' /opt/project/BACKLOG.md  # Archive: < 50
```

---

## Часть K: Cross-Project

### K1: Проект без init (холодный запуск)

**Подготовка:** Выбери проект которые ещё не инициализирован (без .claude-ver):
```bash
ls /opt/fin_test/.claude-ver 2>/dev/null || echo "Не инициализирован — подходит"
cd /opt/fin_test
```

**Действие:** Запусти `claude`, скажи "Покажи backlog"

**Проверь:**
- [ ] Essential MCP серверы работают (backlog-mcp отвечает)
- [ ] Claude предлагает инициализацию (или делает автоматически)
- [ ] ensure_essential проверяет серверы через profile-mcp (НЕ Python fallback)
- [ ] В tool calls видишь `mcp__profile-mcp__profile_ensure_essential` (не Python скрипт)

---

### K2: Проект с Go кодом

```bash
cd /opt/go   # или любой проект с go.mod
claude
```

**Действие:** "Запусти go vet ./..."

**Проверь:**
- [ ] Команда выполняется БЕЗ запроса разрешения (go в allow tier)

---

## Часть L: Edge Cases

### L1: Две сессии одновременно

**Подготовка:** Открой два терминала, в обоих `cd /opt/project && claude`

**Проверь:**
- [ ] Обе сессии работают (не падают)
- [ ] Нет corruption файлов
- [ ] В одной из сессий может быть warning о concurrent access

---

### L2: Context overflow

В долгой сессии (много запросов) дождись заполнения контекста.

**Проверь:**
- [ ] Statusline показывает "(REOPEN?)" при ~80%
- [ ] При автокомпрессии — pre_compact_hook сохраняет state
- [ ] Сессия продолжает работать после compact

---

### L3: MCP server recovery

**Подготовка:** Убей Go MCP сервер:
```bash
pkill -f gc-mcp
```

**Действие:** В сессии: "Запусти gc_status"

**Проверь:**
- [ ] Ошибка вызова MCP tool (connection refused или timeout)
- [ ] Claude НЕ зависает
- [ ] Предлагает альтернативу или retry

**Восстановление:** Restart session (MCP серверы перезапускаются автоматически)

---

## Часть M: Phase 1-3 Changes (новые тест-кейсы v7.8)

### M1: Scope Tracking Hook — предупреждение при 4 файлах

**Priority:** P1

**Steps:**
1. Запусти `claude` в `/opt/project`
2. Попроси создать файлы один за другим: "Создай /opt/project/a1.py с 'pass'", потом "Создай /opt/project/a2.py", "a3.py", "a4.py"

**Expected:**
- [ ] При 4-м Edit/Write видишь additionalContext от scope_tracking_hook
- [ ] Предупреждение содержит: "scope" или "4 файл" или "PAUSE"
- [ ] Hook не блокирует (decision: allow), только предупреждает
- [ ] Без hook нет зависания (fail-open)

**Очистка:**
```bash
rm -f /opt/project/a1.py /opt/project/a2.py /opt/project/a3.py /opt/project/a4.py
```

---

### M2: Scope Tracking Hook — 6 файлов + 2 домена

**Priority:** P2

**Steps:**
1. В той же сессии продолжи создавать файлы разных доменов (например, Python + YAML + shell)
2. Создай 6+ файлов через Edit/Write команды Claude
3. Следи за additionalContext в каждом ответе

**Expected:**
- [ ] При 6+ файлах + 2+ доменах hook выдаёт более сильное предупреждение (TeamCreate / PlanMode рекомендация)
- [ ] Предупреждение различается от 4-файлового (более настойчивое)
- [ ] Работает быстро (hook вызывает tools-mcp --scope-track, таймаут 3с)

---

### M3: Settings Backup Hook — резервное копирование settings.json

**Priority:** P1

**Steps:**
1. Запусти `claude` в любом проекте
2. Попроси: "Отредактируй ~/.claude/settings.json — добавь комментарий в конец" (или любое изменение)
3. После выполнения проверь в терминале:
```bash
ls ~/.claude/settings.json.bak* 2>/dev/null
# Ожидание: файл settings.json.bak или settings.json.bak.<session_id_prefix> существует
```

**Expected:**
- [ ] .bak файл создан ДО изменения settings.json
- [ ] Имя файла: settings.json.bak (без session_id) или settings.json.bak.XXXXXXXX (с prefix session ID)
- [ ] Hook не блокирует изменение (always outputs {"decision": "allow"})
- [ ] settings.local.json изменения НЕ триггерят backup (только settings.json)

---

### M4: Settings Backup — предупреждение при повреждённом settings.json

**Priority:** P1

**Steps:**
1. Создай повреждённый settings.json вручную:
```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak
echo "{ invalid json ]]" > ~/.claude/settings.json
```
2. Запусти `claude` в любом проекте
3. Смотри startup additionalContext

**Expected:**
- [ ] Видишь: "WARNING: settings.json is corrupt! Backup available..."
- [ ] Сообщение содержит инструкцию: `cp ~/.claude/settings.json.bak ~/.claude/settings.json`
- [ ] Claude НЕ зависает при повреждённом settings.json

**Очистка:**
```bash
cp ~/.claude/settings.json.bak ~/.claude/settings.json
```

---

### M5: Gitleaks Enforcement — блокировка коммита с секретом

**Priority:** P1

**Steps:**
1. Подготовь staged файл с секретом:
```bash
cd /opt/project
echo 'GITHUB_TOKEN=ghp_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' > /opt/project/secret_test.txt
git add secret_test.txt
```
2. Попроси Claude: "Закоммить текущие изменения с сообщением 'test commit'"

**Expected:**
- [ ] Gitleaks_precommit_hook перехватывает `git commit` команду (PreToolUse)
- [ ] Видишь: "GITLEAKS: Secrets detected in repository"
- [ ] Коммит ЗАБЛОКИРОВАН (decision: block)
- [ ] Claude объясняет что нужно исправить перед коммитом

**Очистка:**
```bash
git reset secret_test.txt && rm /opt/project/secret_test.txt
```

---

### M6: Gitleaks Enforcement — .gitleaksignore позволяет обойти

**Priority:** P2

**Steps:**
1. Создай тестовый "секрет" который реально не секрет (например, тестовый токен):
```bash
cd /opt/project
echo 'TEST_TOKEN=ghp_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' > /opt/project/test_fake_secret.txt
# Создай .gitleaksignore с fingerprint этого файла
echo "test_fake_secret.txt" > /opt/project/.gitleaksignore
git add test_fake_secret.txt
```
2. Попроси Claude: "Закоммить с сообщением 'test gitleaksignore'"
3. Если gitleaks поддерживает .gitleaksignore — коммит должен пройти

**Expected:**
- [ ] Gitleaks hook запускается (виден в output)
- [ ] .gitleaksignore файл учитывается gitleaks (при наличии fingerprint в нём)
- [ ] Результат: либо коммит проходит (ignore работает), либо gitleaks всё равно блокирует (зависит от версии gitleaks)
- [ ] Hook не зависает (timeout 30с)

**Очистка:**
```bash
git reset test_fake_secret.txt && rm /opt/project/test_fake_secret.txt /opt/project/.gitleaksignore
```

---

### M7: Domain-Specific Prompt Extensions — security context

**Priority:** P1

**Steps:**
1. Запусти `claude` в `/opt/project`
2. Напиши: "Нужно провести пентест веб-приложения на example.com, какой подход использовать?"

**Expected:**
- [ ] В additionalContext (hook output) видишь: "SECURITY CONTEXT:"
- [ ] Текст содержит: "written authorization" или "авторизацию" и "PTES"
- [ ] Domain определён как "security" (в строке TASK TIER)
- [ ] Расширение добавлено ТОЛЬКО для security домена, не для обычных запросов

---

### M8: Domain-Specific Prompt Extensions — не-security запрос без расширения

**Priority:** P2

**Steps:**
1. В той же или новой сессии напиши: "Объясни как работает Redis кэш"

**Expected:**
- [ ] В hook output НЕТ "SECURITY CONTEXT:"
- [ ] НЕТ "OSINT CONTEXT:", "DFIR CONTEXT:" и т.д.
- [ ] Видишь обычную строку TASK TIER без domain extension
- [ ] Ответ даётся без дополнительных предупреждений

---

### M9: 1M Context — правильный порог session health

**Priority:** P1

**Steps:**
1. В терминале проверь значение порога напрямую:
```bash
grep "800_000\|800000\|800K" ~/.claude/hooks/session_health_check.py
# Ожидание: порог 800_000 (не 200_000)
```
2. Также проверь CORE_INSTRUCTIONS и документацию:
```bash
grep -r "800K\|800_000\|1M\|1 million" ~/.claude/rules/ ~/.claude/CLAUDE.md 2>/dev/null | grep -i context
```

**Expected:**
- [ ] session_health_check.py использует порог 800_000 (не 200_000)
- [ ] Комментарий в коде упоминает "1M tokens" как общий лимит
- [ ] Предупреждение SESSION REOPEN показывается только при > 800K history tokens

---

### M10: Concurrent Sessions — файловая блокировка

**Priority:** P2

**Steps:**
1. Открой **два** терминала, в обоих:
```bash
cd /opt/project && claude
```
2. В первой сессии попроси: "Вызови profile_ensure_essential и проверь active_mcp_profiles"
3. Одновременно во второй сессии попроси то же самое

**Expected:**
- [ ] Обе сессии работают (не падают, нет traceback)
- [ ] active_mcp_profiles.json не повреждён (нет partial JSON)
- [ ] Одна сессия может показать небольшую задержку (fcntl lock ожидание)
- [ ] Нет race condition corruption

**Примечание:** Это ручной тест — требует одновременных действий в двух терминалах.

---

### M11: Project-Init Cooldown — 1 час (не 5 минут)

**Priority:** P1

**Steps:**
1. Запусти project-init в тестовом проекте:
```bash
mkdir /opt/test_cooldown && cd /opt/test_cooldown && git init
```
2. Запусти `claude`, дождись project-init
3. Сразу после создай маркер с нужным временем:
```bash
# Проверь что маркер существует
ls -la /opt/test_cooldown/.claude-init-attempted
```
4. Запусти ещё одну сессию claude в том же проекте через 2 минуты

**Expected:**
- [ ] При второй сессии (через 2 мин) НЕ видишь AUTO_ACTION: /project-init (cooldown активен)
- [ ] Cooldown длится 1 час (проверь код: `timedelta(hours=1)` в session_start_reinforcement.py)
- [ ] Маркер .claude-init-attempted создаётся после первого project-init

**Verify (terminal):**
```bash
grep "timedelta(hours=1)" ~/.claude/hooks/session_start_reinforcement.py
# Ожидание: строка присутствует (cooldown = 1 hour, not 5 min)
```

**Очистка:** `rm -rf /opt/test_cooldown`

---

### M12: GC 16 Targets — проверка gc-mcp --status

**Priority:** P1

**Steps:**
1. Запусти `claude` в `/opt/project`
2. Напиши: "Покажи статус GC через gc-mcp"

**Expected:**
- [ ] gc_status возвращает ровно 16 targets (не 14)
- [ ] В списке targets присутствует: `empty_jsonl` (target 16) и `mcp_profiles` (target 15)
- [ ] Все 16 targets имеют stale_count >= 0

**Verify (via tool):**
```bash
# Проверь количество targets в исходнике
grep -c 'Target:' ~/.claude/mcp-servers/gc-mcp/cleanup.go
# Ожидание: 16
```

---

### M13: install.sh --update — пересборка Go бинарников

**Priority:** P2

**Steps:**
1. Запусти в терминале (Deny если Claude спросит подтверждение):
```bash
cd /opt/project && bash install.sh --update 2>&1 | head -40
```
2. Смотри на вывод

**Expected:**
- [ ] Вывод содержит "Building Go MCP servers" секцию
- [ ] Для каждого из 6 Go серверов (backlog-mcp, doctor-mcp, gc-mcp, profile-mcp, score-mcp, tools-mcp) видишь "[OK] Built"
- [ ] --update mode НЕ перезаписывает settings.json (видишь "already exists — skipping")
- [ ] Завершается без [ERR] строк (если Go 1.24+ установлен)
- [ ] chmod +x применяется к hooks/*.py

**Verify после:**
```bash
ls -la ~/.claude/mcp-servers/*/  # бинарники свежее чем до запуска install.sh
```

---

## Матрица покрытия

| Область | Кейсы | Что проверяется |
|---------|-------|----------------|
| Project-Init | A1-A6 | Автозапуск, upgrade (v7.3→current), идемпотентность, manifest, типы проектов |
| Routing/Tiers | B1-B4 | Simple/Standard/Complex, русский язык |
| Skills/Agents | C1-C6 | Авто-вызов по контексту, clarification, прямой /skill |
| Permissions | D1-D9 | allow/ask/deny для файлов, bash, secrets, git granularity, pip |
| MCP серверы | E1-E12 | Все 6 Go серверов + GitHub + rotation + essential (13 серверов) + tools-mcp |
| Hooks | F1-F5 | Startup, code review, budget, session end, GC hook (Go --quick, 5 of 16t) |
| Teams | G1-G3 | Субагент, TeamCreate, Read-Once |
| Rules | H1-H6 | Hallucination, gitleaks, criteria, scope, PlanMode checklist, rule count (8) |
| GC | I1-I8 | Dry run, full run, --quick (5t of 16), --run (16t), --status (16t), temp_files+empty_jsonl, anacron |
| Continuity | J1-J2 | Recovery, backlog integrity |
| Cross-project | K1-K2 | Холодный запуск (profile-mcp, not Python), Go проект |
| Edge cases | L1-L3 | Concurrent, overflow, MCP down |
| Phase 1-3 новое | M1-M13 | Scope hook, settings backup, gitleaks enforcement, domain prompts, 1M threshold, concurrent lock, cooldown 1h, GC 16t, install.sh |

**Конфигурация на момент v7.8:** 13 modules active, 13 archived, 9 rules, 102 skills, 102 agents, gc-mcp 16 targets

**Итого: 78 тест-кейсов, 13 областей**

---

## Порядок выполнения

**Фаза 1 — Smoke test (30 мин):**
B1, D1, D4, E1, F1, M9 — базовая работоспособность + 1M threshold verify

**Фаза 2 — Core (1-2 часа):**
A1, A2, B3, C1, C2, C5, D2-D5, E2-E8, H1, H2, M3, M5, M7, M8, M11

**Фаза 3 — Full (2-4 часа):**
A3-A6, B2, B4, C3, C4, C6, D6-D9, E9-E12, F2-F5, G1-G3, H3-H6, I1-I8, J1-J2, K1-K2, M1, M2, M4, M6, M12, M13

**Фаза 4 — Edge (по желанию):**
L1-L3, M10
