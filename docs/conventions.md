# Conventions

How code, tests, commits and pull requests are written in this repo. Draft 2 · 2026-11-10 · for review by the author.

## Code

- **Vertical slices** on the server: `Features/<Area>/<UseCase>/` holds the endpoint, request, handler, validator and tests for one use case ([architecture §1](../spec/architecture.md#1-shape-of-the-system)). Shared domain types live in `Domain/`.
- **Style** is in `.editorconfig` and enforced in the build: rules set to `warning` fail it, because warnings are errors.
- **Comments** say why, not what. A comment that repeats the code is deleted.
- **C# 15 features** are used where they make the code clearer. Notes on closed hierarchies and union types are added here when the first code that uses them arrives (M3, M7).

## Tests

- A test that proves a requirement starts with its spec id, with the dash as an underscore: `SEC_02_ordinary_request_over_64KB_is_refused_with_413`.
- A test that proves a worked example starts with the example's id: `X13_tick_on_an_offline_extra_splits_the_merged_line`, `C1_resent_batch_returns_the_stored_results`.
- Other tests describe the behaviour in plain words: `Unknown_api_path_returns_404_problem_details_not_html`.
- A test asserts the outcome, not only that something exists. A skipped test carries the reason and the issue that will re-enable it.

## Commits

One logical change per commit. The message:

```
<type>(<area>)[!]: <what it does: imperative, lowercase, no period, at most 72 characters in total>

<Why: the problem, requirement or decision behind it. One to three short
paragraphs, wrapped at 72 characters.>

<What changed, if the diff doesn't make it obvious.>

Spec: SEC-02, SEC-05
Task: M0.6
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

### Subject

- **Types:** `feat` (new behaviour), `fix` (a bug), `test` (tests only), `docs` (documents only), `build` (projects, packages, SDK, repo configuration), `ci` (GitHub Actions), `refactor` (no behaviour change), `chore` (anything else).
- **Area:** the project where the behaviour lives: `server`, `client`, `ui`, `data` or `apphost`; for documents `spec`, `plan`, `adr` or `review`; `deps` for dependency updates; `repo` for repo-wide configuration. A `test` commit names the code under test (`test(server)`), not the tests. The area is left out when a change has no single home, such as a slice that spans server and client equally, or a `ci` change.
- **The text** starts with a lowercase verb in the imperative ("add", "refuse", "fix"), has no full stop at the end, and the whole subject line is at most 72 characters.
- **`!` marks a breaking change**, together with a `BREAKING-CHANGE:` trailer that says what breaks and what phones or people need to do. It's written with a hyphen: git reads the last paragraph as trailers only if every line in it is one, and a key with a space isn't, so `BREAKING CHANGE:` would hide the `Spec:` and `Task:` trailers too. Before v1, the outbox format must not change at all ([sync contract §7](../spec/sync-contract.md#7-versions-and-sessions)), so a breaking change to it fails the push review.
- **Two exceptions** to the pattern: `git revert` subjects (`Revert "<original subject>"`), and Dependabot's (below).

The hook and CI check the subject with exactly this pattern (extended regular expression, the same in `grep -E`, .NET and PowerShell), so the two can't drift apart:

```
^(feat|fix|test|docs|build|ci|refactor|chore)(\((server|client|ui|data|apphost|spec|plan|adr|review|deps|deps-dev|repo)\))?!?: [a-z].*[^.]$
^Revert ".+"$
```

and separately check that the subject is at most 72 characters. The pattern was tested on 2026-11-10 against the example subjects in this document (all accepted) and against `test(tests): …`, a capitalised first word, a trailing full stop, the old unformatted subjects and an 83-character subject (all rejected).

### Body

- **Required**, and it says why. "Fix bug" or "update files" is never enough.
- Wrapped at 72 characters.

### Trailers

Trailers are the **last paragraph** of the message, one per line, with no blank lines between them, so `git interpret-trailers --parse` (which the hook uses) reads them all.

| Trailer | When | Value |
|---|---|---|
| `Spec:` | every `feat`, `fix` and `test` commit | the requirement or worked-example ids the commit implements or changes (`SEC-02, X13`), or `none` when there's no id, for example a bug in the AppHost. `none` is a visible choice, not a forgotten trailer |
| `Task:` | every commit that belongs to a plan task | the milestone and task number from its plan: `M0.6` is task 6 in `docs/plan/M0.md`. The hook checks that the task exists |
| `Issue:` | instead of `Task:`, for work outside any plan task | the GitHub issue: `Issue: #12` (a bug found after a milestone closed, a manual dependency update) |
| `BREAKING-CHANGE:` | with `!` in the subject | what breaks and what to do about it |
| `Review-note:` | when the author overrules a FAIL from the push review | the finding's id and the reason. The note is binding ([push review](review/push-review.md#when-the-reviewer-is-wrong)) |
| `Co-Authored-By:` | when an AI agent wrote the change | `Claude Opus 5.5 <noreply@anthropic.com>` |

`feat`, `fix` and `test` commits need `Spec:` and either `Task:` or `Issue:`. Other types need `Task:` or `Issue:` too, except Dependabot's and reverts.

### Example

```
feat(server): refuse request bodies over 64 KB with ProblemDetails

SEC-02 requires oversized requests to be refused before they're read
in full. Kestrel's limit already stops reading at 64 KB; this maps the
resulting BadHttpRequestException to a 413 ProblemDetails, so the
response carries the same CSP and error shape as every other response.

Spec: SEC-02
Task: M0.6
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

### Dependabot

Dependabot is configured (`.github/dependabot.yml`, M0 task 3) with `commit-message: { prefix: build, include: scope }` for NuGet and the SDK, and `prefix: ci` for GitHub Actions, so its subjects read `build(deps): bump Npgsql from 10.0.3 to 10.0.4` and `ci(deps): bump actions/checkout from 4 to 5`. Its commits can't carry a body in our format or our trailers, so for commits authored by `dependabot[bot]` CI checks only the subject. GitHub's documentation doesn't say whether Dependabot writes "bump" or "Bump" after a prefix, or when it uses `deps-dev` instead of `deps`, so for `dependabot[bot]` the check accepts either case and both scopes. Its first PR confirms what it actually writes.

## Branches and pull requests

- **From M0 task 3 on**, `main` only changes through a pull request with CI green. (M0 task 1 is direct commits, because there's no repo or CI yet, and task 2 merges before CI exists.)
- One branch and one PR per plan task, named after it: `m0/06-server-hardening`.
- The PR description has: what and why, the spec ids, how it was tested, and the push review's summary with its FLAGs, NITs and any review notes ([push review](review/push-review.md#verdict-and-output)).
- The agent opens PRs; the author reviews and merges.
- **Merging is rebase-and-merge only**, with "Require linear history" on in the ruleset for `main`. Squash merging would collapse each task's reviewed commits, messages and trailers into one, and merge commits would clutter the history. With rebase-and-merge, every commit the push review checked lands on `main` with its message and content unchanged. GitHub does give each commit a new id when it rebases it, so reviews are tied to the PR, not to commit ids.
- **Review feedback on an open PR** is folded into the commit it belongs to, not added as a "fix review" commit:
  ```
  git commit --fixup=<sha of the commit being fixed>
  git rebase --autosquash main
  git push --force-with-lease
  ```
  Force-pushing is allowed on PR branches; the ruleset blocks it only on `main`. The rewritten commits go through the push review again.
