# ADR 2: One origin and cookie authentication over JWTs

Status: **Accepted** 2026-11-18 · written 2026-11-12 · decided 2026-10-06 ([approach review §4](../../spec/approach-review.md#4-security-for-a-public-repository)), detailed in [architecture §1 and §4](../../spec/architecture.md#4-auth)

## Context

- Everyone signs in with an email and a password (ACC-30), and nobody joins without an invite ([spec chapter 2](../../spec/spec.md#2-accounts-invites-and-the-owner)). The app is on the public internet.
- A phone keeps working offline for up to 30 days after its last contact with the server (SYNC-50), so a session must outlive many app restarts.
- After the app is closed, the service worker sends waiting shopping changes in the background (SYNC-13). It can't run .NET, and it can't ask the person anything.
- Emails link back into the app ("confirm your new email"), and that tap must land signed in.

## Decision

- **One origin.** The ASP.NET Core host serves both the WebAssembly app and the API, so there's no CORS and every cookie is first-party. The app is its own back end for the front end; no separate BFF framework is needed.
- **ASP.NET Core Identity with a cookie:** HttpOnly, Secure, `SameSite=Lax`, with a 30-day sliding expiry. No token is ever kept in browser storage.
- **Lax, not Strict,** so a tap on a link in an email isn't shown as signed out. Lax still keeps the cookie off cross-site POSTs and fetches.
- **Antiforgery tokens on every unsafe method** (POST, PUT, PATCH, DELETE), as a second lock against cross-site requests. GET never changes data.
- **One exception: `POST /api/sync/shopping`,** which the service worker calls without being able to get a fresh antiforgery token. It accepts only `application/json` with the header `X-MealPlanner-Sync: 1`. A cross-site form can send neither, and a cross-site script can't add the header without a CORS preflight. A request missing the header, or with any other content type, is refused before it reaches the handler. The app registers no CORS policy at all, so a preflight from another origin is never granted. Integration tests prove each refusal. The endpoint also refuses any operation whose `personId` isn't the signed-in person (SYNC-52).
- **Who you are is checked against the database on every request,** not cached in the cookie: the family (person → family) and owner-only actions (the `OwnerOnly` policy). A removed person loses access on their next request, and a hand-over takes effect at once.

## Alternatives considered

| Option | Why not |
|---|---|
| JWT bearer tokens kept in local storage or IndexedDB | Any script that runs in the page can read them, so one cross-site scripting bug hands out a long-lived token. Refreshing tokens on a phone that's offline for weeks adds its own problems. |
| The API on its own origin (`api.…`) | CORS on every call, a second host and certificate, and cookies that browsers treat as third-party. |
| `SameSite=Strict` | A link opened from an email arrives without the cookie, so the person looks signed out. |
| Antiforgery tokens on the sync endpoint too | The service worker has no page to get a fresh token from, so background sending would fail every time. |

## Consequences

- Everything that reaches the app goes through one host, including the tunnel to the phone in development and Caddy in production. The app trusts forwarded headers only from loopback, so HTTPS redirection and per-address rate limiting see the real client ([architecture §1](../../spec/architecture.md#1-shape-of-the-system)).
- Cross-site requests are stopped by two independent locks, with one documented exception that has its own two locks.
- An expired session on a phone with waiting changes asks the person to sign in, then sends them (SYNC-51). The changes wait in IndexedDB throughout, untouched by signing in, and only the signed-in person's are sent; if someone else signs in on that phone, the first person's are kept for later (SYNC-52). The service worker's sender treats a `401` as finished for now and leaves the changes for the app ([sync contract §8](../../spec/sync-contract.md#8-senders)).
- Each request costs one extra database lookup for the person's family, which is cheap at this scale and buys immediate removal.
