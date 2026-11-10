# Milestones: family meal planner

Draft 2 · 2026-11-10 (review fixes; draft 1 was 2026-10-13) · owner: the author · built from [spec.md](spec.md) (chapters 0 to 8.1), [architecture.md](architecture.md) draft 3 and [sync-contract.md](sync-contract.md).

Each milestone is a thin, complete slice of the app: it runs locally with one `dotnet run` on the Aspire AppHost, works on the Galaxy A5 through the HTTPS tunnel, and ends with something the family could actually use. Nothing in a milestone depends on a later one.

## How each milestone is accepted

A milestone is done when all four are true:

1. **Automated:** every MUST in its scope has a passing test that names its id, every Gherkin scenario listed has a passing Playwright test (360 px and desktop), every worked example marked with this milestone ([spec 1.3](spec.md#13-offline-shopping-changes), [sync contract](sync-contract.md#worked-examples-each-becomes-a-test)) has a passing test named after it, and CI is green, including axe and, from M1 on (when the first endpoints that take input and the owner-only policy exist), the abuse suite ([SEC-10](spec.md#81-input-safety)) and the owner-only reflection test.
2. **Screens:** the author has accepted each new screen on the phone against its design (or against the missing-design note, where there is no design yet), including a two-minute pass with TalkBack, Android's screen reader: every control can be reached and is read out with its name and state ("Milk, 2 l, not ticked, button"). Accepted screens become visual baselines.
3. **By hand:** the author works through the milestone's **Try it** list, on the laptop and on the phone, and every step behaves as written.
4. **Seed data:** `mealplanner seed-demo` is extended so the milestone can be tried on a realistic family (people Maria, Diego, Leo, Ava; dishes; a planned week) in seconds, and reset just as fast.

**Working with an AI agent.** A milestone is too big for one agent run (M2a alone is a few weeks of work). At the start of each milestone the agent first writes `docs/plan/Mx.md`: an ordered list of PR-sized tasks, each naming its spec ids and tests. The author approves the list, then the agent works through it one PR at a time. The milestone is accepted as a whole, by the four checks above, once its last task is merged.

**Testing as several people on your own.** Locally every email lands in Mailpit, so any address works: invite `maria@example.com`, open the link from Mailpit, and use a second browser profile (or a private window) as Maria. On the phone, Chrome plus Chrome's incognito tab gives two people at once. Offline is airplane mode on the phone, or DevTools › Network › Offline on the laptop.

**Phone access.** Service workers and installing need HTTPS, so the phone reaches the laptop through a tunnel. An installed PWA is tied to its origin, so the tunnel must keep the same URL every time; a temporary URL gives a new app with empty storage and a dead home-screen icon. Candidates: a persistent, named Microsoft Dev Tunnel with anonymous access (free, wired into Aspire, but its anti-phishing warning page may show inside the installed app), or a named Cloudflare Tunnel on a subdomain of the app's own domain (needs the domain on Cloudflare; the domain is needed in M4 anyway). The M0 spike picks one. Set up in M0.

## Overview

| # | Milestone | What the family can do at the end | Size |
|---|---|---|---|
| M0 | Walking skeleton | Open an empty app on the phone and install it | M |
| M1 | Sign in and invites | Everyone has an account in the Rivera family | M |
| M2a | Shared shopping list | Share one typed-in shopping list that updates live | L |
| M2b | Groceries and list tools | Rename and merge groceries, edit amounts, clear and share the list | M |
| M3 | Shopping with no signal | Tick off the list in a basement with no signal | L |
| M4 | Live for the family | Use M1 to M3 for real, on a server, with backups | M |
| M5 | Recipe box | Keep every dish with ingredients, steps and scaling | L |
| M6 | Planning the week | Plan 21 slots, see what's for dinner | L |
| M7 | From plan to shopping list | Get the week's list in one tap, kept live | L |
| M8 | Starting from last week | Plan a week in minutes from last week or a template | M |
| M9 | Cook mode and rating | Cook hands-free and say how it went | M |
| M10 | Photos | Put a photo on a dish | S |
| M11 | Notifications | Get the planning reminder and other nudges | M |
| M12 | Account and family housekeeping | Change email, hand over, delete account or family | M |
| M13 | v1 sign-off | Performance, accessibility and full regression on every screen | M |

**Why this order.** The riskiest part of the app is the offline shopping list in the shop basement, and it's also the part the family uses most. Building the shopping list with typed-in items first (M2a, M2b, M3) proves the change feed, the local store and the outbox on the simplest data, and gives the family something useful in week one. Recipes and planning then feed into a list that already works offline. M4 (going live) can move: it fits anywhere after M3, and the earlier it happens, the sooner real use finds problems. Photos (M10) can swap places with anything after M5. Notifications (M11) can swap places with anything after M6, because the planning reminder, "week fully planned" and Cook tonight all need planning.

---

## M0. Walking skeleton

**Goal:** the whole pipeline works end to end before any feature: repo, local run, phone, CI, logs.

**Scope**
- Public GitHub repo (the author, 2026-11-10), where every push first passes a pre-push review ([the M0 plan](../docs/plan/M0.md), D12), with the folder layout from [architecture 1](architecture.md#1-shape-of-the-system) (server with vertical slices, WASM client, Razor Class Library for components, tests), the M0 ADRs from [architecture 7](architecture.md#7-adrs-to-write) in `docs/adr/` (the rest are written when their milestone starts). The repo is created in the folder that already holds `spec/`, so `spec/` is committed where it is.
- Aspire AppHost starting Postgres, the ASP.NET Core host (serving the WASM app and an API), Mailpit and the dashboard. EF migrations applied by a separate `mealplanner migrate` step before the server starts (how production migrates is decided in M4), with snake_case table and column names from the first migration (EFCore.NamingConventions, Apache 2.0), so SQL in DBeaver needs no double quotes.
- The app shell: four tabs (Week, Recipes, Shopping, Family), each an empty page; Family › About shows the version and date ([UPD-06](spec.md#74-app-updates)).
- PWA manifest, icon, splash screen and a service worker that caches the app, so it installs and opens full screen ([INST-04](spec.md#73-home-screen-install)).
- Theme as CSS custom properties in one file, so a designer can swap it.
- `TimeProvider` everywhere with the banned-API analyzer (`DateTime.Now`); OpenTelemetry logs, traces and metrics (`ILogger`, no Serilog) to the Aspire dashboard.
- CI on GitHub Actions: build, unit, integration (Testcontainers), one Playwright test at 360 px, axe, gitleaks, a licence check (ADR 12: MIT, Apache, BSD or the PostgreSQL License for the app; test-only packages may also be MPL-2.0). gitleaks runs in the pre-push review and in CI; on a public repo GitHub's own secret scanning and push protection are on as well.
- Security headers and CSP ([SEC-05](spec.md#81-input-safety)), ProblemDetails with an error ref ([SEC-09](spec.md#81-input-safety)), request size limits ([SEC-02](spec.md#81-input-safety)).
- A tunnel to the phone, pointed only at a published, Production-mode build (the development service worker caches nothing, and a Development server would show error details to anyone with the URL), with forwarded headers trusted from loopback.

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

## M1. Sign in and invites

**Goal:** every family member has their own account, joins only by email invite, and the owner is the only one who manages who's in.

**Scope**
- `mealplanner create-family` and `seed-demo` CLI ([ACC-10](spec.md#23-creating-a-family), [ACC-11](spec.md#23-creating-a-family)), family time zone set at creation ([DOM-24](spec.md#03-rules-that-are-always-true)).
- Invite by email, accept the invite with name and password, sign in, sign out, forgot password, change password, lockout, password rules.
- Edit profile: name, sticker colour, "Food I don't eat".
- Manage family: everyone and open invites; owner can invite, resend, cancel, remove. Leave the family (not the owner). The "You're not in a family yet" screen.
- These screens read from the server, because the phone's local copy of the data arrives in M2a. Account actions (sign in, invites, passwords, profile changes) need a connection anyway and say "You're offline. This needs a connection" offline. The Family tab's people list moves to the local copy in M2a, so build it to make that switch small.
- Family isolation in both layers (query filter plus `(FamilyId, Id)` keys), owner-only policy with the reflection test, rate limits on sign-in and code endpoints, the abuse suite against every endpoint so far. Isolation tests cover every write path, not only API handlers: the `mealplanner` commands, background jobs and any bulk or raw-SQL statement (such as the grocery upsert) must also be unable to read, write or link another family's rows.

**Requirements:** [DOM-01](spec.md#03-rules-that-are-always-true), [DOM-02](spec.md#03-rules-that-are-always-true), [DOM-10](spec.md#03-rules-that-are-always-true), [DOM-24](spec.md#03-rules-that-are-always-true) (set at creation), [ACC-01](spec.md#22-who-can-do-what), [ACC-02](spec.md#22-who-can-do-what) (invite, cancel, remove), [ACC-03](spec.md#22-who-can-do-what), [ACC-04](spec.md#22-who-can-do-what), [ACC-10](spec.md#23-creating-a-family), [ACC-11](spec.md#23-creating-a-family), [ACC-20](spec.md#24-joining-a-family) to [ACC-23](spec.md#24-joining-a-family), [ACC-30](spec.md#25-signing-in-codes-and-passwords) to [ACC-35](spec.md#25-signing-in-codes-and-passwords), [ACC-40](spec.md#26-your-own-account), [ACC-42](spec.md#26-your-own-account), [ACC-50](spec.md#27-managing-the-family-owner), [ACC-51](spec.md#27-managing-the-family-owner), [ACC-53](spec.md#27-managing-the-family-owner) (non-owners), [ACC-54](spec.md#27-managing-the-family-owner), [LIM-08](spec.md#03b-limits), [LIM-11](spec.md#03b-limits), [LIM-12](spec.md#03b-limits), [LIM-17](spec.md#03b-limits) (email, food), [SEC-01](spec.md#81-input-safety), [SEC-03](spec.md#81-input-safety), [SEC-04](spec.md#81-input-safety), [SEC-06](spec.md#81-input-safety), [SEC-07](spec.md#81-input-safety), [SEC-10](spec.md#81-input-safety).

**Scenarios:** Joining by email invite · Only the owner can invite · Removed person loses access · Forgot password signs out other devices.

**Try it**
1. Run `mealplanner create-family --name Rivera --owner carlos@example.com --time-zone Europe/Warsaw`, open the invite in Mailpit, set a password, and land on the Week tab.
2. Invite Maria and Diego. Accept Maria's in a second browser profile; leave Diego's open and see "Invite sent" with Resend and Cancel.
3. As Maria, open Manage family: no Invite button. Try a wrong password 5 times and see the lockout message, which doesn't say whether the email exists. Do the same with an email that has no account: the same messages, after the same number of tries ([ACC-31](spec.md#25-signing-in-codes-and-passwords)).
4. Reset Maria's password from the phone while she's signed in on the laptop; the laptop asks her to sign in again.
5. Remove Maria. Her next tap shows "You're not in a family yet".
6. Create a second family with `seed-demo` and confirm nothing of it is visible from the Rivera accounts.

**Screens to accept:** sign in, forgot password and code, accept invite, Manage family, Edit profile, Change password, Leave the family, not-in-a-family. **Designs missing:** the email-only rework of "Auth Screens" (no PIN, no "Who's here?", no family code) and the accept-invite screen ([UI review section 3](../reviews/ui-review-2026-10-05.md#3-missing-screens-third-pass-after-family-settings-2026-10-05), items 1 and 2).

---

## M2a. Shared shopping list

**Goal:** the family shares one shopping list of typed-in items, sees each other's changes within 30 seconds, and can read it offline. This milestone lays the sync foundation every later screen uses: the change feed, the local store, pull-to-refresh and the sync status. It deliberately keeps the list itself simple; managing groceries and the list's extra tools follow in M2b (split from one M2 on 2026-11-10, because together they were about a month of work).

**Scope**
- **First, before any sync code:** finish [sync-contract.md](sync-contract.md) (requests and results, cursor, paging, retries, idempotency, tombstones) and check it against [spec 1.9](spec.md#19-open-questions), whose questions are all answered. Its worked examples marked M2a (C5, C7) are proven here.
- **Performance budgets:** write the chapter 8 numbers (first load, repeat load and download size on the Galaxy A5 profile) as **targets**, not as measurements of the M0 build, which is an empty shell that every real screen would exceed. CI enforces them from this milestone on, so every later screen is checked against them.
- Change feed under the family row lock, paged pull, tombstones; IndexedDB local store; refresh on open, reconnect, every 20 s and pull-to-refresh; sync status header (Synced, Offline · showing {time}).
- Groceries, the basics: one per name, created by upsert, unit kind set by first use, a new grocery goes in "Other".
- Shopping lists by week (dates from the family's week start day, Monday until M2b makes it changeable), ‹ and ›, "Nothing to buy yet". Its **Plan this week** button opens the Week tab, which stays empty until M6.
- Add item (name with suggestions, amount, unit dropdown), extras merging by amount, lines grouped By aisle, ticking with the 2-second pause, Done group, Hide done, progress, the tab badge, other people's changes appearing in place.
- **The outbox, online:** ticks and extras always go through the outbox ([sync contract §5](sync-contract.md#5-ticks-and-extras)). Here it's sent at once, with the per-operation results and the clock correction; M3 makes it work offline.
- The Family tab's people list reads from the local copy, so it opens offline.
- Offline, every edit control says it needs a connection (offline ticking arrives in M3).

**Requirements:** [SYNC-01](spec.md#12-what-works-offline), [SYNC-03](spec.md#12-what-works-offline), [SYNC-04](spec.md#12-what-works-offline) (lists), [SYNC-21](spec.md#14-online-changes), [SYNC-22](spec.md#14-online-changes), [SYNC-30](spec.md#15-seeing-the-familys-changes) to [SYNC-33](spec.md#15-seeing-the-familys-changes), [SYNC-40](spec.md#16-sync-status) (Synced and Offline states), [DOM-08](spec.md#03-rules-that-are-always-true), [DOM-12](spec.md#03-rules-that-are-always-true), [DOM-13](spec.md#03-rules-that-are-always-true), [DOM-15](spec.md#03-rules-that-are-always-true), [DOM-23](spec.md#03-rules-that-are-always-true), [SHOP-01](spec.md#52-the-shopping-tab) to [SHOP-04](spec.md#52-the-shopping-tab), [SHOP-05](spec.md#52-the-shopping-tab) and [SHOP-06](spec.md#52-the-shopping-tab) (By aisle), [SHOP-07](spec.md#52-the-shopping-tab) (extras), [SHOP-09](spec.md#52-the-shopping-tab) to [SHOP-11](spec.md#53-ticking), [SHOP-15](spec.md#53-ticking) to [SHOP-18](spec.md#54-extra-items-and-editing-a-line) (SHOP-18 online; offline in M3), [LIM-09](spec.md#03b-limits), [LIM-14](spec.md#03b-limits).

**Scenarios:** Two people create the same grocery at once · An extra with an amount joins the recipe line (with an extra in place of the recipe) · Extras in g and kg make one line · An extra without an amount stays separate · Adding an extra with an amount · Pull to refresh · Pull to refresh while offline · No change is missed when two people save at once · Opening on next week's list.

**Try it**
1. On the laptop as Carlos, add "Milk 2 l", "Bread", "Minced beef 500 g". On the phone as Maria, see them appear within 30 seconds without touching anything.
2. As Maria add "Minced beef 1 kg": one line "1.5 kg Minced beef" with both names. Add "minced beef" with no amount: its own line.
3. Type "Milk" and open the unit list: only ml, l, tsp, tbsp.
4. Tick three lines; each waits 2 seconds, then moves to Done. Put one back.
5. Airplane mode: the list still shows, the header says "Offline · showing {time}", and Add item says "You're offline. This needs a connection."

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

**Requirements:** [SYNC-20](spec.md#14-online-changes), [DOM-14](spec.md#03-rules-that-are-always-true), [DOM-17](spec.md#03-rules-that-are-always-true), [DOM-18](spec.md#03-rules-that-are-always-true), [DOM-24](spec.md#03-rules-that-are-always-true) (changing it), [DOM-25](spec.md#03-rules-that-are-always-true) (list side), [DOM-27](spec.md#03-rules-that-are-always-true), [ACC-02](spec.md#22-who-can-do-what) (week start day), [SHOP-13](spec.md#53-ticking), [SHOP-19](spec.md#54-extra-items-and-editing-a-line) to [SHOP-22](spec.md#54-extra-items-and-editing-a-line), [SHOP-40](spec.md#56-clear-and-share), [SHOP-41](spec.md#56-clear-and-share), [LIM-10](spec.md#03b-limits).

**Scenarios:** Clear list with undo · Share · Only the owner changes the week start day.

**Try it**
1. Rename "Minced beef" to "Beef mince", then rename another grocery onto an existing name and accept the merge.
2. Move Butter to "Dairy & eggs": it moves in every list.
3. Change the amount to buy on a line to 200 g more: it shows "+200 g from Maria". Have Carlos change the same line at the same moment: the second save says "Maria changed this a moment ago".
4. Clear the list, then Undo. Share it into WhatsApp.
5. As Maria, try to change the week start day: read-only. As Carlos, change it to Tuesday and see the next list's dates follow [DOM-17](spec.md#03-rules-that-are-always-true).
6. Airplane mode: the item editor says "You're offline. This needs a connection."

**Screens to accept:** item editor, Clear confirm, Family settings.

---

## M3. Shopping with no signal

**Goal:** in the shop with no signal, ticking and adding extras just work, survive the app closing and updating, and reach the family when the signal comes back.

**Scope**
- The outbox from M2a, made to work offline: operations (tick, untick, addExtra, removeExtra with `amountSeen` and `madeAt`) kept as plain JSON through closing the app and restarting the phone, sent by the app under one Web Lock; idempotent `opId`s; latest `madeAt` wins; waiting dots; "N waiting" and "Couldn't sync N changes · Retry now"; automatic retries. Proven with the worked examples marked M3: X1, X2, X5, X6 and X8 to X15 ([spec 1.3](spec.md#13-offline-shopping-changes)), and C1, C2, C8, C10 to C12 and C14 to C16 ([sync contract](sync-contract.md)). X3, X4 and X7 need dishes on the list and are proven in M7.
- **Last task, once foreground sync is proven:** the service-worker sender with Background Sync (Android), as an extra delivery path. It sends the same operations under the same Web Lock; operations leave the outbox only when the server confirms them, never just because a sync event fired.
- Sessions: 30 days offline, signing in again when expired, a different person on the same phone, sign-out wipes the phone (offering to send first), removed person's phone wiped.
- App updates: update bar, never reloading mid-edit, waiting changes kept through an update, "Update needed to sync".
- The install card on Android and the How? card on iPhone, `navigator.storage.persist()`.

**Requirements:** [SYNC-02](spec.md#12-what-works-offline), [SYNC-10](spec.md#13-offline-shopping-changes) to [SYNC-17](spec.md#13-offline-shopping-changes), [SYNC-40](spec.md#16-sync-status) (waiting and failed states), [SYNC-41](spec.md#16-sync-status), [SYNC-50](spec.md#17-signing-in-and-out-and-leaving) to [SYNC-55](spec.md#17-signing-in-and-out-and-leaving), [DOM-16](spec.md#03-rules-that-are-always-true), [DOM-22](spec.md#03-rules-that-are-always-true), [SHOP-14](spec.md#53-ticking), [UPD-01](spec.md#74-app-updates) to [UPD-03](spec.md#74-app-updates), [UPD-05](spec.md#74-app-updates), [INST-01](spec.md#73-home-screen-install) to [INST-03](spec.md#73-home-screen-install).

**Scenarios:** Shopping in a shop with no signal · The most recent tick wins · Adding extra items on two phones offline · Duplicate send is harmless · Ticked offline while the line grew (with an extra growing the line) · Tick off in the basement · Ticks made offline survive an update.

**Try it**
1. On the phone, airplane mode. Tick 12 items and add "Dish soap". Each shows the amber dot; the header says "Offline · 13 waiting".
2. Close the app fully, restart the phone, open it again, still offline: all 13 are still there.
3. Turn the signal back on without opening the app (Android) and watch Carlos's laptop for a few minutes. Background Sync is best effort (SYNC-13: "where the browser allows it"), so either outcome passes: the ticks arrive on their own, or they arrive the moment the app is opened. What must never happen is a tick lost or counted twice.
4. Maria ticks "Milk" offline at 10:00; Carlos unticks it online at 10:30; Maria reconnects: "Milk" is unticked on both.
5. While Maria is offline, Carlos adds 1 kg to a line she's looking at. She ticks it and reconnects: her amount is ticked, the extra kilogram is a new unticked line.
6. Ship a new version while ticks are waiting: the "A new version is ready" bar appears, Refresh keeps the ticks.
7. Sign out with changes waiting: you're warned and offered to send them first.
8. First sign-in on a fresh phone shows the install card; Not now hides it.

**Screens to accept:** waiting dots, "Couldn't sync" with Retry, sign-out warning, update bar, "Update needed to sync", install card and the iPhone How? sheet. **Design missing:** the install prompt ([UI review section 3](../reviews/ui-review-2026-10-05.md#3-missing-screens-third-pass-after-family-settings-2026-10-05), item 4).

---

## M4. Live for the family

**Goal:** M1 to M3 run on a real server so the family can use the shopping list for real, with backups that are proven to restore. Can be moved later in the order.

**Scope: needed to go live**
- A domain and a cheap VM; Docker Compose with Caddy (Let's Encrypt; TLS and proxy only, since the app already sends the CSP and security headers from M0), the app, Postgres and Seq; a production check that the headers arrive unchanged through Caddy; `deploy.sh` with the migration step (an EF migration bundle or `mealplanner migrate`, decided here); the first-deployment setup script that creates the family once.
- Gmail SMTP through MailKit with an app password.
- restic nightly encrypted backups (30 daily, 12 monthly), and **one restore rehearsed by hand**: last night's backup restored into a throwaway Postgres, with the family's data checked. A backup nobody has restored doesn't count.
- **The VM can only add to the backups:** an append-only repository (restic's REST server in append-only mode, or a storage key without delete rights), with `forget --prune` run from the admin's machine, so someone who takes over the VM can't delete them ([architecture 5](architecture.md#5-other-infrastructure)).
- From this first release, the outbox format is frozen until v1, and contract tests prove that saved outbox batches from every earlier release still apply. Other changes may ask an old phone to update (UPD-05). The full 30-day rule and expand-then-contract migrations start with v1 (M13).
- Rehearse the whole deploy on a local Linux VM first.

**Scope: can follow after go-live** (each is done before [M13](#m13-v1-sign-off), which checks them)
- The automated monthly restore test that emails on failure (the hand rehearsal above covers launch).
- Seq alerts (Seq itself is needed at launch, to find error refs).
- Running the deploy from GitHub Actions instead of by hand.

**Requirements:** [ACC-12](spec.md#23-creating-a-family), [UPD-04](spec.md#74-app-updates) (the before-v1 part; contract example C9), plus [architecture 5](architecture.md#5-other-infrastructure) (deploy, backups, observability). Chapter 8 will add ids for these.

**Try it**
1. Rehearse: run `deploy.sh` against a local VM, then against the real one.
2. Open the domain on the phone: valid certificate, the owner invite arrives in your real Gmail inbox, and running the deploy again says "Family already set up".
3. Invite the family for real and use the shopping list on the next shop.
4. Find last night's backup in restic, restore it into a throwaway Postgres by hand, and check that the family, its people and its shopping list are there.
5. Find a request's error ref in Seq.
6. Put the restic password in your password manager.

**Screens to accept:** none new; re-check every accepted screen on the live site.

---

## M5. Recipe box

**Goal:** the family keeps every dish they eat, quickly (a name is enough), with ingredients that feed the shared grocery list.

**Scope**
- Recipes tab: tiles, ♥ count placeholder (0 until M9), sorting, search by name and grocery, filters (On this week arrives with M6), the empty "No dishes match".
- Add a dish, view, edit in place (ingredients and steps sent as small batches), delete (warning about planned slots arrives with M6), servings scaler with rounding, ingredient ticks on this phone, coloured tiles by kind, first run "What does your family eat a lot?".
- Groceries from ingredient lines: suggestions, create with aisle, rename and merge from an ingredient line, unit dropdown by kind, orphan cleanup job.

**Requirements:** [REC-01](spec.md#32-browsing-and-searching) to [REC-06](spec.md#32-browsing-and-searching), [REC-10](spec.md#33-adding-a-dish) to [REC-17](spec.md#33-adding-a-dish), [REC-19](spec.md#33-adding-a-dish), [REC-19a](spec.md#33-adding-a-dish), [REC-20](spec.md#34-viewing-a-recipe) to [REC-24](spec.md#34-viewing-a-recipe), [REC-30](spec.md#35-editing-and-deleting), [REC-41](spec.md#36-photos), [REC-50](spec.md#37-first-run) (Recipes tab), [DOM-25](spec.md#03-rules-that-are-always-true) (recipe side), [DOM-27](spec.md#03-rules-that-are-always-true) (ingredient side), [SYNC-01](spec.md#12-what-works-offline) and [SYNC-04](spec.md#12-what-works-offline) (dishes), [LIM-01](spec.md#03b-limits), [LIM-04](spec.md#03b-limits), [LIM-05](spec.md#03b-limits), [LIM-07](spec.md#03b-limits), [LIM-13](spec.md#03b-limits), [LIM-17](spec.md#03b-limits) (description, note).

**Scenarios:** Butter is one grocery across recipes · Renaming a grocery onto an existing one merges them · Someone changed it first · Two people add ingredients at once · A dish can be just a name · Duplicate names are caught · Scaling a recipe · Searching by grocery · First run (Recipes tab) · An extremely long dish name is refused · SQL in a name is stored as text · Script in a name is shown as text.

**Try it**
1. On an empty family, type three dish names in the first-run card and see three name-only dishes.
2. Add "Banana pancakes" with 250 ml milk and 2 pcs eggs, serves 4; scale to 6 and see "375 ml milk", "3 pcs eggs" and "Scaled from 4 to 6".
3. Add "butter" to two different dishes from two browsers: one grocery "Butter".
4. Type "taco night " as a new name: offered to open the existing one.
5. Search "minced": the chili shows up.
6. Maria and Carlos edit the chili's time at once: the second save says "Maria changed this a moment ago".
7. Airplane mode: every recipe still opens, Edit says it needs a connection.

**Screens to accept:** Recipes tab, search and filters, Add a dish (Save not covering "How to cook it"), Recipe view with scaler, edit mode, delete confirm, first run.

---

## M6. Planning the week

**Goal:** the family plans breakfast, lunch and dinner for 21 slots and everyone sees what's for dinner today.

**Scope**
- Week tab: grid and day list (remembered), ‹ › and swipe, 8 weeks back offline and 4 weeks ahead, today highlighted, progress "x of 21", Fill next, read-only offline.
- Slot sheet: add from search (filters, top 20, "Add “Fish tacos”" creates a dish), servings stepper defaulting to family size, reorder, remove, skip and un-skip, Clear slot, Save; changes sent as one small batch; at most 8 dishes and no duplicates.
- "Food I don't eat" line in the slot sheet (rating hints arrive in M9).
- Deleting a planned dish warns and removes it from tomorrow on; today's and past slots show it greyed, and only its name and ratings are kept (a never-planned dish is deleted completely). "On Thu dinner" and the On this week filter in Recipes. First-run card on the Week tab.

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

**Screens to accept:** Week grid, day list, slot sheet, dish search, skip, Fill next, delete-dish warning. Designs exist in "Week Plan v3"; the day list is new (from the UI review).

---

## M7. From plan to shopping list

**Goal:** the week's shopping list comes from the plan in one tap and stays right as the plan changes, without ever touching what's already been bought.

**Scope**
- The live list is recomputed in the same transaction as the plan or recipe change, with every rewritten line stamped with that change's counter ([sync contract](sync-contract.md), example C6). Isolation tests cover the recomputation and the grocery upsert, not only the endpoints.
- 🛒 on a dish, 🛒 Add all in a slot, 🛒 Shop the week, the "already on the list" message with View list, taking a dish off.
- The live list from item sources: servings and recipe changes rewrite unticked lines, ticked lines never change, top-up lines, ticked lines kept when less is needed, We have it, adjustments on top of the plan, highlight of lines changed by someone else.
- By recipe view, "also in 2 other recipes · 900 g total", Take off the list.
- Clear list shows empty 🛒 on the Week tab again.

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

**Scope:** empty-week "Start from" (Copy last week, templates, Start blank), Keep the same servings, Fill empty slots from…, matching by weekday, deleted-dish note, Save week as template, rename and delete templates, Clear this week with Undo.

**Requirements:** [PLAN-30](spec.md#45-starting-a-week-from-before) to [PLAN-36](spec.md#45-starting-a-week-from-before), [LIM-15](spec.md#03b-limits).

**Scenarios:** Copy last week · Templates follow weekdays, not positions.

**Try it**
1. Open next week (empty) and Copy last week: same dishes, same weekdays.
2. Save this week's dinners as "School week dinners", then start the week after from it.
3. Change the week start to Tuesday and start from a template: Monday's dish lands on the 7th day shown.
4. Fill empty slots from a template on a half-planned week: nothing planned is overwritten.
5. Clear this week, then Undo.
6. Time yourself planning a whole week from last week: under five minutes ([intent, success criteria](intent.md#what-success-looks-like)).

**Screens to accept:** "This week is empty" start sheet, Save as template, Fill empty slots, Clear this week (from "More Screens").

---

## M9. Cook mode and rating

**Goal:** whoever cooks follows the recipe one big step at a time with the screen on, and everyone says how it went, so the recipe box learns what the family loves.

**Scope:** Start cooking from the recipe, slot sheet and day list; full-screen steps, swipe, Ingredients overlay, screen wake lock, resume on the same step, ✕; finish screen with "How was it?"; rating on slot sheet and day list with stickers; "How was yesterday's dinner?" card; ♥ count from latest ratings; "Leo: Not again" hints; Served N times.

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

**Scope:** camera or gallery upload, NetVips decode and re-encode to WebP thumbnail and full size (location data stripped), `IPhotoStore` on a volume, remove photo, thumbnails kept offline, full size kept once viewed within a budget.

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

**Scope:** change email with code to the new address and notice to the old; hand the family over; the owner leaving after hand-over; delete account (data download, type DELETE, removal within 30 days); delete the whole family.

**Requirements:** [ACC-02](spec.md#22-who-can-do-what) (hand over, delete family), [ACC-41](spec.md#26-your-own-account), [ACC-43](spec.md#26-your-own-account), [ACC-44](spec.md#26-your-own-account), [ACC-52](spec.md#27-managing-the-family-owner), [ACC-53](spec.md#27-managing-the-family-owner) (owner), [ACC-33](spec.md#25-signing-in-codes-and-passwords) (email-change code).

**Scenarios:** The owner can't leave without handing over.

**Try it**
1. Change your email: the old one keeps working until you enter the code from the new one, and the old inbox gets a notice.
2. Tap Leave the family as owner: you must pick a new owner first. Hand over to Maria; she can now invite, you can't.
3. As Diego, download the family's data, then delete his account; his dishes stay.
4. In a seed-demo family, delete the whole family and check nothing is left.

**Screens to accept:** Change email, hand over, Delete account and data, Delete the whole family (from "Family Settings" and "More Screens").

---

## M13. v1 sign-off

**Goal:** v1 is fast enough on the Galaxy A5, accessible, and every scenario in the spec passes together.

**Scope:** the [chapter 8](spec.md#8-non-functional) performance budgets (enforced in CI since M2a) checked on a real A5 as well as the throttled profile; an accessibility pass on every screen (axe plus a manual TalkBack run); the full Gherkin suite and visual baselines; a final restore test; the M4 "can follow after go-live" items are done; from the v1 release on, the 30-day rule for every sync request (UPD-04, contract example C17) and expand-then-contract migrations; ADRs brought up to date.

**Requirements:** the remaining [chapter 8](spec.md#8-non-functional) ids (performance, accessibility, observability, backups) once they're written.

**Try it**
1. Cold-open the installed app on the A5 on a throttled connection and compare it with the [chapter 8](spec.md#8-non-functional) targets.
2. Use one week (plan, shop offline, cook, rate) with TalkBack on.
3. The family plans, shops and cooks for one full week using only the app. It passes if nobody needed a paper list. Each time someone did is a bug, fixed before v1 is signed off, and then the week is repeated.

---

## Requirement coverage

Every MUST and SHOULD in spec.md chapters 0 to 8.1 is in at least one milestone above. Requirements that grow over several milestones ([SYNC-01](spec.md#12-what-works-offline), [SYNC-04](spec.md#12-what-works-offline), [SEC-01](spec.md#81-input-safety), [SEC-10](spec.md#81-input-safety), [DOM-10](spec.md#03-rules-that-are-always-true)) are tested again in each one that adds a screen or endpoint. LATER items are out: [COOK-10](spec.md#63-timers-later) (timers), [INST-05](spec.md#73-home-screen-install) (Play Store), [LIM-06](spec.md#03b-limits).
