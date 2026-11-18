# Review of milestones.md

2026-11-15 · reviewing [milestones.md](milestones.md) (draft 2) and the [M0 plan](../docs/plan/M0.md) (draft 5) against [spec.md](spec.md), [architecture.md](architecture.md) draft 3, [sync-contract.md](sync-contract.md) draft 3 and the six M0 ADRs.

**Status 2026-11-15:** applied to [milestones.md](milestones.md) (draft 3), the [M0 plan](../docs/plan/M0.md) (draft 6), [architecture.md](architecture.md), [sync-contract.md](sync-contract.md), [intent.md](intent.md), the spec's "Proven in" columns and ADRs 12, 13 and 14, with two differences from the text below. M4b follows M3b, so it doesn't wait on "M3a plus the update bar" (3.1). And six suggestions change a recorded decision or need a new one, so they're listed as open points for the author instead of being applied: G3 (iPhone), G6 (the cut line), 3.2 (what the outbox freeze allows), 2b.1 (Undo), 5.2 (accents in grocery names) and 12.1 (30 days against 12 months of backups). They're in [milestones.md, open points](milestones.md#open-points-for-the-author), and the two about sync are also in [the contract](sync-contract.md#open-points).

Short version: the order is right (the riskiest and most used part first), and the traceability is complete. The suggestions fall into three groups: things that are discovered too late (speed on the A5, deployment, iPhone), work that later milestones depend on but no milestone owns, and milestones that are larger than their size says.

**How to read the marks.** **[A]** changes what a milestone contains or where it sits. **[B]** adds a missing item to a milestone. **[C]** is a small correction. Items marked *(to verify)* rest on how earlier releases of a tool behaved; I couldn't check them against .NET 11.

## What was checked, and passed

- **Requirement coverage:** all 236 ids in the spec's tables were compared with the milestones' Requirements lines, with ranges expanded. Every MUST and SHOULD is in at least one milestone. The only three missing are the LATER ones the coverage note already names (COOK-10, INST-05, LIM-06). No milestone names an id that doesn't exist.
- **Scenarios:** all 62 Gherkin scenarios in the spec are named in a milestone, and no milestone names a scenario the spec doesn't have.
- **Worked examples:** X1 to X15 and C1 to C17 each have a milestone in their "Proven in" column, and those match the milestones, with the gaps listed under M5, M6 and M7 below.

## Across all milestones

| # | Mark | Suggestion |
|---|---|---|
| G1 | A | **Deploy long before go-live.** M0 is called a walking skeleton but never deploys; Compose, Caddy, the migration step, the Docker build without git (M0 plan, D4) and Gmail SMTP are first tried in M4, after two L milestones. Split M4: **M4a, the server** (VM, Compose, Caddy, `deploy.sh`, backups and a restore, on demo data) right after M1, when sign-in protects the site; **M4b, go-live** (the family invited, the outbox rule, real data) after M3 as now. Problems with forwarded headers, cookies behind Caddy and migrations then show up while little depends on them. |
| G2 | A | **Measure the real A5 early.** The intent's fourth success criterion is speed on the A5, and ADR 1 reconsiders Blazor if the budget is missed, yet a real A5 is first compared with the targets in M13. Measure cold load, repeat load and download size on the phone in the M0 spike (it already installs a published app there), set the throttled CI profile from that measurement in M2a, and repeat the phone measurement at each L milestone. |
| G3 | A | **Decide what iPhone means for v1.** The intent, INST-03 and NOTE-11 promise iPhone, but every acceptance step is the A5 and Chromium. Either write "iPhone: best effort, not accepted in v1" into the intent and M13, or add a Playwright WebKit run to the E2E suite from M0 and a real-iPhone Try it step in M3 and M11. iPhone is where storage eviction and the missing Background Sync change behaviour most. |
| G4 | B | **Give chapter 8 an owner.** Only 8.1 exists, but milestones depend on the rest. Write each part at the start of the milestone that first needs it: |

| Chapter 8 part (from spec 0.4b and the chapter's own list) | Needed by |
|---|---|
| The terms text a person agrees to on joining (ACC-22) | M1 |
| Speed and download-size targets for the A5 | M2a (first measured in M0, G2) |
| Accessibility rules beyond "axe passes" (tap sizes, contrast, TalkBack wording) | M1, the first real screens |
| Requirement ids for deploys, backups and observability | M4a |
| The photo storage budget on the phone (SYNC-04) | M10 |
| The format of the data download (ACC-43) | M12 |

| # | Mark | Suggestion |
|---|---|---|
| G5 | B | **Say what the sizes mean.** S, M and L have no unit. The text gives one data point ("M2a alone is a few weeks"). With six L, eight M and one S, that points to most of a year of evenings. Write the unit down, record M0's actual time against its M, and correct the rest from it. |
| G6 | B | **Draw a cut line.** If time runs short, which milestones make v1? The intent's success criteria need M0 to M8 (plan, list, shop offline, start from last week). M9 to M12 could each ship after v1 without breaking the others. Saying so now makes M13 movable. |
| G7 | B | **A release rule for after go-live.** From M4b on, `main` holds half-built milestones (one PR per task), but the family uses production. Decide: production is deployed only from a milestone's acceptance tag; a fix between milestones is made on a branch from that tag; unfinished screens on `main` are not reachable from the tab bar until their milestone is accepted. |
| G8 | B | **Rehearse every migration on real data.** After go-live, each deploy that carries a migration first restores last night's backup into a throwaway Postgres and runs the migration there. It reuses M4's restore rehearsal and turns "a backup nobody has restored" into a weekly habit. `deploy.sh` also takes a `pg_dump` before migrating, and the plan says how to roll back (the previous image plus that dump). |
| G9 | B | **One home for the background-job host and its clean-up jobs.** The hosted service first appears by name in M5 (orphan groceries) and M11, but earlier milestones create rows that must expire: tombstones after 90 days (needed by C16 in M3), processed `opId`s after 60 days, idempotency keys after 24 hours, used and expired invites and codes. Build the host with its first job in M3 and list each purge in the milestone that creates the rows. |
| G10 | B | **Assign the testing-map rows that have no milestone.** Stryker.NET is in [architecture 6](architecture.md#6-testing-map) but in no milestone: start it in M3 (tick resolution), extend it in M5 (scaling, rounding) and M7 (the live list). The seed command also needs sizes: a normal family for Try it, and a family at the limits (2,000 dishes, 3,000 groceries, a 299-line list) for the speed budget, X15 and LIM tests. |
| G11 | B | **Designs due at the start, not during.** Four milestones name missing designs (M1 twice, M3, M9). List them as an entry condition of the milestone's plan, with "built without a design, accepted on the phone" as the stated fallback, so a missing design can't stall a PR. |
| G12 | C | **Three sentences that no longer hold.** "Gives the family something useful in week one" (Why this order): nothing reaches the family before M4. "Nothing in a milestone depends on a later one": M1 depends on M2a's change feed (see M1). And [intent.md](intent.md) still says every screen works offline and changes save on the phone first, which the 2026-10-06 decision replaced with shopping only. |

## M0. Walking skeleton

| # | Mark | Suggestion |
|---|---|---|
| 0.1 | B | Add the A5 measurements to the spike (G2), and one more check while the phone is in hand: that the screen wake lock (M9, COOK-04) and the Web Share sheet (M2b, SHOP-41) exist in its Chrome version. Both are one line in DevTools and decide later designs. |
| 0.2 | B | Build the server's Docker image in CI, even though nothing runs it yet. D4 specifies how a build without git gets its version and date, and that it fails without them; without a CI build that path is untested code until M4. |
| 0.3 | B | **Trusted proxies as a setting.** "Forwarded headers from loopback only" is right for the tunnel but wrong for Compose, where Caddy reaches the app from a container network address. With loopback-only trust in production, every request looks like one address, and M1's rate limiting locks the whole family out together: the failure task 4 describes. Make the trusted proxies a setting that defaults to loopback, and name the Compose network in M4. Architecture §1 needs the same correction. |
| 0.4 | B | **Lock files across operating systems** *(to verify)*. The AppHost has pulled in packages named after the build machine's operating system, so a lock file written on Windows can fail a locked restore on the Linux CI runner (NU1004). Prove it in task 2 with one restore inside the Playwright container before task 3 depends on it. Also say that Dependabot's `dotnet-sdk` PRs arrive red by D9's own reasoning (they change `global.json` only) and are finished by hand. |
| 0.5 | B | **Empty test projects fail the gate.** The gate runs `dotnet test` on every `UnitTests` and `ComponentTests` project and fails on any non-zero exit code; Microsoft.Testing.Platform exits with 8 when no test ran. `ComponentTests` has no test until task 7 and `E2ETests` none until task 8. Create each test project in the task that adds its first test. |
| 0.6 | C | D2 computes the import map's hash "from the published `index.html`", but the SEC-05 integration test and a normal development run have no published output. Say that the hash is of the bytes actually served, read through the web root's file provider. |
| 0.7 | C | The milestone's scope says "one Playwright test at 360 px"; the plan has five. Update the milestone, which the plan was built from. |
| 0.8 | C | Run task 0 next. It's half a day, it decides the tunnel, the oldest browser and whether the domain is needed now, and with 0.1 it gives the first speed numbers. |

## M1. Sign in and invites

| # | Mark | Suggestion |
|---|---|---|
| 1.1 | A | **Sized M, reads as L.** It has about eight screens, both isolation layers, the abuse harness, the owner-only reflection test, rate limits, six kinds of email and the admin commands, with two designs missing. Split it: **M1a** create-family, accept invite, sign in and out, the not-in-a-family screen, isolation and the abuse harness; **M1b** forgot and change password, lockout, profile, Manage family, leave. |
| 1.2 | A | **Build the write path once.** Architecture §2 says every write starts by locking the family row, bumps the change counter and writes tombstones, but that arrives in M2a (ADR 5). M1's handlers (profile, invite, remove, leave) would be written without it and rewritten a milestone later, with a migration, because the people list joins the change feed. Put the write skeleton, the counter column and the tombstone table into M1, without the pull endpoint, and write ADR 5 with it. |
| 1.3 | B | **"Signs out other devices" needs the session checked on every request.** Try it 4 expects the laptop to ask for sign-in straight after a password reset, but Identity re-checks the security stamp every 30 minutes by default. The architecture already looks up the family on every request; say that the stamp is checked in the same lookup. |
| 1.4 | B | **ACC-31's "about the same time"** has no test. Try it 3 compares the messages, not the timing. Add a test that an unknown email runs the same password hashing as a known one. |
| 1.5 | B | **ACC-23 has no scenario and no Try it step:** someone with an account and no family accepts an invite by signing in; someone in another family is told to leave first. Add both to Try it, after step 5. |
| 1.6 | B | **Links in emails need the public address.** An invite opened from Mailpit on the phone must point at the tunnel's URL, not at localhost. Add a public base URL setting, used by every email, and check it in Try it 1 on the phone. |
| 1.7 | B | **`seed-demo` must refuse to run in Production,** like M11's clock offset: it creates accounts with known passwords and ships in the same image as the server. |
| 1.8 | B | **The abuse suite should find endpoints by itself,** as the owner-only test does: an endpoint with no abuse cases fails the suite, so M5's and M6's endpoints can't be forgotten. SEC-10 says "each endpoint". |
| 1.9 | B | Scope leaves out two of the emails in [spec 2.8](spec.md#28-emails-the-app-sends): "you were removed from the family" belongs here ("your email was changed" is M12). Add a SEC-05 test that a name with HTML in it arrives in an email as plain text. |
| 1.10 | B | The seed's "reset just as fast" needs a whole family deleted, which is M12's hardest job. Build the delete-family core here, used by the seed and tested for leaving nothing behind; M12 then adds only the screen and the owner's confirmation. |
| 1.11 | C | D10's check "when M1 starts" should name the package that forces it *(to verify)*: the 11.x Identity store for EF Core has, in every earlier release, depended on EF Core of the same major version. Staying on EF Core 10 means pinning that package to 10.x too. |

## M2a. Shared shopping list

| # | Mark | Suggestion |
|---|---|---|
| 2a.1 | A | **Prove the feed on the people list first.** M2a builds the change feed, the local store, the pull, the status header and the shopping list at once. The people list from M1 is the simplest data there is: make "the Family tab opens offline" the first tasks, proving pull, staging, the cursor, tombstones (a removed person) and C5 and C7, before any shopping table exists. The list then lands on a foundation that already works. |
| 2a.2 | B | **Wipe the phone on sign-out from the day the local store exists.** SYNC-53 and SYNC-54 are in M3, so through M2a and M2b a phone keeps the last person's copy after sign-out. Testing "as several people" on one phone, with a second seed family, would show one family's data to another. Move the plain wipe (on sign-out, on a different person signing in, on removal) here; M3 keeps only what involves waiting changes. |
| 2a.3 | B | **A way to change the local store's shape,** from its first version: when the stored format changes, the phone drops the copy and downloads it again, keeping the outbox (UPD-03 allows exactly this). M2b, M5, M6 and M9 each add stores, and without the rule each one needs its own conversion. |
| 2a.4 | B | **The Blazor decision gets a date.** ADR 1 says the choice is reconsidered "before M2a ends". Make it an acceptance item: the real A5's numbers against the chapter 8 targets, and a written keep-or-change decision. |
| 2a.5 | B | CI can enforce download size reliably; load times on shared runners vary. Fail the build on size, and on time only beyond a generous margin, so the budget isn't switched off after its third false alarm. |
| 2a.6 | C | SYNC-33 (a phone offline for months catches up) is listed here, but its examples (C8, C16) are proven in M3. Mark it "(pull side; old cursors in M3)" as other split requirements are. |

## M2b. Groceries and list tools

| # | Mark | Suggestion |
|---|---|---|
| 2b.1 | B | **Undo isn't in the sync contract.** Clear list removes 42 lines "for everyone" and offers Undo for 8 seconds (SHOP-40); C6 covers the tombstones but not the way back. Decide before the task starts: lines restored with their old ids and a new counter (and what a phone does with a tombstone followed by the same id), or a new set of lines. M8's Clear this week (PLAN-36) uses the same answer. Add it as example C18. |
| 2b.2 | B | **Idempotency keys arrive with the first online edit,** which is the item editor here, not M6 where C3 is proven. Build the key handling in M2b and add an item-editor twin of C3; C3 itself stays in M6. |
| 2b.3 | B | DOM-17's short first list after a week-start change is date arithmetic with many edges. Ask for a table of cases as tests (each start day to each other day, a change on the list's last day, a time zone where "today" differs from the phone's). |
| 2b.4 | C | SHOP-22's two edge results have no Try it step: a negative adjustment ("−200 g from Maria") and a line that reaches zero and shows "not needed". Add them to Try it 3. |

## M3. Shopping with no signal

| # | Mark | Suggestion |
|---|---|---|
| 3.1 | A | **Two milestones in one.** The offline outbox and sessions are the app's biggest risk; app updates (UPD-01 to UPD-05) and the install cards (INST-01 to INST-03) are separate work that shares nothing with them but the milestone. Split: **M3a** outbox offline, sessions, the service-worker sender; **M3b** updates, install cards, `storage.persist()`. Go-live (M4b) then waits only for what it needs: M3a, plus the update bar from M3b. |
| 3.2 | A | **Soften "the outbox format never changes".** It's frozen at M4, but three of its examples (X3, X4, X7) are first proven in M7, on lines that come from dishes. If one of them shows that an operation lacks a field, the rule forbids the fix. Every operation already carries `v`: say instead that **the server accepts every `v` ever released**, which is what the contract tests prove anyway, and that a new `v` needs a reason in an ADR. Also say whether a new optional field or a new operation type counts as a change. |
| 3.3 | B | Hold a short **format review** as M3's last task, before M4b freezes anything: read each operation against chapters 5 and 7 and ask what M7 to M11 could need from it. Save the first sample batches for the contract tests here, not in M4. |
| 3.4 | B | Say what the app does when `navigator.storage.persist()` is refused, which Chrome does for a site that isn't installed or much used. The spec is silent; one line in the install card ("install it so the shop list can't be cleared by the phone") would do. |
| 3.5 | B | List what only a real phone can prove, since Playwright can't: restarting the phone, Background Sync firing after the app is closed, the app killed halfway through sending (C12). They're in Try it already; mark them as the manual part of acceptance so nobody tries to automate them. |
| 3.6 | C | SYNC-50's 30 days must be counted on the phone too, from a stored "last contact" time read through `TimeProvider`: the cookie is HttpOnly, so the app can't read its expiry while offline. |

## M4. Live for the family

| # | Mark | Suggestion |
|---|---|---|
| 4.1 | A | Split into M4a and M4b (G1). The goal line says "can be moved later" while the order's rationale says the earlier the better; after the split neither sentence is needed. |
| 4.2 | B | **Server hardening is in the approach review but not in the scope:** SSH by key only, a firewall open on 22, 80 and 443, automatic security updates, Postgres and Seq reachable only inside the Compose network (Seq's own page has no sign-in by default under the free licence). Add them with a Try it step: a port scan from outside shows three ports. |
| 4.3 | B | **Nothing tells the admin the site is down.** Seq alerts need Seq to be up. Add a free outside uptime check and a disk-space warning to "needed to go live"; a full disk is the most likely first failure of a small VM with nightly dumps. |
| 4.4 | B | Add the backup-before-migrate step and the rollback note (G8) to `deploy.sh`, and the release rule (G7) to this milestone's scope. |
| 4.5 | B | A check that production isn't a demo: the deploy refuses if `seed-demo` data or the development clock offset is present (1.7, M11). |

## M5. Recipe box

| # | Mark | Suggestion |
|---|---|---|
| 5.1 | A | **Large enough to split:** **M5a** add, view, edit and delete a dish, with ingredients, groceries and the scaler; **M5b** the Recipes tab's sorting, search, filters and first run. M5a alone lets the family start typing in recipes, which is the slow part of adopting the app. |
| 5.2 | B | **Names with accents: the spec and the architecture disagree.** REC-11 and REC-03 ignore case, accents and extra spaces; architecture §2 gives dishes "the same normalized name as groceries", which is trimmed, single-spaced and lower-cased only (DOM-12). Decide whether groceries ignore accents too, and write one normalisation used by the index, the search and the client. Test it with Polish letters: "ł" has no accent to strip under Unicode decomposition, so the usual method leaves "Żurek" and "Zurek" equal but "Bułka" and "Bulka" different. |
| 5.3 | B | Name **C4** in the scope. The contract says it's proven in M5, and the scenario "Someone changed it first" is listed, but the example id isn't, unlike every other milestone. |
| 5.4 | B | **The first pull at full size.** SYNC-04 keeps every dish on the phone. Measure the first download and the Recipes tab on the A5 with the limits seed (G10): 2,000 dishes with their ingredients and steps. If it's slow, the fix (paging the first download, a lighter list record) belongs here, not in M13. |
| 5.5 | B | REC-22's rounding and DOM-08's unit combining are pure rules with many edges: ask for table tests and start mutation testing on them (G10). |

## M6. Planning the week

| # | Mark | Suggestion |
|---|---|---|
| 6.1 | B | Name **C3** in the scope (a lost response to a slot save), as the contract's "Proven in" column says. |
| 6.2 | B | **"From tomorrow on" at midnight.** Deleting a planned dish keeps today's slot (REC-32). Add tests at 23:59 and 00:01 in the family's zone with the phone in another zone, and for a time-zone change made on the same day. The testing map promises these in general; this milestone is where they first bite. |
| 6.3 | B | **Weeks older than 8 weeks "load when online"** (PLAN-02): that's a second way of reading plans, outside the local store. Say whether those weeks are fetched and thrown away or kept, so the phone's storage doesn't grow without limit (the critique's point 16). |
| 6.4 | C | Try the three gestures together on the A5: swiping between weeks, pull-to-refresh, and Android's back swipe from the screen edge. They overlap at the edges of the grid, and only the phone shows it. |

## M7. From plan to shopping list

| # | Mark | Suggestion |
|---|---|---|
| 7.1 | B | **The hardest rules in the app deserve the strongest tests.** Write the recomputation as a pure function (item sources and ticked lines in, lines out) and test it with generated plans against the invariants the spec states: a ticked line never changes (DOM-20); what's ticked plus what's unticked is never less than what the plan needs; running it twice changes nothing; no amount is negative; an extra is never removed by a plan change (DOM-19). The named scenarios then sit on top as examples. |
| 7.2 | B | Name **X3, X4 and X7** in the scope. Only X3 appears, inside Try it 8. |
| 7.3 | B | **The lock is held while lists are recomputed.** One recipe edit can touch every list from today to four weeks ahead. Measure it with the limits seed (a full plan, 40 ingredients per dish) and set a time it must stay under, because every other write in the family waits behind it. |
| 7.4 | C | The scope cites "example C6" for stamping rewritten lines with one counter. C6 is Clear list's tombstones. Either add an example of its own (a servings change rewrites 12 lines, all with one counter, in one page) or cite contract §1. |

## M8. Starting from last week

| # | Mark | Suggestion |
|---|---|---|
| 8.1 | B | Clear this week's Undo uses M2b's answer (2b.1); name it in the scope. |
| 8.2 | B | Copy last week and a template can create up to 21 × 8 planned dishes in one save. Say that it's one batch with one counter, and that LIM-03 and DOM-11 are checked for each slot as it is in the database, as slot saves are. |
| 8.3 | C | Try it 6 (under five minutes) is the intent's first success criterion. Record the time in the acceptance notes, so M13 has a number to compare. |

## M9. Cook mode and rating

| # | Mark | Suggestion |
|---|---|---|
| 9.1 | B | **Where the ♥ count is computed.** RATE-05 counts each person's latest rating "at any date", but a phone only keeps plans from 8 weeks back (SYNC-04), so it can't count them itself. The server must keep the count and each person's latest verdict on the dish and send them through the change feed, updated when a rating changes or a person leaves. The same goes for RATE-07's "Served 5 times". Say so in the scope. |
| 9.2 | B | **Finishing offline.** Cook mode works offline (COOK-06) and rating needs a connection (RATE-01), so the finish screen's "How was it?" needs an offline state. RATE-04's card then catches the missed rating the next day; say that this is the intended path. |
| 9.3 | C | Check that the `Permissions-Policy` from ADR 14 leaves the screen wake lock allowed, and add its fallback message (COOK-04) to the screens to accept. |

## M10. Photos

| # | Mark | Suggestion |
|---|---|---|
| 10.1 | A | **Decide the libvips licence question when M4a builds the image, not when M10 starts.** The answer may put a native library into the server's container, and it's cheaper to know before the image and its build are settled. |
| 10.2 | B | **The CSP has no `blob:` for images.** Showing a preview of the picked photo before upload normally uses a blob URL, which `img-src 'self' data:` refuses. Either preview through a `data:` URL (large for a 10 MB photo) or amend ADR 14; the E2E CSP listener will catch it, but the decision is better made than discovered. |
| 10.3 | B | **Limit pixels, not only bytes.** A small file can decode to a huge image. SEC-08's check should refuse by width and height before decoding in full, with a test file in the abuse suite. |
| 10.4 | B | Photos must be read through an endpoint that checks the family, not served as static files, and the isolation tests cover it. Extend M4's restore rehearsal to the photo volume. |
| 10.5 | C | A 10 MB upload from a phone on a weak connection is slow. As a SHOULD, shrink the photo on the phone before sending; the server still re-encodes whatever arrives. |

## M11. Notifications

| # | Mark | Suggestion |
|---|---|---|
| 11.1 | B | **Check the Web Push library's licence first** *(to verify)*, as M10 does for libvips. The most used .NET package for it has been MPL-2.0, which the `src/` list refuses; an MIT alternative exists, and the protocol is small enough to write against .NET's own cryptography if neither fits. |
| 11.2 | B | **A seam for tests.** Playwright can't receive a push. Put the sender behind an interface; automated tests assert what would be sent, to whom and when (with `FakeTimeProvider` for batches, quiet hours and daylight-saving changes), and one real notification on the A5 is the manual part of acceptance. |
| 11.3 | B | Push needs code in the service worker (showing the notification, opening the right place on a tap). That's the third job in the same worker after caching and the outbox sender: test that a worker update with ticks waiting still keeps them (the M3 scenario, run again here). |
| 11.4 | C | "Can swap places with anything after M6" holds: none of NOTE-01 to NOTE-13 depends on cooking or rating. Name what it does need, M2a (list changes) and M6 (planning), in the milestone itself, so the reason travels with it. |

## M12. Account and family housekeeping

| # | Mark | Suggestion |
|---|---|---|
| 12.1 | B | **"Removed within 30 days" against backups kept for 12 months.** ACC-43 promises removal in 30 days; restic keeps monthly snapshots for a year (M4). Either the terms text says backups age out within 12 months, or the retention changes. Decide it with the terms text in M1 (G4), since that's where the promise is made. |
| 12.2 | B | Deleting a family also has to reach things outside the database: photos on the volume, push subscriptions, and the other family members' phones (each wiped on next contact, like SYNC-54). Add them to Try it 4's "check nothing is left". |
| 12.3 | C | With the delete-family core built in M1 (1.10), this milestone drops to S. |

## M13. v1 sign-off

| # | Mark | Suggestion |
|---|---|---|
| 13.1 | A | **Make it a gate, not a discovery.** As written, M13 is the first time the real A5 is measured, the first full TalkBack run, and the first use of expand-then-contract migrations. With G2, the per-milestone TalkBack pass and G8, M13 only confirms. What stays: the 30-day rule (C17), the family's week, the last restore test, and the ADRs. |
| 13.2 | B | Give the family's week numbers to pass against: no open bug that lost a change or blocked a shop, the planning time from 8.3, and the mutation scores from G10. |
| 13.3 | B | Add one long-absence run with the clock moved: a phone 29 days offline with ticks waiting syncs; at 31 days it asks for sign-in and then syncs (C8, C11). It's automated in M3; here it's done once by hand on the installed app, where the service worker and the real cookie are involved. |

## Suggested order after these changes

| # | Milestone | Size |
|---|---|---|
| M0 | Walking skeleton, with A5 measurements and an image built in CI | M |
| M1a | Join and sign in, with the write skeleton | M |
| M1b | Passwords, profile, managing the family | M |
| M4a | The server: deploy, backups, restore, on demo data | M |
| M2a | Sync foundation on the people list, then the shared shopping list | L |
| M2b | Groceries and list tools | M |
| M3a | Shopping with no signal | L |
| M3b | Updates and install | S |
| M4b | Go-live for the family | S |
| M5a, M5b | Recipe box | M, M |
| M6 to M12 | As now | |
| M13 | v1 sign-off, as a gate | S |

The total work is the same. M1, M3 and M5 become smaller pieces, the server exists before any sync code is written instead of after all of it, and the family can go live as soon as M3a and the update bar are done.
