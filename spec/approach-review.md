# Approach review: stack and engineering practices

Draft 1 · 2026-10-06 · reviewing the author's proposed approach before we write the spec.

Overall: the approach is sound and fits a family-only app that also serves as a portfolio piece. The parts below are either small adjustments or things that aren't on the list yet. The biggest gap is **offline sync**, which nothing in the stack gives you for free.

## 1. Your choices, one by one

| Choice | Verdict | Notes |
|---|---|---|
| .NET 10 Blazor WASM PWA | ✅ Keep | .NET 10 is the current LTS. Turn on trimming and Brotli and skip AOT at first, because first load on the Galaxy A5 is the weak spot. Put components in a Razor Class Library so MAUI Blazor Hybrid stays possible later. Host the WASM files from the same ASP.NET Core app as the API: one container, one origin, no CORS. |
| PostgreSQL | ✅ Keep | Run it in a container, both locally and on the VM. |
| Cheap VM (OVH) | ✅ Keep | Docker Compose plus a Caddy reverse proxy (automatic Let's Encrypt HTTPS). This runs the same way on OVH, Hetzner or a Linux box at home, so there's no lock-in. |
| Vertical Slice Architecture + EF Core | ✅ Keep, on the server | One folder per feature (endpoint, handler, validation, tests). EF Core is **server-side only**. The browser needs its own local store (see section 2). Use EF migrations as a migration bundle applied at deploy, never `EnsureCreated`. |
| OpenTelemetry + Serilog | ⚠️ Adjust | Use OTel for traces and metrics, and Serilog for logs written through the OTLP sink, so everything correlates by trace id. On a cheap VM, send it to **Seq** (free for one user, accepts OTLP) rather than running a full Grafana stack. Locally the Aspire dashboard shows all of it. |
| Full test coverage | ⚠️ Reframe | A 100% line-coverage target produces worthless tests. A better rule is "every requirement in the spec has an automated test", plus a coverage gate around 80% and **mutation testing (Stryker.NET)** on the core logic: sync merge, shopping-list merging, serving scaling. Mutation scores impress interviewers more than coverage does. |
| Manual first deploy, then GitHub Actions | ✅ Keep | Write the manual deploy as a script from day one (`deploy.sh`: build image, push, `docker compose pull && up`, run the migration bundle). The GitHub Action then just calls the same script. |
| Fully runnable locally | ✅ Keep | Aspire covers this (section 3). Also keep the production `compose.yaml` runnable on a local Linux VM, so you can rehearse a deploy without touching OVH. |
| You review and accept every screen | ✅ Keep, and automate the evidence | Every screen PR includes Playwright screenshots at 360 px and desktop width. Accepting a screen means approving its screenshot baseline. After that, visual regression tests fail if the screen changes without your sign-off. |
| Fully automated UAT | ✅ Keep | Playwright for .NET, with scenarios written as Given/When/Then straight from the spec's acceptance criteria (Reqnroll if you want Gherkin files). It must include **offline tests** (Playwright can switch a browser context offline) and **two-user tests** (two browser contexts editing the same week) to prove sync works. |
| Email through your Gmail | ✅ Fine for a family | SMTP with a Google app password (needs 2-step verification) via MailKit. Put it behind an `IEmailSender` interface so a switch to a provider later is one class. Locally and in tests, use **Mailpit** (a fake inbox) so no real email is ever sent. |
| Public code, security a must | ⚠️ Needs a plan | See section 4. |
| Interview-ready | ✅ Keep | See section 5. |
| Swappable CSS | ✅ Keep, design for it now | See section 6. |

## 2. Offline sync: the biggest missing piece

The PWA service worker only caches the app itself. Your data needs:

- **A local store in the browser.** IndexedDB, through a thin JS-interop wrapper. SQLite-in-WASM with EF Core works too, but it adds several MB to a first load that's already heavy on the A5.
- **An outbox.** Every change is written locally first, queued, and sent when online (the amber "waiting" dots in the designs).
- **Pull since a cursor.** The client asks the server "what changed since version N" for the family.
- **Conflict rules.** Most fields: the latest change wins. The same meal slot changed by two people while offline: show the "Someone else changed it too" screen from the designs.
- **Offline sign-in rules.** How long the app keeps working offline before it asks you to sign in again.

This shapes the data model (ids generated on the client, change versions, soft deletes), so it's the first spec chapter.

## 3. Should you use Aspire?

**Yes, for local development, and it doesn't lock you to a provider.**

- Locally, one `dotnet run` on the AppHost starts Postgres, the API with the WASM app, Mailpit and Seq, with the dashboard showing logs and traces. That's your "fully workable locally" requirement, solved.
- For deployment, Aspire's Docker Compose publisher generates a plain `compose.yaml` that you run on the OVH VM. Nothing Azure-specific is involved. If you'd rather, keep a hand-written `compose.yaml` and use Aspire for dev only. Either way, OVH stays swappable.
- Integration tests can start the same AppHost (`Aspire.Hosting.Testing`), so tests run against the real wiring.

## 4. Security for a public repository

- **Closed registration.** A public app on a public URL means strangers can sign up, use your server and send email through your Gmail. Sign-up should be by invite only, or limited to an allow-list of emails. This is the most important item on this page.
- **No secrets in the repo.** Use user-secrets locally, an env file on the VM (not committed), and GitHub encrypted secrets in CI. Turn on GitHub secret scanning with push protection, and add gitleaks to CI.
- **Auth for WASM.** ASP.NET Core Identity for password hashing, lockout and email codes. Use **cookie auth on the same origin** (HttpOnly, Secure, SameSite=Strict, the "BFF" pattern) rather than JWTs in local storage, which any XSS can steal. Add rate limiting on sign-in, code and reset endpoints.
- **Family isolation.** Every row carries a `FamilyId`, enforced with an EF global query filter, plus tests proving that one family can never read another's data.
- **Headers.** HTTPS only, HSTS, and a Content Security Policy. Blazor WASM needs `'wasm-unsafe-eval'` but nothing looser.
- **Supply chain.** Dependabot, CodeQL, and `dotnet list package --vulnerable` in CI.
- **The VM.** SSH keys only, firewall open on 22/80/443 only, unattended security upgrades, fail2ban, and Postgres not exposed to the internet.

## 5. Making it interview-ready

- A README with a one-paragraph pitch, an architecture diagram, "run it in one command", and CI, coverage and mutation-score badges.
- **ADRs** (`docs/adr/`) for each real decision: Blazor vs JS, the sync model, cookie vs JWT, Aspire. Interviewers read these.
- The `spec/` folder showing the spec-driven process, with tests traceable to requirement ids.
- A **demo mode** with seeded data (the Ramirez family from the designs), so someone can try it without an account or an email.
- A clean history: small PRs and conventional commits.

## 6. Swappable CSS

- **Design tokens** (colours, fonts, spacing, radii) as CSS custom properties in a single `theme.css`. The current designs already use a consistent palette, so this extracts cleanly.
- Components use only tokens and semantic class names. No inline styles and no colours hard-coded in `.razor` files. Use scoped `.razor.css` for layout only.
- **Avoid a component library** like MudBlazor. Its look is hard to reskin, and it adds download weight.
- A **component gallery page** (every component in every state, with fake data) gives a designer a place to work on the CSS without running the backend or understanding Blazor.

## 7. What else is missing

1. **Backups.** A nightly `pg_dump` copied off the VM (for example to an S3-compatible bucket, which OVH offers), plus a restore you've actually tested. Years of family recipes are the one thing you can't regenerate.
2. **Dish photos.** Where they're stored (a disk volume or S3-compatible storage), resized on upload so the A5 isn't downloading 5 MB images, and how many are cached for offline use.
3. **App updates.** A "new version available, tap to refresh" prompt from the service worker. The API must also accept requests from a client that's been offline for days on an older version.
4. **Push notifications** (the planning reminder). Web Push needs VAPID keys, and on iPhone it only works once the app is on the home screen.
5. **Domain name and HTTPS.** Caddy handles certificates once a domain points at the VM.
6. **Monitoring.** A free uptime check that emails you when the site is down, and disk-space alerts on the VM.
7. **Accessibility.** Contrast, tap targets and screen-reader labels, checked automatically with axe in the Playwright suite.
8. **Language, units and dates.** Which language(s), metric or cups, and Monday as the start of the week.
9. **A definition of done** per screen: spec requirement, tests, screenshots accepted by you, accessibility check passing.
