// Pure guard logic for ninja-kit: no host imports, so plain `bun test` can run it.
// register.ts wires these into the engine hooks.

// `rm` as a command word: start of line or after ; & | ( or sudo/xargs
export const RM = /(^|[;&|(]\s*|\b(sudo|xargs)\s+)rm(\s|$)/m

const HEREDOC = /(?<!<)<<(?!<)(-?)\s*(?:'([^'\n]+)'|"([^"\n]+)"|(\\?[A-Za-z_]\w*))/g
const SUBST = /\$\([^)]*\)?|`[^`]*`/g

// Drop heredoc bodies: text fed to a command is not a command. An unquoted
// delimiter still expands $(...) and backticks, so keep those; they run.
export function stripHeredocs(command: string): string {
  const out: string[] = []
  let pending: { tag: string; dash: boolean; expands: boolean }[] = []
  for (const line of command.split('\n')) {
    const open = pending[0]
    if (open) {
      if ((open.dash ? line.replace(/^\t+/, '') : line) === open.tag) pending.shift()
      else if (open.expands) out.push(...(line.match(SUBST) ?? []).map(s => (s.startsWith('`') ? s.slice(1, -1) : s)))
      continue
    }
    out.push(line)
    pending = [...line.matchAll(HEREDOC)].map(m => ({
      tag: m[2] ?? m[3] ?? m[4]!.replace(/^\\/, ''),
      dash: m[1] === '-',
      expands: m[4] !== undefined && !m[4].startsWith('\\'),
    }))
  }
  return out.join('\n')
}

export const rmCommand = (command: string): boolean => RM.test(stripHeredocs(command))

// Fail closed: a guard that throws is skipped by the host and the tool runs.
// The .catch handler refuses in its place unless `next` already ran.
export const failClosed = <E, R>(
  $: { plugin: { name: string } },
  e: E,
  next: ((e: E) => R) & { called: boolean },
): R | { deny: string } => (next.called ? next(e) : { deny: `${$.plugin.name}: guard failed, call blocked.` })
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

export function guard(e: { tool: string } & Record<string, unknown>): string | undefined {
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

// Deny messages: the register hooks wrap these with the plugin name.
export const rmDeny = (plugin: string): string => `${plugin}: \`rm\` is blocked. Use \`trash <path>\` instead.`
export const guardDeny = (plugin: string, tool: string, why: string): string => `${plugin}: blocked ${tool} — ${why}`

// Instructions handed to the summarizer: the user's own, then the hard rules.
export const compactInstructions = (instructions: string | undefined | null): string =>
  [instructions, COMPACT_RULES].filter(Boolean).join('\n\n')
