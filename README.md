# ask-opinion

A Claude Code plugin that lets Claude debate its plan with another AI (Codex/GPT or Gemini) through structured adversarial review. No human involvement needed — the AIs argue back and forth until they converge on a refined plan.

## How it works

1. You create a plan in Claude Code (plan mode)
2. Run `/ask-opinion codex`
3. Claude sends the plan to Codex for critique
4. They debate back and forth — Claude evaluates each concern, accepts valid ones, rebuts invalid ones
5. The debate continues until they agree or the argument stalls
6. Your plan gets updated with accepted improvements

## Prerequisites

- [Claude Code](https://claude.ai/code) installed
- [Codex CLI](https://github.com/openai/codex) with a working subscription (`codex exec` must work) — for `/ask-opinion codex`
- [Gemini CLI](https://github.com/google-gemini/gemini-cli) (`npm install -g @google/gemini-cli`) — for `/ask-opinion gemini`

## Install

### From the plugin marketplace

```
/plugin marketplace add iustinsibiescu/ask-opinion
/plugin install ask-opinion@ask-opinion-marketplace
```

### Manual install

Clone this repo and symlink the command into your global commands:

```bash
git clone https://github.com/iustinsibiescu/ask-opinion.git
ln -sf "$(pwd)/ask-opinion/plugins/ask-opinion/commands/ask-opinion.md" ~/.claude/commands/ask-opinion.md
```

## Usage

In Claude Code:

```
# Enter plan mode and create a plan, then:
/ask-opinion codex    # debate with Codex/GPT
/ask-opinion gemini   # debate with Gemini
```

The debate runs autonomously. You'll see:
- Claude's plan summary
- Codex's critiques (2-3 concerns per round)
- Claude's evaluation of each concern (ACCEPTED / REJECTED / PARTIALLY ACCEPTED)
- Follow-up rounds until convergence
- Final synthesis with consensus, changes made, and any unresolved disagreements

## Debate protocol

- **Round 1**: Codex reviews the plan cold and raises 2-3 concerns
- **Follow-up rounds**: Codex marks previous concerns as RESOLVED or UNRESOLVED based on Claude's response
- **Termination**: Agreement (`AGREED:`), stale debate (same argument 4-5x), timeout (180s per round), or user interrupt
- **No fixed round limit** — runs until natural convergence

## Testing

Validate the plugin structure:

```bash
claude plugin validate ./path/to/ask-opinion
```

Test locally before publishing:

```
/plugin marketplace add ./path/to/ask-opinion
/plugin install ask-opinion@ask-opinion-marketplace
```

Run the integration test to verify Codex connectivity:

```bash
bash tests/test-codex.sh     # test Codex integration
bash tests/test-gemini.sh    # test Gemini integration
```

## Project structure

```
ask-opinion/
├── .claude-plugin/
│   └── marketplace.json      # Marketplace catalog
├── plugins/
│   └── ask-opinion/
│       ├── .claude-plugin/
│       │   └── plugin.json   # Plugin manifest
│       └── commands/
│           └── ask-opinion.md # The command (all the logic)
├── tests/
│   ├── test-codex.sh         # Codex integration test
│   └── test-gemini.sh        # Gemini integration test
├── LICENSE
└── README.md
```

## Roadmap

- [x] Gemini CLI support (`/ask-opinion gemini`)
- [ ] Debate transcript persistence (save full history)
- [ ] Third AI as tiebreaker/judge
- [ ] Auto-trigger hook (debate before plan finalization)

## License

MIT
