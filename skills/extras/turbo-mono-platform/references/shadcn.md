# shadcn/cli v4 — Preset b1tMcUv91

## Init Commands

```bash
# New monorepo project
bunx --bun shadcn@latest init --preset b1tMcUv91 --template next --monorepo

# New single Next.js project
bunx --bun shadcn@latest init --preset b1tMcUv91 --template next

# Switch existing project to preset
bunx --bun shadcn@latest init --preset b1tMcUv91
```

## Add Components — use -c apps/web flag

```bash
cd packages/ui

bunx shadcn@latest add button -c apps/web
bunx shadcn@latest add dialog -c apps/web
bunx --bun shadcn@latest add button --dry-run    # preview only
bunx --bun shadcn@latest add button --diff       # show diff vs current
```

## Agent / Inspect Commands

```bash
bunx --bun shadcn@latest info
bunx --bun shadcn@latest docs <component>
```

## components.json

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "new-york",
  "preset": "b1tMcUv91",
  "rsc": true,
  "tsx": true,
  "tailwind": {
    "config": "",
    "css": "src/styles/globals.css",
    "baseColor": "neutral",
    "cssVariables": true
  },
  "aliases": {
    "components": "@rp/ui/components",
    "utils": "@rp/ui/lib/utils",
    "ui": "@rp/ui/components/ui"
  }
}
```

## TailwindCSS v4 Theme — packages/ui/src/styles/globals.css

```css
@import "tailwindcss";

@theme {
  --font-sans: "Geist", sans-serif;
  --font-mono: "Geist Mono", monospace;
  --radius: 0.5rem;
}

@layer base {
  :root {
    --background: oklch(1 0 0);
    --foreground: oklch(0.145 0 0);
    --primary: oklch(0.205 0 0);
    --primary-foreground: oklch(0.985 0 0);
    --border: oklch(0.922 0 0);
    --ring: oklch(0.708 0 0);
  }
  .dark {
    --background: oklch(0.145 0 0);
    --foreground: oklch(0.985 0 0);
    --primary: oklch(0.985 0 0);
    --primary-foreground: oklch(0.205 0 0);
    --border: oklch(1 0 0 / 10%);
    --ring: oklch(0.556 0 0);
  }
}
```

Import in `apps/web/app/layout.tsx`:
```typescript
import "@rp/ui/styles/globals.css";
```

## cn() utility — packages/ui/src/lib/utils.ts

```typescript
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

## Rules

- `shadcn add` must run from `packages/ui/` — never `apps/web/`
- Always include `--preset b1tMcUv91` on `shadcn init`
- No `tailwind.config.js` — `@theme` directive only
- Import components as `@rp/ui/components/<n>`
