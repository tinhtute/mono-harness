import type { EngineInterface, Register } from 'claude-code'

import { compactInstructions, guard, guardDeny, RM, rmDeny } from './rules.ts'

export { COMPACT_RULES, privateUrl } from './rules.ts'

const PLANS = '.harness/plans/active'
const CONTEXT = '.claude/context.md'

// 2. Footer label: active plan + checkbox progress (SessionMode draws it bare, unlike $.ui.status)
let plan: string | undefined

function show($: EngineInterface, label: string | undefined) {
  if (label === plan) return
  plan = label
  $.ui.invalidate('ui.render')
}

async function refresh($: EngineInterface) {
  try {
    if (!(await $.fs.exists(PLANS))) return show($, undefined)
    const plans = (await $.fs.list(PLANS)).filter(f => f.kind === 'file' && f.name.endsWith('.md'))
    if (!plans.length) return show($, undefined)
    const newest = [...plans].sort((a, b) => b.mtimeMs - a.mtimeMs)[0]!
    const text = (await $.fs.read(`${PLANS}/${newest.name}`)) as string
    const done = (text.match(/^\s*[-*] \[x\]/gim) ?? []).length
    const total = done + (text.match(/^\s*[-*] \[ \]/gm) ?? []).length
    const more = plans.length > 1 ? ` +${plans.length - 1}` : ''
    show($, `📋 ${newest.name.replace(/\.md$/, '')}${total ? ` ${done}/${total}` : ''}${more}`)
  } catch {
    show($, undefined)
  }
}

export const register: Register = on => {
  // 1. Guard: rm -> trash
  on('tool.call', { tool: 'Bash' }, ($, e, next) =>
    RM.test(e.command)
      ? { deny: rmDeny($.plugin.name) }
      : next(e),
  )

  // 3. Guards: secrets on disk, private URLs to third parties
  on('tool.call', ($, e, next) => {
    const why = guard(e as unknown as { tool: string } & Record<string, unknown>)
    return why ? { deny: guardDeny($.plugin.name, e.tool, why) } : next(e)
  })

  // 2. Refresh the plan label
  on('session.start', async ($, e, next) => {
    const r = await next(e)
    await refresh($)
    return r
  })
  on('turn.complete', async ($, e, next) => {
    const r = await next(e)
    await refresh($)
    return r
  })

  on('ui.render', { component: 'SessionMode' }, ($, e, next) =>
    plan ? next({ ...e, props: { ...e.props, modes: [...e.props.modes, plan] } }) : next(e),
  )

  // 5. Compaction: tell the summarizer to keep the hard rules
  on('session.compact', ($, e, next) =>
    next({ ...e, instructions: compactInstructions(e.instructions) }),
  )

  // 4. Per-repo context: append <project>/.claude/context.md to the system prompt
  on('prompt.compose', async ($, e, next) => {
    const r = await next(e)
    if (!(await $.fs.exists(CONTEXT))) return r
    const text = ((await $.fs.read(CONTEXT)) as string).trim()
    if (!text) return r
    return {
      sections: [...r.sections, { id: `${$.plugin.name}:repo-context`, text: `# Repo context\n\n${text}`, scope: 'session' as const }],
    }
  })
}
