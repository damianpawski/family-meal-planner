# ADR 12: Licence policy and supply chain

Status: **Proposed** · 2026-11-12 · licence rules from architecture draft 2 (2026-10-13), extended 2026-11-09; supply-chain rules decided 2026-11-10 (M0 plan, decisions D3 and D11)

## Context

- The repository is public, and the WebAssembly app ships its .NET assemblies to every browser. Shipping is distribution, so a copyleft licence on anything in the app would put obligations on the app itself.
- Several popular .NET packages changed licence recently: MediatR and AutoMapper moved to a dual licence (RPL-1.5 or commercial) in July 2025, and ImageSharp uses the Six Labors Split Licence, with a licence key needed at build time in its newer versions.
- A package version can be hijacked and published with malicious code. Such versions are often found and pulled within days of being published, but not always.
- An AI agent writes much of the code and may add packages, so the rules must be checked by tools, not remembered.

## Decision

**Choosing a package**
1. Built-in .NET first. A package is added only when the platform doesn't do the job, and the commit says why.
2. The app (`src/`) may use only packages licensed **MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause or the PostgreSQL License** (Npgsql).
3. Test projects (`tests/`), which never ship, may also use **MPL-2.0** (axe-core, for accessibility tests). Code coverage, if added, uses coverlet (MIT), not Microsoft's coverage extension.
4. CI checks every package with `nuget-license` against two allow-lists, one for `src/` and one for `tests/`. An unknown or missing licence fails the build.
5. **Scope:** the lists cover everything the app and the server bring in themselves: NuGet packages, including those that only carry native binaries, and any JavaScript file the app ships. The operating system and its packages in the server's container image are outside them; they come with the base image.

What this rules out, for the record:

| Package | Why not |
|---|---|
| FluentValidation | Its licence is fine, but .NET 11's built-in validation (`AddValidation()` with DataAnnotations) does the job. |
| ImageSharp | The Six Labors Split Licence isn't on the list. |
| MediatR, AutoMapper | Dual RPL-1.5 or commercial since July 2025. Minimal API handlers and explicit mapping need neither. |

**Still open: photo processing (M10).** The architecture names NetVips, which is MIT and reads HEIC through libvips. But the package that carries libvips's native binaries, `NetVips.Native`, is licensed LGPL-3.0-or-later (checked 2026-11-12), so it fails the `src/` list as written. When M10 starts, a new record decides it, amending this one: an exception for native libraries that run only on the server, are loaded dynamically and never reach a browser, or another library.

**Keeping packages honest**
- **One source:** `nuget.config` clears every other source and maps every package to nuget.org, so a package can't be swapped in from elsewhere.
- **Reproducible restores:** central package management, lock files, and `--locked-mode` in CI, so nothing changes until a version is bumped on purpose. The SDK is pinned exactly in `global.json` for the same reason ([ADR 1](0001-blazor-webassembly-pwa.md)).
- **Bumps come from Dependabot** (`nuget`, `github-actions`, `dotnet-sdk`). Its cooldown reduces exposure to a hijacked version: many are found and pulled within days, before Dependabot would propose them. It doesn't make a three-day-old version safe; the lock files, the review of every bump and NuGet Audit still apply. The cooldown is set explicitly to three days in `.github/dependabot.yml` (M0 task 3), the same as GitHub's default since July 2026 ([GitHub changelog](https://github.blog/changelog/2026-07-14-dependabot-version-updates-introduce-default-package-cooldown/)), so it doesn't depend on a default that could change. Security updates skip the cooldown.
- **Packages added by hand or by an agent:** `nuget.config` sets `minPublishAgeHours` to 48, so `dotnet package add` and `dotnet package update` skip versions younger than two days when they pick a version themselves. It doesn't affect restoring versions that are already pinned.
- **Known vulnerabilities:** NuGet Audit fails the build for high and critical ones; low and moderate ones are warnings, fixed through Dependabot's security PRs.

## Alternatives considered

| Option | Why not |
|---|---|
| Any OSI-approved licence | Copyleft licences (GPL, LGPL, MPL) carry obligations for code shipped to browsers. |
| Checking licences by hand when adding a package | It would be forgotten, especially for packages that come in indirectly. |
| Floating versions without lock files | The same commit could build differently on two days. |
| An age gate on restore only | Restores of pinned versions don't apply `minPublishAgeHours`, so the gate belongs where versions are chosen: Dependabot and `dotnet package add`. |

## Consequences

- Some convenient packages are off the table, and a little more code is written by hand, such as mapping.
- Every version bump is a pull request with lock-file changes, reviewed like any other change.
- A licence that isn't on a list stops CI until the package is replaced or a new record changes the policy, deliberately and visibly.
- New releases reach the app a few days late, apart from security fixes.
