# ADR 1: Blazor WebAssembly PWA over a JavaScript framework

Status: **Accepted** 2026-11-18 · written 2026-11-12 · decided 2026-10-06, moved to .NET 11 on 2026-11-10 ([spec decision log](../../spec/spec.md#decisions-log))

## Context

- The app is used mostly on phones, including a Galaxy A5 in a shop with no signal. It must open and work offline ([spec chapter 1](../../spec/spec.md#1-offline-and-sync)), install to the home screen (INST-04) and update without losing waiting changes (chapter 7).
- One .NET developer builds and maintains it, and it doubles as a portfolio piece.
- The server is ASP.NET Core with EF Core. The client must enforce the same limits and rules as the server ([spec 0.3b](../../spec/spec.md#03b-limits), [8.1](../../spec/spec.md#81-input-safety)), so they shouldn't be written twice in two languages.

## Decision

- The client is **Blazor WebAssembly, installed as a PWA**.
- It's a **standalone Blazor WebAssembly project served by the ASP.NET Core server**, not a Blazor Web App in WebAssembly mode. A static `index.html` and the PWA template's service worker let the app open from cache with no server involved, which offline-first needs.
- Components live in a **Razor Class Library**, so a MAUI Blazor Hybrid shell could reuse them later.
- **.NET 11 and C# 15**, with the SDK pinned exactly in `global.json` (`11.0.100`, `rollForward: disable`). A floating SDK changes implicit packages such as the ILLink tasks and breaks locked restores ([ADR 12](0012-licence-and-supply-chain.md)). .NET 11.0.0 and SDK 11.0.100 were released on 2026-11-10, with support until 2028-11-14 ([Microsoft's release metadata](https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/11.0/releases.json)); the move to .NET 12 (LTS, November 2027) is a planned upgrade.
- Trimming and Brotli compression are on; ahead-of-time compilation isn't, because it makes the download larger. **What would change that:** if the first load on the A5 misses chapter 8's budget with trimming and compression, ahead-of-time compilation and lazily loaded assemblies are measured next. If no combination meets the budget, the choice is reconsidered before M2a ends, while changing course is still cheap, and a new record replaces this one if it changes.

## Alternatives considered

| Option | Why not |
|---|---|
| React, Angular or Svelte with TypeScript | A smaller first download and more offline libraries, but two languages, every limit and rule written twice, and not the stack this project is meant to show. |
| Blazor Server | Every click needs a live connection, so nothing works in the shop. |
| Blazor Web App (server rendering plus WebAssembly) | Server-rendered pages don't fit an app that must open from its own cache with no server; the static standalone app is simpler for offline. |
| A native MAUI app | Distribution through app stores, and an iPhone build needs a Mac. A PWA installs from the browser on any phone. |

## Consequences

- Request records and limit constants are shared between client and server, so both check the same numbers.
- The first download is several megabytes, which is the weak spot on the A5. Chapter 8 sets the budget from targets, and CI enforces it from M2a. The M0 spike records the A5's exact Chrome version, the oldest browser the app supports.
- The Content Security Policy must allow `'wasm-unsafe-eval'` ([ADR 14](0014-security-headers-in-the-app.md)).
- Code that runs in the service worker can't be .NET. The sender that empties the outbox after the app is closed is a small JavaScript file ([architecture §3](../../spec/architecture.md#3-client-storage-and-sync)), which is why outbox operations are plain JSON.
- The browser's local store is reached through JavaScript interop (ADR 4, written in M2a).
- EF Core can't follow .NET 11 straight away ([ADR 13](0013-snake-case-database-names.md)).
