import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Sent } from '../types'

const sent = atom({ plugin: 'cache-guard', key: 'sent' } as const, null)
const dismissed = atom({ plugin: 'cache-guard', key: 'dismissed' } as const, null)
const busy = atom({ plugin: 'cache-guard', key: 'busy' } as const, false)

const hex = (h: string) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16))
const gradient = (text: string, from: string, to: string): [string, string][] => {
  const [a, b] = [hex(from), hex(to)]
  const chars = [...text]
  return chars.map((c, i) => {
    const t = chars.length > 1 ? i / (chars.length - 1) : 0
    const rgb = a.map((v, k) => Math.round(v + ((b[k] ?? v) - v) * t).toString(16).padStart(2, '0'))
    return [c, `#${rgb.join('')}`]
  })
}

const label = (s: Sent) => `${s.model}${s.effort ? `/${s.effort}` : ''}`

export const register: Register = (on, options) => {
  const threshold = Number(options.threshold ?? 40)

  on('session.start', async ($, e, next) => {
    await $.ui.status(undefined)
    $.clock.every(2000, () => $.ui.invalidate('ui.render'))
    return next(e)
  })

  on('turn.step', async function* ($, e, next) {
    if (e.agentId === undefined) {
      const effort = e.effort === undefined ? null : String(e.effort)
      await update($, sent, () => ({ model: e.model, effort }))
      await update($, dismissed, () => null)
    }
    return yield* next(e)
  })

  on('session.compact', async ($, e, next) => {
    const r = await next(e)
    await update($, sent, () => null)
    return r
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const last = await read($, sent)
    if (e.props.hasSurvey || last === null) return next(e)

    const model = await $.session.model()
    // /effort saves per model under modelSettings[model].effortLevel; top-level is the fallback
    const settings = (await $.settings.read()) as {
      effortLevel?: unknown
      modelSettings?: Record<string, { effortLevel?: unknown }>
    }
    const raw = settings.modelSettings?.[model]?.effortLevel ?? settings.effortLevel
    const now: Sent = { model, effort: typeof raw === 'string' ? raw : last.effort }
    const changed = now.model !== last.model || now.effort !== last.effort
    const pct = (await $.session.usage()).context.percent ?? 0
    const key = `${label(last)}->${label(now)}`
    const skipped = (await read($, dismissed)) === key
    if (!changed || pct < threshold || skipped) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    const isBusy = await read($, busy)
    const what = [now.effort !== last.effort && 'effort', now.model !== last.model && 'model']
      .filter(Boolean)
      .join('/')
    return (
      <Box gap={1}>
        <Text>
          {gradient('⚠ Warning:', '#fbbf24', '#f472b6').map(([c, color], i) => (
            <Text key={`w${i}`} bold color={color}>{c}</Text>
          ))}
          <Text> change {what} at </Text>
          <Text bold color="#f97316">{Math.round(pct)}% ctx</Text>
          <Text dimColor color="#9ca3af"> · prompt cache will be lost, compact first?</Text>
        </Text>
        <Button
          key="compact"
          variant="primary"
          hotkey="c"
          label={isBusy ? 'Compacting…' : 'Compact'}
          onPress={async () => {
            if (isBusy) return
            await update($, busy, () => true)
            $.clock.after(0, async () => {
              try {
                await $.session.compact()
              } finally {
                await update($, busy, () => false)
              }
            })
          }}
        />
        <Button key="skip" dimColor hotkey="s" label="Skip" onPress={() => update($, dismissed, () => key)} />
      </Box>
    )
  })
}
