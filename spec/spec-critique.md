# Architect's critique of spec.md (chapter 1, offline and sync)

2026-10-06 · reviewing [spec.md](spec.md) as it stood after SYNC-17 (pull-to-refresh). Requirement ids below refer to that version.

> **Status, later on 2026-10-06:** The author chose Option B (offline edits for shopping only). Items 1–17 are addressed in the rewritten spec chapters 0 and 1 and in [architecture.md](architecture.md); 10 and 11 no longer apply because there is no conflict screen. Item 18 (performance targets) is still open for chapter 8.

Short version: the chapter reads well and is testable, but it was written **before the domain model exists**, so several rules are built on undefined ground. It also mixes product behaviour with implementation, contradicts the designs in one place, and has some classic sync bugs baked in. Ranked by how much they'd hurt.

## Must fix before going further

### 1. The scope may be bigger than the problem
Full offline *writes* everywhere, with conflict resolution, is the most expensive feature in the app, and in .NET/WASM you're building the sync engine yourself (there's no off-the-shelf IndexedDB sync library). The intent's real offline need is **the shop basement**: reading the plan and ticking the list.
- **Option A, as written:** everything works offline, including planning and editing dishes. Needs the conflict screen, op rebasing, dependency handling (see 5) and a lot of tests.
- **Option B, offline where it matters:** everything is *readable* offline; shopping ticks and extra items are *writable* offline (trivially mergeable); planning and recipe edits are queued while offline but blocked if they'd overwrite someone else's newer change. No conflict screen in v1.
- Option B removes about half of this chapter and most of the risk, and it's still an impressive portfolio piece. Option A is the better product if you're sure you'll plan meals on the train.

### 2. There's no domain model or glossary yet
The intent says "meals", the designs say "dish", the spec says "record". The merge rules (SYNC-20/21) talk about "fields" without saying which entities exist or what their fields are. **A chapter 0 (glossary and domain model) should come before sync**, because sync rules are statements *about* the model.

### 3. Field-level "last write wins" breaks on lists
Ingredients, steps, the dishes in a meal slot, and extra shopping items are all *lists*. If a list is a single field, two people each adding an ingredient offline means one addition is silently lost, which is exactly what the goal in 1.1 promises won't happen. Each list item has to be its own record (with its own id and a sort position), or the spec needs explicit list-merge rules.

### 4. SYNC-04 contradicts the designs: the shopping list isn't purely derived
The designs build the list explicitly: "🛒 Add all", 🛒 per dish, per slot, with item edits, unit merging, moving to the pantry and extra items. The spec says the list is recomputed on each device and only ticks and edits are synced. That gives ticks no stable identity: change a dish's servings or rename an ingredient and the tick or edit no longer matches anything. **Shopping list items should be real synced records**, created when someone adds dishes to the list.

### 5. Rejected changes cascade (SYNC-25)
"Undo a rejected change on the device" ignores that later changes may depend on it. Example: create a new dish offline, then put it on Tuesday dinner. If the create is rejected, the slot change points at a dish that doesn't exist. The spec needs ordered operations with dependents rejected together, and a rule for what the user sees.

### 6. Version numbering has a known cursor bug
"Version increasing per family" plus "pull everything above my last version" misses changes when two transactions commit out of order: version 41 commits after 42, and a device that already pulled 42 never sees 41. The spec should require that versions are assigned in commit order (for example, under a per-family row lock inside the transaction). Write this as a requirement with a test, not an implementation detail someone might miss.

## Should fix

7. **Contradiction:** SYNC-41 says no screen shows a spinner, and SYNC-17 shows a spinner. Reword SYNC-41 as "never shows a spinner *to save*".
8. **Dead data:** SYNC-11 records device time, but nothing uses it. Either use it (SYNC-21 could compare device times instead of arrival order) or drop it.
9. **Arrival order isn't intent order.** With "last to reach the server wins", Maria ticks milk in the basement at 10:00 and syncs at 11:00, overriding Diego's untick at 10:30 ("we need more"). That might be fine, but the spec should say it's a deliberate trade-off.
10. **False conflicts.** Two people adding *the same* dish to Tuesday dinner is reported as a conflict. Conflicts should compare content, not just versions.
11. **Who resolves a conflict?** Only the person who synced second ever sees it. If they sign out (SYNC-52) or are removed (SYNC-53) before resolving it, their version is lost silently.
12. **Several tabs or devices for one user.** Two open tabs would both push the same outbox. One tab should own syncing (Web Locks API), and the service worker and page need rules for writing the same IndexedDB.
13. **Server-side authorization is missing from the sync chapter.** Every operation must be checked: does the record id belong to this family, and does this member's role allow this change? The client generates ids, so the server must never trust an id it hasn't seen in this family. Add limits on batch size and rate.
14. **Lost phone.** Family data sits unencrypted in IndexedDB for up to 30 days and can only be wiped once the phone goes online. Probably acceptable for a meal planner, but the spec should say so.
15. **SYNC-51 discards another person's outbox**, which contradicts "nothing is lost". At least keep it until the original user signs in again on that device.
16. **Local data grows forever.** "Full family copy" needs a bound: for example all dishes, plus weeks from 8 weeks back onwards, plus a size budget for photos (the Galaxy A5 has little storage).

## Structural

17. **Behaviour and implementation are mixed.** IndexedDB, UUID v7, `overscroll-behavior-y` and the version columns are design decisions, not product requirements. Keep `spec.md` to behaviour and acceptance criteria, and move the "how" into `docs/architecture.md` plus ADRs. The spec then stays stable when the implementation changes, and interviewers see you know the difference.
18. **No non-functional targets yet.** Sync timings exist, but not the one that matters most on the A5: first load and repeat load times. Chapter 8 should set numbers early, because they constrain chapter 1 (bundle size versus SQLite-in-WASM, for example).

## Suggested next steps

1. Decide scope: Option A or B (item 1).
2. Write chapter 0: glossary and domain model, with lists as their own records.
3. Revise chapter 1 against the model, fixing items 3–16, and split the "how" into an architecture doc.
