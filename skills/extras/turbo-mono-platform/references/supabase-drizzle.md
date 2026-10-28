# @rp/supabase — Supabase SDK + Drizzle

## Decision: When to use what

| Need | Use | Why |
|------|-----|-----|
| CRUD queries, joins, aggregations | Drizzle ORM | Type-safe, composable, fast |
| Realtime subscriptions | Supabase SDK | Only SDK supports channels |
| Auth (user management) | Better Auth via `@rp/auth` | More control, not Supabase Auth |
| Storage (file upload) | Supabase Storage SDK | Native integration |
| Edge functions | Supabase SDK | Direct invocation |
| RLS policies | Supabase SDK | Can't do via Drizzle |

---

## Package Setup — `packages/supabase/src/index.ts`

```typescript
import "server-only";
export { db } from "./db";
export { supabase, supabaseAdmin } from "./client";
export * from "./schema";
```

## Drizzle Client — `packages/supabase/src/db.ts`

```typescript
import "server-only";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { env } from "@rp/env";
import * as schema from "./schema";

const client = postgres(env.DATABASE_URL, { prepare: false });
export const db = drizzle(client, { schema });
```

## Supabase SDK Client — `packages/supabase/src/client.ts`

```typescript
import "server-only";
import { createClient } from "@supabase/supabase-js";
import { env } from "@rp/env";

export const supabase = createClient(
  env.NEXT_PUBLIC_SUPABASE_URL,
  env.NEXT_PUBLIC_SUPABASE_ANON_KEY
);

export const supabaseAdmin = createClient(
  env.NEXT_PUBLIC_SUPABASE_URL,
  env.SUPABASE_SERVICE_ROLE_KEY
);
```

## Schema — `packages/supabase/src/schema/users.ts`

```typescript
import { pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  email: text("email").notNull().unique(),
  name: text("name"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
```

## Drizzle Queries (Correct)

```typescript
import { db } from "@rp/supabase";
import { users } from "@rp/supabase";
import { eq } from "drizzle-orm";

// ✅ In Server Component or Server Action
export async function getUserById(id: string) {
  return db.query.users.findFirst({ where: eq(users.id, id) });
}

export async function createUser(data: NewUser) {
  const [user] = await db.insert(users).values(data).returning();
  return user;
}
```

## Realtime Subscription (Supabase SDK)

```typescript
"use client";
import { supabase } from "@rp/supabase/client";   // client-safe export

export function useRealtimePosts() {
  useEffect(() => {
    const channel = supabase
      .channel("posts")
      .on("postgres_changes", { event: "*", schema: "public", table: "posts" },
        (payload) => console.log(payload)
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, []);
}
```

## `packages/supabase/src/client-safe.ts` — Client Component Export

```typescript
// No server-only — safe for "use client" components
import { createClient } from "@supabase/supabase-js";

export const createBrowserClient = () =>
  createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
```

## `drizzle.config.ts` — Root

```typescript
import { defineConfig } from "drizzle-kit";
import { env } from "@rp/env";

export default defineConfig({
  schema: "./packages/supabase/src/schema/index.ts",
  out: "./packages/supabase/drizzle",
  dialect: "postgresql",
  dbCredentials: { url: env.DATABASE_URL },
});
```

## Gotchas

- `drizzle-orm/postgres-js` — not `drizzle-orm/node-postgres`
- Drizzle `0.40.x` only — v1.0 breaks Better Auth adapter
- `server-only` must be the first import in `db.ts` and `client.ts`
- Realtime requires Supabase SDK — cannot use Drizzle
- `supabaseAdmin` for server-side operations needing service role
