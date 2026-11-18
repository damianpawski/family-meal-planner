# ADR 13: snake_case database names through EFCore.NamingConventions

Status: **Proposed** · 2026-11-12 · decided 2026-10-14; EF Core version rule added 2026-11-10 ([architecture §2](../../spec/architecture.md#2-data-and-identity))

## Context

- Tables and columns are queried by hand in DBeaver or psql, for example when checking a sync problem in production.
- EF Core's default names are PascalCase. In PostgreSQL that means quoting every identifier (`SELECT "Name" FROM "Dish" WHERE "FamilyId" = …`), because unquoted names are folded to lower case.
- Renaming every table and column after the first migration means a migration that touches all of them.

## Decision

- **Database names are snake_case** (`planned_dish`, `family_id`, `deleted_at`), including indexes, keys and constraints, while C# stays PascalCase. EF Core maps between them with **EFCore.NamingConventions** (Apache-2.0, maintained by the Npgsql maintainer), switched on from the very first migration.
- One method, `UseMealPlannerDatabase(connectionString)` in `MealPlanner.Data`, applies `UseNpgsql`, `UseSnakeCaseNamingConvention()` and the migrations history table name `__ef_migrations_history`, so the app, the `mealplanner` commands and the tests can't configure it differently.
- A test proves the convention itself: a test model's table and columns are found in `information_schema` under their snake_case names.
- **EF Core's own history table may keep PascalCase columns** (`MigrationId`, `ProductVersion`) if the convention doesn't reach them. That's accepted, not a fallback: the table is EF Core's bookkeeping, nobody queries it by hand, and renaming its columns would mean replacing EF Core's history repository. The same test records whichever names the table has, so a change after an upgrade is noticed.
- **EF Core stays on 10.x for now.** The app targets .NET 11, but EFCore.NamingConventions had no 11.x release on 2026-11-10; its 10.0.0 came two months after .NET 10. EF Core 10 runs on .NET 11 and is supported until November 2028. The question is checked again when M1a starts, because sign-in brings the first real tables. That check includes the Identity store package for EF Core: if its 11.x version requires EF Core 11, as each earlier major version required its own, it's pinned to 10.x together with EF Core.
- **Moving to EF Core 11** is accepted only when the full test suite passes, including the integration tests against real Postgres, and a migration generated after the upgrade comes out empty, so a change in provider behaviour or naming shows up before it ships. If the package still hasn't shipped when a feature needs EF Core 11, a small in-house snake_case convention replaces it.

## Alternatives considered

| Option | Why not |
|---|---|
| EF Core's default names | Every hand-written query needs quotes around every name. |
| `ToTable` and `HasColumnName` on every entity and property | Noisy, and one forgotten property breaks the pattern silently. |
| An in-house naming convention from the start | More code to own while a maintained package does the same job. |

## Consequences

- SQL reads naturally, and the C# code doesn't change.
- The project depends on a community package that follows EF Core's releases with a delay, so EF Core can trail .NET by a major version for a while.
- The test that checks the names fails if the convention is ever lost, for example after a package upgrade.
