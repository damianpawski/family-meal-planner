# Milestones: family meal planner

Draft 3 · 2026-11-15 (changes from [milestones-review.md](milestones-review.md); draft 2 was 2026-11-10) · owner: the author · built from [spec.md](spec.md) (chapters 0 to 8.1), [architecture.md](architecture.md) draft 3 and [sync-contract.md](sync-contract.md).

Each milestone is a thin, complete slice of the app: it runs locally with one `dotnet run` on the Aspire AppHost, works on the Galaxy A5 through the HTTPS tunnel, and ends with something the family could actually use. Nothing in a milestone depends on a later one.

## How each milestone is accepted

A milestone is done when all four are true:

1. **Automated:** every MUST in its scope has a passing test that names its id, every Gherkin scenario listed has a passing Playwright test (360 px and desktop), every worked example marked with this milestone ([spec 1.3](spec.md#13-offline-shopping-changes), [sync contract](sync-contract.md#worked-examples-each-becomes-a-test)) has a passing test named after it, and CI is green, including axe and, from M1a on (when the first endpoints that take input and the owner-only policy exist), the abuse suite ([SEC-10](spec.md#81-input-safety)) and the owner-only reflection test.
2. **Screens:** the author has accepted each new screen on the phone against its design (or against the missing-design note, where there is no design yet), including a two-minute pass with TalkBack, Android's screen reader: every control can be reached and is read out with its name and state ("Milk, 2 l, not ticked, button"). Accepted screens become visual baselines.
3. **By hand:** the author works through the milestone's **Try it** list, on the laptop and on the phone, and every step behaves as written.
4. **Seed data:** `mealplanner seed-demo` is extended so the milestone can be tried on a realistic family (people Maria, Diego, Leo, Ava; dishes; a planned week) in seconds, and reset just as fast. From M5a on it can also make a family at the limits (2,000 dishes, 3,000 groceries, a 299-line shopping list), for the speed budget and the limit tests.

**Working with an AI agent.** A milestone is too big for one agent run (M2a alone is a few weeks of work). At the start of each milestone the agent first writes `docs/plan/Mx.md`: an ordered list of PR-sized tasks, each naming its spec ids and tests. The author approves the list, then the agent works through it one PR at a time. The milestone is accepted as a whole, by the four checks above, once its last task is merged.

**Sizes** are relative: S, M and L. The one fixed point is that an L is a few weeks of the author's time (M2a). When M0 is accepted, the time it really took is written next to its M, and the other sizes are corrected from it.

**Designs.** A milestone that names a missing design gets it when its plan is written, not during the work. If the design still isn't there, the screen is built without one and accepted on the phone, and the plan says so, so a missing design can't stall a PR.

**The real phone, every time.** Cold load, repeat load and download size are measured on the Galaxy A5 itself in M0 and again at every L milestone, and written into that milestone's acceptance notes. The throttled profile CI uses is set from those measurements (M2a), so M13 confirms the speed instead of discovering it.

**Testing as several people on your own.** Locally every email lands in Mailpit, so any address works: invite `maria@example.com`, open the link from Mailpit, and use a second browser profile (or a private window) as Maria. On the phone, Chrome plus Chrome's incognito tab gives two people at once. Offline is airplane mode on the phone, or DevTools › Network › Offline on the laptop.

**Phone access.** Service workers and installing need HTTPS, so the phone reaches the laptop through a tunnel. An installed PWA is tied to its origin, so the tunnel must keep the same URL every time; a temporary URL gives a new app with empty storage and a dead home-screen icon. Candidates: a persistent, named Microsoft Dev Tunnel with anonymous access (free, wired into Aspire, but its anti-phishing warning page may show inside the installed app), or a named Cloudflare Tunnel on a subdomain of the app's own domain (needs the domain on Cloudflare; the domain is needed in M4a anyway). The M0 spike picks one. Set up in M0.

## Overview

| # | Milestone | What the family can do at the end | Size |
|---|---|---|---|
| M0 | Walking skeleton | Open an empty app on the phone and install it | M |
| M1a | Join and sign in | The Rivera family exists and its people can join and sign in | M |
| M1b | Passwords, profile and managing the family | Everyone looks after their own account; the owner decides who stays | M |
| M4a | The server | Nothing new to see, but the app runs on the real server with backups | M |
| M2a | Shared shopping list | Share one typed-in shopping list that updates live | L |
| M2b | Groceries and list tools | Rename and merge groceries, edit amounts, clear and share the list | M |
| M3a | Shopping with no signal | Tick off the list in a basement with no signal | L |
| M3b | Updates and install | Get new versions without losing a tick; put the app on the home screen | S |
| M4b | Live for the family | Use the shopping list for real | S |
| M5a | Dishes and recipes | Keep every dish with ingredients, steps and scaling | M |
| M5b | Recipes tab | Browse, search and filter the recipe box | M |
| M6 | Planning the week | Plan 21 slots, see what's for dinner | L |
| M7 | From plan to shopping list | Get the week's list in one tap, kept live | L |
| M8 | Starting from last week | Plan a week in minutes from last week or a template | M |
| M9 | Cook mode and rating | Cook hands-free and say how it went | M |
| M10 | Photos | Put a photo on a dish | S |
| M11 | Notifications | Get the planning reminder and other nudges | M |
| M12 | Account and family housekeeping | Change email, hand over, delete account or family | M |
| M13 | v1 sign-off | Performance, accessibility and full regression on every screen | M |

**Why this order.** The riskiest part of the app is the offline shopping list in the shop basement, and it's also the part the family uses most. Building the shopping list with typed-in items first (M2a, M2b, M3a) proves the change feed, the local store and the outbox on the simplest data, and gives the family something useful as soon as it goes live (M4b). Recipes and planning then feed into a list that already works offline.

The server comes early and go-live comes later. M4a puts the app on the real server straight after sign-in exists, with only the author using it, so deployment, backups and the proxy are proven while little depends on them. M4b, where the family starts using it, needs M3a (shopping offline) and M3b (updates that keep waiting ticks).

Photos (M10) can swap places with anything after M5a. Notifications (M11) can swap places with anything after M6: they need M2a (list changes) and M6 (planning), and nothing from cooking or rating.

---

## M0. Walking skeleton

**Goal:** the whole pipeline works end to end before any feature: repo, local run, phone, CI, logs.

**Scope**
- Public GitHub repo (the author, 2026-11-10), where every push first passes a pre-push review ([the M0 plan](../docs/plan/M0.md), D12), with the folder layout from [architecture 1](architecture.md#1-shape-of-the-system) (server with vertical slices, WASM client, Razor Class Library for components, tests), the M0 ADRs from [architecture 7](architecture.md#7-adrs-to-write) in `docs/adr/` (the rest are written when their milestone starts). The repo is created in the folder that already holds `spec/`, so `spec/` is committed where it is.
- Aspire AppHost starting Postgres, the ASP.NET Core host (serving the WASM app and an API), Mailpit and the dashboard. EF migrations applied by a separate `mealplanner migrate` step before the server starts (how production migrates is decided in M4a), with snake_case table and column names from the first migration (EFCore.NamingConventions, Apache 2.0), so SQL in DBeaver needs no double quotes.
- The app shell: four tabs (Week, Recipes, Shopping, Family), each an empty page; Family › About shows the version and date ([UPD-06](spec.md#74-app-updates)).
- PWA manifest, icon, splash screen and a service worker that caches the app, so it installs and opens full screen ([INST-04](spec.md#73-home-screen-install)).
- Theme as CSS custom properties in one file, so a designer can swap it.
- `TimeProvider` everywhere with the banned-API analyzer (`DateTime.Now`); OpenTelemetry logs, traces and metrics (`ILogger`, no Serilog) to the Aspire dashboard.
- CI on GitHub Actions: build, unit, integration (Testcontainers), Playwright end-to-end tests at 360 px and desktop, axe, gitleaks, a licence check (ADR 12: MIT, Apache, BSD or the PostgreSQL License for the app; test-only packages may also be MPL-2.0). gitleaks runs in the pre-push review and in CI; on a public repo GitHub's own secret scanning and push protection are on as well.
- Security headers and CSP ([SEC-05](spec.md#81-input-safety)), ProblemDetails with an error ref ([SEC-09](spec.md#81-input-safety)), request size limits ([SEC-02](spec.md#81-input-safety)).
- A tunnel to the phone, pointed only at a published, Production-mode build (the development service worker caches nothing, and a Development server would show error details to anyone with the URL), with forwarded headers trusted only from the proxies named in a setting (loopback by default; M4a adds the Compose network).
- **The spike measures the phone:** cold load, repeat load and download size of a published app on the A5, the first numbers for [chapter 8](spec.md#8-non-functional)'s targets, and whether its Chrome has the screen wake lock (M9) and the share sheet (M2b).
- **The server's Docker image is built in CI,** though nothing runs it until M4a, so the build without git ([the M0 plan](../docs/plan/M0.md), D4) is tested from the start.

**Requirements:** [INST-04](spec.md#73-home-screen-install), [UPD-06](spec.md#74-app-updates), [SEC-02](spec.md#81-input-safety), [SEC-05](spec.md#81-input-safety), [SEC-09](spec.md#81-input-safety).

**Try it**
1. Clone the repo into a new folder and, following only the README, run the AppHost and see the dashboard with Postgres, the app and Mailpit all green. (The build from nothing is proven by CI, which starts each run on a fresh machine.)
2. Open the app on the laptop and tap through the four tabs.
3. Open the tunnel URL on the Galaxy A5, add it to the home screen, and open it from the icon: full screen, own icon and splash.
4. Family › About shows the version and date.
5. Find the request you just made as a trace in the Aspire dashboard.
6. Push a commit with a fake secret on a branch and see gitleaks fail the CI run.

**Screens to accept:** tab bar and empty tabs (from "More Screens"), splash.

---

## M1a. Join and sign in

**Goal:** a family exists, its people join only by email invite and sign in, and nothing one family owns can be reached from another.

**Scope**
- **First:** the terms text a person agrees to on joining ([ACC-22](spec.md#24-joining-a-family)) and the accessibility rules beyond "axe passes" (tap sizes, contrast, what TalkBack reads) are written into [chapter 8](spec.md#8-non-functional), because these are the first real screens.
- `mealplanner create-family` and `seed-demo` CLI ([ACC-10](spec.md#23-creating-a-family), [ACC-11](spec.md#23-creating-a-family)), family time zone set at creation ([DOM-24](spec.md#03-rules-that-are-always-true)). `seed-demo` refuses to run in Production: it creates accounts with known passwords and ships in the same image as the server.
- Invite by email, accept the invite with name and password (with the password rules), sign in, sign out. The "You're not in a family yet" screen.
- Manage family, first part: everyone and open invites; the owner can invite, resend and cancel.
- **Links in emails use a public base URL setting** (the tunnel's URL locally), so an invite opened on the phone doesn't point at localhost.
- These screens read from the server, because the phone's local copy of the data arrives in M2a. Account actions (sign in, invites, passwords, profile changes) need a connection anyway and say "You're offline. This needs a connection" offline. The Family tab's people list moves to the local copy in M2a, so build it to make that switch small.
- **The write path, built once:** from the first handler here, every write starts by locking the family row, bumps the family's change counter, stamps the rows it writes and records deletions as tombstones ([architecture 2](architecture.md#2-data-and-identity), [sync contract §1](sync-contract.md#1-change-counter)). The pull endpoint and the phone's local copy still arrive in M2a; building the write path now means these handlers aren't rewritten then. ADR 5 is written here.
- **The session is checked on every request:** the security stamp and the family are read in the same database lookup, so a password reset or a removal takes effect on the next request, not when Identity next re-checks the stamp (every 30 minutes by default).
- Family isolation in both layers (query filter plus `(FamilyId, Id)` keys), owner-only policy with the reflection test, and the abuse suite against every endpoint so far. **The abuse suite finds endpoints by itself,** as the owner-only test does: an endpoint with no abuse cases fails the suite, so a later milestone's endpoints can't be forgotten. Isolation tests cover every write path, not only API handlers: the `mealplanner` commands, background jobs and any bulk or raw-SQL statement (such as the grocery upsert) must also be unable to read, write or link another family's rows.
- **Deleting a whole family, the core:** `seed-demo`'s reset needs it, so it's built and tested here (nothing of the family is left in any table). The screen and the owner's confirmation are M12.

**Requirements:** [DOM-01](spec.md#03-rules-that-are-always-true), [DOM-02](spec.md#03-rules-that-are-always-true), [DOM-10](spec.md#03-rules-that-are-always-true), [DOM-24](spec.md#03-rules-that-are-always-true) (set at creation), [ACC-01](spec.md#22-who-can-do-what), [ACC-02](spec.md#22-who-can-do-what) (invite, cancel), [ACC-04](spec.md#22-who-can-do-what), [ACC-10](spec.md#23-creating-a-family), [ACC-11](spec.md#23-creating-a-family), [ACC-20](spec.md#24-joining-a-family) to [ACC-22](spec.md#24-joining-a-family), [ACC-30](spec.md#25-signing-in-codes-and-passwords), [ACC-32](spec.md#25-signing-in-codes-and-passwords), [ACC-35](spec.md#25-signing-in-codes-and-passwords), [ACC-50](spec.md#27-managing-the-family-owner) (the list and invites), [ACC-54](spec.md#27-managing-the-family-owner), [LIM-08](spec.md#03b-limits), [LIM-11](spec.md#03b-limits), [LIM-12](spec.md#03b-limits), [LIM-17](spec.md#03b-limits) (email), [SEC-01](spec.md#81-input-safety), [SEC-03](spec.md#81-input-safety), [SEC-04](spec.md#81-input-safety), [SEC-06](spec.md#81-input-safety), [SEC-07](spec.md#81-input-safety), [SEC-10](spec.md#81-input-safety).

**Scenarios:** Joining by email invite · Only the owner can invite.

**Try it**
1. Run `mealplanner create-family --name Rivera --owner carlos@example.com --time-zone Europe/Warsaw`, open the invite from Mailpit on the phone (its link points at the tunnel), set a password, and land on the Week tab.
2. Invite Maria and Diego. Accept Maria's in a second browser profile; leave Diego's open and see "Invite sent" with Resend and Cancel.
3. As Maria, open Manage family: no Invite button.
4. Sign out and sign in again.
5. Create a second family with `seed-demo` and confirm nothing of it is visible from the Rivera accounts. Reset the seed and confirm the second family is gone.

**Screens to accept:** sign in, accept invite, Manage family (the list and invites), not-in-a-family. **Designs missing** (due when this milestone's plan is written): the email-only rework of "Auth Screens" (no PIN, no "Who's here?", no family code) and the accept-invite screen ([UI review section 3](../reviews/ui-review-2026-10-05.md#3-missing-screens-third-pass-after-family-settings-2026-10-05), items 1 and 2).

---

## M1b. Passwords, profile and managing the family

**Goal:** the account jobs around signing in work safely, and the owner is the only one who decides who stays in the family.

**Scope**
- Forgot password with an emailed code, change password, lockout, and rate limits on the sign-in and code endpoints. The limits key on the client's address from the forwarded headers, so they're tried through the tunnel as well as on the laptop.
- **[ACC-31](spec.md#25-signing-in-codes-and-passwords)'s "in about the same time" gets a test:** an email with no account runs the same password hashing as one that has an account.
- Edit profile: name, sticker colour, "Food I don't eat".
- Manage family, second part: the owner removes a person, who gets the "you were removed from the family" email ([spec 2.8](spec.md#28-emails-the-app-sends)). Leave the family (not the owner).
- [ACC-23](spec.md#24-joining-a-family): someone with an account and no family accepts an invite by signing in; someone in another family is told to leave it first.
- **Emails show names as plain text** ([SEC-05](spec.md#81-input-safety)): a test sends an invite from a person whose name contains HTML.
- Every new endpoint joins the isolation tests, the owner-only test and the abuse suite.

**Requirements:** [ACC-02](spec.md#22-who-can-do-what) (remove), [ACC-03](spec.md#22-who-can-do-what), [ACC-23](spec.md#24-joining-a-family), [ACC-31](spec.md#25-signing-in-codes-and-passwords), [ACC-33](spec.md#25-signing-in-codes-and-passwords), [ACC-34](spec.md#25-signing-in-codes-and-passwords), [ACC-40](spec.md#26-your-own-account), [ACC-42](spec.md#26-your-own-account), [ACC-51](spec.md#27-managing-the-family-owner), [ACC-53](spec.md#27-managing-the-family-owner) (non-owners), [LIM-17](spec.md#03b-limits) (food), [SEC-05](spec.md#81-input-safety) (emails).

**Scenarios:** Removed person loses access · Forgot password signs out other devices.

**Try it**
1. As Maria, try a wrong password 5 times and see the lockout message, which doesn't say whether the email exists. Do the same with an email that has no account: the same messages, after the same number of tries ([ACC-31](spec.md#25-signing-in-codes-and-passwords)).
2. Reset Maria's password from the phone while she's signed in on the laptop; the laptop asks her to sign in again on her next tap.
3. Change Maria's name, sticker colour and "Food I don't eat".
4. Remove Maria. Her next tap shows "You're not in a family yet", and Mailpit has the email telling her so.
5. Invite Maria again: she joins by signing in, without making a new account. Invite an address that belongs to the `seed-demo` family: that person is told to leave their family first.
6. As Diego, leave the family.

**Screens to accept:** forgot password and code, Edit profile, Change password, removing a person, Leave the family.

---

## M4a. The server

**Goal:** the app as built so far runs on the real server, deployed by a script, with backups that are proven to restore, long before the family depends on it. Only the author uses it until [M4b](#m4b-live-for-the-family).

**Why here.** Sign-in protects the site from M1a on, and little depends on the server yet. Problems with forwarded headers, cookies behind Caddy, the build without git, migrations and email are found while they're cheap to fix, not on the day the family is waiting.

**Scope**
- **First:** the requirement ids for deploys, backups and observability are written into [chapter 8](spec.md#8-non-functional), so this milestone's tests have ids to name.
- A domain and a cheap VM; Docker Compose with Caddy (Let's Encrypt; TLS and proxy only, since the app already sends the CSP and security headers from M0), the app, Postgres and Seq; a production check that the headers arrive unchanged through Caddy.
- **Trusted proxies:** in Compose, Caddy reaches the app from a container network address, not from loopback. The trusted-proxies setting from M0 names that network, and a check proves the app sees the phone's own address, so rate limiting doesn't treat the whole family as one visitor.
- `deploy.sh` with the migration step (an EF migration bundle or `mealplanner migrate`, decided here). It takes a `pg_dump` before migrating, and the README says how to go back: the previous image plus that dump. The first-deployment setup script creates the family once ([ACC-12](spec.md#23-creating-a-family)), with the author as its owner.
- **Server hardening:** SSH by key only; a firewall open on 22, 80 and 443 only; automatic security updates; Postgres and Seq reachable only inside the Compose network (Seq's own page has no sign-in under the free licence).
- **Knowing when it's down:** a free outside uptime check that emails the admin, and a disk-space warning. A full disk is the likeliest first failure of a small VM with nightly dumps.
- Gmail SMTP through MailKit with an app password.
- restic nightly encrypted backups (30 daily, 12 monthly), and **one restore rehearsed by hand**: last night's backup restored into a throwaway Postgres, with the data checked. A backup nobody has restored doesn't count.
- **The VM can only add to the backups:** an append-only repository (restic's REST server in append-only mode, or a storage key without delete rights), with `forget --prune` run from the admin's machine, so someone who takes over the VM can't delete them ([architecture 5](architecture.md#5-other-infrastructure)).
- **Decided here, because it may put a native library into the image:** how libvips's LGPL binaries fit the licence policy, or what replaces them ([ADR 12](../docs/adr/0012-licence-and-supply-chain.md)). The photo work itself stays in M10.
- Rehearse the whole deploy on a local Linux VM first.
- **From here on, every accepted milestone is deployed** with the same script, from its acceptance tag.

**Requirements:** [ACC-12](spec.md#23-creating-a-family), plus [architecture 5](architecture.md#5-other-infrastructure) (deploy, backups, observability) under the chapter 8 ids written first.

**Try it**
1. Rehearse: run `deploy.sh` against a local VM, then against the real one.
2. Open the domain on the phone: valid certificate, the owner invite arrives in your real Gmail inbox, and running the deploy again says "Family already set up".
3. Scan the server's ports from outside: only 22, 80 and 443 answer.
4. Sign in from the phone on mobile data and find the request in Seq: it shows the phone's address, not Caddy's.
5. Find last night's backup in restic, restore it into a throwaway Postgres by hand, and check that the family and its people are there.
6. Make a request fail and find its error ref in Seq.
7. Put the restic password in your password manager.

**Screens to accept:** none new; re-check every accepted screen on the live site, and install the app from the real domain on the A5.

---

## M2a. Shared shopping list

**Goal:** the family shares one shopping list of typed-in items, sees each other's changes within 30 seconds, and can read it offline. This milestone lays the sync foundation every later screen uses: the change feed, the local store, pull-to-refresh and the sync status. It deliberately keeps the list itself simple; managing groceries and the list's extra tools follow in M2b (split from one M2 on 2026-11-10, because together they were about a month of work).

**Scope**
- **First, before any sync code:** finish [sync-contract.md](sync-contract.md) (requests and results, cursor, paging, retries, idempotency, tombstones) and check it against [spec 1.9](spec.md#19-open-questions), whose questions are all answered. Its worked examples marked M2a (C5, C7) are proven here.
- **Then the feed is proven on the people list,** the simplest data there is, before any shopping table exists: the Family tab opens offline from the local copy, with the pull, staging, the cursor and tombstones (a removed person), and the contract's examples C5 and C7.
- **Performance budgets:** write the chapter 8 numbers (first load, repeat load and download size on the Galaxy A5 profile) as **targets**, not as measurements of the M0 build, which is an empty shell that every real screen would exceed. The throttled profile is set from the real A5's measurements. CI enforces the targets from this milestone on, so every later screen is checked against them: it fails on download size exactly, and on load time only beyond a generous margin, because times on shared runners vary and a check that cries wolf gets switched off.
- **The Blazor decision is made here** ([ADR 1](../docs/adr/0001-blazor-webassembly-pwa.md)): the real A5's numbers against the targets, and a written decision to keep the choice or change it.
- Change feed under the family row lock, paged pull, tombstones; IndexedDB local store; refresh on open, reconnect, every 20 s and pull-to-refresh; sync status header (Synced, Offline · showing {time}).
- Groceries, the basics: one per name, created by upsert, unit kind set by first use, a new grocery goes in "Other".
- Shopping lists by week (dates from the family's week start day, Monday until M2b makes it changeable), ‹ and ›, "Nothing to buy yet". Its **Plan this week** button opens the Week tab, which stays empty until M6.
- Add item (name with suggestions, amount, unit dropdown), extras merging by amount, lines grouped By aisle, ticking with the 2-second pause, Done group, Hide done, progress, the tab badge, other people's changes appearing in place.
- **The outbox, online:** ticks and extras always go through the outbox ([sync contract §5](sync-contract.md#5-ticks-and-extras)). Here it's sent at once, with the per-operation results and the clock correction; M3a makes it work offline.
- **The phone is wiped from the day it holds a copy:** on sign-out, when a different person signs in, and when a person is removed. Otherwise trying the app as several people on one phone would show one family's data to another. What involves waiting changes (the warning, keeping another person's outbox) stays in M3a.
- **A way to change the local store's shape,** from its first version: when the stored format changes, the phone drops its copy and downloads it again, keeping the outbox ([UPD-03](spec.md#74-app-updates) allows exactly this). M2b, M5a, M6 and M9 each add to the store.
- Offline, every edit control says it needs a connection (offline ticking arrives in M3a).

**Requirements:** [SYNC-01](spec.md#12-what-works-offline), [SYNC-03](spec.md#12-what-works-offline), [SYNC-04](spec.md#12-what-works-offline) (lists), [SYNC-21](spec.md#14-online-changes), [SYNC-22](spec.md#14-online-changes), [SYNC-30](spec.md#15-seeing-the-familys-changes) to [SYNC-33](spec.md#15-seeing-the-familys-changes) (SYNC-33: the pull side; old cursors in M3a), [SYNC-40](spec.md#16-sync-status) (Synced and Offline states), [SYNC-53](spec.md#17-signing-in-and-out-and-leaving) (the plain wipe), [SYNC-54](spec.md#17-signing-in-and-out-and-leaving), [DOM-08](spec.md#03-rules-that-are-always-true), [DOM-12](spec.md#03-rules-that-are-always-true), [DOM-13](spec.md#03-rules-that-are-always-true), [DOM-15](spec.md#03-rules-that-are-always-true), [DOM-23](spec.md#03-rules-that-are-always-true), [SHOP-01](spec.md#52-the-shopping-tab) to [SHOP-04](spec.md#52-the-shopping-tab), [SHOP-05](spec.md#52-the-shopping-tab) and [SHOP-06](spec.md#52-the-shopping-tab) (By aisle), [SHOP-07](spec.md#52-the-shopping-tab) (extras), [SHOP-09](spec.md#52-the-shopping-tab) to [SHOP-11](spec.md#53-ticking), [SHOP-15](spec.md#53-ticking) to [SHOP-18](spec.md#54-extra-items-and-editing-a-line) (SHOP-18 online; offline in M3a), [LIM-09](spec.md#03b-limits), [LIM-14](spec.md#03b-limits).

**Scenarios:** Two people create the same grocery at once · An extra with an amount joins the recipe line (with an extra in place of the recipe) · Extras in g and kg make one line · An extra without an amount stays separate · Adding an extra with an amount · Pull to refresh · Pull to refresh while offline · No change is missed when two people save at once · Opening on next week's list.

**Try it**
1. On the laptop as Carlos, add "Milk 2 l", "Bread", "Minced beef 500 g". On the phone as Maria, see them appear within 30 seconds without touching anything.
2. As Maria add "Minced beef 1 kg": one line "1.5 kg Minced beef" with both names. Add "minced beef" with no amount: its own line.
3. Type "Milk" and open the unit list: only ml, l, tsp, tbsp.
4. Tick three lines; each waits 2 seconds, then moves to Done. Put one back.
5. Airplane mode: the list still shows, the header says "Offline · showing {time}", and Add item says "You're offline. This needs a connection."
6. Sign out on the phone and sign in as someone from a `seed-demo` family: nothing of the Riveras is on the phone.
7. Measure cold load, repeat load and download size on the A5, compare them with the targets, and write down the decision on Blazor.

**Screens to accept:** Shopping tab (By aisle, Done, empty), Add item, sync status header. Design nit to fix: the Shopping tab's stray back arrow ([UI review section 4](../reviews/ui-review-2026-10-05.md#4-ui-notes-on-existing-screens)).

---

## M2b. Groceries and list tools

**Goal:** the family can tidy the list and its groceries: fix names and aisles, change amounts, clear and share the list, and set the week the lists follow.

**Scope**
- Item editor: rename (everywhere, with the merge offer), aisle, amount to buy as an adjustment, delete extra; online edits refused on a stale counter ([SYNC-20](spec.md#14-online-changes)) with who changed it.
- Groceries: rename and merge (DOM-14, DOM-25), change unit kind while unused (DOM-27).
- ✓ All in the cart, Clear list with Undo, Share, the 300-line limit.
- Family settings: family name and time zone for everyone; week start day for the owner only, with the list dates that follow (DOM-17).
- The sync contract's worked examples marked M2b (C6, C13).
- **First, how Undo works:** Clear list removes every line "for everyone" and offers Undo for 8 seconds, but the sync contract only covers the removal (C6). The way back is decided and added to the contract as example C18 before this task starts ([open points](#open-points-for-the-author)). M8's Clear this week uses the same answer.
- **Idempotency keys arrive here,** with the first online edit (the item editor), not in M6: a lost response to an item-editor save is retried with the same key and applied once. C3, the same case for a slot save, stays in M6.
- [DOM-17](spec.md#03-rules-that-are-always-true)'s short first list after a change of week start day is tested as a table: each start day to each other day, a change made on a list's last day, and a family whose "today" differs from the phone's.

**Requirements:** [SYNC-20](spec.md#14-online-changes), [DOM-14](spec.md#03-rules-that-are-always-true), [DOM-17](spec.md#03-rules-that-are-always-true), [DOM-18](spec.md#03-rules-that-are-always-true), [DOM-24](spec.md#03-rules-that-are-always-true) (changing it), [DOM-25](spec.md#03-rules-that-are-always-true) (list side), [DOM-27](spec.md#03-rules-that-are-always-true), [ACC-02](spec.md#22-who-can-do-what) (week start day), [SHOP-13](spec.md#53-ticking), [SHOP-19](spec.md#54-extra-items-and-editing-a-line) to [SHOP-22](spec.md#54-extra-items-and-editing-a-line), [SHOP-40](spec.md#56-clear-and-share), [SHOP-41](spec.md#56-clear-and-share), [LIM-10](spec.md#03b-limits).

**Scenarios:** Clear list with undo · Share · Only the owner changes the week start day.

**Try it**
1. Rename "Minced beef" to "Beef mince", then rename another grocery onto an existing name and accept the merge.
2. Move Butter to "Dairy & eggs": it moves in every list.
3. Change the amount to buy on a line to 200 g more: it shows "+200 g from Maria". Have Carlos change the same line at the same moment: the second save says "Maria changed this a moment ago". Change another line to 200 g less: "−200 g from Maria". Bring one down to nothing: it shows as done with "not needed".
4. Clear the list, then Undo. Share it into WhatsApp.
5. As Maria, try to change the week start day: read-only. As Carlos, change it to Tuesday and see the next list's dates follow [DOM-17](spec.md#03-rules-that-are-always-true).
6. Airplane mode: the item editor says "You're offline. This needs a connection."

**Screens to accept:** item editor, Clear confirm, Family settings.

---

## M3a. Shopping with no signal

**Goal:** in the shop with no signal, ticking and adding extras just work, survive the app closing, and reach the family when the signal comes back.

**Scope**
- The outbox from M2a, made to work offline: operations (tick, untick, addExtra, removeExtra with `amountSeen` and `madeAt`) kept as plain JSON through closing the app and restarting the phone, sent by the app under one Web Lock; idempotent `opId`s; latest `madeAt` wins; waiting dots; "N waiting" and "Couldn't sync N changes · Retry now"; automatic retries. Proven with the worked examples marked M3a: X1, X2, X5, X6 and X8 to X15 ([spec 1.3](spec.md#13-offline-shopping-changes)), and C1, C2, C8, C11, C12 and C14 to C16 ([sync contract](sync-contract.md)). X3, X4 and X7 need dishes on the list and are proven in M7.
- Sessions: 30 days offline, signing in again when expired, a different person on the same phone (the first person's waiting changes are kept), the sign-out warning that offers to send waiting changes first. The plain wipe on sign-out and removal is already there from M2a. **The 30 days are counted on the phone too,** from a stored time of last contact read through `TimeProvider`: the cookie is HttpOnly, so the app can't read its expiry while offline.
- **The background-job host arrives here, with its first jobs:** the tombstone purge after 90 days (C16 needs it), and the clean-up of processed `opId`s (60 days), idempotency keys (24 hours) and used or expired invites and codes. Each takes the family lock like any other write where it changes family data ([architecture 5](architecture.md#5-other-infrastructure)).
- **Mutation testing starts here** (Stryker.NET, [architecture 6](architecture.md#6-testing-map)), on tick resolution and the outbox rules.
- **Once foreground sync is proven:** the service-worker sender with Background Sync (Android), as an extra delivery path. It sends the same operations under the same Web Lock; operations leave the outbox only when the server confirms them, never just because a sync event fired.
- **Last task, a format review:** before M4b makes the outbox format a promise, each operation is read against chapters 5 and 7 for what M7 to M11 could need from it, and the first sample batches are saved for the contract tests.

**Requirements:** [SYNC-02](spec.md#12-what-works-offline), [SYNC-10](spec.md#13-offline-shopping-changes) to [SYNC-17](spec.md#13-offline-shopping-changes), [SYNC-40](spec.md#16-sync-status) (waiting and failed states), [SYNC-41](spec.md#16-sync-status), [SYNC-50](spec.md#17-signing-in-and-out-and-leaving) to [SYNC-55](spec.md#17-signing-in-and-out-and-leaving) (the plain wipe of [SYNC-53](spec.md#17-signing-in-and-out-and-leaving) and [SYNC-54](spec.md#17-signing-in-and-out-and-leaving) is in M2a), [DOM-16](spec.md#03-rules-that-are-always-true), [DOM-22](spec.md#03-rules-that-are-always-true), [SHOP-14](spec.md#53-ticking).

**Scenarios:** Shopping in a shop with no signal · The most recent tick wins · Adding extra items on two phones offline · Duplicate send is harmless · Ticked offline while the line grew (with an extra growing the line) · Tick off in the basement.

**Try it** (steps 2, 3 and 4 are the manual part of acceptance: only a real phone can restart, wake a closed app or be stopped halfway through sending)
1. On the phone, airplane mode. Tick 12 items and add "Dish soap". Each shows the amber dot; the header says "Offline · 13 waiting".
2. Close the app fully, restart the phone, open it again, still offline: all 13 are still there.
3. Turn the signal back on without opening the app (Android) and watch Carlos's laptop for a few minutes. Background Sync is best effort (SYNC-13: "where the browser allows it"), so either outcome passes: the ticks arrive on their own, or they arrive the moment the app is opened. What must never happen is a tick lost or counted twice.
4. Tick 20 items offline, turn the signal on, and close the app while the dots are disappearing. Open it again: every tick arrives once (C12).
5. Maria ticks "Milk" offline at 10:00; Carlos unticks it online at 10:30; Maria reconnects: "Milk" is unticked on both.
6. While Maria is offline, Carlos adds 1 kg to a line she's looking at. She ticks it and reconnects: her amount is ticked, the extra kilogram is a new unticked line.
7. Sign out with changes waiting: you're warned and offered to send them first.

**Screens to accept:** waiting dots, "Couldn't sync" with Retry, sign-out warning.

---

## M3b. Updates and install

**Goal:** the app updates itself without ever losing a tick made in the shop, and invites people to put it on the home screen.

**Scope**
- App updates: update bar, never reloading mid-edit, waiting changes kept through an update, "Update needed to sync". Proven with the contract's example C10.
- The install card on Android and the How? card on iPhone.
- `navigator.storage.persist()` on first sign-in. Chrome can refuse it for a site that isn't installed or much used; what the app says then is added to [spec 7.3](spec.md#73-home-screen-install) first (one line in the install card would do).

**Requirements:** [SYNC-11](spec.md#13-offline-shopping-changes) (through an update), [UPD-01](spec.md#74-app-updates) to [UPD-03](spec.md#74-app-updates), [UPD-05](spec.md#74-app-updates), [INST-01](spec.md#73-home-screen-install) to [INST-03](spec.md#73-home-screen-install).

**Scenarios:** Ticks made offline survive an update.

**Try it**
1. Ship a new version while ticks are waiting: the "A new version is ready" bar appears, Refresh keeps the ticks.
2. Leave a sheet open while a new version becomes ready: nothing reloads.
3. First sign-in on a fresh phone shows the install card; Not now hides it.

**Screens to accept:** update bar, "Update needed to sync", install card and the iPhone How? sheet. **Design missing** (due when this milestone's plan is written): the install prompt ([UI review section 3](../reviews/ui-review-2026-10-05.md#3-missing-screens-third-pass-after-family-settings-2026-10-05), item 4).

---

## M4b. Live for the family

**Goal:** the family uses the shopping list for real, on the server that has been running since [M4a](#m4a-the-server).

**Scope: needed to go live**
- The family is invited for real.
- From this first release, the outbox format is frozen until v1, and contract tests prove that saved outbox batches from every earlier release still apply (the first samples were saved in M3a). Other changes may ask an old phone to update (UPD-05). The full 30-day rule and expand-then-contract migrations start with v1 (M13).
- **The release rule starts here:** production is deployed only from a milestone's acceptance tag; a fix between milestones is made on a branch from that tag; and a screen whose milestone isn't accepted yet can't be reached from the tab bar, even though its code is on `main`.
- **Every migration is rehearsed on real data:** before a deploy that carries a migration, last night's backup is restored into a throwaway Postgres and the migration runs there first. It reuses M4a's restore rehearsal and makes restoring a habit.
- **Production isn't a demo:** the deploy refuses to go ahead if demo data or a development clock offset (M11) is present.

**Scope: can follow after go-live** (each is done before [M13](#m13-v1-sign-off), which checks them)
- The automated monthly restore test that emails on failure (the hand rehearsals cover launch).
- Seq alerts (Seq itself is needed at launch, to find error refs).
- Running the deploy from GitHub Actions instead of by hand.

**Requirements:** [UPD-04](spec.md#74-app-updates) (the before-v1 part; contract example C9).

**Try it**
1. Invite the family for real and use the shopping list on the next shop.
2. With ticks waiting on a phone, deploy a new release: the ticks still arrive, and the phone then asks to update (C9).
3. Restore last night's backup into a throwaway Postgres by hand, and check that the family, its people and its shopping list are there.

**Screens to accept:** none new.

---

## M5a. Dishes and recipes

**Goal:** the family keeps every dish they eat, quickly (a name is enough), with ingredients that feed the shared grocery list. Typing recipes in is the slow part of adopting the app, so it comes before browsing them nicely.

**Scope**
- **First:** one rule for comparing names. REC-11 and REC-03 ignore case, accents and extra spaces, while [architecture 2](architecture.md#2-data-and-identity) gives dishes the groceries' normalised name, which ignores only case and spaces (DOM-12). The author decides whether groceries ignore accents too ([open points](#open-points-for-the-author)); then one function is used by the unique index, the search and the phone. Its tests include Polish letters: "ł" has no accent to strip, so the usual method treats "Żurek" and "Zurek" as equal but "Bułka" and "Bulka" as different.
- A plain list of dish names on the Recipes tab, enough to open a dish (the full tab is M5b).
- Add a dish, view, edit in place (ingredients and steps sent as small batches), delete (warning about planned slots arrives with M6), servings scaler with rounding, ingredient ticks on this phone.
- Groceries from ingredient lines: suggestions, create with aisle, rename and merge from an ingredient line, unit dropdown by kind, orphan cleanup job (on the job host from M3a).
- The contract's example C4 (two people save the same dish at once).
- **Rules tested as tables, and mutation-tested:** the rounding of scaled amounts (REC-22) and the combining of units (DOM-08).
- **The first download at full size:** with a seed family at the limits (2,000 dishes with their ingredients and steps), the first pull is measured on the A5. If it's slow, the fix (paging the first download, or a lighter record for lists) belongs here, not in M13.

**Requirements:** [REC-06](spec.md#32-browsing-and-searching), [REC-10](spec.md#33-adding-a-dish) to [REC-17](spec.md#33-adding-a-dish), [REC-19](spec.md#33-adding-a-dish), [REC-19a](spec.md#33-adding-a-dish), [REC-20](spec.md#34-viewing-a-recipe) to [REC-24](spec.md#34-viewing-a-recipe), [REC-30](spec.md#35-editing-and-deleting), [DOM-25](spec.md#03-rules-that-are-always-true) (recipe side), [DOM-27](spec.md#03-rules-that-are-always-true) (ingredient side), [SYNC-01](spec.md#12-what-works-offline) and [SYNC-04](spec.md#12-what-works-offline) (dishes), [LIM-01](spec.md#03b-limits), [LIM-04](spec.md#03b-limits), [LIM-05](spec.md#03b-limits), [LIM-07](spec.md#03b-limits), [LIM-13](spec.md#03b-limits), [LIM-17](spec.md#03b-limits) (description, note).

**Scenarios:** Butter is one grocery across recipes · Renaming a grocery onto an existing one merges them · Someone changed it first · Two people add ingredients at once · A dish can be just a name · Duplicate names are caught · Scaling a recipe · An extremely long dish name is refused · SQL in a name is stored as text · Script in a name is shown as text.

**Try it**
1. Add "Banana pancakes" with 250 ml milk and 2 pcs eggs, serves 4; scale to 6 and see "375 ml milk", "3 pcs eggs" and "Scaled from 4 to 6".
2. Add "butter" to two different dishes from two browsers: one grocery "Butter".
3. Type "taco night " as a new name: offered to open the existing one.
4. Maria and Carlos edit the chili's time at once: the second save says "Maria changed this a moment ago".
5. Airplane mode: every recipe still opens, Edit says it needs a connection.

**Screens to accept:** Add a dish (Save not covering "How to cook it"), Recipe view with scaler, edit mode, delete confirm.

---

## M5b. Recipes tab

**Goal:** finding a dish takes a few taps on a 360 px screen, and an empty recipe box gets the family started.

**Scope**
- Recipes tab: tiles, coloured by kind where there's no photo, ♥ count placeholder (0 until M9), sorting, search by name and grocery (with M5a's name rule), filters (On this week arrives with M6), the empty "No dishes match".
- First run "What does your family eat a lot?".
- The tab is measured on the A5 with the limits seed (2,000 dishes).

**Requirements:** [REC-01](spec.md#32-browsing-and-searching) to [REC-05](spec.md#32-browsing-and-searching), [REC-41](spec.md#36-photos), [REC-50](spec.md#37-first-run) (Recipes tab).

**Scenarios:** Searching by grocery · First run (Recipes tab).

**Try it**
1. On an empty family, type three dish names in the first-run card and see three name-only dishes.
2. Search "minced": the chili shows up.
3. Search for a dish with a Polish letter in its name, typed with and without it.
4. Airplane mode: the tab still opens and searches.

**Screens to accept:** Recipes tab, search and filters, first run.

---

## M6. Planning the week

**Goal:** the family plans breakfast, lunch and dinner for 21 slots and everyone sees what's for dinner today.

**Scope**
- Week tab: grid and day list (remembered), ‹ › and swipe, 8 weeks back offline and 4 weeks ahead, today highlighted, progress "x of 21", Fill next, read-only offline.
- Slot sheet: add from search (filters, top 20, "Add “Fish tacos”" creates a dish), servings stepper defaulting to family size, reorder, remove, skip and un-skip, Clear slot, Save; changes sent as one small batch; at most 8 dishes and no duplicates.
- "Food I don't eat" line in the slot sheet (rating hints arrive in M9).
- Deleting a planned dish warns and removes it from tomorrow on; today's and past slots show it greyed, and only its name and ratings are kept (a never-planned dish is deleted completely). "On Thu dinner" and the On this week filter in Recipes. First-run card on the Week tab.
- The contract's example C3 (a slot save whose response is lost).
- **"From tomorrow on" at midnight:** deleting a planned dish is tested at 23:59 and 00:01 in the family's time zone with the phone in another zone, and on a day the family's time zone was changed.
- Weeks older than 8 weeks are fetched when opened and not kept on the phone, so its storage doesn't grow without limit.

**Requirements:** [PLAN-01](spec.md#42-the-week-tab) to [PLAN-06](spec.md#42-the-week-tab), [PLAN-10](spec.md#43-planning-a-slot) to [PLAN-15](spec.md#43-planning-a-slot), [PLAN-16](spec.md#43-planning-a-slot) (food), [PLAN-17](spec.md#43-planning-a-slot) to [PLAN-19](spec.md#43-planning-a-slot), [REC-01](spec.md#32-browsing-and-searching) ("On Thu dinner"), [REC-04](spec.md#32-browsing-and-searching) (On this week), [REC-18](spec.md#33-adding-a-dish), [REC-32](spec.md#35-editing-and-deleting), [REC-33](spec.md#35-editing-and-deleting), [REC-50](spec.md#37-first-run) (Week tab), [DOM-03](spec.md#03-rules-that-are-always-true), [DOM-04](spec.md#03-rules-that-are-always-true), [DOM-09](spec.md#03-rules-that-are-always-true), [DOM-11](spec.md#03-rules-that-are-always-true), [SYNC-04](spec.md#12-what-works-offline) (plans), [LIM-02](spec.md#03b-limits), [LIM-03](spec.md#03b-limits).

**Scenarios:** Two dishes for breakfast · A skipped slot counts as planned · A slot holds up to 8 dishes · New dish from the planning search · Planning needs a connection · Deleting a planned dish · Week starts on Tuesday · Another family's id is refused.

**Try it**
1. Put Sandwiches and Scones on Monday breakfast; each starts at your family's size.
2. Fill the week with Fill next; skip Saturday dinner and reach "21 of 21 planned".
3. Switch to the day list, close the app, reopen: still the day list.
4. Maria and Carlos add different dishes to Tuesday dinner at once: both stay.
5. Search "Fish tacos", tap Add: it's on the slot and in the recipe box.
6. Delete a dish that's on next Thursday and was on last Monday: Thursday loses it, Monday shows it greyed.
7. As owner, change the week start to Tuesday: nothing moves, the week view starts on Tuesday.
8. Airplane mode: tapping a slot shows its dishes, no edit controls.
9. On the A5, try the three gestures that meet at the edges of the grid: swiping between weeks, pull-to-refresh, and Android's back swipe from the screen edge.

**Screens to accept:** Week grid, day list, slot sheet, dish search, skip, Fill next, delete-dish warning. Designs exist in "Week Plan v3"; the day list is new (from the UI review).

---

## M7. From plan to shopping list

**Goal:** the week's shopping list comes from the plan in one tap and stays right as the plan changes, without ever touching what's already been bought.

**Scope**
- The live list is recomputed in the same transaction as the plan or recipe change, with every rewritten line stamped with that change's counter ([sync contract §1](sync-contract.md#1-change-counter)). Isolation tests cover the recomputation and the grocery upsert, not only the endpoints.
- 🛒 on a dish, 🛒 Add all in a slot, 🛒 Shop the week, the "already on the list" message with View list, taking a dish off.
- The live list from item sources: servings and recipe changes rewrite unticked lines, ticked lines never change, top-up lines, ticked lines kept when less is needed, We have it, adjustments on top of the plan, highlight of lines changed by someone else.
- By recipe view, "also in 2 other recipes · 900 g total", Take off the list.
- Clear list shows empty 🛒 on the Week tab again.
- The worked examples that need dishes on the list: X3, X4 and X7 ([spec 1.3](spec.md#13-offline-shopping-changes)).
- **The recomputation is a pure function** (item sources and ticked lines in, lines out), tested with generated plans against the rules the spec states: a ticked line never changes (DOM-20); what's ticked plus what's unticked is never less than the plan needs; running it twice changes nothing; no amount is negative; a plan change never removes an extra (DOM-19). The scenarios below sit on top as examples, and mutation testing covers the function.
- **The family lock is held while lists are recomputed,** and one recipe edit can touch every list from today to four weeks ahead. It's measured with the limits seed (a full plan, 40 ingredients a dish) against a time it must stay under, because every other write in the family waits behind it.

**Requirements:** [PLAN-20](spec.md#44-from-the-plan-to-the-shopping-list) to [PLAN-24](spec.md#44-from-the-plan-to-the-shopping-list), [DOM-05](spec.md#03-rules-that-are-always-true) to [DOM-07](spec.md#03-rules-that-are-always-true), [DOM-19](spec.md#03-rules-that-are-always-true) to [DOM-21](spec.md#03-rules-that-are-always-true), [DOM-22](spec.md#03-rules-that-are-always-true) (with dishes), [REC-31](spec.md#35-editing-and-deleting), [SHOP-05](spec.md#52-the-shopping-tab) and [SHOP-08](spec.md#52-the-shopping-tab) (By recipe), [SHOP-07](spec.md#52-the-shopping-tab) (dish sources), [SHOP-12](spec.md#53-ticking), [SHOP-23](spec.md#54-extra-items-and-editing-a-line), [SHOP-24](spec.md#54-extra-items-and-editing-a-line), [SHOP-30](spec.md#55-getting-dishes-on-and-off-the-list) to [SHOP-32](spec.md#55-getting-dishes-on-and-off-the-list), [SHOP-40](spec.md#56-clear-and-share) (Week tab side).

**Scenarios:** More butter needed after it was bought · A dish leaves the plan · Ticked offline while the line grew · Shop the week doesn't double anything · We have it · Buying a bit more than the recipe needs · One unit kind per grocery · Butter is one grocery across recipes (list half).

**Try it**
1. Plan a week from seed data and tap Shop the week: the list fills, grouped by aisle, and the message says how many dishes.
2. Tap Shop the week again: "Already on the list. Nothing was added."
3. Tick "50 g Butter", then add Apple crumble: a new line "+100 g Butter, for Apple crumble".
4. Take Taco night off Tuesday: shared lines shrink, its own lines go, ticked ones stay.
5. Mark Salt "We have it", change the chili's servings: Salt doesn't come back.
6. Change the minced beef to 1 kg, then take Taco night off: the chili's share plus 100 g.
7. Switch to By recipe and tick a shared line: the whole line is ticked.
8. Repeat step 3 with Maria offline in the basement: she ticks "50 g Butter" offline while Carlos, online, adds Apple crumble. When she reconnects, her tick stands and the "+100 g Butter, for Apple crumble" line appears (X3).

**Screens to accept:** 🛒 states on the Week tab, the added/already-on-the-list message, By recipe view, We have it, top-up line, changed-line highlight.

---

## M8. Starting from last week

**Goal:** a parent plans a full week in under five minutes from last week or a template.

**Scope:** empty-week "Start from" (Copy last week, templates, Start blank), Keep the same servings, Fill empty slots from…, matching by weekday, deleted-dish note, Save week as template, rename and delete templates, Clear this week with Undo. Clear this week's Undo works the way M2b's Clear list does (contract example C18). Copy last week and a template are each saved as one batch with one counter, and the 8-per-slot limit and the no-duplicates rule are checked against each slot as it is in the database.

**Requirements:** [PLAN-30](spec.md#45-starting-a-week-from-before) to [PLAN-36](spec.md#45-starting-a-week-from-before), [LIM-15](spec.md#03b-limits).

**Scenarios:** Copy last week · Templates follow weekdays, not positions.

**Try it**
1. Open next week (empty) and Copy last week: same dishes, same weekdays.
2. Save this week's dinners as "School week dinners", then start the week after from it.
3. Change the week start to Tuesday and start from a template: Monday's dish lands on the 7th day shown.
4. Fill empty slots from a template on a half-planned week: nothing planned is overwritten.
5. Clear this week, then Undo.
6. Time yourself planning a whole week from last week: under five minutes ([intent, success criteria](intent.md#what-success-looks-like)). Write the time into the acceptance notes; M13 compares against it.

**Screens to accept:** "This week is empty" start sheet, Save as template, Fill empty slots, Clear this week (from "More Screens").

---

## M9. Cook mode and rating

**Goal:** whoever cooks follows the recipe one big step at a time with the screen on, and everyone says how it went, so the recipe box learns what the family loves.

**Scope:** Start cooking from the recipe, slot sheet and day list; full-screen steps, swipe, Ingredients overlay, screen wake lock, resume on the same step, ✕; finish screen with "How was it?"; rating on slot sheet and day list with stickers; "How was yesterday's dinner?" card; ♥ count from latest ratings; "Leo: Not again" hints; Served N times. **The ♥ count and "Served N times" are kept by the server** on the dish and sent through the change feed, updated when a rating changes or a person leaves: a phone only holds plans from 8 weeks back (SYNC-04), so it can't count "at any date" (RATE-05) itself. **Finishing offline:** cook mode works offline and rating needs a connection, so the finish screen's "How was it?" has an offline state, and the "How was yesterday's dinner?" card is how that rating is caught up. The `Permissions-Policy` ([ADR 14](../docs/adr/0014-security-headers-in-the-app.md)) is checked to leave the screen wake lock allowed.

**Requirements:** [COOK-01](spec.md#62-starting-and-moving-through-cook-mode) to [COOK-07](spec.md#62-starting-and-moving-through-cook-mode), [COOK-20](spec.md#64-finishing), [COOK-21](spec.md#64-finishing), [RATE-01](spec.md#65-rating) to [RATE-08](spec.md#65-rating), [DOM-26](spec.md#03-rules-that-are-always-true), [UPD-02](spec.md#74-app-updates) (cook mode), [PLAN-16](spec.md#43-planning-a-slot) (rating hints), [REC-01](spec.md#32-browsing-and-searching) and [REC-02](spec.md#32-browsing-and-searching) (♥ sorting with real counts), [REC-33](spec.md#35-editing-and-deleting) (ratings kept).

**Scenarios:** The screen stays on while cooking · Cook mode survives the app being closed · Rate at the end of cook mode · No rating before the day · The heart follows each person's latest rating · An update never interrupts cooking.

**Try it**
1. On the phone, start cooking tonight's dinner from the slot and leave it untouched for 5 minutes: the screen stays on.
2. On step 3, close the app and reopen: still step 3. In airplane mode too.
3. Finish: "Dinner's ready!" and "How was it?"; tap Loved it.
4. Next day, the Week tab asks about yesterday's dinner for the people who haven't rated.
5. As Leo, change Taco night to Not again: its ♥ drops and planning shows "Leo: Not again".
6. Try to rate next Sunday's roast: not offered.

**Screens to accept:** cook mode (visible Back, 56 px buttons), Ingredients overlay, finish screen with rating, rating on slot sheet and day list, the yesterday card. **Design missing:** rating a cooked meal ([UI review section 3](../reviews/ui-review-2026-10-05.md#3-missing-screens-third-pass-after-family-settings-2026-10-05), item 5).

---

## M10. Photos

**Goal:** dishes can have a photo, taken on the phone, that's small to keep offline and safe to store.

**Scope:** first, the photo storage budget on the phone (SYNC-04) is written into [chapter 8](spec.md#8-non-functional), and a check on the A5's Chrome that taking a photo through a file input still works under the app's `Permissions-Policy` ([ADR 14](../docs/adr/0014-security-headers-in-the-app.md)). Then camera or gallery upload, NetVips decode and re-encode to WebP thumbnail and full size (location data stripped), `IPhotoStore` on a volume, remove photo, thumbnails kept offline, full size kept once viewed within a budget. The libvips licence question was decided in M4a ([ADR 12](../docs/adr/0012-licence-and-supply-chain.md)). **Previews and the CSP:** showing a picked photo before upload normally uses a `blob:` address, which `img-src 'self' data:` refuses; whether to preview another way or amend [ADR 14](../docs/adr/0014-security-headers-in-the-app.md) is decided first. **Pixels, not only bytes:** a small file can decode to a huge image, so SEC-08's check refuses by width and height before decoding in full, with such a file in the abuse suite. Photos are read through an endpoint that checks the family, never served as static files, and the isolation tests cover it. The restore rehearsal from M4a is repeated with the photo volume. SHOULD: the phone shrinks a photo before sending it, since 10 MB over a weak connection is slow; the server re-encodes whatever arrives.

**Requirements:** [REC-40](spec.md#36-photos), [SEC-08](spec.md#81-input-safety), [LIM-16](spec.md#03b-limits), [SYNC-04](spec.md#12-what-works-offline) (photos).

**Try it**
1. Take a photo of a dish on the A5 and save it: the tile shows the thumbnail.
2. Upload an iPhone HEIC photo from the laptop: it works.
3. Download the stored photo and check it has no GPS data.
4. Try a 12 MB file and a text file renamed to .jpg: both refused with a short reason.
5. Airplane mode: thumbnails show; a full photo you opened before still opens.

**Screens to accept:** photo picker in Add a dish and edit mode, Remove photo.

---

## M11. Notifications

**Goal:** the app nudges the family at the few moments that matter and is quiet otherwise.

**Scope**
- Per-person settings, permission asked on first switch-on, Web Push with VAPID, one subscription per phone; planning reminder, someone added a dish, week fully planned, list changes, Cook tonight; 10-minute batches, quiet hours, never your own changes; deep links; the iPhone home-screen note; restart-safe jobs.
- Signing out unsubscribes the phone from push locally first, so it works offline: a wiped phone stops receiving family notifications even if the server never hears about the sign-out ([architecture 5](architecture.md#5-other-infrastructure)).
- **Isolation:** the background jobs (reminders, Cook tonight, batches) are covered by the family isolation tests: a job working for one family never reads or notifies another family's people.
- **A clock you can move, for trying it locally:** a development-only clock offset that the server's `TimeProvider` reads from a setting, so it survives a restart (Try 5). The server refuses to start in Production with an offset set.
- **First, the Web Push library's licence** is checked against [ADR 12](../docs/adr/0012-licence-and-supply-chain.md)'s list, as M4a did for libvips. If no package on the list fits, the protocol is small enough to write against .NET's own cryptography.
- **A seam for tests:** the sender sits behind an interface. Automated tests assert what would be sent, to whom and when (with `FakeTimeProvider` for batches, quiet hours and daylight-saving changes); one real notification on the A5 is the manual part of acceptance, because Playwright can't receive a push.
- Showing a notification and opening the right place on a tap is a third job for the service worker, after caching and the outbox sender. The M3b scenario "Ticks made offline survive an update" is run again with the new worker.

**Requirements:** [NOTE-01](spec.md#72-notifications) to [NOTE-13](spec.md#72-notifications).

**Scenarios:** Planning reminder when next week isn't planned · No reminder when the week is planned · Batched list changes, not your own · Quiet hours.

**Try it** (the development clock offset moves the server's clock forward, so you don't wait until Sunday)
1. Turn on Shopping list changes as Carlos: the permission prompt appears only now.
2. As Maria add Milk, Bread and Eggs: Carlos gets one "Maria added Milk, Bread +1", Maria gets nothing.
3. Add Milk at 22:30: it arrives at 07:00.
4. Tap the notification: it opens the shopping list.
5. Set the clock to Sunday 18:59 with next week half planned, restart the app at 19:00: exactly one planning reminder.
6. Sign out on the phone, once online and once in airplane mode: no more notifications there either way.

**Screens to accept:** Notifications settings (from "Family Settings"), blocked-notifications help, iPhone note.

---

## M12. Account and family housekeeping

**Goal:** the less frequent account jobs work safely: changing email, handing the family over, and deleting an account or the whole family.

**Scope:** change email with code to the new address and notice to the old; hand the family over; the owner leaving after hand-over; delete account (data download, type DELETE, removal within 30 days); delete the whole family. The delete-family core exists since M1a; here it also reaches what's outside the database: photos on the volume, push subscriptions, and the other people's phones (each wiped on its next contact, like SYNC-54). **First:** the format of the data download ([ACC-43](spec.md#26-your-own-account)) is written into [chapter 8](spec.md#8-non-functional), and "removed within 30 days" is squared with backups that are kept for 12 months ([open points](#open-points-for-the-author)).

**Requirements:** [ACC-02](spec.md#22-who-can-do-what) (hand over, delete family), [ACC-41](spec.md#26-your-own-account), [ACC-43](spec.md#26-your-own-account), [ACC-44](spec.md#26-your-own-account), [ACC-52](spec.md#27-managing-the-family-owner), [ACC-53](spec.md#27-managing-the-family-owner) (owner), [ACC-33](spec.md#25-signing-in-codes-and-passwords) (email-change code).

**Scenarios:** The owner can't leave without handing over.

**Try it**
1. Change your email: the old one keeps working until you enter the code from the new one, and the old inbox gets a notice.
2. Tap Leave the family as owner: you must pick a new owner first. Hand over to Maria; she can now invite, you can't.
3. As Diego, download the family's data, then delete his account; his dishes stay.
4. In a seed-demo family, delete the whole family and check nothing is left: no rows, no photos on the volume, no push subscriptions, and the others' phones wiped on their next contact.

**Screens to accept:** Change email, hand over, Delete account and data, Delete the whole family (from "Family Settings" and "More Screens").

---

## M13. v1 sign-off

**Goal:** v1 is fast enough on the Galaxy A5, accessible, and every scenario in the spec passes together.

**Scope:** the [chapter 8](spec.md#8-non-functional) performance budgets (enforced in CI since M2a) checked on a real A5 as well as the throttled profile (the phone has been measured at every L milestone since M0, so this confirms rather than discovers); an accessibility pass on every screen (axe plus a manual TalkBack run); the full Gherkin suite and visual baselines; a final restore test; the M4b "can follow after go-live" items are done; the mutation scores from M3a, M5a and M7 are above the thresholds set there; from the v1 release on, the 30-day rule for every sync request (UPD-04, contract example C17) and expand-then-contract migrations; ADRs brought up to date.

**Requirements:** the remaining [chapter 8](spec.md#8-non-functional) ids (performance, accessibility, observability, backups) once they're written.

**Try it**
1. Cold-open the installed app on the A5 on a throttled connection and compare it with the [chapter 8](spec.md#8-non-functional) targets.
2. Use one week (plan, shop offline, cook, rate) with TalkBack on.
3. The family plans, shops and cooks for one full week using only the app. It passes if nobody needed a paper list. Each time someone did is a bug, fixed before v1 is signed off, and then the week is repeated.
4. On the installed app, move the phone's clock: 29 days offline with ticks waiting, it syncs; at 31 days it asks for sign-in and then syncs (C8 and C11, by hand this once, where the real cookie and service worker are involved).
5. Plan a week from last week and compare the time with M8's.

---

## Requirement coverage

Every MUST and SHOULD in spec.md chapters 0 to 8.1 is in at least one milestone above. Requirements that grow over several milestones ([SYNC-01](spec.md#12-what-works-offline), [SYNC-04](spec.md#12-what-works-offline), [SEC-01](spec.md#81-input-safety), [SEC-10](spec.md#81-input-safety), [DOM-10](spec.md#03-rules-that-are-always-true)) are tested again in each one that adds a screen or endpoint. LATER items are out: [COOK-10](spec.md#63-timers-later) (timers), [INST-05](spec.md#73-home-screen-install) (Play Store), [LIM-06](spec.md#03b-limits).

## Open points for the author

Raised by [milestones-review.md](milestones-review.md) on 2026-11-15. Each changes a decision already recorded, or makes a new one, so they're listed here instead of being applied.

1. **iPhone in v1.** The intent, INST-03 and NOTE-11 promise iPhone, but every acceptance step is the Galaxy A5 and Chromium. Either the intent and M13 say "iPhone: best effort, not accepted in v1", or the E2E suite also runs on Playwright's WebKit from M0 and a real iPhone gets Try it steps in M3a, M3b and M11.
2. **The cut line.** If time runs short, which milestones make v1? The intent's success criteria need M0 to M8. M9 to M12 could each follow v1 without breaking the others.
3. **What "the outbox format never changes" allows** ([sync contract §7](sync-contract.md#7-versions-and-sessions)). The format is frozen at M4b, but X3, X4 and X7 are first proven in M7. Every operation carries `v`: the rule could instead be that the server accepts every `v` ever released, which is what the contract tests prove, with a new `v` needing an ADR. Either way, say whether a new optional field or a new operation type counts as a change.
4. **How Undo works** after Clear list (M2b) and Clear this week (M8): the lines come back with their old ids and a new counter, or as new lines. Needed before M2b.
5. **Do groceries ignore accents,** as dish names do (REC-11, DOM-12)? Needed before M5a.
6. **"Removed within 30 days" (ACC-43) against backups kept for 12 months.** Either the terms text (M1a) says backups age out within a year, or the retention changes.
