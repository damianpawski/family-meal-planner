# F2 and F4 of the push review (docs/review/push-review.md, Part 1): the noreply emails
# and the commit format from docs/conventions.md#commits.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:RepoRoot = New-TestRepository
    . (Join-Path $HooksDirectory 'lib/Process.ps1')
    . (Join-Path $HooksDirectory 'lib/Git.ps1')
    . (Join-Path $HooksDirectory 'lib/FixedChecks.ps1')

    # F4 looks up spec ids and plan tasks in the commit being checked.
    $script:FixtureSha = Add-TestCommit $RepoRoot -Files @{
        'docs/plan/M0.md'       = "# Plan: M0`n`n### 1. Repo bootstrap`n`n### 6. Server hardening`n"
        'spec/spec.md'          = "| Id | Requirement |`n|---|---|`n| SEC-02 | Oversized requests are refused |`n"
        'spec/sync-contract.md' = "| Id | Example |`n|---|---|`n| X13 | A tick on an offline extra |`n"
    }

    function Get-FormatProblem([string] $Message, [string] $AuthorName = 'Test Author') {
        @(Test-CommitFormat @(New-TestCommit $Message -AuthorName $AuthorName))
    }

    function Get-OnlyProblem([object[]] $Problems) {
        $Problems | Should -HaveCount 1
        $Problems[0]
    }
}

AfterAll { Remove-TestRepository $RepoRoot }

Describe 'F4: the subject pattern' {
    # The cases docs/conventions.md#subject says the pattern was tested against.
    It 'accepts <Subject>' -ForEach @(
        @{ Subject = 'feat(server): refuse request bodies over 64 KB with ProblemDetails' }
        @{ Subject = 'docs(spec): add spec, architecture, sync contract, milestones, M0 plan' }
        @{ Subject = 'docs(spec): record decisions on sync, compatibility and acceptance' }
        @{ Subject = 'build(deps): bump Npgsql from 10.0.3 to 10.0.4' }
        @{ Subject = 'ci(deps): bump actions/checkout from 4 to 5' }
        @{ Subject = 'docs: record that the author agreed the push review checklist' }
        @{ Subject = 'feat(server)!: change the outbox format' }
    ) {
        $Subject | Should -MatchExactly $SubjectPattern
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'an area that names the tests, not the code'; Subject = 'test(tests): cover the command parser' }
        @{ Case = 'a capitalised first word'; Subject = 'feat(server): Refuse oversized requests' }
        @{ Case = 'a capitalised type'; Subject = 'Feat(server): refuse oversized requests' }
        @{ Case = 'a full stop at the end'; Subject = 'fix(server): refuse oversized requests.' }
        @{ Case = 'the first old unformatted subject'; Subject = 'Add spec, architecture, sync contract, milestones and M0 plan' }
        @{ Case = 'the second old unformatted subject'; Subject = 'Record decisions on sync, compatibility and acceptance' }
        @{ Case = 'an unknown type'; Subject = 'feature(server): refuse oversized requests' }
        @{ Case = 'a missing space after the colon'; Subject = 'feat(server):refuse oversized requests' }
    ) {
        $Subject | Should -Not -MatchExactly $SubjectPattern
    }

    It 'refuses a subject of 83 characters' {
        $subject = 'docs(plan): ' + ('x' * 71)
        (Get-OnlyProblem (Get-FormatProblem "$subject`n`nWhy.`n`nTask: M0.6")).Problem |
            Should -Be 'the subject has 83 characters; the limit is 72'
    }

    It 'accepts a revert subject with a body and no trailers' {
        Get-FormatProblem "Revert ""feat(server): add ping""`n`nThe ping broke the build." | Should -BeNullOrEmpty
    }
}

Describe 'F4: body and trailers' {
    It 'accepts a complete feat commit' {
        Get-FormatProblem "feat(server): refuse oversized requests`n`nSEC-02 says why.`n`nSpec: SEC-02, X13`nTask: M0.6" |
            Should -BeNullOrEmpty
    }

    It 'refuses a commit with no body' {
        (Get-OnlyProblem (Get-FormatProblem "docs(plan): add a table`n`nTask: M0.6")).Where | Should -Be 'body'
    }

    It 'refuses a second line that isn''t blank' {
        (Get-FormatProblem "docs(plan): add a table`nNot blank.`n`nWhy.`n`nTask: M0.6" | ForEach-Object { $_.Where }) |
            Should -Contain 'message'
    }

    It 'refuses a <Type> commit without Spec' -ForEach @(@{ Type = 'feat' }, @{ Type = 'fix' }, @{ Type = 'test' }) {
        (Get-OnlyProblem (Get-FormatProblem "$Type(server): change something`n`nWhy.`n`nTask: M0.6")).Problem |
            Should -Be "a $Type commit needs 'Spec:' (ids, or 'none')"
    }

    It 'accepts Spec: none' {
        Get-FormatProblem "fix(apphost): wait for the database`n`nWhy.`n`nSpec: none`nTask: M0.6" | Should -BeNullOrEmpty
    }

    It 'refuses the Spec value <Value>' -ForEach @(
        @{ Value = 'SEC-99'; Problem = "'SEC-99' doesn't exist in spec/spec.md or spec/sync-contract.md" }
        @{ Value = 'sec-02'; Problem = "'sec-02' isn't a spec id (like SEC-02), a worked example (like X13 or C1), or 'none'" }
    ) {
        (Get-OnlyProblem (Get-FormatProblem "feat(server): change something`n`nWhy.`n`nSpec: $Value`nTask: M0.6")).Problem |
            Should -Be $Problem
    }

    It 'refuses a commit with neither Task nor Issue' {
        (Get-OnlyProblem (Get-FormatProblem "docs(plan): add a table`n`nWhy.`n`nCo-Authored-By: Test <test@example.com>")).Problem |
            Should -Be "the commit needs 'Task:' (like M0.6) or 'Issue:' (like #12)"
    }

    It 'refuses the Task value <Value>' -ForEach @(
        @{ Value = 'M0.9'; Problem = 'docs/plan/M0.md has no task 9' }
        @{ Value = 'M1a.1'; Problem = "docs/plan/M1a.md doesn't exist" }
        @{ Value = 'task 6'; Problem = "'task 6' isn't a task id like M0.6" }
    ) {
        (Get-OnlyProblem (Get-FormatProblem "docs(plan): add a table`n`nWhy.`n`nTask: $Value")).Problem | Should -Be $Problem
    }

    It 'accepts Issue: #12 instead of Task' {
        Get-FormatProblem "docs(plan): add a table`n`nWhy.`n`nIssue: #12" | Should -BeNullOrEmpty
    }

    It 'refuses an Issue value that isn''t a reference' {
        (Get-OnlyProblem (Get-FormatProblem "docs(plan): add a table`n`nWhy.`n`nIssue: 12")).Problem |
            Should -Be "'12' isn't an issue reference like #12"
    }

    It 'refuses a breaking subject without BREAKING-CHANGE' {
        (Get-OnlyProblem (Get-FormatProblem "feat(server)!: change the outbox`n`nWhy.`n`nSpec: SEC-02`nTask: M0.6")).Problem |
            Should -Be "a subject with '!' needs a 'BREAKING-CHANGE:' trailer"
    }

    It 'accepts a breaking subject with BREAKING-CHANGE' {
        Get-FormatProblem "feat(server)!: change the outbox`n`nWhy.`n`nSpec: SEC-02`nTask: M0.6`nBREAKING-CHANGE: phones must update first" |
            Should -BeNullOrEmpty
    }

    It 'reads no trailers when a key has a space, as BREAKING CHANGE does' {
        # git reads the last paragraph as trailers only if every line in it is one.
        $problems = Get-FormatProblem "feat(server)!: change the outbox`n`nWhy.`n`nSpec: SEC-02`nTask: M0.6`nBREAKING CHANGE: phones must update first"
        $problems.Problem | Should -Contain "the commit needs 'Task:' (like M0.6) or 'Issue:' (like #12)"
    }

    It 'reads no trailers from a paragraph that isn''t the last' {
        $problems = Get-FormatProblem "docs(plan): add a table`n`nWhy.`n`nTask: M0.6`n`nA last paragraph of prose."
        $problems.Problem | Should -Contain "the commit needs 'Task:' (like M0.6) or 'Issue:' (like #12)"
    }

    It 'checks only the subject of a Dependabot commit' {
        Get-FormatProblem 'build(deps): Bump Npgsql from 10.0.3 to 10.0.4' -AuthorName 'dependabot[bot]' | Should -BeNullOrEmpty
    }

    It 'refuses a Dependabot subject outside the agreed format' {
        (Get-OnlyProblem (Get-FormatProblem 'Bump Npgsql from 10.0.3 to 10.0.4' -AuthorName 'dependabot[bot]')).Where |
            Should -Be 'subject'
    }
}

Describe 'F2: noreply emails' {
    BeforeAll {
        $script:DependabotCommit = New-TestCommit 'build(deps): bump Npgsql from 10.0.3 to 10.0.4' -AuthorName 'dependabot[bot]' `
            -AuthorEmail '49699333+dependabot[bot]@users.noreply.github.com' -CommitterEmail 'noreply@github.com'
    }

    It 'accepts commits by the expected noreply address' {
        Test-Emails @(New-TestCommit "docs: x`n`nWhy.") $TestEmail | Should -BeNullOrEmpty
    }

    It 'refuses <Case> as the expected address, without printing it' -ForEach @(
        @{ Case = 'a private address'; Address = 'maria@example.com' }
        @{ Case = 'the old noreply form without the id'; Address = 'maria@users.noreply.github.com' }
    ) {
        $failure = Get-OnlyProblem @(Test-Emails @(New-TestCommit "docs: x`n`nWhy.") $Address)
        $failure.Where | Should -Be 'git config user.email'
        "$($failure.Where) $($failure.Problem)" | Should -Not -Match 'maria'
    }

    It 'refuses a commit whose <Role> email differs, without printing it' -ForEach @(
        @{ Role = 'author'; Author = 'maria@example.com'; Committer = '1+test@users.noreply.github.com' }
        @{ Role = 'committer'; Author = '1+test@users.noreply.github.com'; Committer = 'maria@example.com' }
    ) {
        $failure = Get-OnlyProblem @(Test-Emails @(New-TestCommit "docs: x`n`nWhy." -AuthorEmail $Author -CommitterEmail $Committer) $TestEmail)
        $failure.Where | Should -Be "$Role email"
        $failure.Problem | Should -Not -Match 'maria'
    }

    It 'accepts Dependabot as author and GitHub as committer only in CI mode' {
        Test-Emails @($DependabotCommit) $TestEmail -AllowDependabot | Should -BeNullOrEmpty
        @(Test-Emails @($DependabotCommit) $TestEmail) | Should -HaveCount 2
    }
}
