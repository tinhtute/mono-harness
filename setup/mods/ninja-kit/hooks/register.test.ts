import { test, expect } from 'claude-code/testing'

test('blocks rm, suggests trash', async ($, on) => {
  on('tool.call', { tool: 'Bash' }, () => ({ result: 'ran' }))
  for (const command of ['rm -rf build', 'cd x && rm a', 'sudo rm f']) {
    const r = await $.tool.call({ tool: 'Bash', command })
    expect('deny' in r && r.deny).toContain('trash')
  }
})

test('lets non-rm commands through', async ($, on) => {
  on('tool.call', { tool: 'Bash' }, () => ({ result: 'ran' }))
  for (const command of ['ls', 'trash build', 'git rm --cached a', 'echo form']) {
    const r = await $.tool.call({ tool: 'Bash', command })
    expect(r).toEqual({ result: 'ran' })
  }
})

test('appends repo context to system prompt', async ($, on) => {
  on('prompt.compose', () => ({ sections: [] }))
  on('fs.exists', () => ({ value: true }))
  on('fs.read', () => ({ value: 'Use pnpm.' }))
  const { sections } = await $.prompt.compose({ model: 'claude-opus-5-5', promptModel: 'claude-opus-5-5', surfaces: ['terminal'], tools: [], outputStyle: null, traits: [] })
  expect(sections.at(-1)?.text).toContain('Use pnpm.')
})

test('blocks sensitive files and private URLs', async ($, on) => {
  on('tool.call', () => ({ result: 'ran' }))
  const denied = [
    { tool: 'Read', file_path: '/repo/.env' },
    { tool: 'Grep', pattern: 'x', path: '/home/u/.ssh/id_ed25519' },
    { tool: 'WebFetch', url: 'http://localhost:3000/x', prompt: 'read' },
    { tool: 'mcp__plugin_tinyfish_tinyfish__fetch_content', urls: ['https://10.0.0.5/a'] },
    { tool: 'mcp__claude_ai_Exa__web_fetch_exa', url: 'https://a.com/?token=abc' },
    { tool: 'mcp__plugin_tinyfish_tinyfish__search', query: 'see https://git.corp/x' },
  ]
  for (const call of denied) {
    const r = await $.tool.call(call as never)
    expect('deny' in r && r.deny).toContain('blocked')
  }
})

test('lets ordinary files and public URLs through', async ($, on) => {
  on('tool.call', () => ({ result: 'ran' }))
  const allowed = [
    { tool: 'Read', file_path: '/repo/src/main.rs' },
    { tool: 'WebFetch', url: 'https://claude.dev/blog', prompt: 'read' },
    { tool: 'mcp__plugin_tinyfish_tinyfish__fetch_content', urls: ['https://arxiv.org/abs/2512.24601'] },
  ]
  for (const call of allowed) expect(await $.tool.call(call as never)).toEqual({ result: 'ran' })
})

test('compaction keeps the hard rules and the user instructions', async ($, on) => {
  let seen: string | undefined
  on('session.compact', (_$, e) => { seen = e.instructions; return { skip: 'test' } })
  await $.session.compact({ instructions: 'focus on the plan', messages: [{ role: 'user', text: 'hi', toolUses: [] }] } as never)
  expect(seen).toContain('focus on the plan')
  expect(seen).toContain('trash not rm')
})
