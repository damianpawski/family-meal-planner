# Sync contract: family meal planner

Draft 3 · 2026-11-10 · finished as the **first task of M2a**, before any sync code. It ties together the pieces described in [architecture.md §2 and §3](architecture.md#3-client-storage-and-sync) (family change counter, record versions, operation ids, tombstones, cursors) into one protocol: what the phone and the server send, store and retry.

**Which document wins:** the spec ([chapter 1](spec.md#1-offline-and-sync)) says what must be true and wins over both other files. On protocol details, this contract wins over architecture.md.

The author decided every open point in this contract on 2026-11-10; finishing it in M2a means checking it against the code as it's written. Every worked example names the milestone whose tests prove it.

## 1. Change counter

- Every write transaction **starts** by locking the family row (`SELECT … FOR UPDATE`). Taking it first, always, means two transactions never wait for each other's locks in opposite orders, so there are no deadlocks.
- The transaction then bumps the family's change counter once. Every row it writes, including derived rows (recomputed shopping lines) and tombstones, gets that **same** value. One user action is one counter value.
- Background jobs that change family data follow the same rule.
- The counter on each record also serves as its concurrency token for online edits; there's no separate `version` (architecture §2).

## 2. Pull and paging

`GET /api/sync?since={cursor}` and the following pages:

```json
{ "upTo": 120, "changes": [ { "entity": "shoppingLine", "id": "…", "counter": 101, "data": { … } } ],
  "tombstones": [ { "entity": "extra", "id": "…", "counter": 104 } ],
  "after": 104, "more": true }
```

- **High-water mark:** the first page fixes `upTo` (the family's counter at that moment). The phone passes it on every following page (`&upTo=120&after=104`), so a busy family's pull ends instead of chasing new changes. Changes after `upTo` come with the next pull.
- Pages are ordered by counter and **never split one counter value**, even if that makes a page larger than usual.
- **Staged:** the phone keeps the pages aside and applies them in one IndexedDB transaction once `more` is false, then sets its cursor to `upTo`. A record rewritten at counter 60 while the pull covers up to 30 can't leave an older transaction half-visible.
- **Newer local data wins:** a pulled record replaces the local copy only if its counter is higher. A pull that started before an online save (counter 50) and returns that record at counter 30 leaves the saved version on screen.
- **What the screen shows:** the server's state with the outbox replayed on top, so a pull that lands while ticks are waiting never removes them from the screen.

## 3. The cursor and online edits

- An online edit **doesn't** move the phone's cursor. Its response updates that record locally (with its counter), but the cursor moves only through pulls. Otherwise a phone that saves counter 50 would skip someone else's change 49 that it never pulled.

## 4. Retries and lost responses

### Shopping operations

`POST /api/sync/shopping`, with `Content-Type: application/json` and `X-MealPlanner-Sync: 1` (the antiforgery exception in architecture §4):

```json
{ "contract": 1,
  "ops": [ { "v": 1, "opId": "…", "personId": "…", "type": "tick", "itemId": "…", "amountSeen": 500, "madeAt": "2026-11-10T10:00:00.123Z" } ] }
```

Response `200`:

```json
{ "results": [ { "opId": "…", "result": "applied" },
               { "opId": "…", "result": "applied", "note": "Milk is counted in pcs, so the amount was left off" },
               { "opId": "…", "result": "dropped", "reason": "Diego already bought it" },
               { "opId": "…", "result": "refused", "reason": "The list is full" } ] }
```

- **`applied`:** the operation took effect, possibly adjusted: a DOM-22 split, a clamped time, or an extra kept without an amount that didn't fit its grocery's unit kind (spec example X14). An adjustment the person should know about comes with a `note`, which the phone shows.
- **`dropped`:** it had no effect because its target is gone or was overtaken (SYNC-17, spec 1.9 question 5). It leaves the outbox; if the person can see the difference, the phone shows the short reason.
- **`refused`:** it broke a rule: another family's id (SYNC-55), a full list (LIM-10), a validation limit, or a `personId` that isn't the signed-in person. It's undone on the phone with the short reason (SYNC-55).
- A dropped or refused operation **never stops the rest of the batch**.
- **Idempotency:** the server keeps each processed `opId` with its result for **60 days** (more than the 30-day offline limit). A resent operation returns its stored result, so the phone learns what was committed even when the first response was lost (SYNC-14).
- **A tick for a record that was purged** (deleted more than 90 days ago) comes back `dropped`, not `refused`.
- Operations stay in the outbox, with the amber waiting dot, until a response confirms them (SYNC-12). A Background Sync event firing proves nothing.

### Online edits

- Each save carries an `Idempotency-Key`, scoped to the person. The server keeps the response for 24 hours and returns it again for a retry with the same key.
- **Lost response:** the phone keeps the key until it learns the outcome. It resends the same request automatically; if it's offline, it shows SYNC-22's "wasn't saved" and resends when the connection returns. If that resend shows the save was applied, the edit is shown as saved after all. A later change by the person is a new request, based on the confirmed state, with a new key.
- Records a batch creates have client-made ids (architecture §2), so a retried `add` is recognised by its id rather than failing on a duplicate.

## 5. Ticks and extras

The rules are in the spec: SYNC-15 to SYNC-17 and DOM-22, DOM-23, with worked examples X1 to X15 in [spec 1.3](spec.md#13-offline-shopping-changes) and the answers in [spec 1.9](spec.md#19-open-questions). This contract adds:
- Ticks and extras **always** go through the outbox, online or offline; online, it's simply sent at once (the author, 2026-11-10; architecture §3).
- **`madeAt` is corrected by the phone:** every response carries a `Date` header, and the phone keeps the difference between that and its own clock. It stamps each operation with its own time plus that difference (spec 1.9, question 7). The `Date` header has one-second precision, which is enough here.
- A `madeAt` that's still later than the server's time when it arrives is clamped to the server's time.
- Ties: the later `(madeAt, opId)` wins (spec 1.9, question 6).

## 6. Tombstones and old cursors

- Deletions of every entity a phone keeps are recorded in one `tombstone (family_id, entity, id, counter)` table (architecture §2).
- Tombstones are kept 90 days. The family stores `purged_through`, the highest counter purged so far. A pull with `since < purged_through` gets `410 Gone`. A quiet family with no deletions never sends anyone into a re-download, and a phone isn't sent into one just because the family's first deletion was recent.
- **On `410`:** the phone first sends its outbox, then downloads everything again and sets its cursor to the new `upTo`.

## 7. Versions and sessions

- Every request carries the contract version (`contract`).
- **Before v1** (the author, 2026-11-10): the outbox format, meaning `POST /api/sync/shopping` and its operations, **never changes**, so the server accepts waiting operations from every earlier version. Any other request from an older contract version gets `426`, and the phone does what UPD-05 says. Contract tests prove that saved operation batches from every earlier release still apply.
- **From v1 on:** the server accepts **every contract version released in the last 30 days** (UPD-04). An older one gets `426`.
- Every outbox operation carries its own format version (`v`), so an app update can convert waiting operations if the format ever changes after v1 (UPD-03).
- An expired session gets `401`. The outbox is kept, and SYNC-51 and SYNC-52 apply: only the signed-in person's operations are ever sent.

## 8. Senders

- The foreground sender (the app) is built and proven first in M3. The service-worker sender with Background Sync is M3's last task.
- **The sync event:** network errors and `5xx` fail the event, so the browser retries it later. `200`, `401` and `426` complete it: retrying can't help, and the app handles those states when it next opens.
- The service worker tells an open app what it sent through a `BroadcastChannel`, so the waiting dots update.

## Worked examples (each becomes a test)

| # | Situation | Expected result | Proven in |
|---|---|---|---|
| C1 | A batch of 3 operations commits, the response is lost, the phone resends | Applied once; the resend returns the same 3 results; the outbox is empty | M3 |
| C2 | A batch where one operation targets a deleted line | The other operations apply; that one is `dropped` (SYNC-17) and leaves the outbox | M3 |
| C3 | An online slot save commits, the response is lost, the phone retries with the same key | The stored response comes back; no `409`, no second change | M6 |
| C4 | Two people save the same dish at once from the same state | One wins; the other gets `409` with the current dish and "Maria changed this a moment ago" (SYNC-20) | M5 |
| C5 | A pull is on page 2 of 3 while someone saves | The pull ends at its `upTo`; the new change comes with the next pull, never lost and never half-shown | M2a |
| C6 | Clear list removes 5 lines in one action | All 5 tombstones have the same counter and arrive in the same page | M2b |
| C7 | A phone saves online (counter 50) without having pulled 49 | Its cursor stays where it was; the next pull returns 49 and 50 | M2a |
| C8 | A phone comes back after 4 months | `401` (the 30-day session expired); after signing in, the outbox is sent (ticks for purged items come back `dropped`); the pull gets `410`; full re-download | M3 |
| C9 | Before v1: a phone one release behind sends its waiting ticks, then pulls | The ticks are accepted (the outbox format never changes); the pull gets `426` and the phone shows "Update needed to sync" (UPD-04, UPD-05) | M4 |
| C10 | A phone's contract version is no longer accepted | `426`; "Update needed to sync"; ticks kept; the app stays usable read-only (UPD-05) | M3 |
| C11 | The session expired while ticks were waiting | `401`; sign in again; ticks then sent (SYNC-51) | M3 |
| C12 | The service worker is stopped halfway through sending | Operations not confirmed stay in the outbox and are sent again; no duplicates (SYNC-14) | M3 |
| C13 | A pull starts; the person changes an item's amount to buy (counter 50); the pull's page brings the same item at counter 30 | The saved version stays on screen | M2b |
| C14 | Maria's ticks are waiting; Diego signs in on her phone | Only Diego's operations are sent; Maria's are kept (SYNC-52); an operation sent with Maria's `personId` under Diego's session would be `refused` | M3 |
| C15 | One operation in a batch is refused (the list is full) | The others apply; the refused one is undone on the phone with its reason | M3 |
| C16 | A phone's cursor is below `purged_through` | `410`; the outbox is sent first, then a full re-download | M3 |
| C17 | From v1: a phone on a contract version from 3 weeks ago sends ticks and pulls, after two releases | Both accepted (UPD-04) | M13 |
