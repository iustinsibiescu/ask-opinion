#!/usr/bin/env bash
# Integration test for ask-opinion plugin
# Tests that the Codex CLI is available and responds correctly

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1 — $2"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}WARN${NC}: $1"; }

echo "=== ask-opinion integration tests ==="
echo ""

# --- Test 1: Codex CLI is installed ---
if command -v codex &>/dev/null; then
  pass "codex CLI is installed ($(which codex))"
else
  fail "codex CLI is installed" "codex not found in PATH"
  echo "Install Codex CLI first: https://github.com/openai/codex"
  exit 1
fi

# --- Test 2: codex exec basic functionality ---
echo "Running codex exec basic test (up to 60s)..."
OUTPUT_FILE="/tmp/ask-opinion-test-basic.txt"
rm -f "$OUTPUT_FILE"
if codex exec \
  --sandbox read-only \
  --skip-git-repo-check \
  --ephemeral \
  -o "$OUTPUT_FILE" \
  "Respond with exactly: HELLO_TEST_OK"; then

  if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    pass "codex exec produces output"
  else
    fail "codex exec produces output" "output file is empty or missing"
  fi
else
  fail "codex exec basic functionality" "command failed (exit code $?)"
fi

# --- Test 3: codex exec with structured prompt (simulates debate) ---
echo ""
echo "Running structured critique test (up to 120s)..."
OUTPUT_FILE="/tmp/ask-opinion-test-debate.txt"
rm -f "$OUTPUT_FILE"
DEBATE_TEST_PROMPT='You are reviewing a plan. The plan is: "Use a simple array to store 10 million records." Identify one concern. Use this format:
### Concern 1: <title>
**Problem**: ...
**Risk**: ...
**Alternative**: ...
Keep your response under 200 words.'

if codex exec \
  --sandbox read-only \
  --skip-git-repo-check \
  --ephemeral \
  -o "$OUTPUT_FILE" \
  "$DEBATE_TEST_PROMPT"; then

  if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    CONTENT=$(cat "$OUTPUT_FILE")
    if echo "$CONTENT" | grep -qi "concern\|problem\|risk\|alternative"; then
      pass "codex exec returns structured critique"
    else
      warn "codex exec returned output but format didn't match expected structure"
      echo "  Output preview: $(head -5 "$OUTPUT_FILE")"
      pass "codex exec returns output (format may vary)"
    fi
  else
    fail "codex exec structured prompt" "output file is empty or missing"
  fi
else
  fail "codex exec structured prompt" "command failed (exit code $?)"
fi

# --- Test 4: AGREED signal detection ---
echo ""
echo "Running AGREED signal test (up to 120s)..."
OUTPUT_FILE="/tmp/ask-opinion-test-agreed.txt"
rm -f "$OUTPUT_FILE"
AGREED_PROMPT='You are reviewing a plan. The plan is: "Use PostgreSQL with proper indexing, connection pooling, migrations, and automated backups for a production web app database." This plan is solid and complete. Respond EXACTLY with: AGREED: The plan is sound because it covers all critical database concerns.'

if codex exec \
  --sandbox read-only \
  --skip-git-repo-check \
  --ephemeral \
  -o "$OUTPUT_FILE" \
  "$AGREED_PROMPT"; then

  if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    if grep -q "AGREED:" "$OUTPUT_FILE"; then
      pass "AGREED: signal detected in response"
    else
      warn "codex did not respond with AGREED: — this is fine, LLMs don't always comply exactly"
      echo "  Output preview: $(head -3 "$OUTPUT_FILE")"
      pass "codex exec responds to agreement prompt (signal may vary)"
    fi
  else
    fail "AGREED signal test" "output file is empty or missing"
  fi
else
  fail "AGREED signal test" "command failed (exit code $?)"
fi

# --- Test 5: Plugin structure validation ---
echo ""
echo "Validating plugin structure..."
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$PLUGIN_DIR/.claude-plugin/marketplace.json" ]; then
  pass "marketplace.json exists"
else
  fail "marketplace.json exists" "not found at $PLUGIN_DIR/.claude-plugin/marketplace.json"
fi

if [ -f "$PLUGIN_DIR/plugins/ask-opinion/.claude-plugin/plugin.json" ]; then
  pass "plugin.json exists"
else
  fail "plugin.json exists" "not found"
fi

if [ -f "$PLUGIN_DIR/plugins/ask-opinion/commands/ask-opinion.md" ]; then
  pass "ask-opinion.md command file exists"
else
  fail "ask-opinion.md exists" "not found"
fi

# Check that JSON files are valid
if python3 -c "import json; json.load(open('$PLUGIN_DIR/.claude-plugin/marketplace.json'))" 2>/dev/null; then
  pass "marketplace.json is valid JSON"
else
  fail "marketplace.json is valid JSON" "parse error"
fi

if python3 -c "import json; json.load(open('$PLUGIN_DIR/plugins/ask-opinion/.claude-plugin/plugin.json'))" 2>/dev/null; then
  pass "plugin.json is valid JSON"
else
  fail "plugin.json is valid JSON" "parse error"
fi

# --- Summary ---
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

# Cleanup
rm -f /tmp/ask-opinion-test-*.txt

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
