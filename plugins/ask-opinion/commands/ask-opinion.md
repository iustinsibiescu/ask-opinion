---
description: Debate your current plan with another AI to refine it through adversarial review
argument-hint: codex
allowed-tools: Bash, Read, Glob, Grep, WebSearch, WebFetch, Edit
---

# AI-to-AI Debate Protocol

You are about to engage in a structured debate with another AI ($ARGUMENTS) to stress-test and refine the current plan. Follow this protocol exactly.

## Phase 1: Prepare the Debate

1. Identify the current plan. Look for it in this order:
   - Files in `.claude/plans/` (use Glob to find `**/*.md` in `.claude/plans/`)
   - If no plan file exists, use the plan from the current conversation context
   - If no plan can be found at all, tell the user "No plan found. Please enter plan mode and create a plan first, then run /ask-opinion again." and stop.

2. Read the plan file (if one exists) and compose a structured summary with these sections:
   - **Problem**: What is being solved
   - **Approach**: How it's being solved
   - **Key Decisions**: Important choices made and why
   - **Trade-offs**: What was traded off and why

3. Store the original user request (from the plan or conversation) separately — you'll need it in every round.

4. Print to the user:
```
=== Starting debate with $ARGUMENTS. Sending plan for review... ===
```

## Phase 2: Round 1 — Initial Critique

Construct the debate prompt and send it to the other AI. The prompt must include the original user request and the full plan content.

Run this command using the Bash tool (replace `<USER_REQUEST>` with the actual user request and `<PLAN_CONTENT>` with the actual plan content):

```bash
DEBATE_PROMPT="You are a senior software architect reviewing a plan. Your job is to be constructively contrarian - challenge assumptions, find blind spots, and suggest better alternatives. Be thorough but fair.

RULES:
- Do NOT edit any files. You are read-only.
- Identify the 2-3 most significant weaknesses, risks, or blind spots.
- For each: explain the PROBLEM, the RISK if unaddressed, and a SPECIFIC ALTERNATIVE.
- If you genuinely find no significant issues, respond EXACTLY with: AGREED: followed by one paragraph explaining why the plan is sound.

## Original User Request
<USER_REQUEST>

## Plan Under Review
<PLAN_CONTENT>

## Response Format
For each concern use this format:

### Concern 1: <title>
**Problem**: ...
**Risk**: ...
**Alternative**: ...

Or if no concerns: AGREED: <summary>"

codex exec \
  --sandbox read-only \
  --skip-git-repo-check \
  --ephemeral \
  -o /tmp/debate-round-1.txt \
  -C "$(pwd)" \
  "$DEBATE_PROMPT"
```

**IMPORTANT construction notes:**
- Use a shell variable (`DEBATE_PROMPT`) to hold the prompt, then pass `"$DEBATE_PROMPT"` to codex exec.
- Escape any double quotes, dollar signs, and backticks in the plan content when inserting it into the variable assignment. Use single quotes for the variable assignment if possible, or properly escape special characters.
- Make sure the entire command is a single Bash tool call.
- Set the Bash tool timeout to 200000 (200 seconds) to allow for codex processing time.

## Phase 3: Evaluate the Response

1. Read `/tmp/debate-round-N.txt` (where N is the current round number).

2. If the file is empty, report an error and suggest the user retry. Stop.

3. If the response contains `AGREED:` at the start of a line, the debate is over — skip to Phase 6.

4. For each concern raised:
   - **If valid**: Accept it. Note what will change in the plan. Be honest — if the critique is right, say so.
   - **If questionable**: Research it first. Use Glob, Grep, Read, WebSearch, or WebFetch to gather evidence. Then make your judgment based on what you found.
   - **If wrong**: Explain why with specific reasoning and evidence.

5. Print your evaluation to the user, clearly prefixed:

```
[CLAUDE - Round N Evaluation]:

### Concern 1: <title>
**Verdict**: ACCEPTED / REJECTED / PARTIALLY ACCEPTED
**Reasoning**: ...
**Plan change** (if accepted): ...
```

6. If you accepted any concerns, update the plan file using the Edit tool. If the plan is only in conversation context (no file), note the changes clearly for the user.

7. Track the debate history. For each completed round, keep a condensed summary (2-3 sentences) of what was raised and what was decided.

## Phase 4: Follow-up Rounds

If there were any REJECTED or PARTIALLY ACCEPTED concerns, send the updated plan back for another round.

Construct the follow-up prompt (replace all placeholders with actual content):

```bash
DEBATE_PROMPT="You are continuing a technical debate about a software plan. This is round N.

## Original Plan
<PLAN_SUMMARY>

## Debate History
<CONDENSED_HISTORY — summarize each prior round in 2-3 sentences>

## Architect's Response to Your Concerns
<CLAUDE_EVALUATION — your verdicts and reasoning from the previous phase>

## Updated Plan (incorporating accepted changes)
<CURRENT_PLAN — always include the full current plan>

## Instructions
For each previous concern:
- Mark RESOLVED if adequately addressed
- Mark UNRESOLVED if you still disagree (explain why with NEW evidence or reasoning)
- You may raise at most 1 new concern if you spot something in the updated plan
- If ALL concerns are resolved, respond EXACTLY with: AGREED: followed by a consensus summary

### Concern 1: <title>
**Status**: RESOLVED | UNRESOLVED
**Reasoning**: ...
**Refined suggestion**: (if unresolved)"

codex exec \
  --sandbox read-only \
  --skip-git-repo-check \
  --ephemeral \
  -o /tmp/debate-round-N.txt \
  -C "$(pwd)" \
  "$DEBATE_PROMPT"
```

Then go back to Phase 3 to evaluate the new response.

**Context management for long debates:**
- Compress older rounds aggressively (1-2 sentences per round).
- Keep the last 2-3 rounds in more detail.
- Always include the full current plan verbatim — it's the anchor.
- If the total prompt exceeds ~6000 tokens, drop the oldest round summaries and keep only their one-line conclusions.

## Phase 5: Termination Conditions

Stop the debate when ANY of these occur:

1. **Agreement**: The response contains `AGREED:` at the start of a line.
2. **Stale debate**: The other AI repeats substantially the same argument for 4-5 consecutive rounds without introducing new evidence or reasoning. In this case, keep your position, terminate, and explain to the user why you're ending the debate (the argument has stalled).
3. **Timeout/Error**: codex exec fails or times out (exit code non-zero, empty output). Report the error and proceed with the current plan.
4. **User interruption**: The user manually stops.

There is **no fixed round limit**. The debate runs until convergence or stale detection.

**Stale detection**: After each round, compare the current UNRESOLVED concerns with the previous round's. If the same concerns appear with substantially similar reasoning (no new evidence, no refined alternatives), increment a stale counter. When it hits 4-5, terminate.

## Phase 6: Synthesis

Print a final summary:

```
=== Debate Concluded (N rounds with $ARGUMENTS) ===

## Consensus Points
- [things both AIs agreed on]

## Changes Made to Plan
- [specific modifications based on accepted feedback]

## Unresolved Disagreements (for your consideration)
- [if any — state both positions so the user can decide]
```

If there are accepted changes that haven't been applied to the plan file yet, apply them now using the Edit tool.

## Error Handling

| Scenario | Action |
|----------|--------|
| codex exec times out | Print "Codex timed out. Proceeding with current plan." and go to Phase 6 with what you have. |
| codex exec returns non-zero exit code | Print the error message and suggest the user retry with `/ask-opinion $ARGUMENTS`. |
| Output file is empty | Print "Codex returned empty response. This may be a transient issue. Suggest retrying." and stop. |
| Stale debate (4-5 rounds same argument) | Print "Debate has stalled — same argument repeated N times with no new evidence. Keeping current position." and go to Phase 6. |
| No plan found | Print instructions to create a plan first. Stop. |

## Important Notes

- You are the primary architect. The other AI is a reviewer. You make the final call on what to accept or reject, but you must be intellectually honest — if a critique is valid, accept it.
- Always show your reasoning to the user. Transparency is key.
- Never let the other AI modify files. All file modifications are done by you (Claude) via the Edit tool.
- The `--sandbox read-only` flag on codex exec ensures the other AI cannot write to the filesystem.
- Keep the user informed at each phase with clear headers and status updates.
