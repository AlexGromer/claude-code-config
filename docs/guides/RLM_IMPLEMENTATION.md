# RLM — Recursive Language Models (research → implementation)

**Date:** 2026-06-24 · **Paper:** "Recursive Language Models", Zhang, Kraska,
Khattab (MIT CSAIL), [arXiv:2512.24601v3](https://arxiv.org/abs/2512.24601) ·
**Authors' code:** github.com/alexzhang13/rlm · **Our implementation:** `/opt/project`

## 1. The problem RLMs solve

Frontier models degrade on long contexts ("context rot") *before* their window
limit, and worse for harder tasks. RLMs avoid stuffing the long prompt into the
model at all: the prompt becomes an **external REPL environment**.

> The prompt `P` is stored as a `context` variable in a persistent Python REPL.
> The root model sees only constant-size **metadata** (length, type, chunk sizes)
> and writes code that peeks / chunks / **recursively sub-calls the model** over
> slices, accumulating the answer in variables until it emits `FINAL`.

Reported: RLM(GPT-5, depth=1) beats GPT-5 + compaction / CodeAct / Claude Code on
four long-context benchmarks at comparable cost, scaling to 10M+ tokens.

## 2. Algorithm 1

```
state  <- InitREPL(prompt = P)              # P is a variable, not in context
state  <- AddFunction(state, sub_RLM)
hist   <- [Metadata(state)]                 # root sees only metadata
while True:
    code         <- LLM(hist)               # root emits a ```repl block
    state, stdout<- REPL(state, code)       # execute; capture stdout
    hist         <- hist || code || Metadata(stdout)   # only truncated stdout returns
    if state[Final] is set: return state[Final]
```

Distinctive choices: symbolic handle to `P` (never copied into context),
unbounded output (answer from a REPL variable via `FINAL_VAR`), and **symbolic
recursion** (code calls the model programmatically in loops over slices).

## 3. Our implementation (`/opt/project`, standalone git project)

Model-agnostic by design — the only model-specific code is the provider adapter:

| Component | File |
|-----------|------|
| Algorithm-1 loop, depth, iteration cap | `rlm/core.py` |
| REPL (context var, `llm_query`/`rlm_query`, exec, FINAL parsing) | `rlm/repl.py` |
| Constant-size metadata / stdout truncation | `rlm/metadata.py` |
| Providers: anthropic, openai, deepseek, **claude_code**, mock | `rlm/providers/` |
| Root system prompt (paper Appendix C) | `rlm/prompts/root_system.md` |
| CLI / Claude Code skill + launcher | `rlm/cli.py`, `integrations/claude_code/` |
| Design notes | `/opt/project/docs/RLM_DESIGN.md` |

**Interface** (verbatim from Appendix C): `context` variable; `llm_query(prompt)`
single sub-call; `rlm_query(context, query)` recursive sub-loop (falls back to
`llm_query` at max depth); code in ` ```repl ` fences; terminate with `FINAL(...)`
or `FINAL_VAR(name)`.

## 4. How to run

```bash
cd /opt/project && pip install -e ".[all]"

# Claude Code as the model M (no API key needed)
python3 integrations/claude_code/rlm_cc.py --file huge.txt --query "what changed?"

# any other model — set the matching *_API_KEY
echo "$BIG" | rlm run --provider deepseek  --query "find the bug"        --depth 1
echo "$BIG" | rlm run --provider openai    --query "summarize the thread" --depth 1
echo "$BIG" | rlm run --provider anthropic --query "extract all dates"    --depth 1
```

Strong root + cheaper sub-model (paper: GPT-5 / GPT-5-mini):
```python
from rlm import RLM, get_provider
RLM(get_provider("anthropic", model="claude-opus-4-8"),
    sub_provider=get_provider("anthropic", model="claude-haiku-4-5-20251001"),
    depth=1).run(huge_text, query="...")
```

## 5. Status, caveats, deferred

- **Reference implementation**, not production-hardened.
- **Security:** the REPL executes model-generated Python in an isolated namespace
  but **not a sandbox** (it can `import os`, open files, etc.). Run only on trusted
  inputs, or wrap the REPL in a subprocess/container. (`/opt/project` README "Security".)
- **Tests:** 23 deterministic (MockProvider, no API) + gated live smoke tests;
  deep-reviewer pass fixed 2 HIGH + 5 MED/LOW.
- **Deferred (BACKLOG):** fine-tuning a natively-recursive model (RLM-Qwen3-8B,
  Appendix A) — documented, not trained; production sandbox; real-provider eval.
