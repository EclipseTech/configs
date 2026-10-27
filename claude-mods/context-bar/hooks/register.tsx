import { atom, read, update } from 'claude-code'
import type { EngineInterface, PluginOptions, Register, RenderElement, RenderInput, SessionRateLimit } from 'claude-code'

import type { History, Limit, Mode, Position, Segment, Snapshot } from '../types'

const snapshot = atom({ plugin: 'context-bar', key: 'snapshot' } as const, null)
const mode = atom({ plugin: 'context-bar', key: 'mode' } as const, 'compact' as Mode)
const position = atom({ plugin: 'context-bar', key: 'position' } as const, 'below' as Position)
const isDockOpen = atom({ plugin: 'context-bar', key: 'isDockOpen' } as const, true)
const isFullscreen = atom({ plugin: 'context-bar', key: 'isFullscreen' } as const, null as boolean | null)
const limits = atom({ plugin: 'context-bar', key: 'limits' } as const, [] as Limit[])
const cost = atom({ plugin: 'context-bar', key: 'cost' } as const, null)
const history = atom({ plugin: 'context-bar', key: 'history' } as const, { startedAt: 0, totals: [] } as History)
// The time the reset countdowns are measured from, moved on once a minute.
const now = atom({ plugin: 'context-bar', key: 'now' } as const, 0)

// Persisted across sessions: the current mode, the last visible one so a
// bare /context-bar toggles back to it, where the bar draws, and whether the
// side dock is open.
const MODE_KEY = 'mode'
const LAST_SHOWN_KEY = 'lastShown'
const POSITION_KEY = 'position'
const DOCK_KEY = 'dockOpen'
const DEFAULT_MODE: Mode = 'compact'
const DEFAULT_POSITION: Position = 'below'

// Longer than any band is wide; the free track's box clips it to its share.
const FREE_FILL = '─'.repeat(400)
// The compaction point: a tick through the free track, in the text colour so
// no category's colour can match it.
const MARK = '│'
const PANE = 'context-bar'

// The person's settings (the manifest's userConfig), read again on each load.
// `dockColumns` is the dock's requested width; the person can drag it wider or
// narrower. `turnsWindow` is how many recent turns the turns-to-compact
// estimate averages over.
type Config = {
  accent: string
  compactBarWidth: number
  dockColumns: number
  tickMs: number
  turnsWindow: number
  warnPercent: number
  dangerPercent: number
}

const DEFAULT_ACCENT = '#D97757'

let config: Config = {
  accent: DEFAULT_ACCENT,
  compactBarWidth: 24,
  dockColumns: 38,
  tickMs: 60_000,
  turnsWindow: 5,
  warnPercent: 50,
  dangerPercent: 80,
}

// A whole number within bounds; the fallback for anything else.
const bounded = (v: unknown, fallback: number, min: number, max: number) =>
  typeof v === 'number' && Number.isFinite(v) ? Math.min(max, Math.max(min, Math.round(v))) : fallback

const toConfig = (options: PluginOptions): Config => {
  const accent = options.accentColor
  const warnPercent = bounded(options.warnPercent, 50, 0, 100)
  return {
    accent: typeof accent === 'string' && /^#[0-9a-f]{6}$/i.test(accent.trim()) ? accent.trim() : DEFAULT_ACCENT,
    compactBarWidth: bounded(options.compactBarWidth, 24, 8, 80),
    dockColumns: bounded(options.dockColumns, 38, 24, 120),
    tickMs: bounded(options.refreshSeconds, 60, 10, 3600) * 1000,
    turnsWindow: bounded(options.turnsWindow, 5, 1, 20),
    warnPercent,
    // Red never starts below yellow.
    dangerPercent: Math.max(warnPercent, bounded(options.dangerPercent, 80, 0, 100)),
  }
}

// Shorter legend labels for /context's category names; others show as given.
const LABELS: Record<string, string> = {
  'system prompt': 'system',
  'system tools': 'tools',
  'mcp tools': 'mcp',
  'mcp server instructions': 'mcp instr',
  'custom agents': 'agents',
  'memory files': 'memory',
}

// Short names for the rate-limit windows; others show with spaces for underscores.
const LIMIT_LABELS: Record<string, string> = {
  five_hour: '5h',
  seven_day: '7d',
  spend_limit: 'spend',
}

const USAGE_TEXT = 'Usage: /context-bar [compact|full|on|off|above|below|side]'
const SIDE_NEEDS_FULLSCREEN =
  'The side dock needs the fullscreen layout: run /tui fullscreen, then /context-bar side.'

const short = (n: number) => {
  const abs = Math.abs(n)
  if (abs >= 1_000_000) return `${+(n / 1_000_000).toFixed(1)}M`
  if (abs >= 1_000) return `${+(n / 1_000).toFixed(abs >= 100_000 ? 0 : 1)}k`
  return String(n)
}

const signed = (n: number) => (n >= 0 ? `+${short(n)}` : `-${short(-n)}`)

const usd = (n: number) => `$${n.toFixed(2)}`

// A share of the window as a flex weight, in hundredths of a percent: the
// surfaces cap flexGrow at 10000.
const growOf = (tokens: number, max: number) => Math.min(10_000, (tokens / max) * 10_000)

const badgeColor = (percent: number) =>
  percent < config.warnPercent ? 'success' : percent < config.dangerPercent ? 'warning' : 'error'

// Time left as `45m`, `2h 14m` or `3d 4h`, rounded up to the minute; null once
// it has passed.
const until = (ms: number) => {
  const minutes = Math.ceil(ms / 60_000)
  if (minutes <= 0) return null
  if (minutes < 60) return `${minutes}m`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return minutes % 60 ? `${hours}h ${minutes % 60}m` : `${hours}h`
  const days = Math.floor(hours / 24)
  return hours % 24 ? `${days}d ${hours % 24}h` : `${days}d`
}

const limitLabel = (kind: string) => LIMIT_LABELS[kind] ?? kind.replace(/_/g, ' ')

// The change over the last turn, null before there are two readings.
const deltaOf = (totals: number[]) =>
  totals.length < 2 ? null : (totals.at(-1) ?? 0) - (totals.at(-2) ?? 0)

// Turns left until auto-compaction at the recent average growth per turn;
// null without a threshold, enough readings or any growth.
const turnsToCompact = (snap: Snapshot, totals: number[]) => {
  if (snap.threshold === null || totals.length < 2) return null
  const recent = totals.slice(-(config.turnsWindow + 1))
  const perTurn = ((recent.at(-1) ?? 0) - (recent[0] ?? 0)) / (recent.length - 1)
  if (perTurn <= 0) return null
  return Math.max(0, Math.ceil((snap.threshold - snap.total) / perTurn))
}

const toLimits = (windows: readonly SessionRateLimit[]): Limit[] =>
  windows.map(w => {
    const resetsAt = w.resetsAt === undefined ? NaN : Date.parse(w.resetsAt)
    return { kind: w.kind, percent: w.percentUsed, resetsAt: Number.isNaN(resetsAt) ? null : resetsAt }
  })

const setLimits = async ($: EngineInterface, windows: readonly SessionRateLimit[]) => {
  const time = await $.clock.now()
  await update($, now, () => time)
  await update($, limits, () => toLimits(windows))
}

// Moves the countdowns on; skipped while there is nothing on screen to move.
const tick = async ($: EngineInterface) => {
  if ((await read($, mode)) === 'off' || !(await read($, limits)).some(l => l.resetsAt !== null)) {
    return
  }
  const time = await $.clock.now()
  await update($, now, () => time)
}

type Recording = 'none' | 'turn' | 'compact'

// Takes a reading. `record` says whether it lands in the history: after a
// main-thread turn it is appended, after a compaction the history starts over
// from it.
const refresh = async ($: EngineInterface, record: Recording = 'none') => {
  try {
    const usage = await $.session.usage({ breakdown: 'summary' })
    await setLimits($, usage.rateLimits)
    await update($, cost, () => usage.cost?.usd ?? null)
    const b = usage.context.breakdown
    if (!b) {
      return
    }
    const segments: Segment[] = b.categories
      .filter(c => c.kind !== 'deferred')
      .map(c => ({
        name: c.name.toLowerCase(),
        tokens: c.tokens,
        color: c.color,
        kind: c.kind === 'free' ? 'free' : c.kind === 'buffer' ? 'buffer' : 'used',
      }))
    const next: Snapshot = {
      total: b.totalTokens,
      max: b.rawMaxTokens,
      threshold: b.isAutoCompactEnabled ? (b.autoCompactThreshold ?? null) : null,
      segments,
    }
    await update($, snapshot, () => next)
    await update($, history, h => {
      // A new session (or /clear) starts the history over.
      const totals = h.startedAt === usage.startedAt ? h.totals : []
      if (record === 'none') {
        return { startedAt: usage.startedAt, totals }
      }
      const kept = record === 'compact' ? [] : totals
      return { startedAt: usage.startedAt, totals: [...kept, next.total].slice(-(config.turnsWindow + 1)) }
    })
  } catch {
    // No reading this time; the bar keeps the last one.
  }
}

const setMode = async ($: EngineInterface, value: Mode) => {
  await $.store.set(MODE_KEY, value)
  if (value !== 'off') {
    await $.store.set(LAST_SHOWN_KEY, value)
  }
  await update($, mode, () => value)
  if (value !== 'off') {
    await refresh($)
  }
  await syncDock($)
}

const lastShown = async ($: EngineInterface): Promise<Mode> => {
  const stored = await $.store.get(LAST_SHOWN_KEY)
  return stored === 'full' || stored === 'compact' ? stored : DEFAULT_MODE
}

const isMode = (v: unknown): v is Mode => v === 'compact' || v === 'full' || v === 'off'

const isPosition = (v: unknown): v is Position => v === 'above' || v === 'below' || v === 'side'

// Opens or closes the dock to match the mode, position, the person's choice
// and the layout: off fullscreen the dock never opens.
const syncDock = async ($: EngineInterface) => {
  const isWanted =
    (await read($, mode)) !== 'off' &&
    (await read($, position)) === 'side' &&
    (await read($, isDockOpen)) &&
    (await read($, isFullscreen)) === true
  try {
    if (isWanted) {
      await $.ui.open({ id: PANE, title: 'Context', columns: config.dockColumns })
    } else if ((await $.ui.panes()).some(p => p.id === PANE)) {
      await $.ui.close({ id: PANE })
    }
  } catch {
    // Refused by another hook; the toggle stays usable.
  }
}

// Records the layout a command or a drawing reports (fixed per session on the
// terminal), opening or closing the dock to match.
const learnFullscreen = async ($: EngineInterface, value: boolean | undefined) => {
  if (value === undefined || (await read($, isFullscreen)) === value) {
    return
  }
  await update($, isFullscreen, () => value)
  await syncDock($)
}

// Where the bar draws at this drawing: a stored `side` draws below the prompt
// off fullscreen, and the layout the drawing reports is recorded after it.
const drawnPosition = async ($: EngineInterface, e: RenderInput<'PromptHint'>): Promise<Position> => {
  const reported = e.viewport?.isFullscreen
  const known = await read($, isFullscreen)
  if (reported !== undefined && reported !== known) {
    $.clock.after(0, () => void learnFullscreen($, reported))
  }
  const at = await read($, position)
  return at === 'side' && (reported ?? known) !== true ? 'below' : at
}

const setDock = async ($: EngineInterface, value: boolean) => {
  await $.store.set(DOCK_KEY, value)
  await update($, isDockOpen, () => value)
  await syncDock($)
}

const setPosition = async ($: EngineInterface, value: Position) => {
  await $.store.set(POSITION_KEY, value)
  await update($, position, () => value)
  await refresh($)
  if (value === 'side') {
    await setDock($, true)
  } else {
    await syncDock($)
  }
}

export const register: Register = (on, options) => {
  config = toConfig(options)

  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await $.command.register({
      name: 'context-bar',
      description: 'Show the context bar compact or full, or hide it',
      argumentHint: '[compact|full|on|off|above|below|side]',
      immediate: true,
    })
    const stored = await $.store.get(MODE_KEY)
    await update($, mode, () => (isMode(stored) ? stored : DEFAULT_MODE))
    const storedPosition = await $.store.get(POSITION_KEY)
    await update($, position, () => (isPosition(storedPosition) ? storedPosition : DEFAULT_POSITION))
    const storedDock = await $.store.get(DOCK_KEY)
    await update($, isDockOpen, () => storedDock !== false)
    void syncDock($)
    $.clock.after(0, () => void refresh($))
    $.clock.every(config.tickMs, () => void tick($))

    return result
  })

  on('command.run', { command: 'context-bar' }, async ($, e) => {
    const arg = e.args.trim().toLowerCase()
    await learnFullscreen($, e.presentation.isFullscreen)
    if (arg === 'side' && !e.presentation.isFullscreen) {
      return { text: SIDE_NEEDS_FULLSCREEN }
    }
    if (isPosition(arg)) {
      await setPosition($, arg)
      return { text: arg === 'side' ? 'Context bar in the side dock.' : `Context bar ${arg} the prompt.` }
    }
    let value: Mode
    if (arg === '') {
      value = (await read($, mode)) === 'off' ? await lastShown($) : 'off'
    } else if (arg === 'on') {
      value = await lastShown($)
    } else if (isMode(arg)) {
      value = arg
    } else {
      return { text: USAGE_TEXT }
    }
    await setMode($, value)

    return { text: value === 'off' ? 'Context bar off.' : `Context bar on (${value}).` }
  })

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId === undefined) {
      $.clock.after(0, () => void refresh($, 'turn'))
    }
    return result
  })

  on('session.compact', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId === undefined) {
      $.clock.after(0, () => void refresh($, 'compact'))
    }
    return result
  })

  // The person closed the dock from the engine's own close mark: remember it,
  // so the toggle under the prompt shows `<`.
  on('ui.close', async ($, e, next) => {
    const result = await next(e)
    if (e.id === PANE && e.origin.kind === 'person') {
      await $.store.set(DOCK_KEY, false)
      await update($, isDockOpen, () => false)
    }
    return result
  })

  // Rate limits and cost move between turns too; the engine pushes them here.
  on('session.measure', async ($, e, next) => {
    const result = await next(e)
    if (e.changed.includes('rateLimits')) {
      await setLimits($, e.rateLimits)
    }
    if (e.changed.includes('cost') && e.cost) {
      const usdNow = e.cost.usd
      await update($, cost, () => usdNow)
    }
    return result
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const current = await read($, mode)
    if (e.props.hasSurvey || current === 'off' || (await read($, position)) !== 'above') {
      return next(e)
    }
    return draw($, e, current)
  })

  // Under the prompt: the engine's hint line as it draws it, the bar beneath.
  // In the side position, while the dock is closed, the line under the hint
  // holds `<` to open it and the compact bar beside it; while it is open the
  // dock's own `>` hides it.
  on('ui.render', { component: 'PromptHint' }, async ($, e, next) => {
    const current = await read($, mode)
    const at = await drawnPosition($, e)
    if (current === 'off' || at === 'above') {
      return next(e)
    }
    const { Box, Button } = $.ui.resolve(e)
    const hint = await next(e)
    if (at === 'below') {
      return (
        <Box flexDirection="column">
          {hint}
          {await draw($, e, current)}
        </Box>
      )
    }
    if (await read($, isDockOpen)) {
      return hint
    }
    return (
      <Box flexDirection="column">
        {hint}
        <Box flexDirection="row">
          <Button key="dock-toggle" label="<" onPress={() => setDock($, true)} />
          {await draw($, e, 'compact')}
        </Box>
      </Box>
    )
  })

  // The side dock: a `>` to hide it, then the bar laid out down the pane.
  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Button } = $.ui.resolve(e)
    return (
      <Box flexDirection="column">
        <Box flexDirection="row">
          <Button key="dock-close" label=">" onPress={() => setDock($, false)} />
        </Box>
        {await draw($, e, 'side')}
      </Box>
    )
  })
}

// The bar as a tree, for the band above the prompt or the hint line under it.
const draw = async (
  $: EngineInterface,
  e: RenderInput<'AbovePrompt' | 'PromptHint' | 'Pane'>,
  layout: Exclude<Mode, 'off'> | 'side',
): Promise<RenderElement> => {
  const { Box, Text } = $.ui.resolve(e)
  const snap = await read($, snapshot)
  const windows = await read($, limits)
  const time = await read($, now)
  const spent = await read($, cost)
  const { totals } = await read($, history)
  const isTerminal = e.surface === 'terminal'
  const isCompact = layout === 'compact'

  const head = (
    <Box key="head" flexDirection="row">
      <Text color={config.accent}>◆ </Text>
      <Text bold>context </Text>
    </Box>
  )

  // Each rate-limit window with its share used and when it resets. Absent
  // off a subscription, where no window is reported.
  const limitItems = windows.map((l, i) => {
    const percent = Math.round(l.percent)
    const left = l.resetsAt === null ? null : until(l.resetsAt - time)
    const reset = l.resetsAt === null ? null : left === null ? 'resetting' : isCompact ? left.replace(' ', '') : `resets in ${left}`
    return (
      <Box key={`lim${i}`} flexDirection="row">
        <Text dimColor>{limitLabel(l.kind)} </Text>
        <Text bold color={badgeColor(percent)}>{`${percent}%`}</Text>
        {reset !== null && <Text dimColor>{` · ${reset}`}</Text>}
      </Box>
    )
  })

  if (snap === null || snap.max <= 0) {
    return (
      <Box flexDirection={isCompact ? 'row' : 'column'} flexWrap="wrap" columnGap={2} paddingX={1}>
        <Box flexDirection="row">
          {head}
          <Text dimColor> waiting for the first reading…</Text>
        </Box>
        {limitItems}
      </Box>
    )
  }

  const percent = Math.round((snap.total / snap.max) * 100)
  const used = snap.segments.filter(s => s.kind === 'used' && s.tokens > 0)
  const free = snap.segments.find(s => s.kind === 'free')
  const usedTokens = used.reduce((sum, s) => sum + s.tokens, 0)
  const rest = Math.max(0, snap.max - usedTokens)
  // The free track splits at the compaction point, where a marker goes.
  const beforeCompact =
    snap.threshold === null ? rest : Math.max(0, Math.min(rest, snap.threshold - usedTokens))
  const afterCompact = rest - beforeCompact
  const hasMarker = snap.threshold !== null && afterCompact > 0
  const delta = deltaOf(totals)
  const turnsLeft = turnsToCompact(snap, totals)

  // A free run, drawn as a dim line on the terminal (the engine's colour for
  // free space there reads as used) and filled elsewhere (other surfaces wrap
  // a long text run rather than clip it).
  const freeRun = (key: string, tokens: number) =>
    tokens <= 0 ? null : isTerminal ? (
      <Box key={key} width={0} flexGrow={growOf(tokens, snap.max)} height={1} overflow="hidden">
        <Text dimColor>{FREE_FILL}</Text>
      </Box>
    ) : (
      <Box key={key} width={0} flexGrow={growOf(tokens, snap.max)} height={1} backgroundColor={free?.color} />
    )

  // Each segment grows by its token count from a zero basis, so the row
  // splits in exact proportion at any width.
  const bar = (
    <Box
      key="bar"
      flexDirection="row"
      height={1}
      overflow="hidden"
      {...(isCompact ? { width: config.compactBarWidth, flexShrink: 0 } : {})}
    >
      {used.map((s, i) => (
        <Box
          key={`seg${i}`}
          width={0}
          flexGrow={growOf(s.tokens, snap.max)}
          minWidth={1}
          height={1}
          backgroundColor={s.color}
        />
      ))}
      {freeRun('free', beforeCompact)}
      {hasMarker && (
        <Box key="mark" width={1} minWidth={1} height={1} {...(isTerminal ? {} : { backgroundColor: free?.color })}>
          <Text bold>{MARK}</Text>
        </Box>
      )}
      {/* Past the compaction point the context never fills, so the bar ends
          at the tick: the reserve keeps its share of the row, left empty. */}
      {afterCompact > 0 && (
        <Box key="reserve" width={0} flexGrow={growOf(afterCompact, snap.max)} height={1} />
      )}
    </Box>
  )

  // The badge sits beside the totals, not at the row's right edge, where the
  // engine draws the band's own [-] control over it.
  const badge = (
    <Text key="badge" bold color="black" backgroundColor={badgeColor(percent)}>
      {` ${percent}% `}
    </Text>
  )

  // The tokens in use, the change over the last turn, then the window:
  // `164kΔ+2.1k/1M`.
  const totalsText = (
    <Box key="totals" flexDirection="row">
      <Text bold>{short(snap.total)}</Text>
      {delta !== null && delta !== 0 && (
        <Text key="delta" bold>{`Δ${signed(delta)}`}</Text>
      )}
      <Text dimColor>/{short(snap.max)}</Text>
    </Box>
  )

  const extras = [
    !isCompact && turnsLeft !== null && (
      <Text key="turns" dimColor>{`~${turnsLeft} turn${turnsLeft === 1 ? '' : 's'} to compact`}</Text>
    ),
    layout === 'full' && snap.threshold !== null && (
      <Text key="compacts" dimColor>{`compacts ${short(snap.threshold)}`}</Text>
    ),
    spent !== null && <Text key="cost" dimColor>{usd(spent)}</Text>,
  ].filter(Boolean)

  // Down a narrow pane: one fact per row, the legend and limits as lists.
  if (layout === 'side') {
    const row = (key: string, label: RenderElement, value: RenderElement) => (
      <Box key={key} flexDirection="row" justifyContent="space-between">
        {label}
        {value}
      </Box>
    )
    return (
      <Box flexDirection="column" paddingX={1}>
        <Box flexDirection="row">
          {head}
          {badge}
        </Box>
        {totalsText}
        {bar}
        <Text> </Text>
        {extras}
        <Text> </Text>
        {used.map((s, i) =>
          row(
            `leg${i}`,
            <Box flexDirection="row"><Text color={s.color}>■ </Text><Text dimColor>{LABELS[s.name] ?? s.name}</Text></Box>,
            <Text>{short(s.tokens)}</Text>,
          ),
        )}
        {hasMarker &&
          row(
            'leg-mark',
            <Box flexDirection="row"><Text bold>{`${MARK} `}</Text><Text dimColor>compacts at</Text></Box>,
            <Text>{short(snap.threshold ?? 0)}</Text>,
          )}
        {free && free.tokens > 0 &&
          row(
            'leg-free',
            <Box flexDirection="row">{isTerminal ? <Text dimColor>─ </Text> : <Text color={free.color}>■ </Text>}<Text dimColor>free</Text></Box>,
            <Text>{short(free.tokens)}</Text>,
          )}
        {limitItems.length > 0 && <Text> </Text>}
        {limitItems.length > 0 && (
          <Box key="usage-head" flexDirection="row">
            <Text color={config.accent}>◆ </Text>
            <Text bold>usage</Text>
          </Box>
        )}
        {limitItems}
      </Box>
    )
  }

  if (isCompact) {
    return (
      <Box flexDirection="row" flexWrap="wrap" columnGap={2} paddingX={1}>
        <Box key="main" flexDirection="row" columnGap={1}>
          <Text color={config.accent}>◆</Text>
          {badge}
          {bar}
          {totalsText}
        </Box>
        {extras}
        {limitItems}
      </Box>
    )
  }

  return (
    <Box flexDirection="column" paddingX={1}>
      <Box flexDirection="row" flexWrap="wrap" columnGap={2}>
        <Box key="main" flexDirection="row">
          {head}
          {badge}
          <Text> </Text>
          {totalsText}
        </Box>
        {extras}
      </Box>
      {bar}
      <Box flexDirection="row" flexWrap="wrap" columnGap={2}>
        {used.map((s, i) => (
          <Box key={`leg${i}`} flexDirection="row">
            <Text color={s.color}>■ </Text>
            <Text dimColor>{LABELS[s.name] ?? s.name} </Text>
            <Text>{short(s.tokens)}</Text>
          </Box>
        ))}
        {free && free.tokens > 0 && (
          <Box key="leg-free" flexDirection="row">
            {isTerminal ? <Text dimColor>─ </Text> : <Text color={free.color}>■ </Text>}
            <Text dimColor>free </Text>
            <Text>{short(free.tokens)}</Text>
          </Box>
        )}
      </Box>
      {limitItems.length > 0 && (
        <Box flexDirection="row" flexWrap="wrap" columnGap={2}>
          <Box key="usage-head" flexDirection="row">
            <Text color={config.accent}>◆ </Text>
            <Text bold>usage</Text>
          </Box>
          {limitItems}
        </Box>
      )}
    </Box>
  )
}
