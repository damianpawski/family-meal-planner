# Family meal planner

One shared place for a family to keep its recipes, plan the week's breakfasts, lunches and dinners, and get a shopping list from the plan, which works start to finish in a shop with no signal. It's a phone-first progressive web app for one family, built with .NET 11: Blazor WebAssembly in the browser, ASP.NET Core and PostgreSQL on the server.

The project is spec-driven. Requirements have ids (`SYNC-15`, `SEC-02`), the tests that prove them are named after those ids as the code arrives, and significant decisions are recorded as ADRs.

## Status

Planning is done, and the first milestone, M0 (a walking skeleton that installs on a phone), is under way. The solution runs locally: the server hosts the template WebAssembly app and answers `GET /api/ping`, on a migrated but still empty database. The tabs, the phone install and CI follow in the next [M0 tasks](docs/plan/M0.md).

## Documents

| Document | What it says |
|---|---|
| [spec/intent.md](spec/intent.md) | Why the app exists and what success looks like |
| [spec/spec.md](spec/spec.md) | What the app does, as numbered requirements with Given/When/Then scenarios |
| [spec/architecture.md](spec/architecture.md) | How it's built |
| [spec/sync-contract.md](spec/sync-contract.md) | How phones and the server stay in step, offline included |
| [spec/milestones.md](spec/milestones.md) | The order it's built in, M0 to M13 |
| [docs/plan/](docs/plan/) | The plan for the current milestone, task by task |
| [docs/adr/](docs/adr/README.md) | Architecture decision records |
| [docs/conventions.md](docs/conventions.md) | How code, tests, commits and pull requests are written |
| [docs/review/push-review.md](docs/review/push-review.md) | The review every push passes before it's published |
| [CLAUDE.md](CLAUDE.md) | Working rules for the coding agents that build the app |

## Working on it

**Prerequisites**
- The .NET SDK version in [global.json](global.json), exactly (it's pinned, with no roll-forward).
- PowerShell 7.4 or later, [gitleaks](https://github.com/gitleaks/gitleaks), and [Claude Code](https://claude.com/claude-code), signed in. The pre-push review needs all three.
- Docker Desktop, running, for the local Postgres and Mailpit containers and for the integration tests.
- The development HTTPS certificate, trusted: `dotnet dev-certs https --trust`.

**Once per clone**
1. Switch on the pre-push review: `git config core.hooksPath .githooks`.
2. Create `.git/info/personal-strings`, the private list the review checks every push against ([check F3](docs/review/push-review.md#part-1-fixed-checks)). It stays inside `.git`, so it's never committed.

**Running the app**
1. `dotnet run --project src/MealPlanner.AppHost`. The first run also downloads the Aspire CLI that matches the AppHost (through `dnx`, from nuget.org) and the Postgres and Mailpit images, so it takes a few minutes.
2. Open the dashboard link the console prints; it carries a login token. `postgres`, `mailpit` and `server` show as running, and `migrate` as finished: it brings the database up to date, and the server only starts once it has.
3. Open the app from the `server` row's link, <https://localhost:7180>. Mailpit's inbox is linked from its row; nothing sends email yet.

Stop it with Ctrl+C. The database is kept in a Docker volume between runs (`mealplanner.apphost-…-postgres-data`); deleting the volume starts again from an empty database.

**Tests:** `dotnet test` runs the unit and integration tests. The integration tests start their own Postgres container, so Docker Desktop must be running.

**Commits and pull requests** follow [docs/conventions.md](docs/conventions.md): one logical change per commit, a message that says why, `Spec:` and `Task:` trailers, one pull request per plan task, and rebase-and-merge only. Before anything is pushed, the pre-push hook runs fixed checks and a four-pass AI review; CI repeats the fixed checks on every pull request.

## Licence

The code and documents are licensed under the [MIT Licence](LICENSE).
