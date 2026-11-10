# Intent: family meal planner

Status: draft 1 · 2026-10-06 · owner: the author

## Why this exists

Every week a family has to answer the same questions: what are we eating, who's cooking it, and what do we need to buy. Today that lives in someone's head, a chat thread and a paper list that gets left at home. This app gives the whole family one shared place to plan the week's meals and turns that plan into a shopping list automatically.

## What it is

A mobile-first app where a family:

1. **Keeps a shared recipe box** of the dishes they actually eat, with ingredients, steps and servings.
2. **Plans the week** by putting dishes into breakfast, lunch and dinner for each day.
3. **Gets a shopping list** generated from the planned week (or just the meals they pick), merged and grouped by aisle, which they tick off in the shop.
4. **Cooks** from the recipe with a hands-free, step-by-step cook mode.

## Who it's for

- **Parents** who plan meals and do the shopping. They want planning to take minutes, not an evening.
- **Everyone else in the household** (older kids, partners, grandparents) who wants to see what's for dinner, suggest dishes and help tick off the list.

Every family member has their own account and signs in with email and password. There are no shared-device PINs.

## Principles

- **Phone first.** Designed for a small, older Android phone (Galaxy A5, 360 px wide) held in one hand in a supermarket aisle. Larger screens get the same app with more room.
- **Works offline.** The shop basement with no signal is the main use case for the list. Every screen works offline; changes save on the phone first and sync when there's a connection. Nothing is ever lost because the network dropped.
- **One codebase, every device.** One app runs on Android, iPhone, tablets and desktop browsers, installable to the home screen. No separate native apps to maintain.
- **Shared, not bossy.** The family plans together. Everyone in the family has the same rights; one owner manages who's in it and which day the week starts.
- **Quick over complete.** A dish can be just a name to start with; ingredients and steps can come later. Three dishes is enough to plan a first week.

## What success looks like

- A parent can plan a full week, starting from last week or a template, in under five minutes.
- The shopping list for the week is generated with one tap, needs little or no manual fixing, and can be used start to finish in a shop with no signal.
- Two family members editing the same week on different phones never silently lose each other's changes.
- The app opens fast enough on a Galaxy A5 that nobody reaches for paper instead.

## Out of scope for the first version

- Nutrition tracking, calorie counts or diet plans.
- Grocery delivery or price comparison.
- Importing recipes from a link or photo (a good later addition).
- Native app-store builds (the architecture keeps this possible later).
- Multiple families per account at the same time (an account belongs to one family; it can leave and join another).

## Sources

- Designs: `Auth Screens`, `Recipe Screens`, `Week Plan v3`, `Shopping List`, `More Screens`, `Family Settings` (Galaxy A5), in the project files.
- Design review: [reviews/ui-review-2026-10-05.md](../reviews/ui-review-2026-10-05.md).
- Detailed behaviour: [spec.md](spec.md).
