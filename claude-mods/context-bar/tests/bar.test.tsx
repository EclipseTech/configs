import { test, expect, mock } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On } from 'claude-code'

const cat = (name: string, tokens: number, color: string, kind: 'used' | 'free' | 'buffer') =>
  ({ name, tokens, color, isDeferred: false, kind })

// 2026-10-04T12:00:00Z; the windows reset 2h 14m and 3d 4h later.
const NOW = Date.parse('2026-10-04T12:00:00Z')
const RATE_LIMITS = [
  { kind: 'five_hour', percentUsed: 23.4, resetsAt: '2026-10-04T14:14:00Z' },
  { kind: 'seven_day', percentUsed: 81, resetsAt: '2026-10-07T16:00:00Z' },
]

const WINDOW = 200_000
const THRESHOLD = 167_000

// A reading with `total` tokens in use: a fixed system share, the rest messages.
const usageAt = (total: number, startedAt = 1) => ({
  startedAt,
  rateLimits: RATE_LIMITS,
  cost: { usd: 1.234 },
  context: {
    tokens: total,
    window: WINDOW,
    percent: Math.round((total / WINDOW) * 100),
    breakdown: {
      categories: [
        cat('System prompt', 4_000, 'promptBorder', 'used'),
        cat('System tools', 16_000, 'inactive', 'used'),
        cat('Messages', total - 20_000, 'permission', 'used'),
        cat('Free space', WINDOW - total - 33_000, 'promptBorder', 'free'),
        cat('Autocompact buffer', 33_000, 'inactive', 'buffer'),
      ],
      totalTokens: total, maxTokens: WINDOW, rawMaxTokens: WINDOW,
      autocompactSource: 'model-default', percentage: Math.round((total / WINDOW) * 100),
      gridRows: [], model: 'x', memoryFiles: [], mcpTools: [], agents: [],
      autoCompactThreshold: THRESHOLD, isAutoCompactEnabled: true, apiUsage: null,
    },
  },
})

const run = (args: string) => ({
  command: 'context-bar', args,
  origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 120 },
}) as const

const BAND_PROPS = {
  hasSurvey: false, isWorking: false, maxRows: 20, bodyColumns: 120,
  scroll: { offset: 0, bodyRows: 19 }, view: {},
}

const HINT_PROPS = { isDraft: false, isWorking: false, hint: '? for shortcuts' }

// The component each position draws in, with its props.
const SLOT = {
  above: { component: 'AbovePrompt', props: BAND_PROPS },
  below: { component: 'PromptHint', props: HINT_PROPS },
} as const

const mountAt = ($: Engine, surface: 'terminal' | 'desktop', at: keyof typeof SLOT) =>
  $.ui.mount({ plugin: 'context-bar', surface, component: SLOT[at].component, props: SLOT[at].props as never })

const MESSAGES = [{ role: 'user', text: 'summary', toolUses: [] }]

const TURN = { answer: '', durationMs: 1, isAborted: false, turnId: 't', reason: 'answer' } as never

// The engine beneath the mod: a usage reading the test moves, an in-memory store.
const engine = (on: On, usage: () => unknown) => {
  const store = new Map<string, unknown>()
  on('session.usage', () => ({ value: usage() }) as never)
  on('store.set', (_$, e) => (store.set((e as { key: string }).key, (e as { value: unknown }).value), { value: undefined }) as never)
  on('store.get', (_$, e) => ({ value: store.get((e as { key: string }).key) }) as never)
  on('session.start', () => ({ cwd: '/' }))
  on('command.register', () => ({ value: undefined }) as never)
  on('turn.complete', () => ({ text: '' }) as never)
  on('session.compact', () => ({ messages: MESSAGES }) as never)
  // The engine's own band and hint line, drawn when the mod steps aside or
  // kept above the bar.
  on('ui.render', () => ({ type: 'Text', props: {}, children: ['engine line'] }) as never)
  return store
}

// The surface's panes beneath the mod: which ids are open.
const panes = (on: On) => {
  const open = new Set<string>()
  on('ui.open', (_$, e) => (open.add(e.id), { value: { isPlaced: true } }) as never)
  on('ui.close', (_$, e) => (open.delete(e.id), { value: undefined }) as never)
  on('ui.panes', () => ({ value: [...open].map(id => ({ id, title: 'Context', isShown: true })) }) as never)
  return open
}

const PANE_PROPS = {
  title: 'Context', isFocused: false, bodyColumns: 38, placement: 'dock',
  scroll: { offset: 0, bodyRows: 40 }, view: {},
}

for (const surface of ['terminal', 'desktop'] as const) {
  for (const mode of ['compact', 'full'] as const) {
    for (const at of ['above', 'below'] as const) {
    test(`draws ${mode} ${at} the prompt on ${surface}`, async ($, on) => {
      mock.clock(on, { now: NOW })
      engine(on, () => usageAt(100_000))
      await $.command.run(run(mode))
      await $.command.run(run(at))
      const ui = await mountAt($, surface, at)
      expect(await ui.drawn()).toBeDefined()
      if (at === 'below') {
        expect(await ui.find({ type: 'Text', text: 'engine line' })).toBeDefined()
      }
      expect(await ui.find({ type: 'Text', text: ' 50% ' })).toBeDefined()
      expect(await ui.find({ type: 'Text', text: '$1.23' })).toBeDefined()
      expect(await ui.find({ type: 'Text', text: '23%' })).toBeDefined()
      const reset = mode === 'compact' ? ' · 2h14m' : ' · resets in 2h 14m'
      expect(await ui.find({ type: 'Text', text: reset })).toBeDefined()
    })
    }
  }
}

test('shows the per-turn delta and turns to compact, and starts over after compaction', async ($, on) => {
  const clock = mock.clock(on, { now: NOW })
  let total = 100_000
  engine(on, () => usageAt(total))
  await $.session.start({ cwd: '/' } as never)
  await $.command.run(run('full'))
  const ui = await mountAt($, 'terminal', 'below')

  for (const t of [100_000, 120_000, 140_000]) {
    total = t
    await $.turn.complete(TURN)
    await clock.advance(1)
  }
  expect(await ui.find({ type: 'Text', text: 'Δ+20k' })).toBeDefined()
  // (167k - 140k) / 20k per turn, rounded up.
  expect(await ui.find({ type: 'Text', text: '~2 turns to compact' })).toBeDefined()

  total = 40_000
  await $.session.compact({ trigger: 'auto', messages: MESSAGES } as never)
  await clock.advance(1)
  expect(await ui.find({ type: 'Text', text: '~2 turns to compact' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: '-100k' })).toBeUndefined()
})

test('toggles between off and the last visible mode', async ($, on) => {
  mock.clock(on, { now: NOW })
  const store = engine(on, () => usageAt(100_000))
  await $.session.start({ cwd: '/' } as never)
  const ui = await mountAt($, 'terminal', 'below')

  expect((await $.command.run(run('full'))).text).toBe('Context bar on (full).')
  expect((await $.command.run(run(''))).text).toBe('Context bar off.')
  expect(store.get('mode')).toBe('off')
  expect(await ui.find({ type: 'Text', text: ' 50% ' })).toBeUndefined()

  expect((await $.command.run(run(''))).text).toBe('Context bar on (full).')
  expect(await ui.find({ type: 'Text', text: ' 50% ' })).toBeDefined()
  expect((await $.command.run(run('bogus'))).text).toBe('Usage: /context-bar [compact|full|on|off|above|below|side]')
})

test('moves between above and below the prompt, below by default', async ($, on) => {
  const clock = mock.clock(on, { now: NOW })
  const store = engine(on, () => usageAt(100_000))
  await $.session.start({ cwd: '/' } as never)
  await clock.advance(1)
  const band = await mountAt($, 'terminal', 'above')
  const hint = await mountAt($, 'terminal', 'below')
  expect(await hint.find({ type: 'Text', text: ' 50% ' })).toBeDefined()
  expect(await band.find({ type: 'Text', text: ' 50% ' })).toBeUndefined()

  expect((await $.command.run(run('above'))).text).toBe('Context bar above the prompt.')
  expect(store.get('position')).toBe('above')
  expect(await band.find({ type: 'Text', text: ' 50% ' })).toBeDefined()
  expect(await hint.find({ type: 'Text', text: ' 50% ' })).toBeUndefined()
})

for (const surface of ['terminal', 'desktop'] as const) {
  test(`draws the side dock on ${surface}`, async ($, on) => {
    mock.clock(on, { now: NOW })
    engine(on, () => usageAt(100_000))
    panes(on)
    await $.command.run(run('side'))
    const dock = await $.ui.mount({
      plugin: 'context-bar', surface, component: 'Pane', requestId: 'context-bar', props: PANE_PROPS as never,
    })
    expect(await dock.drawn()).toBeDefined()
    expect(await dock.find({ type: 'Text', text: ' 50% ' })).toBeDefined()
    expect(await dock.find({ type: 'Text', text: 'system' })).toBeDefined()
    expect(await dock.find({ type: 'Text', text: ' · resets in 2h 14m' })).toBeDefined()
    expect(await dock.find({ type: 'Button', key: 'dock-close' } as never)).toBeDefined()
  })
}

test('the < and > buttons open and hide the side dock', async ($, on) => {
  mock.clock(on, { now: NOW })
  const store = engine(on, () => usageAt(100_000))
  const open = panes(on)
  expect((await $.command.run(run('side'))).text).toBe('Context bar in the side dock.')
  expect(open.has('context-bar')).toBe(true)

  const hint = await mountAt($, 'terminal', 'below')
  const dock = await $.ui.mount({
    plugin: 'context-bar', surface: 'terminal', component: 'Pane', requestId: 'context-bar', props: PANE_PROPS as never,
  })
  // Open: under the prompt only the engine's hint line, no toggle or bar.
  expect(await hint.find({ type: 'Text', text: ' 50% ' })).toBeUndefined()
  expect(await hint.find({ type: 'Button', key: 'dock-toggle' } as never)).toBeUndefined()

  await dock.press({ key: 'dock-close' })
  expect(open.has('context-bar')).toBe(false)
  expect(store.get('dockOpen')).toBe(false)
  // Closed: the compact bar comes back beside the `<`.
  expect(await hint.find({ type: 'Text', text: ' 50% ' })).toBeDefined()

  await hint.press({ key: 'dock-toggle' })
  expect(open.has('context-bar')).toBe(true)
  expect(store.get('dockOpen')).toBe(true)

  // Leaving the side position closes the dock.
  await $.command.run(run('below'))
  expect(open.has('context-bar')).toBe(false)
})

test('leaves turns to compact out of the compact view', async ($, on) => {
  const clock = mock.clock(on, { now: NOW })
  let total = 100_000
  engine(on, () => usageAt(total))
  await $.session.start({ cwd: '/' } as never)
  await $.command.run(run('compact'))
  const ui = await mountAt($, 'terminal', 'below')
  for (const t of [100_000, 120_000]) {
    total = t
    await $.turn.complete(TURN)
    await clock.advance(1)
  }
  expect(await ui.find({ type: 'Text', text: 'Δ+20k' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '~4 turns to compact' })).toBeUndefined()
})
