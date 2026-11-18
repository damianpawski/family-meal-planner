# ADR 14: Security headers and CSP sent by the app, not the reverse proxy

Status: **Accepted** 2026-11-18 · written 2026-11-12 · decided 2026-11-09 (M0 plan, decision D2), detailed in [architecture §4](../../spec/architecture.md#4-auth)

## Context

- SEC-05 requires a Content Security Policy, so the browser runs only the app's own scripts ([spec 8.1](../../spec/spec.md#81-input-safety)). Together with Razor's encoding, it's the second lock against a dish name being run as script.
- The architecture first put the CSP in Caddy, which only arrives in M4a. M0 must already test it.
- The app runs in four places: local development, behind the tunnel to the phone, in tests, and in production behind Caddy. Headers that differ between them would be tested in one and broken in another.
- The Blazor template has two inline scripts. The service worker registration can move into a file. The import map can't, because browsers don't load external import maps, and its content includes fingerprinted file names that change with every build.

## Decision

- **One middleware in the app** sends the CSP and the other security headers on every response: API calls, static files, the WebAssembly fallback and error responses.
- **The production policy:** `default-src 'self'; script-src 'self' 'wasm-unsafe-eval' 'sha256-<import map>'; style-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'`. The import map's hash is computed when the server starts, from the `index.html` it actually serves (read through the web root's file provider: the published file in Production, the built one in a development run and in integration tests), so it follows every build by itself. `object-src 'none'` is explicit because `default-src 'self'` would still allow plugin content from this origin, which the app never uses.
- Next to it: `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, a `Permissions-Policy` that turns off the camera, microphone and location, and HSTS outside Development. Adding a dish photo from the camera (REC-40, M10) uses a file input, which hands over to the phone's camera app rather than the camera feature this policy controls; M10 confirms that on the A5's Chrome; if it doesn't hold, a new record amends this policy.
- **No `'unsafe-inline'`,** for scripts or styles. Our components write no `style="…"` attributes; dynamic values go through classes and CSS custom properties. The rule covers third-party components too. If one we need writes inline styles, the first choice is another component or styling it through classes; failing that, its exact styles may be allowed by hash with `'unsafe-hashes'`, in a new record that amends this one. `'unsafe-inline'` is never the answer.
- **Development adds only** the hot-reload websocket to `connect-src`. Tests run with the production policy.
- **Caddy terminates TLS and proxies, and adds no headers of its own.**

## Alternatives considered

| Option | Why not |
|---|---|
| Headers in Caddy | Not testable before M4a, and missing from local development and the tunnel. |
| `'unsafe-inline'` for scripts or styles | It lets injected inline script run, which is what the policy exists to stop. |
| A nonce per response instead of a hash | `index.html` is a static file the service worker serves from its cache, so it can't carry a fresh nonce each time. |

## Consequences

- An integration test checks that every kind of response carries a header **equal** to the production policy, so a stray development source or an added `'unsafe-inline'` fails it. The end-to-end tests fail on any `securitypolicyviolation` event in the browser, which catches an inline style added in a later milestone, from our code or a library. Their smoke test also runs on the oldest supported Chrome, the version the M0 spike finds on the A5, so the import map's hash is proven to be honoured there too ([M0 task 8](../plan/M0.md#8-pwa-and-end-to-end-tests-inst-04)).
- Components that write inline styles can't be used. .NET 11's `Virtualize` no longer does ([What's new in ASP.NET Core for .NET 11](https://learn.microsoft.com/aspnet/core/release-notes/aspnetcore-11)).
- Responses that Kestrel produces itself, before any middleware runs (request headers over its limits, malformed requests), carry none of these headers. They have no body a browser could run, so that's accepted, and a canary test notices if Kestrel's behaviour changes. A body over the size limit does reach the middleware, so its 413 carries the headers (checked by experiment on .NET 10 and .NET 11, recorded in [M0 task 6](../plan/M0.md#6-server-hardening-sec-02-sec-05-sec-09), whose integration tests prove it again).
