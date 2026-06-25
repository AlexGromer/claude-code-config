# Few-Shot Example: Testing a Custom Skill

## Task
Пользователь: "Как проверить что мой custom skill работает корректно?"

## Solution

**Reference:** `~/.claude/modules/15-skills.md` (Skills Testing)

---

## Step 1: Validate SKILL.md Format

```bash
# Check YAML frontmatter
head -5 ~/.claude/skills/my-skill/SKILL.md
# Should have: name, description in YAML block

# Check required sections
for section in "Workflow" "Error Handling" "Safety Rules" "Usage" "Checklists"; do
  grep -qi "$section" ~/.claude/skills/my-skill/SKILL.md && echo "$section: OK" || echo "$section: MISSING"
done
```

## Step 2: Test Skill Invocation

```bash
# In Claude Code session:
/my-skill                    # Basic invocation
/my-skill --help             # Should show usage
/my-skill --target example   # With parameters
```

## Step 3: Verify Routing

```bash
# Check skill is listed in module 15
grep "my-skill" ~/.claude/modules/15-skills.md

# Check skill appears in available skills
# Claude Code lists skills on session start
```

## Step 4: Automated Testing

```python
# tests/test_skill_completeness.py
from pathlib import Path

def test_skill_has_required_sections():
    skill = Path("~/.claude/skills/my-skill/SKILL.md").expanduser().read_text()
    for section in ["Workflow", "Error Handling", "Safety", "Checklist", "Authorization"]:
        assert section.lower() in skill.lower(), f"Missing: {section}"

def test_skill_yaml_frontmatter():
    skill = Path("~/.claude/skills/my-skill/SKILL.md").expanduser().read_text()
    assert skill.startswith("---"), "Missing YAML frontmatter"
    assert "name:" in skill[:200], "Missing name in frontmatter"
```

---

## Verification

- SKILL.md has valid YAML frontmatter
- All 6 required sections present (Workflow, Error Handling, Safety Rules, Clarification, Authorization, Checklists)
- Skill invocation works in Claude Code session
- Skill is registered in modules/15-skills.md
