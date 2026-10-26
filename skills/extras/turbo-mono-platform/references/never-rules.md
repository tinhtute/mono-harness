# Stack Conventions

The stack is fixed; each row names the convention, what it replaces, and why. Breaking one splits the monorepo into two ways of doing the same thing.

| Use | Instead of | Why |
|---|---|---|
| Bun | npm / yarn / pnpm | One lockfile and runtime across the repo |
| Biome | ESLint / Prettier | One fast tool for lint and format |
| Better Auth 1.4 | NextAuth / Clerk | Self-hosted auth that lives in `@rp/auth` |
| Drizzle 0.40.x | Prisma, Drizzle v1.0 | Better Auth's Drizzle adapter does not support the v1 query syntax |
| `@rp/` scope, `@rp/<n>` imports | `@repo/`, `../../packages/...` | Workspace resolution and Turbo graph rely on package names |
| `env.VAR` from `@rp/env` | `process.env.VAR` | Validated, typed env in one place |
| Server-only vars | Secrets in `NEXT_PUBLIC_*` | `NEXT_PUBLIC_*` ships to the browser |
| `bunx shadcn@latest add <n> -c apps/web` | `shadcn add` without `-c` | Components land in the right workspace |
| `import { Button } from '@rp/ui'` | `@rp/ui/components/button` | The package entry is the public API |
| `proxy.ts` | `middleware.ts` | Next.js 16 renamed it |
| `cacheComponents: true` | `experimental.dynamicIO` | Next.js 16 stable flag |
| `revalidateTag(tag, "max")` | `revalidateTag(tag)` | Next.js 16 requires the cache profile |
| `await params` / `cookies()` / `headers()` | Sync access | Async in Next.js 16 |
| DB queries in `@rp/supabase`, routers in `@rp/trpc` | Queries or routers elsewhere | One owner per data path |
| tRPC + TanStack Query on the client | Client `fetch()` | Typed calls with shared caching |
| `server-only` as the first import in supabase/auth/kv | Omitting it | Fails the build if server code reaches the client |
| CSS-first `@theme` | `tailwind.config.js` | Tailwind v4 configuration |
| Transit task pattern for lint | `dependsOn: ["^lint"]` | Avoids rerunning lint for every dependent |
| `flex` + `gap-*` | `space-x-*` / `space-y-*` | Gap handles wrapping and conditional children |
| Semantic tokens | Color overrides in `className` | Keeps theming consistent |
