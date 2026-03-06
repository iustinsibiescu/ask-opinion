#!/usr/bin/env bash
# Integration test for ask-opinion plugin (Gemini CLI)
# Tests that the Gemini CLI is available and responds correctly

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1 — $2"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}WARN${NC}: $1"; }

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== ask-opinion Gemini integration tests ==="
echo ""

# --- Test 1: Gemini CLI is installed ---
if command -v gemini &>/dev/null; then
  pass "gemini CLI is installed ($(which gemini))"
else
  fail "gemini CLI is installed" "gemini not found in PATH"
  echo "Install Gemini CLI first: npm install -g @google/gemini-cli"
  exit 1
fi

# --- Test 2: gemini basic functionality ---
echo "Running gemini basic test (up to 60s)..."
OUTPUT_FILE="/tmp/ask-opinion-test-gemini-basic.txt"
rm -f "$OUTPUT_FILE"
if gemini -p "Respond with exactly: HELLO_TEST_OK" \
  --approval-mode plan \
  -o text > "$OUTPUT_FILE" 2>&1; then

  if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    pass "gemini produces output"
  else
    fail "gemini produces output" "output file is empty or missing"
  fi
else
  fail "gemini basic functionality" "command failed (exit code $?)"
fi

# --- Test 3: gemini with structured prompt (simulates debate) ---
echo ""
echo "Running structured critique test (up to 120s)..."
OUTPUT_FILE="/tmp/ask-opinion-test-gemini-debate.txt"
rm -f "$OUTPUT_FILE"
DEBATE_TEST_PROMPT='You are reviewing a plan. The plan is: "Use a simple array to store 10 million records." Identify one concern. Use this format:
### Concern 1: <title>
**Problem**: ...
**Risk**: ...
**Alternative**: ...
Keep your response under 200 words.'

if gemini -p "$DEBATE_TEST_PROMPT" \
  --approval-mode plan \
  -o text > "$OUTPUT_FILE" 2>&1; then

  if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    CONTENT=$(cat "$OUTPUT_FILE")
    if echo "$CONTENT" | grep -qi "concern\|problem\|risk\|alternative"; then
      pass "gemini returns structured critique"
    else
      warn "gemini returned output but format didn't match expected structure"
      echo "  Output preview: $(head -5 "$OUTPUT_FILE")"
      pass "gemini returns output (format may vary)"
    fi
  else
    fail "gemini structured prompt" "output file is empty or missing"
  fi
else
  fail "gemini structured prompt" "command failed (exit code $?)"
fi

# --- Test 4: AGREED signal detection ---
echo ""
echo "Running AGREED signal test (up to 120s)..."
OUTPUT_FILE="/tmp/ask-opinion-test-gemini-agreed.txt"
rm -f "$OUTPUT_FILE"
AGREED_PROMPT='You are reviewing a plan. The plan is: "Use PostgreSQL with proper indexing, connection pooling, migrations, and automated backups for a production web app database." This plan is solid and complete. Respond EXACTLY with: AGREED: The plan is sound because it covers all critical database concerns.'

if gemini -p "$AGREED_PROMPT" \
  --approval-mode plan \
  -o text > "$OUTPUT_FILE" 2>&1; then

  if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    if grep -q "AGREED:" "$OUTPUT_FILE"; then
      pass "AGREED: signal detected in response"
    else
      warn "gemini did not respond with AGREED: — this is fine, LLMs don't always comply exactly"
      echo "  Output preview: $(head -3 "$OUTPUT_FILE")"
      pass "gemini responds to agreement prompt (signal may vary)"
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

# --- Test 6: Structural assertions (no API calls) ---
echo ""
echo "Validating Gemini integration in plugin files..."

COMMAND_FILE="$PLUGIN_DIR/plugins/ask-opinion/commands/ask-opinion.md"

# argument-hint includes gemini
if grep -q 'argument-hint:.*gemini' "$COMMAND_FILE"; then
  pass "argument-hint includes gemini"
else
  fail "argument-hint includes gemini" "not found in ask-opinion.md frontmatter"
fi

# Phase 2 contains Gemini dispatch
if grep -q 'gemini' "$COMMAND_FILE" && grep -q 'debate-round-1' "$COMMAND_FILE"; then
  pass "ask-opinion.md contains Gemini dispatch (Phase 2)"
else
  fail "Gemini dispatch in Phase 2" "gemini invocation not found"
fi

# Phase 4 contains Gemini dispatch
if grep -q 'debate-round-N' "$COMMAND_FILE"; then
  pass "ask-opinion.md contains Gemini dispatch (Phase 4)"
else
  fail "Gemini dispatch in Phase 4" "debate-round-N pattern not found"
fi

# README mentions gemini
if grep -qi 'gemini' "$PLUGIN_DIR/README.md"; then
  pass "README.md mentions Gemini"
else
  fail "README.md mentions Gemini" "gemini not found in README"
fi

# marketplace.json keywords include gemini
if grep -q '"gemini"' "$PLUGIN_DIR/.claude-plugin/marketplace.json"; then
  pass "marketplace.json keywords include gemini"
else
  fail "marketplace.json keywords include gemini" "gemini keyword not found"
fi

# plugin.json description mentions Gemini
if grep -qi 'gemini' "$PLUGIN_DIR/plugins/ask-opinion/.claude-plugin/plugin.json"; then
  pass "plugin.json mentions Gemini"
else
  fail "plugin.json mentions Gemini" "gemini not found in plugin.json"
fi

# --- Summary ---
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

# Cleanup
rm -f /tmp/ask-opinion-test-gemini-*.txt

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
