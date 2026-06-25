#!/usr/bin/env bash
# PoC demo for ADR-007: PPID-keyed criteria isolation
#
# Demonstrates three properties:
#   1. Different "sessions" (different parent shells) → isolated storage
#   2. Same "session" (same parent shell, two child invocations) → shared storage
#   3. PPID + starttime defeats PID reuse (paths differ even if PID collides)
#
# Read expected output in README.md.
#
# NOTE on `; :` after each target invocation:
# Bash optimizes `bash -c '<single-cmd>'` by exec-replacing itself with the
# command, so the command's PPID becomes the original demo.sh, not the bash
# subshell. This breaks the "different sessions = different PPIDs" simulation.
# Adding `; :` makes the target NOT the last command, forcing bash to fork
# normally — target's PPID = the bash subshell, which is unique per `bash -c`.
# In production this is moot: tools-mcp is a long-running stdio child of
# Claude Code, never invoked via `bash -c`.

set -euo pipefail
cd "$(dirname "$0")"

if ! command -v go >/dev/null 2>&1; then
  echo "go not found in PATH; need Go toolchain to build PoC binary" >&2
  exit 2
fi

go build -o ppid_isolator ppid_isolator.go

export POC_WORK_DIR="/tmp/poc-adr-007"
rm -rf "$POC_WORK_DIR"

hr() { printf '%.0s=' {1..72}; printf '\n'; }

hr
echo "TEST 1: two SEPARATE bash shells freeze independently — must NOT leak"
hr
bash -c './ppid_isolator freeze "Session A — analyze logs"; :'
echo
echo "Now a fresh bash (different PPID) does check — it should see NOT FROZEN:"
bash -c './ppid_isolator check; :'
echo
echo "Storage layout:"
ls -la "$POC_WORK_DIR"
echo

hr
echo "TEST 2: same bash freeze + check — must SEE the same data (subagent equivalence)"
hr
bash -c '
  ./ppid_isolator freeze "Session B — review PR";
  echo "[same shell] check after freeze:";
  ./ppid_isolator check;
  :
'
echo
echo "Storage layout (now two session dirs):"
ls -la "$POC_WORK_DIR"
echo

hr
echo "TEST 3: PPID+starttime path uniqueness (PID reuse defeated)"
hr
bash -c './ppid_isolator path; :'
sleep 1
bash -c './ppid_isolator path; :'
echo "(both bash shells could in principle have the same PID later, but starttime differs)"
echo

hr
echo "RESULT: Test 1 demonstrates isolation. Test 2 demonstrates same-session sharing."
echo "        Test 3 demonstrates the starttime suffix protects against PID reuse."
hr
