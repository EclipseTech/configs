export type SegmentKind = 'used' | 'free' | 'buffer'

export type Segment = { name: string; tokens: number; color: string; kind: SegmentKind }

export type Snapshot = {
  total: number
  max: number
  // Where auto-compaction runs, null when it is off.
  threshold: number | null
  segments: Segment[]
}

// A rate-limit window: `five_hour`, `seven_day` or a gateway's `spend_limit`.
// `resetsAt` is in epoch milliseconds, null when not reported.
export type Limit = { kind: string; percent: number; resetsAt: number | null }

export type Mode = 'compact' | 'full' | 'off'

// Where the bar draws: the band above the prompt, under the prompt's hint
// line, or a pane docked beside the transcript.
export type Position = 'below' | 'above' | 'side'

// Context totals after each main-thread turn, oldest first, for the per-turn
// delta and the turns-to-compact estimate. `startedAt` ties it to one
// session, so /clear starts it over.
export type History = { startedAt: number; totals: number[] }

declare module 'claude-code' {
  interface PluginState {
    'context-bar': {
      snapshot: Snapshot | null
      mode: Mode
      position: Position
      // Whether the side dock is open; only drawn in the `side` position.
      isDockOpen: boolean
      limits: Limit[]
      cost: number | null
      history: History
      now: number
    }
  }
}
