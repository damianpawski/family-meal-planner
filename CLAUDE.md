# Working rules for coding agents

This repo builds a family meal planner, one milestone and one plan task at a time. These are the rules an agent can't work out from the plan alone. Where they and another document disagree, stop and ask the author.

## What wins

The [spec](spec/spec.md) says what must be true and wins over everything else. Then the [architecture](spec/architecture.md), the [sync contract](spec/sync-contract.md) (which wins over the architecture on protocol details), the [ADRs](docs/adr/README.md) and the current plan in [docs/plan/](docs/plan/). If the code you're asked to write would contradict one of them, don't write it: say so.

## Before you start

- **Work on one plan task per session,** the one you were given, such as task 2 of [docs/plan/M0.md](docs/plan/M0.md). Read the task, the plan's decisions table, and every spec id, ADR and worked example the task cites.
- Read [docs/conventions.md](docs/conventions.md) and [docs/review/push-review.md](docs/review/push-review.md). Every commit you make is judged against them before it can be pushed.
- **Ask instead of guessing** when the plan is unclear, contradicts the spec, or needs a decision that isn't recorded. Open points listed in [milestones.md](spec/milestones.md#open-points-for-the-author) or the plan are the author's to decide. A change to the plan is its own commit, made after the author agrees.

## Writing code

- The .NET SDK is pinned in `global.json`, and warnings are errors. A banned API (the clock outside `TimeProvider`, `FromSqlRaw`, `MarkupString`, and the rest listed in `BannedSymbols.txt` from M0 task 5 on) means the code changes; a suppression needs a reason and is rare.
- **Packages:** built-in .NET first. A new package must be on [ADR 12](docs/adr/0012-licence-and-supply-chain.md)'s licence list, its commit says why the platform isn't enough, and its lock-file changes are committed. Never add a package source.
- **Test names** start with the spec id or worked example the test proves, followed by the behaviour in plain words, so the name reads on its own and still points to its requirement: `SEC_02_ordinary_request_over_64KB_is_refused_with_413`, `X13_tick_on_an_offline_extra_splits_the_merged_line`. A bare id (`SEC_02_test1`) isn't enough. Without an id, the name is just the behaviour: `Unknown_api_path_returns_404_problem_details_not_html`. A test project is created in the task that adds its first test. Integration and end-to-end tests need Docker Desktop running.
- No secrets, ever. A dev-only value that a check mistakes for one needs an exception: in `.githooks/allowed-secrets.txt` when F6 flags a JSON key, or as a narrow, path-scoped allowlist in `.gitleaks.toml` when gitleaks (F1) flags it. Each has a comment saying why the value is safe, and each needs the author's agreement first, because it loosens a check (M0 task 2's dev-only Postgres password is the planned example).

## Commits

- Follow [the commit format](docs/conventions.md#commits) exactly: the subject pattern, a body that says why, and the `Spec:` and `Task:` trailers. The hook checks it.
- One logical change per commit, about 400 changed lines or fewer; say in the message why a bigger one can't be split.
- **Every claim in a message must be true.** Say how the change was tested, and don't claim anything you didn't check: the reviewers compare messages with the diff.

## Pushing and pull requests

- `git push` runs the [push review](docs/review/push-review.md): fixed checks, then four AI reviewers. **Never use `--no-verify`.** If the hook isn't switched on (`git config core.hooksPath` doesn't print `.githooks`), stop and tell the author instead of pushing.
- When the review blocks a push, fix the commit it names: `git commit --fixup=<sha>`, then `git rebase --autosquash` onto the branch's base. Don't stack "fix review" commits. If you think a FAIL is wrong, tell the author: only the author adds a `Review-note:` trailer.
- Work on a branch named after the task (`m0/02-solution-apphost`), never on `main`. Push the branch, then open a pull request with `gh pr create`. Its description includes the "For the PR description" section of the review report in `.git/push-reviews/`.
- **Never merge.** The author reviews and merges every pull request, with rebase-and-merge. Force-push only your own pull request's branch, with `--force-with-lease`.

## Ask the author first

- Anything visible outside this machine: creating or changing the GitHub repository, its settings, rulesets or secrets, publishing anything, sending email.
- Anything needing the phone or a person: steps on the Galaxy A5, the tunnel's sign-in, designs, the app's name and icon, accepting screens and their visual baselines.
- Changes to the push review itself (the scripts in `.githooks/`, the checklist and `.claude/agents/push-reviewer.md`), and any exception that loosens one of its checks (`.githooks/allowed-secrets.txt`, `.gitleaks.toml`).

## Safety

- **Personal data:** never read, print or edit `.git/info/personal-strings`. Never write a real person's name, email address, phone number, home address or a local user path (`C:\Users\…`) into a file, commit or output. The people in the spec are fictional: the Rivera family and `@example.com` addresses. Documents call the repository's owner "the author".
- **Destructive git commands** (`reset --hard`, `clean`, `checkout --`, `branch -D`, `rebase`): first check that `git rev-parse --show-toplevel` is the repository you mean and that the working tree holds nothing you'd lose. In scripts, stop when a `cd` fails (`cd <dir> || exit 1`); a failed `cd` must never leave a command running in the wrong repository.
- **Throwaway work** (spikes, experiments, test clones) lives outside the repository and is never committed.

## Where things are

| Path | What |
|---|---|
| `spec/` | Intent, spec, architecture, sync contract, milestones and their reviews |
| `docs/plan/` | The plan for the current milestone, task by task |
| `docs/adr/` | Architecture decision records |
| `docs/conventions.md` | Code, tests, commits, branches and pull requests |
| `docs/review/push-review.md` | What every push is checked against |
| `.githooks/` | The pre-push hook and its checks |
| `.claude/agents/push-reviewer.md` | The reviewer the hook runs |

Documents use plain English, short sentences and British spelling ("licence", "colour"), as the existing ones do. A decision is recorded with its date and "the author", never a personal name.
