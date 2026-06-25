# Architecture Fixes v2 — Mechanical vs Advisory

## Ключевой факт

Всё загружается (CLAUDE.md, rules/, CORE_INSTRUCTIONS, SessionStart hooks).
Модель всё видит. AUTO_ACTION compliance = **0/10**.
LLM не выполняет инструкции автоматически — только если пользователь спросит.

## Принцип v2

**Всё что должно произойти гарантированно — выполнять БЕЗ LLM.**
- Wrapper (bash, до claude) — для pre-session actions
- settings.json permissions — для enforcement (client-side)
- PreToolUse hooks с `decision: block` — для gates
- LLM instructions (CLAUDE.md, rules/) — только для advisory, workflow guidance, tone

---

## MECHANICAL (100% reliability)

### M1: Project-init в wrapper (bash)
**Факт:** AUTO_ACTION compliance = 0/10. Модель не запускает project-init.
**Решение:** Wrapper проверяет `.claude-ver` до запуска claude и выполняет init механически.
```bash
# В wrapper, перед запуском claude:
CWD="$(pwd)"
CLAUDE_VER="$CWD/.claude-ver"
INIT_MARKER="$CWD/.claude-init-attempted"

# Skip /tmp and ~/.claude
case "$CWD" in /tmp*|$HOME/.claude*) ;; *)
  if [ ! -f "$CLAUDE_VER" ]; then
    # Check cooldown (1 hour)
    if [ ! -f "$INIT_MARKER" ] || [ $(( $(date +%s) - $(stat -c %Y "$INIT_MARKER" 2>/dev/null || echo 0) )) -gt 3600 ]; then
      touch "$INIT_MARKER"
      echo "⚡ New project detected. Run /project-init after session starts." >&2
    fi
  fi
esac
```
**Ограничение:** Wrapper не может запустить project-init Skill (это LLM tool). Может только:
- Создать marker file для хука
- Вывести banner пользователю
- Создать минимальные файлы (BACKLOG.md, .claude-ver) через bash
**Effort:** 30 min

### M2: Gitleaks enforcement (DONE)
**Факт:** PreToolUse hook с `decision: block` — 100% mechanical.
**Статус:** Реализовано. gitleaks_precommit_hook.py блокирует git commit при secrets.

### M3: settings.json backup (DONE)
**Факт:** PreToolUse hook копирует .bak — 100% mechanical.
**Статус:** Реализовано. settings_backup_hook.py.

### M4: Permission enforcement (DONE)
**Факт:** settings.json deny/allow/ask — client-side, модель не участвует.
**Статус:** 337 allow + 112 ask + deny rules.

### M5: GC (DONE)
**Факт:** gc-mcp --quick в SessionStart — Go binary, 100% mechanical.
**Статус:** 16 targets.

### M6: Scope tracking (DONE)
**Факт:** PostToolUse hook → Go binary tools-mcp --scope-track. Mechanical.
**Статус:** Warnings inject в additionalContext (advisory), но tracking = mechanical.

### M7: Wrapper session_id + budget (DONE)
**Факт:** Bash wrapper генерирует session_id, архивирует spending. 100% mechanical.

### M8: Project-init minimal bootstrap в wrapper (NEW)
**Проблема:** Полный project-init требует LLM (опрос пользователя, выбор типа). Но базовые файлы можно создать механически.
**Решение:** Wrapper создаёт минимальный набор для нового проекта:
```bash
if [ ! -f "$CLAUDE_VER" ] && [ ! -f "$INIT_MARKER" ]; then
  mkdir -p "$CWD/.claude"
  # Создать minimal .claude-ver
  echo "config-version: $(cat $HOME/.claude/VERSION 2>/dev/null || echo 8.0.0)" > "$CLAUDE_VER"
  # Создать BACKLOG.md если нет
  [ ! -f "$CWD/BACKLOG.md" ] && echo -e "# BACKLOG\n\n## Active\n\n## Completed Archive\n" > "$CWD/BACKLOG.md"
  # Создать .gitignore если нет
  [ ! -f "$CWD/.gitignore" ] && cp "$HOME/.claude/templates/project-init/gitignore.template" "$CWD/.gitignore" 2>/dev/null
  touch "$INIT_MARKER"
  echo "⚡ Project initialized (minimal). Run /project-init for full setup." >&2
fi
```
**Что это даёт:** Базовые файлы создаются 100% reliably. Полная инициализация (ARCHITECTURE, permissions, ONBOARDING) — по-прежнему через LLM/skill, но не критична.
**Effort:** 30 min

### M9: Banner в wrapper (NEW)
**Проблема:** Пользователь не видит что wrapper работает.
**Решение:** Добавить echo перед запуском claude:
```bash
echo "═══ Claude Code Wrapper v3.0 ═══" >&2
echo "Session: ${CLAUDE_SESSION_ID:0:8} | Project: $(basename $CWD)" >&2
```
**Effort:** 5 min

---

## ADVISORY (зависит от модели, 0-80% compliance)

### A1: AUTO_ACTION в CLAUDE.md
**Факт:** Модель видит, но compliance 0/10 для автоматического выполнения.
**Что делать:** Оставить — иногда срабатывает. Не полагаться. M8 покрывает critical path.
**Улучшение T9:** Сделать формулировку конкретнее — вместо "execute AUTO_ACTION" написать точный tool call.

### A2: Scoring compliance (PlanMode, TeamCreate)
**Факт:** Модель видит TASK TIER, иногда следует, иногда нет.
**Что делать:** Оставить в CLAUDE.md и CORE_INSTRUCTIONS как guidance. Mechanical enforcement невозможен (нет PreToolUse hook для Agent/EnterPlanMode tools).

### A3: Routing feedback (⚙ Role | CONFIDENCE)
**Факт:** Модель обычно следует (~80%). Не критично если пропускает.
**Что делать:** Оставить.

### A4: Domain-specific context extensions
**Факт:** "SECURITY CONTEXT:" инжектируется через UserPromptSubmit. Advisory.
**Что делать:** Оставить — усиливает awareness, не критично.

### A5: Managed CLAUDE.md (/etc/claude-code/CLAUDE.md)
**Факт:** Третий слой дублирования. Docs: "cannot be excluded" но всё ещё "context not enforcement".
**Что делать:** Создать с минимальным текстом. Не ожидать magic — та же модель, тот же результат.
**Effort:** 10 min

---

## НЕ ДЕЛАТЬ (бесполезно)

- ~~Усиливать формулировки~~ — "MANDATORY", "MUST", "IMMEDIATELY" уже есть. Больше caps lock не поможет.
- ~~Дублировать правила в 4+ местах~~ — больше текста = меньше adherence (docs: >200 строк снижает compliance)
- ~~InstructionsLoaded hook~~ — загрузка работает, проблема не в ней

---

## Порядок выполнения

```
M8 (wrapper bootstrap) + M9 (banner) → сразу
A5 (Managed CLAUDE.md) → параллельно
T9 (конкретные Skill calls) → after M8
T10 (compliance retest) → after all above
```

## Summary

| Тип | Задач | Reliability | Статус |
|-----|-------|-------------|--------|
| MECHANICAL (M1-M9) | 9 | 100% | 7 DONE, 2 NEW (M8, M9) |
| ADVISORY (A1-A5) | 5 | 0-80% | 4 existing, 1 NEW (A5) |
| НЕ ДЕЛАТЬ | 3 | — | Отклонено |
