// Pure threshold logic for cache-guard: no host imports, so plain `bun test` can run it.
// register.tsx wires these into the engine hooks.

import type { Sent } from '../types'

export const hex = (h: string) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16))
export const gradient = (text: string, from: string, to: string): [string, string][] => {
  const [a, b] = [hex(from), hex(to)]
  const chars = [...text]
  return chars.map((c, i) => {
    const t = chars.length > 1 ? i / (chars.length - 1) : 0
    const rgb = a.map((v, k) => Math.round(v + ((b[k] ?? v) - v) * t).toString(16).padStart(2, '0'))
    return [c, `#${rgb.join('')}`]
  })
}

export const label = (s: Sent) => `${s.model}${s.effort ? `/${s.effort}` : ''}`

export const DEFAULT_THRESHOLD = 40

export const parseThreshold = (raw: unknown): number => Number(raw ?? DEFAULT_THRESHOLD)

// /effort saves per model under modelSettings[model].effortLevel; top-level is the fallback
export type Settings = {
  effortLevel?: unknown
  modelSettings?: Record<string, { effortLevel?: unknown }>
}

export function currentSent(model: string, settings: Settings, last: Sent): Sent {
  const raw = settings.modelSettings?.[model]?.effortLevel ?? settings.effortLevel
  return { model, effort: typeof raw === 'string' ? raw : last.effort }
}

export const warnKey = (last: Sent, now: Sent): string => `${label(last)}->${label(now)}`

export const changedWhat = (last: Sent, now: Sent): string =>
  [now.effort !== last.effort && 'effort', now.model !== last.model && 'model']
    .filter(Boolean)
    .join('/')

// Warn only when model/effort changed, context is at/over the threshold, and the user has not skipped this change.
export function shouldWarn(last: Sent, now: Sent, pct: number, threshold: number, dismissed: unknown): boolean {
  const changed = now.model !== last.model || now.effort !== last.effort
  const skipped = dismissed === warnKey(last, now)
  return !(!changed || pct < threshold || skipped)
}
