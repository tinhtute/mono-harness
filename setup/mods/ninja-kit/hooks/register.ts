import type { EngineInterface, Register } from 'claude-code'

// `rm` as a command word: start of line or after ; & | ( or sudo/xargs
const RM = /(^|[;&|(]\s*|\b(sudo|xargs)\s+)rm(\s|$)/m
const PLANS = '.harness/plans/active'
const CONTEXT = '.claude/context.md'
export const COMPACT_RULES = 'Keep these rules verbatim in the summary: AskUserQuestion tool, trash not rm, prove before done, read before edit, minimal change only.'

// 3. Guards: secrets on disk, private URLs to third parties
const SENSITIVE = [
  /\.env$/i, /\.env[.-]/i, /credentials/i, /secrets/i, /\.secret/i, /api[-_]?key/i, /token/i,
  /id_(rsa|dsa|ecdsa|ed25519)/i, /\.(pem|key|crt|cer|p12|pfx)$/i, /\.pgpass/i, /\.my\.cnf/i,
]
const FILE_TOOLS: Record<string, string> = { Read: 'file_path', Edit: 'file_path', Write: 'file_path', Grep: 'path' }
const WEB_TOOL = /^(WebFetch|WebSearch|mcp__plugin_tinyfish_tinyfish__.*|mcp__claude_ai_(Firecrawl|Exa)__.*)$/
const PRIVATE_HOST = [
  /^localhost$/i, /\.(local|internal|lan|corp|home|intranet)$/i,
  /^127\./, /^10\./, /^192\.168\./, /^172\.(1[6-9]|2\d|3[01])\./, /^169\.254\./, /^0\.0\.0\.0$/, /^\[?(::1|f[cd][0-9a-f]{2}:)/i,
]
const SECRET_PARAM = /[?&](token|access_token|api_key|apikey|key|secret|sig|signature|password|auth|session|X-Amz-Signature)=/i

function strings(v: unknown, out: string[] = []): string[] {
  if (typeof v === 'string') out.push(v)
  else if (v && typeof v === 'object') Object.values(v).forEach(x => strings(x, out))
  return out
}

export function privateUrl(raw: string): string | undefined {
  let u: URL
  try { u = new URL(raw) } catch { return undefined }
  if (!/^https?:$/.test(u.protocol)) return `non-web scheme ${u.protocol}`
  if (u.username || u.password) return 'credentials in URL'
  if (PRIVATE_HOST.some(re => re.test(u.hostname))) return `private host ${u.hostname}`
  if (SECRET_PARAM.test(u.search)) return 'token-bearing query string'
  return undefined
}

function guard(e: { tool: string } & Record<string, unknown>): string | undefined {
  const field = FILE_TOOLS[e.tool]
  if (field) {
    const path = String(e[field] ?? '').replace(/\\/g, '/')
    return path && SENSITIVE.some(re => re.test(path))
      ? `sensitive file ${path}. Ask the user for approval, then read it with Bash.`
      : undefined
  }
  if (!WEB_TOOL.test(e.tool)) return undefined
  const { tool, tool_use_id, agentId, ...args } = e
  for (const url of strings(args).flatMap(s => s.match(/\b[a-z][a-z0-9+.-]*:\/\/[^\s"'<>)]+/gi) ?? [])) {
    const why = privateUrl(url)
    if (why) return `${why} (${url}). Never send private or internal URLs to a third party; read it locally.`
  }
  return undefined
}

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
      ? { deny: `${$.plugin.name}: \`rm\` is blocked. Use \`trash <path>\` instead.` }
      : next(e),
  )

  // 3. Guards: secrets on disk, private URLs to third parties
  on('tool.call', ($, e, next) => {
    const why = guard(e as unknown as { tool: string } & Record<string, unknown>)
    return why ? { deny: `${$.plugin.name}: blocked ${e.tool} — ${why}` } : next(e)
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
    next({ ...e, instructions: [e.instructions, COMPACT_RULES].filter(Boolean).join('\n\n') }),
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
