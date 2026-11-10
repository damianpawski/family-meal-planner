# Review of architecture.md

2026-10-13 · reviewing [architecture.md](architecture.md) (draft 1, written 2026-10-06) against [spec.md](spec.md) as it stands after chapters 0 to 7 and 8.1. Ranked by how much each would hurt.

**Status 2026-10-13:** all 15 items applied or decided with the author.

Short version: the core is sound (one origin, cookie auth, change feed under a row lock, outbox for shopping only). But the file was written before chapters 2 to 8, so parts are stale, and four things in it don't work as described.

## Must fix: wrong or broken as written

### 1. Purging deleted dishes breaks history ✅ applied 2026-10-13
Deletes are tombstones purged after 90 days, but REC-33 keeps a deleted dish's name and ratings in past slots forever. After 90 days, past slots would point at nothing.
**Fix:** a deleted dish keeps its row with `DeletedAt` set (it's hidden from the recipe box and frees its name through a unique index on live dishes only). Only true removals (shopping lines, extras, planned dishes) become purgeable tombstones.

### 2. The global query filter doesn't protect writes or raw SQL ✅ applied 2026-10-13
An EF query filter stops *reading* another family's rows. It does nothing when a request *links* to another family's id (putting family B's dish on family A's Tuesday), and it's skipped by the raw `INSERT … ON CONFLICT` used for groceries.
**Fix:** composite keys. Every family table gets a unique `(FamilyId, Id)`, and every foreign key includes `FamilyId` (`PlannedDish (FamilyId, DishId) → Dish (FamilyId, Id)`). The database then refuses cross-family links whatever the code does. Keep the query filter for reads and the integration tests (SEC-06, DOM-10).

### 3. The offline outbox can't express an extra item ✅ applied 2026-10-13
`{ opId, type, itemId, amountSeen, madeAt }` has no grocery name, amount, unit or aisle, which `addExtra` needs (DOM-16, SHOP-16, SHOP-17). Since extras can merge into another line (DOM-23), `removeExtra` must also point at the extra itself, not at the line it merged into.
**Fix:** `addExtra { opId, extraId, listId, groceryName, amount?, unit?, aisle?, madeAt }` and `removeExtra { opId, extraId, madeAt }`, where `extraId` is the client-made id of the extra's source row. Ticks keep `itemId` plus `amountSeen`.

### 4. Cook-mode timer alerts can't come from the service worker ✅ resolved 2026-10-13: the author removed timers from v1
Section 5 says timer alerts are "local notifications from the service worker". A service worker can't wake itself at a time in the future: the API for that (Notification Triggers) was abandoned, and a backgrounded page's timers are throttled or frozen.
**Fix:** say plainly that COOK-14 is best effort. While the page is alive (the screen stays on, COOK-04), it alerts itself. If it's frozen, "Time's up 2 min ago" shows on return (already in the spec). An optional extra is a server push scheduled for the end time when online. ADR-worthy, because it's a known PWA limit.

## Should fix: stale or missing

5. ✅ *Applied 2026-10-13, with the first family created by the first deployment's setup script (spec ACC-12), marked as a future improvement.* **Stale auth text.** "Invite token **or family code**": the family code was dropped. `create-family` is missing the time zone (ACC-10). Nothing says how owner-only actions are enforced (ACC-04): an `OwnerOnly` authorization policy on those endpoints plus a test per endpoint.
6. ✅ *Applied 2026-10-13.* **SameSite=Strict breaks links from email.** Strict cookies aren't sent when someone taps a link in Gmail, so a signed-in person opening a "confirm your new email" link looks signed out. Use **Lax** (still blocks cross-site POSTs) together with antiforgery.
7. ✅ *Applied 2026-10-13.* **Background Sync runs in the service worker, which can't run the Blazor code.** The outbox sender has to be a small piece of JavaScript in the service worker that posts the stored operations as they are. Keep operations as plain JSON so both the page and the worker can send them, and rely on the Web Lock (one sender at a time) in both. This was open since the first critique (item 12).
8. ✅ *Applied 2026-10-13.* **Slot saves must be diffs.** PLAN-19 says two people adding different dishes to one slot both succeed. A slot sheet's Save must send "add X, remove Y, change servings of Z" per planned-dish record, not "the slot is now [A, B]", or the second save wipes the first.
9. ✅ *Applied 2026-10-13.* **Background jobs need to survive restarts.** Reminders, Cook tonight, 10-minute batches, quiet hours and the orphan-grocery cleanup (REC-19a) run in a hosted service. Nothing may live only in memory: each tick computes what's due from the database and records what was sent, so a deploy at 18:59 neither skips nor doubles the 19:00 reminder.
10. ✅ *Applied 2026-10-13.* **Time must be testable.** "Today", quiet hours, reminders, rating windows and the 30-day limits all depend on the clock. Use .NET's `TimeProvider` everywhere (`FakeTimeProvider` in tests) and never `DateTime.Now`.
11. ✅ *Applied 2026-10-13.* **Database changes vs 30-day-old phones.** UPD-04 accepts the previous sync contract for 30 days, so migrations must be expand-then-contract: add new columns, keep old ones readable, and drop them only in a later release.
12. ✅ *Applied 2026-10-13.* **Backups hold personal data off the VM.** Encrypt them before they leave (restic, BSD licence), keep 30 daily and 12 monthly, and test a restore on a schedule, not once.
13. ✅ *Decided 2026-10-13: keep Seq.* **Seq's free licence is for one person.** That's fine while only you read the logs. If you want nothing with a licence catch, the standalone Aspire dashboard (MIT) can receive the same OTLP data, though it keeps it only in memory.

## Missing from the testing map

14. ✅ *Applied 2026-10-13.* The abuse suite (SEC-10), time-zone and clock tests (with `TimeProvider`), a test that every owner-only endpoint refuses non-owners, and a performance budget check once chapter 8 sets numbers.

## ADRs to add

15. ✅ *Applied 2026-10-13 as ADRs 8 to 12.* Groceries have one unit kind and amounts are stored in base units (DOM-08). The live shopping list built from item sources (DOM-19 to DOM-23). Composite family keys (item 2). Timer alerts are best effort (item 4). A licence policy: built-in .NET first, then MIT or Apache only.
