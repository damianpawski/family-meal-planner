# Architecture decision records

One file per significant decision: its context, the decision, the alternatives that lost and the consequences. The list of decisions comes from [architecture §7](../../spec/architecture.md#7-adrs-to-write). An ADR is written when the milestone that first depends on it starts, so the later ones below don't exist yet.

A record is **Proposed** until the author agrees with it, and can still be edited until then. Once it's **Accepted**, it isn't rewritten: a decision that changes later gets a new record that replaces or amends it, and the old one says so.

| # | Decision | Status |
|---|---|---|
| 1 | [Blazor WebAssembly PWA over a JavaScript framework](0001-blazor-webassembly-pwa.md) | Proposed |
| 2 | [One origin and cookie authentication over JWTs](0002-one-origin-cookie-auth.md) | Proposed |
| 3 | Offline edits limited to shopping in v1 | Written in M2a |
| 4 | IndexedDB over SQLite in WebAssembly | Written in M2a |
| 5 | Change feed with a per-family counter under a row lock | Written in M2a |
| 6 | Family isolation through a global query filter | Written in M1 |
| 7 | [Aspire for local development, Docker Compose in production](0007-aspire-locally-compose-in-production.md) | Proposed |
| 8 | One unit kind per grocery, amounts stored in base units | Written in M2a |
| 9 | The live shopping list built from item sources | Written in M7 |
| 10 | Family id in every key and foreign key | Written in M1 |
| 11 | No step timers in v1 | Written in M9 |
| 12 | [Licence policy and supply chain](0012-licence-and-supply-chain.md) | Proposed |
| 13 | [snake_case database names through EFCore.NamingConventions](0013-snake-case-database-names.md) | Proposed |
| 14 | [Security headers and CSP sent by the app, not the reverse proxy](0014-security-headers-in-the-app.md) | Proposed |
