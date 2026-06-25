#!/usr/bin/env bash
# install.sh — Claude Code DevSecOps config installer
# Usage: ./install.sh [--minimal|--full|--update]
set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}[OK]${RESET}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()  { echo -e "${RED}[ERR]${RESET} $*"; }
info() { echo -e "${BLUE}[..]${RESET}  $*"; }
hdr()  { echo -e "\n${BOLD}==> $*${RESET}"; }

CLAUDE_DIR="${HOME}/.claude"
MODE="full"  # default
ERRORS=0

for arg in "$@"; do
  case "$arg" in
    --minimal) MODE="minimal" ;;
    --full)    MODE="full" ;;
    --update)  MODE="update" ;;
    *) warn "Unknown flag: $arg"; ;;
  esac
done

# ---------------------------------------------------------------------------
# 1. Prerequisites
# ---------------------------------------------------------------------------
hdr "Checking prerequisites (mode: ${MODE})"

check_version() {
  local cmd="$1" min_major="$2" min_minor="$3" label="$4" ver_flag="${5:---version}"
  if ! command -v "$cmd" &>/dev/null; then
    warn "$label not found — skipping dependent steps"
    echo "missing"
    return
  fi
  local ver
  ver=$("$cmd" $ver_flag 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  local major minor
  major=$(echo "$ver" | cut -d. -f1)
  minor=$(echo "$ver" | cut -d. -f2)
  if [[ "$major" -gt "$min_major" ]] || \
     { [[ "$major" -eq "$min_major" ]] && [[ "$minor" -ge "$min_minor" ]]; }; then
    ok "$label $ver"
    echo "ok"
  else
    warn "$label $ver found, need ${min_major}.${min_minor}+"
    echo "old"
  fi
}

GO_STATUS=$(check_version go 1 24 "Go" version)
PY_STATUS=$(check_version python3 3 10 "Python3")
NODE_STATUS=$(check_version node 18 0 "Node.js")
NPM_STATUS=$(check_version npm 8 0 "npm")

if command -v claude &>/dev/null; then
  ok "claude CLI found"
  CLAUDE_STATUS="ok"
else
  warn "claude CLI not found — install with: npm install -g @anthropic-ai/claude-code"
  CLAUDE_STATUS="missing"
fi

# ---------------------------------------------------------------------------
# 2. Directory structure
# ---------------------------------------------------------------------------
hdr "Creating directory structure"

DIRS=(
  "${CLAUDE_DIR}/hooks"
  "${CLAUDE_DIR}/agents"
  "${CLAUDE_DIR}/skills"
  "${CLAUDE_DIR}/rules"
  "${CLAUDE_DIR}/modules"
  "${CLAUDE_DIR}/mcp-servers"
  "${CLAUDE_DIR}/templates"
  "${CLAUDE_DIR}/workflows"
  "${CLAUDE_DIR}/evaluation"
  "${CLAUDE_DIR}/agent-memory"
  "${CLAUDE_DIR}/output-styles"
  "${CLAUDE_DIR}/prompts"
)

for d in "${DIRS[@]}"; do
  if [[ ! -d "$d" ]]; then
    mkdir -p "$d"
    ok "Created $d"
  else
    info "Exists  $d"
  fi
done

# ---------------------------------------------------------------------------
# 3. Backup settings.json (NEVER overwrite)
# ---------------------------------------------------------------------------
SETTINGS="${CLAUDE_DIR}/settings.json"
if [[ -f "$SETTINGS" ]]; then
  info "settings.json already exists — skipping (use manual merge if needed)"
else
  info "No settings.json found — you may need to create one from template"
fi

# ---------------------------------------------------------------------------
# 4. Build Go MCP servers
# ---------------------------------------------------------------------------
hdr "Building Go MCP servers"

if [[ "$GO_STATUS" == "missing" || "$GO_STATUS" == "old" ]]; then
  warn "Go not available — skipping MCP server builds"
  (( ERRORS++ )) || true
else
  MCP_SERVERS=(backlog-mcp doctor-mcp gc-mcp profile-mcp score-mcp tools-mcp)
  for srv in "${MCP_SERVERS[@]}"; do
    srv_dir="${CLAUDE_DIR}/mcp-servers/${srv}"
    if [[ ! -d "$srv_dir" ]]; then
      warn "Not found: $srv_dir — skipping"
      continue
    fi
    binary="${srv_dir}/${srv}"
    # Idempotency: skip if binary is already newer than all .go sources
    if [[ -x "$binary" ]] && [[ -n "$(find "$srv_dir" -name '*.go' -newer "$binary" 2>/dev/null)" ]] || [[ ! -x "$binary" ]]; then
      info "Building ${srv}..."
      if (cd "$srv_dir" && go build -ldflags="-s -w" -o "$srv" . 2>&1); then
        ok "Built $srv"
      else
        err "Failed to build $srv"
        (( ERRORS++ )) || true
      fi
    else
      info "Up-to-date: $srv (binary newer than sources)"
    fi
  done
fi

# ---------------------------------------------------------------------------
# 5. Make Python hooks executable
# ---------------------------------------------------------------------------
hdr "Setting hook permissions"

HOOKS_DIR="${CLAUDE_DIR}/hooks"
if compgen -G "${HOOKS_DIR}/*.py" > /dev/null 2>&1; then
  chmod +x "${HOOKS_DIR}"/*.py
  ok "chmod +x hooks/*.py ($(ls "${HOOKS_DIR}"/*.py | wc -l | tr -d ' ') files)"
else
  info "No .py hooks found in ${HOOKS_DIR}"
fi

# Evaluation hooks
EVAL_HOOKS_DIR="${CLAUDE_DIR}/evaluation/hooks"
if [[ -d "$EVAL_HOOKS_DIR" ]] && compgen -G "${EVAL_HOOKS_DIR}/*.py" > /dev/null 2>&1; then
  chmod +x "${EVAL_HOOKS_DIR}"/*.py
  ok "chmod +x evaluation/hooks/*.py ($(ls "${EVAL_HOOKS_DIR}"/*.py | wc -l | tr -d ' ') files)"
fi

# ---------------------------------------------------------------------------
# 6. Install Python dependencies
# ---------------------------------------------------------------------------
hdr "Installing Python dependencies"

if [[ "$PY_STATUS" == "missing" ]]; then
  warn "Python3 not available — skipping pip installs"
else
  # portalocker provides cross-platform file locking (already installed on Linux
  # via compat.py fallback, but explicit install ensures availability)
  if python3 -c "import portalocker" &>/dev/null 2>&1; then
    info "portalocker already installed"
  else
    if python3 -m pip install --quiet portalocker 2>/dev/null; then
      ok "Installed portalocker"
    else
      warn "Could not install portalocker — compat.py will use fcntl fallback (Linux-only)"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 7. Validate settings.json
# ---------------------------------------------------------------------------
hdr "Validating settings.json"

if [[ -f "$SETTINGS" ]]; then
  if python3 -c "import json, sys; json.load(open('${SETTINGS}'))" 2>/dev/null; then
    ok "settings.json is valid JSON"
  else
    err "settings.json has invalid JSON — fix before using Claude Code"
    (( ERRORS++ )) || true
  fi
else
  warn "settings.json not present — skipping validation"
fi

# ---------------------------------------------------------------------------
# 8. VS Codium / VS Code extension setup
# ---------------------------------------------------------------------------
hdr "VS Codium / VS Code extension setup"

VSCODIUM_STATUS="not_found"
VSCODE_STATUS="not_found"

# Detect VS Codium (multiple possible binary names)
VSCODIUM_BIN=""
for bin in codium vscodium code-oss; do
  if command -v "$bin" &>/dev/null; then
    VSCODIUM_BIN="$bin"
    VSCODIUM_STATUS="found"
    ok "VS Codium found: $bin"
    break
  fi
done

# Detect VS Code
VSCODE_BIN=""
if command -v code &>/dev/null; then
  VSCODE_BIN="code"
  VSCODE_STATUS="found"
  ok "VS Code found: code"
fi

# Detect VS Codium user settings directory
VSCODIUM_CONFIG_DIR=""
for candidate in \
  "${HOME}/.config/VSCodium/User" \
  "${HOME}/.config/VSCode/User" \
  "${HOME}/.config/Code - OSS/User" \
  "${HOME}/Library/Application Support/VSCodium/User" \
  "${HOME}/Library/Application Support/Code/User"; do
  if [[ -d "$candidate" ]]; then
    VSCODIUM_CONFIG_DIR="$candidate"
    info "VS Codium/Code config dir: $candidate"
    break
  fi
done

if [[ -n "$VSCODIUM_CONFIG_DIR" ]]; then
  VSCODIUM_SETTINGS="${VSCODIUM_CONFIG_DIR}/settings.json"

  # Ensure claude-code.environmentVariables are set for the extension
  # (workaround for issue #21926 — env block not reliably loaded from settings.json)
  if [[ -f "$VSCODIUM_SETTINGS" ]]; then
    info "VS Codium settings.json exists — checking for claude-code env vars"
    if python3 -c "
import json, sys
with open('${VSCODIUM_SETTINGS}') as f:
    s = json.load(f)
env_key = 'claude-code.environmentVariables'
if env_key not in s:
    s[env_key] = {
        'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS': '1',
        'BASH_DEFAULT_TIMEOUT_MS': '300000',
        'API_TIMEOUT_MS': '600000'
    }
    with open('${VSCODIUM_SETTINGS}', 'w') as f:
        json.dump(s, f, indent=2)
    print('updated')
else:
    print('exists')
" 2>/dev/null | grep -q "updated"; then
      ok "Added claude-code.environmentVariables to VS Codium settings.json"
    else
      info "claude-code.environmentVariables already present in VS Codium settings.json"
    fi
  else
    # Create minimal VS Codium settings with env vars
    mkdir -p "$VSCODIUM_CONFIG_DIR"
    python3 -c "
import json
settings = {
    'claude-code.environmentVariables': {
        'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS': '1',
        'BASH_DEFAULT_TIMEOUT_MS': '300000',
        'API_TIMEOUT_MS': '600000'
    }
}
with open('${VSCODIUM_SETTINGS}', 'w') as f:
    json.dump(settings, f, indent=2)
print('created')
" 2>/dev/null && ok "Created VS Codium settings.json with claude-code env vars" || \
      warn "Could not create VS Codium settings.json"
  fi

  # Install extension via CLI if possible
  if [[ -n "$VSCODIUM_BIN" ]] || [[ -n "$VSCODE_BIN" ]]; then
    _install_bin="${VSCODIUM_BIN:-$VSCODE_BIN}"
    info "Attempting extension install via: $_install_bin"
    # VS Codium uses Open VSX; VS Code uses Marketplace
    # Try publisher.extension-id format that works on both
    if "$_install_bin" --install-extension anthropic.claude-code --force 2>/dev/null; then
      ok "Claude Code extension installed/updated via $_install_bin"
    else
      warn "Could not auto-install extension — install manually:"
      echo "    $_install_bin --install-extension anthropic.claude-code"
      echo "    Or open Extensions panel and search 'Claude Code' by Anthropic"
    fi
  fi
else
  info "No VS Codium/VS Code config directory detected — skipping extension setup"
  if [[ "$VSCODIUM_STATUS" == "not_found" && "$VSCODE_STATUS" == "not_found" ]]; then
    info "Neither VS Codium nor VS Code found — OK if using CLI only"
  fi
fi

# ---------------------------------------------------------------------------
# 9. Doctor check
# ---------------------------------------------------------------------------
hdr "Running doctor check"

DOCTOR="${CLAUDE_DIR}/mcp-servers/doctor-mcp/doctor-mcp"
if [[ -x "$DOCTOR" ]]; then
  if "$DOCTOR" --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('doctor: ' + d.get('status','?'))" 2>/dev/null; then
    ok "doctor-mcp check passed"
  else
    # Non-JSON output is fine — just run it for a visible status
    "$DOCTOR" 2>/dev/null || true
    ok "doctor-mcp ran"
  fi
else
  warn "doctor-mcp binary not found — run after Go build succeeds"
fi

# ---------------------------------------------------------------------------
# 10. Summary
# ---------------------------------------------------------------------------
hdr "Summary"

echo ""
printf "  %-22s %s\n" "Go:"            "$GO_STATUS"
printf "  %-22s %s\n" "Python3:"       "$PY_STATUS"
printf "  %-22s %s\n" "Node/npm:"      "$NODE_STATUS / $NPM_STATUS"
printf "  %-22s %s\n" "claude CLI:"    "$CLAUDE_STATUS"
printf "  %-22s %s\n" "VS Codium:"     "$VSCODIUM_STATUS"
printf "  %-22s %s\n" "VS Code:"       "$VSCODE_STATUS"
printf "  %-22s %s\n" "Mode:"          "$MODE"
echo ""

if [[ "$ERRORS" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}Installation complete — no errors.${RESET}"
else
  echo -e "${YELLOW}${BOLD}Done with ${ERRORS} warning(s) — review output above.${RESET}"
fi

echo ""
echo "Next steps:"
if [[ "$CLAUDE_STATUS" == "missing" ]]; then
  echo "  npm install -g @anthropic-ai/claude-code"
fi
if [[ "$VSCODIUM_STATUS" == "not_found" && "$VSCODE_STATUS" == "not_found" ]]; then
  echo "  # To setup VS Codium: run ./setup-vscodium.sh after installing VS Codium"
fi
echo "  claude mcp list        # verify MCP servers"
echo "  claude doctor          # full health check"
echo "  bash setup-vscodium.sh # standalone VS Codium config (optional)"
echo ""
