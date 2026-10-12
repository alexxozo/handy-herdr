#!/usr/bin/env bash
# Self-contained tests for handy-to-herdr (no live Handy/Herdr required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/bin/handy-to-herdr"
MOCKS="$ROOT/tests/mocks"
FIX="$ROOT/tests/fixtures"

PASS=0
FAIL=0

assert_eq() {
  local name="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    echo "  ok - $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL - $name"
    echo "    got:  $got"
    echo "    want: $want"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_contains() {
  local name="$1" file="$2" needle="$3"
  if [[ -f "$file" ]] && grep -qF "$needle" "$file"; then
    echo "  ok - $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL - $name (missing '$needle' in $file)"
    [[ -f "$file" ]] && sed 's/^/    | /' "$file" || echo "    (file missing)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_file_contains() {
  local name="$1" file="$2" needle="$3"
  if [[ -f "$file" ]] && grep -qF "$needle" "$file"; then
    echo "  FAIL - $name (unexpected '$needle')"
    FAIL=$((FAIL + 1))
  else
    echo "  ok - $name"
    PASS=$((PASS + 1))
  fi
}

setup_case() {
  CASE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/handy-herdr-test.XXXXXX")"
  export HOME="$CASE_DIR/home"
  export MOCK_HERDR_DIR="$CASE_DIR/mock"
  export MOCK_CALLS="$CASE_DIR/calls.log"
  export MOCK_PBCOPY_OUT="$CASE_DIR/clipboard.txt"
  export HANDY_HERDR_LOG="$CASE_DIR/handy.log"
  export HANDY_HERDR_TARGET_FILE="$HOME/.config/herdr/handy-target"
  export HANDY_HERDR_MODE_FILE="$HOME/.config/herdr/handy-mode"
  export HERDR_BIN="$MOCKS/herdr"
  export PBCOPY_BIN="$MOCKS/pbcopy"
  export OSASCRIPT_BIN="$MOCKS/osascript"
  unset HANDY_HERDR_TARGET HANDY_HERDR_MODE HANDY_HERDR_KIND
  unset MOCK_HERDR_LIST_FAIL MOCK_HERDR_FOCUS_FAIL MOCK_HERDR_PROMPT_FAIL

  mkdir -p "$HOME/.config/herdr" "$MOCK_HERDR_DIR" "$(dirname "$HANDY_HERDR_LOG")"
  cp "$FIX/agents.json" "$MOCK_HERDR_DIR/agents.json"
  : >"$MOCK_CALLS"
  : >"$MOCK_HERDR_DIR/prompts.txt"
}

run_script() {
  # GUI-like PATH: only system bins + ensure python3 still reachable via /usr/bin
  env -i \
    HOME="$HOME" \
    USER="${USER:-test}" \
    PATH="/usr/bin:/bin" \
    HERDR_BIN="$HERDR_BIN" \
    PBCOPY_BIN="$PBCOPY_BIN" \
    OSASCRIPT_BIN="$OSASCRIPT_BIN" \
    HANDY_HERDR_LOG="$HANDY_HERDR_LOG" \
    HANDY_HERDR_TARGET_FILE="$HANDY_HERDR_TARGET_FILE" \
    HANDY_HERDR_MODE_FILE="$HANDY_HERDR_MODE_FILE" \
    HANDY_HERDR_TARGET="${HANDY_HERDR_TARGET-}" \
    HANDY_HERDR_MODE="${HANDY_HERDR_MODE-}" \
    HANDY_HERDR_KIND="${HANDY_HERDR_KIND-}" \
    MOCK_CALLS="$MOCK_CALLS" \
    MOCK_HERDR_DIR="$MOCK_HERDR_DIR" \
    MOCK_PBCOPY_OUT="$MOCK_PBCOPY_OUT" \
    MOCK_HERDR_LIST_FAIL="${MOCK_HERDR_LIST_FAIL-}" \
    MOCK_HERDR_FOCUS_FAIL="${MOCK_HERDR_FOCUS_FAIL-}" \
    MOCK_HERDR_PROMPT_FAIL="${MOCK_HERDR_PROMPT_FAIL-}" \
    "$SCRIPT" "$@"
}

echo "==> handy-herdr tests"

# --- empty input is a no-op ---
setup_case
run_script "" || true
assert_eq "empty text exits 0 without calls" "$(wc -l <"$MOCK_CALLS" | tr -d ' ')" "0"

# --- native mode uses pbcopy + osascript ---
setup_case
printf 'native\n' >"$HANDY_HERDR_MODE_FILE"
run_script "hello native"
assert_file_contains "native logs ok" "$HANDY_HERDR_LOG" "ok native"
assert_file_contains "native called pbcopy" "$MOCK_CALLS" "pbcopy"
assert_file_contains "native called osascript" "$MOCK_CALLS" "osascript"
assert_eq "clipboard has text" "$(cat "$MOCK_PBCOPY_OUT")" "hello native"
assert_not_file_contains "native did not call herdr prompt" "$MOCK_CALLS" "agent prompt"

# --- env HANDY_HERDR_MODE=native ---
setup_case
printf 'herdr\n' >"$HANDY_HERDR_MODE_FILE"
HANDY_HERDR_MODE=native run_script "env native wins"
assert_file_contains "env mode overrides file" "$HANDY_HERDR_LOG" "ok native"

# --- auto-pick prefers working cursor ---
setup_case
printf 'herdr\n' >"$HANDY_HERDR_MODE_FILE"
run_script "auto pick please"
assert_file_contains "auto focused working cursor" "$MOCK_CALLS" "agent focus w1:p3"
assert_file_contains "auto prompted working cursor" "$MOCK_CALLS" "agent prompt w1:p3"
assert_eq "prompt text recorded" "$(cat "$MOCK_HERDR_DIR/prompts.txt")" "auto pick please"
assert_file_contains "herdr path logged ok" "$HANDY_HERDR_LOG" "ok"

# --- pinned target wins over auto ---
setup_case
printf 'herdr\n' >"$HANDY_HERDR_MODE_FILE"
printf 'w1:p2\n' >"$HANDY_HERDR_TARGET_FILE"
run_script "use pin"
assert_file_contains "pin used for focus" "$MOCK_CALLS" "agent focus w1:p2"
assert_file_contains "pin used for prompt" "$MOCK_CALLS" "agent prompt w1:p2"

# --- HANDY_HERDR_TARGET env wins over pin ---
setup_case
printf 'herdr\n' >"$HANDY_HERDR_MODE_FILE"
printf 'w1:p2\n' >"$HANDY_HERDR_TARGET_FILE"
HANDY_HERDR_TARGET=w1:p1 run_script "env target"
assert_file_contains "env target overrides pin" "$MOCK_CALLS" "agent prompt w1:p1"

# --- herdr list failure → native fallback ---
setup_case
printf 'herdr\n' >"$HANDY_HERDR_MODE_FILE"
MOCK_HERDR_LIST_FAIL=1 run_script "fallback list"
assert_file_contains "list fail → native" "$HANDY_HERDR_LOG" "native fallback"
assert_file_contains "list fail used pbcopy" "$MOCK_CALLS" "pbcopy"

# --- focus failure → native fallback ---
setup_case
printf 'herdr\n' >"$HANDY_HERDR_MODE_FILE"
MOCK_HERDR_FOCUS_FAIL=1 run_script "fallback focus"
assert_file_contains "focus fail → native" "$HANDY_HERDR_LOG" "focus failed"
assert_file_contains "focus fail used pbcopy" "$MOCK_CALLS" "pbcopy"

# --- prompt failure → native fallback ---
setup_case
printf 'herdr\n' >"$HANDY_HERDR_MODE_FILE"
MOCK_HERDR_PROMPT_FAIL=1 run_script "fallback prompt"
assert_file_contains "prompt fail → native" "$HANDY_HERDR_LOG" "prompt failed"
assert_file_contains "prompt fail used pbcopy" "$MOCK_CALLS" "pbcopy"

# --- missing herdr binary → native fallback ---
setup_case
printf 'herdr\n' >"$HANDY_HERDR_MODE_FILE"
HERDR_BIN="/nonexistent/herdr" run_script "no herdr"
assert_file_contains "missing herdr → native" "$HANDY_HERDR_LOG" "herdr missing"
assert_file_contains "missing herdr used pbcopy" "$MOCK_CALLS" "pbcopy"

# --- speech with special chars stays one prompt arg (no shell split) ---
setup_case
printf 'herdr\n' >"$HANDY_HERDR_MODE_FILE"
run_script 'hello; rm -rf / | false && echo injected'
assert_eq "special chars preserved as prompt body" "$(cat "$MOCK_HERDR_DIR/prompts.txt")" 'hello; rm -rf / | false && echo injected'

echo
echo "Passed: $PASS"
echo "Failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
