# context-bar

A live view of the context window under Claude Code's prompt (or in the band above it).

## Modes

**compact** (default), one line:

```
◆ [ 50% ] ▇▇▇▇▇▇▇▇▇▇▇───│     100kΔ+20k/200k  $1.23  5h 23% · 2h14m  7d 81% · 3d4h
```

**full**, three or four rows: a header with totals, the turns-to-compact estimate and the compaction point, a full-width category bar, a legend with each category's tokens, and a usage row with the rate-limit windows:

```
◆ context [ 50% ] 100kΔ+20k/200k  ~3 turns to compact  compacts 160k  $1.23
▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇───────────────────│
■ system 3.1k  ■ tools 14k  ■ memory 2.4k  ■ messages 80.5k  ─ free 60k
◆ usage  5h 23% · resets in 2h 14m  7d 81% · resets in 3d 4h
```

In both, the bar's segments take each category's color, and the usage row appears only on a subscription.

## What it shows

- **Badge:** share of the window in use, green under 50%, yellow under 80%, red above
- **Bar:** one segment per `/context` category, then the free track, ending at a `│` tick where auto-compaction runs (the reserve past it is left blank)
- **Delta:** context growth over the last turn, between the tokens in use and the window: `164kΔ+2.1k/1M`
- **Turns to compact:** remaining room before auto-compaction divided by the average growth over the last 5 turns. It starts over after a compaction or `/clear`
- **Cost:** session cost in USD, as `/cost` reports it
- **Rate limits:** 5h / 7d (or a gateway's spend) windows with reset countdowns. Subscriptions only

## Usage

| Command | Does |
| --- | --- |
| `/context-bar` | Toggles between off and the last visible mode |
| `/context-bar compact` | One-line bar |
| `/context-bar full` | Full bar with legend |
| `/context-bar on` | Shows the last visible mode |
| `/context-bar off` | Hides the bar |
| `/context-bar below` | Draws the bar under the prompt, beneath the hint line (default) |
| `/context-bar above` | Draws the bar in the band above the prompt |
| `/context-bar side` | Draws the bar in a dock beside the transcript |

The mode and position are remembered across sessions.

### Side dock

In the `side` position a `[ < ]` button sits under the prompt, with the compact bar beside it. Click it to open the dock, a pane beside the transcript that lists the bar, delta, turns to compact, cost, every category and the rate limits, one per row. While the dock is open, nothing extra shows under the prompt; click `[ > ]` at the top of the dock to hide it. Closing the dock with Claude Code's own close mark does the same. Whether it's open is remembered across sessions.

The dock needs Claude Code's fullscreen renderer: run `/tui fullscreen` (restarts and resumes the session), or set `"tui": "fullscreen"` in `~/.claude/settings.json` to keep it on. Fullscreen also lets you click the buttons with the mouse. The dock sits beside the transcript at 110 columns or wider; otherwise, or off fullscreen, Claude Code shows the pane above the prompt. When it opens on its own at session start, it needs 144 columns, and waits until then.

## Running it

```bash
claude --plugin-dir ~/path/to/context-bar
```

## How it works

| Hook | What it does |
| --- | --- |
| `session.start` | Registers `/context-bar`, restores the mode, takes a first reading, starts a 1-minute tick for countdowns |
| `turn.complete` | Takes a reading after each main-thread turn and records it in the history |
| `session.compact` | Takes a reading and starts the history over |
| `session.measure` | Updates rate limits and cost when they move, between turns too |
| `ui.render` on `PromptHint` | Below the prompt: draws the engine's hint line, then the bar under it |
| `ui.render` on `Pane` | The side dock |
| `ui.close` | Remembers when you close the dock with Claude Code's own close mark |
| `ui.render` on `AbovePrompt` | Above the prompt: draws the band, stepping aside for surveys |

Readings come from `$.session.usage({ breakdown: 'summary' })`, which is estimated locally and sends no requests.

## Limitations

- Category figures are estimates, as in `/context`
- Updates after each turn, not during one
- In the `above` position, the band holds one mod at a time
- Claude Code has no slot at the very bottom of the screen for mods. `below` sits directly under the prompt's hint line

## Development

```bash
claude plugin validate .
claude plugin test .
```
