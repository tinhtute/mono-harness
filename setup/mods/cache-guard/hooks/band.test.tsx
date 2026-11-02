import { expect, test } from 'claude-code/testing'

test('band draws Warning and Compact after an effort change', async ($, on) => {
  on('state.get', (_, e) =>
    e.key === 'sent'
      ? { value: { value: { model: 'claude-opus-5-5', effort: 'medium' }, version: 1 } }
      : { value: { value: e.key === 'busy' ? false : null, version: 1 } },
  )
  on('settings.read', () => ({ value: { effortLevel: 'medium', modelSettings: { 'claude-opus-5-5': { effortLevel: 'high' } } } }))
  on('session.model', () => ({ value: 'claude-opus-5-5' }))
  on('session.usage', () => ({ value: { context: { percent: 50, window: 1000000 } } }) as never)
  on('ui.status', () => ({ value: undefined }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>ENGINE</Text>
  })

  const ui = await $.ui.mount({
    plugin: 'cache-guard',
    component: 'AbovePrompt',
    surface: 'terminal',
    props: { hasSurvey: false, isWorking: false, maxRows: 20, columns: 120 },
  } as never)
  expect((await ui.find({ type: 'Text', text: /Warning/ }))?.text ?? 'NONE').toContain('Warning')
  expect(await ui.find({ type: 'Button', key: 'compact' } as never)).toBeTruthy()
  await ui.unmount()
})
