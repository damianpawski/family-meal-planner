#Requires -Version 7.4
<#
.SYNOPSIS
    The push review gate described in docs/review/push-review.md.

.DESCRIPTION
    Run by .githooks/pre-push, which passes git's arguments (the remote's name and URL)
    and the refs being pushed on standard input. Runs the fixed checks (Part 1) on every
    commit being pushed, then the AI review (Part 2). Exits with 1 to block the push.

    CI repeats the fixed checks on a pull request's commits with -Ci (Part 4): all of
    them except F3, whose list of personal strings exists only on the author's machine,
    and no AI review. No option makes a check more lenient; git push --no-verify skips
    the hook altogether, which is why CI repeats the checks.

.EXAMPLE
    pwsh .githooks/push-review.ps1 -Range origin/main..HEAD -Ci -ExpectedEmail 1+user@users.noreply.github.com
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $RemoteName = 'origin',
    [Parameter(Position = 1)] [string] $RemoteUrl,
    # The commits to check, as git rev-list takes them, instead of reading refs from stdin.
    [string] $Range,
    [switch] $Ci,
    # Defaults to git config user.email; CI passes the author's noreply address.
    [string] $ExpectedEmail
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

. "$PSScriptRoot/lib/Process.ps1"
$script:RepoRoot = (Invoke-Native -FilePath (Resolve-Executable 'git') -ArgumentList @('rev-parse', '--show-toplevel')).StdOut.Trim()
. "$PSScriptRoot/lib/Git.ps1"
. "$PSScriptRoot/lib/FixedChecks.ps1"
. "$PSScriptRoot/lib/AiReview.ps1"

function Get-PushedRefs {
    # One entry per branch being pushed, with the commits no branch on the remote has yet,
    # oldest first. Counting from every remote branch, not only the one being updated,
    # matters twice: a branch's first push doesn't review the whole history again, and a
    # branch rebased onto a newer main doesn't re-check main's commits, which GitHub
    # rewrote (with itself as committer) when it merged them.
    if ($Range) {
        $commits = @(Get-GitLines @('rev-list', '--reverse', $Range))
        return [pscustomobject]@{ Branch = $Range; Tip = $commits[-1]; Shas = $commits }
    }
    foreach ($line in ([Console]::In.ReadToEnd() -split "`n" | Where-Object { $_.Trim() })) {
        $localRef, $localSha, $remoteRef, $remoteSha = $line.Trim() -split ' '
        if ($localSha -match '^0+$') { continue }    # deleting a branch publishes nothing
        $revList = @('rev-list', '--reverse', $localSha)
        # The branch's current tip on the remote is excluded too when this clone has it,
        # in case the remote-tracking branch hasn't been fetched since. It goes before
        # --not, which would otherwise turn the exclusion around.
        if ($remoteSha -notmatch '^0+$' -and (Invoke-Git @('cat-file', '-e', "$remoteSha^{commit}") -AllowFailure).ExitCode -eq 0) {
            $revList += "^$remoteSha"
        }
        $revList += @('--not', "--remotes=$RemoteName")
        [pscustomobject]@{ Branch = $remoteRef -replace '^refs/heads/', ''; Tip = $localSha; Shas = @(Get-GitLines $revList) }
    }
}

function Write-FixedChecks([object[]] $Failures, [bool] $BuildRan) {
    $names = [ordered]@{ F1 = 'secrets'; F2 = 'noreply emails'; F3 = 'personal data'; F4 = 'commit format'; F6 = 'forbidden files and values'; F5 = 'build and unit tests' }
    if ($Ci) { $names.Remove('F3') }
    foreach ($check in $names.Keys) {
        $found = @($Failures | Where-Object Check -EQ $check)
        if ($check -eq 'F5' -and -not $BuildRan) {
            Write-Host "  F5 $($names[$check]): not run, because other checks failed"
            continue
        }
        if ($found.Count -eq 0) {
            Write-Host "  $check $($names[$check]): passed"
            continue
        }
        Write-Host "  $check $($names[$check]): FAILED" -ForegroundColor Red
        foreach ($failure in $found) { Write-Host "      $($failure.Commit) $($failure.Where): $($failure.Problem)" -ForegroundColor Red }
    }
}

try {
    $stateDirectory = (Invoke-Git @('rev-parse', '--path-format=absolute', '--git-path', 'push-reviews')).StdOut.Trim()
    $refs = @(Get-PushedRefs | Where-Object { $_.Shas.Count -gt 0 })
    $shas = @($refs | ForEach-Object { $_.Shas } | Select-Object -Unique)
    if ($shas.Count -eq 0) { exit 0 }
    $commits = @($shas | ForEach-Object { Get-Commit $_ })
    if (-not $ExpectedEmail) { $ExpectedEmail = (Invoke-Git @('config', 'user.email') -AllowFailure).StdOut.Trim() }
    $personalStrings = (Invoke-Git @('rev-parse', '--path-format=absolute', '--git-path', 'info/personal-strings')).StdOut.Trim()

    Write-Host "Push review: $($commits.Count) commit(s) (docs/review/push-review.md)"
    Write-Host 'Part 1, fixed checks:'
    $failures = @(
        Test-Emails $commits $ExpectedEmail -AllowDependabot:$Ci
        Test-CommitFormat $commits
        Test-ForbiddenContent $commits
        if (-not $Ci) {
            Test-PersonalData $commits $personalStrings
        }
        Test-Secrets $commits
    )
    # Building every commit is slow, so it only runs once everything else has passed.
    $buildRan = $failures.Count -eq 0
    if ($buildRan) { $failures = @(Test-Build $commits $stateDirectory) }
    if (-not $Ci) { $failures = @(Hide-PersonalData $failures $personalStrings) }
    Write-FixedChecks $failures $buildRan
    if ($failures.Count -gt 0) {
        Write-Host 'Push blocked by the fixed checks. These can''t be overruled; fix the commits or the check''s input.' -ForegroundColor Red
        exit 1
    }
    if ($Ci) { exit 0 }

    Write-Host 'Part 2, AI review:'
    $passed = $true
    foreach ($ref in $refs) {
        $refCommits = @($commits | Where-Object { $_.Sha -in $ref.Shas })
        $review = Invoke-AiReview $refCommits $ref.Tip $stateDirectory
        Write-AiReview $review
        $report = Write-ReviewReport $review $ref.Branch $stateDirectory
        Write-Host "  Report: $report"
        $passed = $passed -and $review.Passed
    }
    if (-not $passed) {
        Write-Host 'Push blocked by the AI review. Fix the commits, or overrule a FAIL with a Review-note: trailer (docs/review/push-review.md).' -ForegroundColor Red
        exit 1
    }
    Write-Host 'Push review passed.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "Push blocked: the review couldn't complete. $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  at $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor DarkGray
    exit 1
}
