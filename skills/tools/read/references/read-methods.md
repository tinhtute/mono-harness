# Read Methods

## Local fetcher

```bash
bash <skill-dir>/scripts/fetch.sh "<url>"                 # local only; URL never leaves the machine
bash <skill-dir>/scripts/fetch.sh "<url>" "<http-proxy>"  # same, through a network proxy
bash <skill-dir>/scripts/fetch.sh --use-proxy "<url>"     # local, then defuddle.md, then r.jina.ai (opt-in)
```

`fetch.sh` rejects pages with ≤5 lines or login/captcha markers and writes one `[fetch] tier=...` line per tier to stderr. Read stderr before choosing the next tier. A network failure → retry once through the user's HTTP proxy (second argument) if one is configured.

## GitHub

```bash
curl -sL "https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>"
gh api "repos/<owner>/<repo>/contents/<path>" --jq .content | base64 -d
git clone --depth 1 "https://github.com/<owner>/<repo>" "<scratchpad>/<repo>"   # whole tree
```

Issues and PRs: `gh issue view` / `gh pr view --comments`. Rendered pages go through the cascade only when public.

## MCP readers

| Provider | Search | Fetch | Notes |
|---|---|---|---|
| TinyFish | `search` | `fetch_content` | `run_web_automation` for click-through or logged-out JS flows |
| Firecrawl | `firecrawl_search` (`categories: ["developer"]` for code) | `firecrawl_scrape` (`formats: ["markdown"]`, `maxAge: 0` for live) | billed per request |
| Exa | `web_search_exa` | `web_fetch_exa` | semantic search; good for "pages like X" |

Use whichever is connected, in table order. Pass a one-sentence `objective` where the tool asks for one; never include private data in it.

## PDF

```bash
d=$(mktemp -d); curl -fL "<pdf-url>" -o "$d/in.pdf" && pdftotext -layout "$d/in.pdf" -
```

No `pdftotext` → `python3 -c "import pypdf"` route, or Firecrawl `parsers: ["pdf"]` for a public URL.

## Credit

`scripts/fetch.sh` and `scripts/fetch_local.py` adapt `skills/read` from [tw93/Waza](https://github.com/tw93/Waza) (MIT); the DeepSeek, Feishu and WeChat paths are dropped.

## Gotchas

| What happened | Rule |
|---|---|
| Got a login, paywall, consent or bot-check page | Stop and say so; do not summarize or save the shell. |
| Every tier failed | List each tier and its reason; suggest a browser or another source. Never fabricate content. |
| Reader returned JSON | Extract the Markdown field; raw JSON is not an answer. |
| Long page | Preview with `head -n 200`; state where output was cut. |
