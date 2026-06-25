# Database Plan

## Phase 1 (current): localStorage
Keys: `tdd.seeds`, `tdd.traces`, `tdd.theme`, `tdd.settings`. SSR-safe adapter in `lib/storage.ts`. No login, no network. This is the MVP and must never be blocked by DB work.

## Phase 2 (optional): Prisma + SQLite/Postgres
Schema sketch lives in the master brief (User / Seed / Opportunity / DailyTrace). When introduced:
- Keep `lib/storage.ts` as the interface; add a server adapter behind the same methods.
- Coarsen context before persisting (see privacy rules) — never store precise GPS/biometrics.
- Migrate localStorage → server on first login; keep offline-first.

## Why not now
Login + DB + sync would block the core emotional loop. Documented here intentionally; revisit only after the web MVP + PWA feel right.
