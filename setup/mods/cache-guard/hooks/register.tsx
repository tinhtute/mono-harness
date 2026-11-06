import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Settings } from './rules.ts'
import { changedWhat, currentSent, gradient, parseThreshold, shouldWarn, warnKey } from './rules.ts'

const sent = atom({ plugin: 'cache-guard', key: 'sent' } as const, null)
const dismissed = atom({ plugin: 'cache-guard', key: 'dismissed' } as const, null)
const busy = atom({ plugin: 'cache-guard', key: 'busy' } as const, false)

export const register: Register = (on, options) => {
  const threshold = parseThreshold(options.threshold)

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
    const settings = (await $.settings.read()) as Settings
    const now = currentSent(model, settings, last)
    const pct = (await $.session.usage()).context.percent ?? 0
    const key = warnKey(last, now)
    const dismissedKey = await read($, dismissed)
    if (!shouldWarn(last, now, pct, threshold, dismissedKey)) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    const isBusy = await read($, busy)
    const what = changedWhat(last, now)
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
