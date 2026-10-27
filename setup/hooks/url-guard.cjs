#!/usr/bin/env node
/**
 * url-guard.cjs
 * PreToolUse hook - block private, internal, or token-bearing URLs from
 * reaching third-party fetch/search services (WebFetch, TinyFish, Firecrawl, Exa).
 *
 * Exit codes: 0 allow, 2 block (reason on stderr). Parse errors fail open.
 */

const PRIVATE_HOST = [
  /^localhost$/i,
  /\.(local|internal|lan|corp|home|intranet)$/i,
  /^127\./, /^10\./, /^192\.168\./, /^172\.(1[6-9]|2\d|3[01])\./, /^169\.254\./,
  /^0\.0\.0\.0$/, /^\[?::1\]?$/, /^\[?f[cd][0-9a-f]{2}:/i,
];
const SECRET_PARAM = /[?&](token|access_token|api_key|apikey|key|secret|sig|signature|password|auth|session|X-Amz-Signature)=/i;

function strings(value, out = []) {
  if (typeof value === 'string') out.push(value);
  else if (value && typeof value === 'object') Object.values(value).forEach(v => strings(v, out));
  return out;
}

function reason(raw) {
  let url;
  try { url = new URL(raw); } catch { return null; }
  if (!/^https?:$/.test(url.protocol)) return `non-web scheme ${url.protocol}`;
  if (url.username || url.password) return 'credentials in URL';
  if (PRIVATE_HOST.some(re => re.test(url.hostname))) return `private host ${url.hostname}`;
  if (SECRET_PARAM.test(url.search)) return 'token-bearing query string';
  return null;
}

const chunks = [];
process.stdin.on('data', c => chunks.push(c));
process.stdin.on('end', () => {
  let data;
  try { data = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { process.exit(0); }
  const urls = strings(data.tool_input).flatMap(s => s.match(/\b[a-z][a-z0-9+.-]*:\/\/[^\s"'<>)]+/gi) || []);
  for (const u of urls) {
    const why = reason(u);
    if (why) {
      process.stderr.write(`url-guard: blocked ${data.tool_name} — ${why} (${u}). Never send private or internal URLs to a third party; read it locally instead.\n`);
      process.exit(2);
    }
  }
  process.exit(0);
});
