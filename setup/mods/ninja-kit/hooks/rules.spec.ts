import { expect, test } from 'bun:test'

import { COMPACT_RULES, RM, compactInstructions, guard, guardDeny, privateUrl, rmDeny } from './rules.ts'

test('RM matches rm as a command word', () => {
  for (const c of ['rm -rf build', 'cd x && rm a', 'sudo rm f', 'ls; rm a', 'a | xargs rm', '(rm a)', 'echo hi\nrm a', 'rm']) {
    expect(RM.test(c)).toBe(true)
  }
})

test('RM lets non-rm commands through', () => {
  for (const c of ['ls', 'trash build', 'git rm --cached a', 'echo form', 'rmdir x', 'npm run rm-all']) {
    expect(RM.test(c)).toBe(false)
  }
})

test('deny messages are unchanged', () => {
  expect(rmDeny('ninja-kit')).toBe('ninja-kit: `rm` is blocked. Use `trash <path>` instead.')
  expect(guardDeny('ninja-kit', 'Read', 'why')).toBe('ninja-kit: blocked Read — why')
})

test('privateUrl blocks private hosts, credentials, secrets, odd schemes', () => {
  expect(privateUrl('http://localhost:3000/x')).toBe('private host localhost')
  expect(privateUrl('https://10.0.0.5/a')).toBe('private host 10.0.0.5')
  expect(privateUrl('https://192.168.1.2/')).toBe('private host 192.168.1.2')
  expect(privateUrl('https://172.16.0.1/')).toBe('private host 172.16.0.1')
  expect(privateUrl('http://169.254.169.254/latest')).toBe('private host 169.254.169.254')
  expect(privateUrl('https://git.corp/x')).toBe('private host git.corp')
  expect(privateUrl(['https://', 'user', ':', 'pw', '@a.com/'].join(''))).toBe('credentials in URL')
  expect(privateUrl('https://a.com/?token=abc')).toBe('token-bearing query string')
  expect(privateUrl('https://a.com/?x=1&X-Amz-Signature=abc')).toBe('token-bearing query string')
  expect(privateUrl('ftp://a.com/')).toBe('non-web scheme ftp:')
})

test('privateUrl allows public URLs and non-URLs', () => {
  expect(privateUrl('https://claude.dev/blog')).toBeUndefined()
  expect(privateUrl('https://172.32.0.1/')).toBeUndefined()
  expect(privateUrl('not a url')).toBeUndefined()
})

test('guard denies sensitive files', () => {
  for (const call of [
    { tool: 'Read', file_path: '/repo/.env' },
    { tool: 'Edit', file_path: '/repo/.env.local' },
    { tool: 'Write', file_path: 'C:\\u\\credentials.json' },
    { tool: 'Grep', pattern: 'x', path: '/home/u/.ssh/id_ed25519' },
    { tool: 'Read', file_path: '/repo/server.pem' },
  ]) {
    expect(guard(call)).toContain('sensitive file')
  }
  expect(guard({ tool: 'Read', file_path: '/repo/.env' })).toBe(
    'sensitive file /repo/.env. Ask the user for approval, then read it with Bash.',
  )
})

test('guard denies private URLs in web tools, nested anywhere', () => {
  const calls = [
    { tool: 'WebFetch', url: 'http://localhost:3000/x', prompt: 'read' },
    { tool: 'mcp__plugin_tinyfish_tinyfish__fetch_content', urls: ['https://10.0.0.5/a'] },
    { tool: 'mcp__claude_ai_Exa__web_fetch_exa', url: 'https://a.com/?token=abc' },
    { tool: 'mcp__plugin_tinyfish_tinyfish__search', query: 'see https://git.corp/x' },
  ]
  for (const call of calls) expect(guard(call)).toContain('Never send private or internal URLs to a third party; read it locally.')
  expect(guard(calls[0]!)).toBe(
    'private host localhost (http://localhost:3000/x). Never send private or internal URLs to a third party; read it locally.',
  )
})

test('guard lets ordinary files, public URLs, and other tools through', () => {
  expect(guard({ tool: 'Read', file_path: '/repo/src/main.rs' })).toBeUndefined()
  expect(guard({ tool: 'Read' })).toBeUndefined()
  expect(guard({ tool: 'WebFetch', url: 'https://claude.dev/blog', prompt: 'read' })).toBeUndefined()
  expect(guard({ tool: 'mcp__plugin_tinyfish_tinyfish__fetch_content', urls: ['https://arxiv.org/abs/2512.24601'] })).toBeUndefined()
  expect(guard({ tool: 'Bash', command: 'curl http://localhost' })).toBeUndefined()
})

test('compaction keeps the hard rules and the user instructions', () => {
  expect(COMPACT_RULES).toContain('trash not rm')
  expect(compactInstructions('focus on the plan')).toBe(`focus on the plan\n\n${COMPACT_RULES}`)
  expect(compactInstructions(undefined)).toBe(COMPACT_RULES)
  expect(compactInstructions('')).toBe(COMPACT_RULES)
})
