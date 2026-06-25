#!/usr/bin/env bash
# setup-vscodium.sh — Standalone VS Codium / VS Code extension config script
# Detects editor installation (Linux + Windows via Git Bash/WSL)
# Links Claude Code env vars, configures claude binary path, optionally installs extension
#
# Usage: bash setup-vscodium.sh [--install-ext] [--test-only]
#   --install-ext   Also attempt to install the Claude Code extension via CLI
#   --test-only     Only test current state, make no changes

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}[OK]${RESET}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()  { echo -e "${RED}[ERR]${RESET} $*"; }
info() { echo -e "${BLUE}[..]${RESET}  $*"; }
hdr()  { echo -e "\n${BOLD}==> $*${RESET}"; }
pass() { echo -e "${GREEN}[PASS]${RESET} $*"; }
fail() { echo -e "${RED}[FAIL]${RESET} $*"; }

INSTALL_EXT=false
TEST_ONLY=false
ERRORS=0

for arg in "$@"; do
  case "$arg" in
    --install-ext) INSTALL_EXT=true ;;
    --test-only)   TEST_ONLY=true ;;
    *) warn "Unknown flag: $arg" ;;
  esac
done

# ---------------------------------------------------------------------------
# 1. Detect OS and editor binary
# ---------------------------------------------------------------------------
hdr "Detecting OS and editor"

# OS detection
IS_WSL=false
IS_LINUX=false
IS_MACOS=false
IS_WINDOWS_GITBASH=false

case "$(uname -s)" in
  Linux*)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      IS_WSL=true
      info "OS: Linux (WSL)"
    else
      IS_LINUX=true
      info "OS: Linux (native)"
    fi
    ;;
  Darwin*) IS_MACOS=true; info "OS: macOS" ;;
  MINGW*|CYGWIN*|MSYS*)
    IS_WINDOWS_GITBASH=true
    info "OS: Windows (Git Bash / MSYS2)"
    ;;
esac

# Editor detection: try multiple binary names in priority order
EDITOR_BIN=""
EDITOR_NAME=""
for bin in codium vscodium code-oss code; do
  if command -v "$bin" &>/dev/null; then
    EDITOR_BIN="$bin"
    EDITOR_NAME="$bin"
    ok "Editor found: $bin ($(command -v "$bin"))"
    break
  fi
done

if [[ -z "$EDITOR_BIN" ]]; then
  # Windows/WSL: check common install paths
  WIN_PATHS=(
    "/mnt/c/Program Files/VSCodium/bin/codium"
    "/mnt/c/Program Files/Microsoft VS Code/bin/code"
    "/mnt/c/Users/${USER}/AppData/Local/Programs/VSCodium/bin/codium"
    "/mnt/c/Users/${USER}/AppData/Local/Programs/Microsoft VS Code/bin/code"
  )
  for p in "${WIN_PATHS[@]}"; do
    if [[ -x "$p" ]]; then
      EDITOR_BIN="$p"
      EDITOR_NAME="$(basename "$p")"
      ok "Editor found at Windows path: $p"
      break
    fi
  done
fi

if [[ -z "$EDITOR_BIN" ]]; then
  warn "No VS Codium or VS Code binary found in PATH or common locations"
  EDITOR_STATUS="not_found"
else
  EDITOR_STATUS="found"
fi

# ---------------------------------------------------------------------------
# 2. Locate VS Codium / VS Code user config directory
# ---------------------------------------------------------------------------
hdr "Locating editor config directory"

VS_CONFIG_DIR=""

# Linux paths (in priority order)
LINUX_CANDIDATES=(
  "${HOME}/.config/VSCodium/User"
  "${HOME}/.config/VSCode/User"
  "${HOME}/.config/Code - OSS/User"
  "${HOME}/.config/Code/User"
)

# macOS paths
MACOS_CANDIDATES=(
  "${HOME}/Library/Application Support/VSCodium/User"
  "${HOME}/Library/Application Support/Code/User"
)

# WSL/Windows paths (accessed via /mnt/c)
WSL_WIN_USER="${WINUSER:-${USER}}"
WSL_CANDIDATES=(
  "/mnt/c/Users/${WSL_WIN_USER}/AppData/Roaming/VSCodium/User"
  "/mnt/c/Users/${WSL_WIN_USER}/AppData/Roaming/Code/User"
)

# Git Bash on Windows
GITBASH_CANDIDATES=(
  "${APPDATA}/VSCodium/User"
  "${APPDATA}/Code/User"
)

if [[ "$IS_LINUX" == "true" || "$IS_WSL" == "true" ]]; then
  for c in "${LINUX_CANDIDATES[@]}"; do
    if [[ -d "$c" ]]; then
      VS_CONFIG_DIR="$c"
      info "Config dir (Linux): $c"
      break
    fi
  done
  # WSL: also check Windows-side if Linux side not found
  if [[ -z "$VS_CONFIG_DIR" && "$IS_WSL" == "true" ]]; then
    for c in "${WSL_CANDIDATES[@]}"; do
      if [[ -d "$c" ]]; then
        VS_CONFIG_DIR="$c"
        info "Config dir (Windows via WSL): $c"
        break
      fi
    done
  fi
elif [[ "$IS_MACOS" == "true" ]]; then
  for c in "${MACOS_CANDIDATES[@]}"; do
    if [[ -d "$c" ]]; then
      VS_CONFIG_DIR="$c"
      info "Config dir (macOS): $c"
      break
    fi
  done
elif [[ "$IS_WINDOWS_GITBASH" == "true" ]]; then
  for c in "${GITBASH_CANDIDATES[@]}"; do
    if [[ -d "$c" ]]; then
      VS_CONFIG_DIR="$c"
      info "Config dir (Windows): $c"
      break
    fi
  done
fi

if [[ -z "$VS_CONFIG_DIR" ]]; then
  warn "No VS Codium/VS Code config directory found"
  warn "Expected one of:"
  for c in "${LINUX_CANDIDATES[@]}" "${MACOS_CANDIDATES[@]}"; do
    echo "    $c"
  done
  CONFIG_STATUS="not_found"
else
  CONFIG_STATUS="found"
fi

# ---------------------------------------------------------------------------
# 3. Find claude binary path
# ---------------------------------------------------------------------------
hdr "Locating claude CLI binary"

CLAUDE_BIN=""
if command -v claude &>/dev/null; then
  CLAUDE_BIN="$(command -v claude)"
  ok "claude found: $CLAUDE_BIN"
  CLAUDE_STATUS="ok"
else
  warn "claude CLI not found in PATH"
  # Try npm global paths
  for npm_path in \
    "${HOME}/.npm-global/bin/claude" \
    "${HOME}/.local/bin/claude" \
    "/usr/local/bin/claude" \
    "/usr/bin/claude"; do
    if [[ -x "$npm_path" ]]; then
      CLAUDE_BIN="$npm_path"
      ok "claude found at: $CLAUDE_BIN"
      CLAUDE_STATUS="ok"
      break
    fi
  done
  if [[ -z "$CLAUDE_BIN" ]]; then
    warn "claude binary not found — extension may not work"
    CLAUDE_STATUS="missing"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Configure VS Codium settings.json
# ---------------------------------------------------------------------------
if [[ "$TEST_ONLY" != "true" && -n "$VS_CONFIG_DIR" ]]; then
  hdr "Configuring VS Codium settings.json"

  VS_SETTINGS="${VS_CONFIG_DIR}/settings.json"
  mkdir -p "$VS_CONFIG_DIR"

  # Python script for JSON merge (avoids jq dependency)
  python3 - "$VS_SETTINGS" "$CLAUDE_BIN" <<'PYEOF'
import json, sys, os
from pathlib import Path

settings_path = sys.argv[1]
claude_bin    = sys.argv[2] if len(sys.argv) > 2 else ""

# Load existing settings
settings = {}
if os.path.exists(settings_path):
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except (json.JSONDecodeError, IOError):
        print("[WARN] Could not parse existing settings.json — starting fresh")
        settings = {}

# 1. claude-code.environmentVariables
# Workaround for Issue #21926: env block in settings.json not loaded by extension
env_key = "claude-code.environmentVariables"
existing_env = settings.get(env_key, {})
default_env = {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "BASH_DEFAULT_TIMEOUT_MS":              "300000",
    "API_TIMEOUT_MS":                       "600000",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS":        "64000",
    "SLASH_COMMAND_TOOL_CHAR_BUDGET":       "8000",
}
# Merge: keep user values, add missing defaults
for k, v in default_env.items():
    if k not in existing_env:
        existing_env[k] = v
settings[env_key] = existing_env

# 2. claude-code.claudePath — point extension to the CLI binary
if claude_bin and os.path.exists(claude_bin):
    settings["claude-code.claudePath"] = claude_bin
    print(f"[..]   Set claude-code.claudePath = {claude_bin}")

# 3. Recommended extension settings
# Single-root workspace recommended for CWD correctness (Issue #8873)
if "claude-code.preferredWorkspaceMode" not in settings:
    settings["claude-code.preferredWorkspaceMode"] = "single"

# Write back
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print(f"[OK]   Updated {settings_path}")
PYEOF

fi

# ---------------------------------------------------------------------------
# 5. Install Claude Code extension via CLI
# ---------------------------------------------------------------------------
if [[ "$INSTALL_EXT" == "true" && -n "$EDITOR_BIN" ]]; then
  hdr "Installing Claude Code extension"
  info "Using: $EDITOR_BIN --install-extension anthropic.claude-code"
  if "$EDITOR_BIN" --install-extension anthropic.claude-code --force 2>/dev/null; then
    ok "Claude Code extension installed/updated"
  else
    warn "Could not install extension via CLI — install manually:"
    echo "    $EDITOR_BIN --install-extension anthropic.claude-code"
    echo "    Or: Open Extensions panel -> search 'Claude Code' by Anthropic"
    echo "    VS Codium: uses Open VSX Registry (official Anthropic publisher)"
    (( ERRORS++ )) || true
  fi
fi

# ---------------------------------------------------------------------------
# 6. Test: verify extension can find claude binary
# ---------------------------------------------------------------------------
hdr "Testing extension connectivity"

TESTS_PASS=0
TESTS_FAIL=0

# Test 1: claude binary accessible
if [[ "$CLAUDE_STATUS" == "ok" ]]; then
  pass "T1: claude binary accessible at $CLAUDE_BIN"
  (( TESTS_PASS++ )) || true
else
  fail "T1: claude binary NOT found — extension cannot function without it"
  (( TESTS_FAIL++ )) || true
fi

# Test 2: editor installed
if [[ "$EDITOR_STATUS" == "found" ]]; then
  pass "T2: Editor binary found ($EDITOR_BIN)"
  (( TESTS_PASS++ )) || true
else
  fail "T2: No editor binary found — install VS Codium or VS Code"
  (( TESTS_FAIL++ )) || true
fi

# Test 3: config directory exists
if [[ "$CONFIG_STATUS" == "found" ]]; then
  pass "T3: Config directory exists ($VS_CONFIG_DIR)"
  (( TESTS_PASS++ )) || true
else
  fail "T3: Config directory not found — extension may not be installed yet"
  (( TESTS_FAIL++ )) || true
fi

# Test 4: settings.json has claude-code.environmentVariables
if [[ -n "$VS_CONFIG_DIR" ]]; then
  VS_SETTINGS="${VS_CONFIG_DIR}/settings.json"
  if [[ -f "$VS_SETTINGS" ]]; then
    if python3 -c "
import json, sys
with open('${VS_SETTINGS}') as f:
    s = json.load(f)
if 'claude-code.environmentVariables' in s:
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
      pass "T4: claude-code.environmentVariables present in settings.json"
      (( TESTS_PASS++ )) || true
    else
      fail "T4: claude-code.environmentVariables MISSING from settings.json"
      info "    Run without --test-only to fix"
      (( TESTS_FAIL++ )) || true
    fi
  else
    fail "T4: settings.json not found at ${VS_SETTINGS}"
    (( TESTS_FAIL++ )) || true
  fi
fi

# Test 5: extension installed (check extensions dir)
EXT_FOUND=false
EXT_DIRS=(
  "${HOME}/.vscode-oss/extensions"
  "${HOME}/.vscode/extensions"
  "${HOME}/.config/VSCodium/extensions"
  "/mnt/c/Users/${USER}/.vscode/extensions"
)
for ext_dir in "${EXT_DIRS[@]}"; do
  if [[ -d "$ext_dir" ]] && ls "$ext_dir"/anthropic.claude-code-* &>/dev/null 2>&1; then
    EXT_VERSION=$(ls "$ext_dir"/anthropic.claude-code-* 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    pass "T5: Claude Code extension installed (v${EXT_VERSION}) in $ext_dir"
    EXT_FOUND=true
    (( TESTS_PASS++ )) || true
    break
  fi
done
if [[ "$EXT_FOUND" != "true" ]]; then
  warn "T5: Claude Code extension not detected in known extension dirs"
  info "    Run: $EDITOR_BIN --install-extension anthropic.claude-code"
  info "    Or pass --install-ext flag to this script"
  (( TESTS_FAIL++ )) || true
fi

# Test 6: CLAUDE.md / settings.json symlink not needed (direct share via ~/.claude/)
if [[ -f "${HOME}/.claude/settings.json" ]]; then
  pass "T6: ~/.claude/settings.json present (shared between CLI and extension)"
  (( TESTS_PASS++ )) || true
else
  warn "T6: ~/.claude/settings.json not found — hooks will not be configured"
  (( TESTS_FAIL++ )) || true
fi

# ---------------------------------------------------------------------------
# 7. Summary
# ---------------------------------------------------------------------------
hdr "Summary"

echo ""
printf "  %-22s %s\n" "Editor:"       "${EDITOR_BIN:-not found}"
printf "  %-22s %s\n" "Config dir:"   "${VS_CONFIG_DIR:-not found}"
printf "  %-22s %s\n" "claude CLI:"   "${CLAUDE_BIN:-not found}"
printf "  %-22s %s\n" "Tests passed:" "${TESTS_PASS}"
printf "  %-22s %s\n" "Tests failed:" "${TESTS_FAIL}"
echo ""

if [[ "$TESTS_FAIL" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}VS Codium setup complete — all tests passed.${RESET}"
else
  echo -e "${YELLOW}${BOLD}Setup complete with ${TESTS_FAIL} issue(s) — see output above.${RESET}"
fi

echo ""
echo "Known extension limitations (see docs/VSCODIUM_COMPATIBILITY.md):"
echo "  - settings.json env block NOT loaded reliably (Issue #21926) — fixed above"
echo "  - permissions block NOT enforced (Issue #29159) — use extension diff UI"
echo "  - UserPromptSubmit hook intermittent (Issue #17277) — domain detection may miss"
echo ""
echo "Manual verification steps:"
echo "  1. Open VS Codium, open workspace /opt/project/"
echo "  2. Run /mcp in chat — verify 13 essential servers listed"
echo "  3. Ask: 'What is your model?' — verify claude-opus-4-6 (not default)"
echo "  4. Ask Claude to write a file — verify FILEMAP.md updates (PostToolUse hook)"
echo ""
