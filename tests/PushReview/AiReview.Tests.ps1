# The hook's side of the AI review (docs/review/push-review.md, Part 2), which needs no
# AI to test: how an answer is checked before it's trusted, the reason shown when a run
# fails, how review notes clear a FAIL, and the cache key.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:RepoRoot = New-TestRepository
    . (Join-Path $HooksDirectory 'lib/Process.ps1')
    . (Join-Path $HooksDirectory 'lib/Git.ps1')
    . (Join-Path $HooksDirectory 'lib/FixedChecks.ps1')
    . (Join-Path $HooksDirectory 'lib/AiReview.ps1')

    $script:FixtureSha = Add-TestCommit $RepoRoot -Files @{ 'README.md' = "# Test`n" }
}

AfterAll { Remove-TestRepository $RepoRoot }

Describe 'Checking an answer before it''s trusted' {
    BeforeAll {
        $script:Reviewed = @(
            New-TestCommit "docs: first`n`nWhy." -Sha ('a' * 40)
            New-TestCommit "docs: second`n`nWhy." -Sha ('b' * 40)
        )

        function New-Answer([string] $Pass = 'developer') {
            @{
                pass     = $Pass
                verdict  = 'PASS'
                summary  = 'Both commits are fine.'
                findings = @(@{ id = 'D4'; severity = 'NIT'; commit = 'aaaaaaa'; file = 'a.cs'; line = 3; evidence = 'A long name.'; fix = 'Shorten it.' })
                commits  = @(
                    @{ commit = 'aaaaaaaaa'; summary = 'First.'; talkingPoints = 'One.' }
                    @{ commit = 'bbbbbbbbb'; summary = 'Second.'; talkingPoints = 'Two.' }
                )
            }
        }

        function Read-Answer([hashtable] $Answer, [string] $Pass = 'developer') {
            $stdout = @{ is_error = $false; result = ''; structured_output = $Answer } | ConvertTo-Json -Depth 10
            Read-ReviewPass $Pass ([pscustomobject]@{ ExitCode = 0; StdOut = $stdout; StdErr = '' }) $Reviewed
        }
    }

    It 'accepts a well-formed answer' {
        $read = Read-Answer (New-Answer)
        $read.Error | Should -BeNullOrEmpty
        $read.Result.findings[0].id | Should -Be 'D4'
    }

    It 'refuses an answer for another pass' {
        (Read-Answer (New-Answer 'reader')).Error | Should -Be "its answer can't be used: it answered for pass 'reader'"
    }

    It 'refuses a finding id from another pass' {
        $answer = New-Answer
        $answer.findings[0].id = 'R1'
        (Read-Answer $answer).Error | Should -Be "its answer can't be used: finding id 'R1' isn't a developer question"
    }

    It 'refuses a finding that names <Case>' -ForEach @(
        @{ Case = 'a commit that isn''t being reviewed'; Commit = 'ccccccc' }
        @{ Case = 'a commit by an id shorter than seven characters'; Commit = 'aaaaaa' }
    ) {
        $answer = New-Answer
        $answer.findings[0].commit = $Commit
        (Read-Answer $answer).Error | Should -Be "its answer can't be used: finding D4 names commit '$Commit', which isn't being reviewed"
    }

    It 'refuses a FAIL without evidence' {
        $answer = New-Answer
        $answer.verdict = 'FAIL'
        $answer.findings[0].severity = 'FAIL'
        $answer.findings[0].evidence = ' '
        (Read-Answer $answer).Error | Should -Be "its answer can't be used: FAIL D4 has no evidence"
    }

    It 'refuses a verdict of <Verdict> with <Case>' -ForEach @(
        @{ Verdict = 'PASS'; Severity = 'FAIL'; Case = 'a FAIL among the findings' }
        @{ Verdict = 'FAIL'; Severity = 'NIT'; Case = 'no FAIL among the findings' }
    ) {
        $answer = New-Answer
        $answer.verdict = $Verdict
        $answer.findings[0].severity = $Severity
        (Read-Answer $answer).Error | Should -Be "its answer can't be used: its verdict $Verdict contradicts its findings"
    }

    It 'refuses an answer with no summary for one of the commits' {
        $answer = New-Answer
        $answer.commits = @($answer.commits[0])
        (Read-Answer $answer).Error | Should -Be "its answer can't be used: it has no summary for commit bbbbbbbbb"
    }

    It 'refuses output that isn''t JSON' {
        (Read-ReviewPass 'developer' ([pscustomobject]@{ ExitCode = 0; StdOut = 'Sorry, I can''t'; StdErr = '' }) $Reviewed).Error |
            Should -Be 'its output isn''t JSON'
    }
}

Describe 'The reason shown when a run fails' {
    BeforeAll {
        $script:Reviewed = @(New-TestCommit "docs: first`n`nWhy." -Sha ('a' * 40))
        $script:LimitOutput = @{ is_error = $true; result = 'Usage limit reached for maria@example.com' } | ConvertTo-Json
    }

    It 'gives the error output of a run that failed' {
        (Read-ReviewPass 'developer' ([pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = 'Not signed in' }) $Reviewed).Error |
            Should -Be 'Claude Code exited with 1: Not signed in'
    }

    It 'takes the reason from the JSON output when the error output is empty' {
        (Read-ReviewPass 'developer' ([pscustomobject]@{ ExitCode = 1; StdOut = $LimitOutput; StdErr = '' }) $Reviewed).Error |
            Should -Be 'Claude Code exited with 1: Usage limit reached for maria@example.com'
    }

    It 'never quotes the sensitive-data pass''s own text, <Case>' -ForEach @(
        @{ Case = 'when the run fails'; ExitCode = 1 }
        @{ Case = 'when it returns no structured result'; ExitCode = 0 }
    ) {
        $reason = (Read-ReviewPass 'sensitive' ([pscustomobject]@{ ExitCode = $ExitCode; StdOut = $LimitOutput; StdErr = '' }) $Reviewed).Error
        $reason | Should -Match 'not shown for the sensitive-data pass'
        $reason | Should -Not -Match 'example\.com'
    }

    It 'shows a sensitive-data finding outside the local report only by its id and place' {
        $finding = [pscustomobject]@{ id = 'S2'; severity = 'FAIL'; file = 'notes.md'; line = 4; evidence = 'The line names maria@example.com.'; fix = 'Remove it.' }
        Format-Finding $finding -Public | Should -Be 'FAIL S2 notes.md:4, details in the local report'
    }
}

Describe 'Review notes clearing a FAIL' {
    BeforeAll {
        $script:StateDirectory = Join-Path $RepoRoot '.git/push-reviews'
        Mock Resolve-Executable { 'claude' } -ParameterFilter { $Name -eq 'claude' }
        Mock Get-ChecklistVersion { 'checklist-1' }

        # Stores a review of the commit for every pass, as if each had already run, so
        # Invoke-AiReview reads the stored answers and asks no one.
        function Invoke-StoredReview([string] $Trailers, [object[]] $DeveloperFindings) {
            $file = "f$([guid]::NewGuid().ToString('N').Substring(0, 8)).txt"
            $sha = Add-TestCommit $RepoRoot -Files @{ $file = 'content' } -Message "docs(plan): add a file`n`nWhy.`n`nTask: M0.1`n$Trailers".TrimEnd()
            $commit = Get-Commit $sha
            $key = Get-ReviewKey $commit 'checklist-1'
            New-Item -ItemType Directory -Force -Path (Join-Path $StateDirectory 'cache') | Out-Null
            foreach ($pass in $PassQuestions.Keys) {
                $findings = if ($pass -eq 'developer') { @($DeveloperFindings) } else { @() }
                $verdict = if (@($findings | Where-Object severity -EQ 'FAIL').Count -gt 0) { 'FAIL' } else { 'PASS' }
                @{ Pass = $pass; ReviewedSha = $sha; Verdict = $verdict; Findings = $findings; Summary = 's'; TalkingPoints = 't'; PassSummary = 's' } |
                    ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $StateDirectory "cache/$key.$pass.json") -Encoding utf8NoBOM
            }
            Invoke-AiReview @($commit) $sha $StateDirectory
        }

        function New-Finding([string] $Id, [string] $Severity = 'FAIL') {
            @{ id = $Id; severity = $Severity; commit = 'x'; file = 'a.cs'; line = 1; evidence = 'Evidence.'; fix = 'Fix.' }
        }
    }

    It 'blocks on a FAIL without a note' {
        $review = Invoke-StoredReview '' @(New-Finding 'D4')
        $review.Passed | Should -BeFalse
        $review.Outcome[0].Blocking.id | Should -Be 'D4'
    }

    It 'passes when a note names the FAIL and gives a reason' {
        $review = Invoke-StoredReview "Review-note: D4, EF Core's design-time tools need the second constructor" @(New-Finding 'D4')
        $review.Passed | Should -BeTrue
        $review.Outcome[0].Unmatched | Should -BeNullOrEmpty
    }

    It 'clears every FAIL with the id the note names' {
        $review = Invoke-StoredReview 'Review-note: D4, both are needed' @((New-Finding 'D4'), (New-Finding 'D4'))
        $review.Passed | Should -BeTrue
    }

    It 'ignores a note with no reason' {
        $review = Invoke-StoredReview 'Review-note: D4' @(New-Finding 'D4')
        $review.Passed | Should -BeFalse
        $review.Outcome[0].Unmatched.Id | Should -Be 'D4'
    }

    It 'ignores a note for a FAIL the stored review didn''t raise' {
        $review = Invoke-StoredReview 'Review-note: D2, not raised' @(New-Finding 'D4')
        $review.Passed | Should -BeFalse
        $review.Outcome[0].Unmatched.Id | Should -Be 'D2'
        $review.Outcome[0].Blocking.id | Should -Be 'D4'
    }

    It 'doesn''t block on FLAGs and NITs' {
        (Invoke-StoredReview '' @((New-Finding 'D1' 'FLAG'), (New-Finding 'D2' 'NIT'))).Passed | Should -BeTrue
    }
}

Describe 'The cache key' {
    BeforeAll {
        $script:Base = Add-TestCommit $RepoRoot -Files @{ 'key/a.txt' = "one`ntwo`nthree`n"; 'key/b.txt' = 'b' }
        $script:Change = "docs(plan): change a`n`nWhy.`n`nTask: M0.1"
        $script:Original = Get-Commit (Add-TestCommit $RepoRoot -Files @{ 'key/a.txt' = "one`n2`nthree`n" } -Message $Change)

        function Get-Key([object] $Commit, [string] $Version = 'checklist-1') { Get-ReviewKey $Commit $Version }
    }

    It 'stays the same when a rebase gives the commit a new id' {
        Invoke-TestGit $RepoRoot switch --quiet --detach $Base | Out-Null
        Add-TestCommit $RepoRoot -Files @{ 'key/b.txt' = 'b changed' } | Out-Null
        Invoke-TestGit $RepoRoot cherry-pick $Original.Sha | Out-Null
        $rebased = Get-Commit "$(Invoke-TestGit $RepoRoot rev-parse HEAD)".Trim()
        $rebased.Sha | Should -Not -Be $Original.Sha
        Get-Key $rebased | Should -Be (Get-Key $Original)
    }

    It 'stays the same when a Review-note trailer is added' {
        $noted = New-TestCommit "$Change`nReview-note: D4, a reason" -Sha $Original.Sha
        Get-Key $noted | Should -Be (Get-Key $Original)
    }

    It 'changes when the message changes' {
        Get-Key (New-TestCommit "$Change`nSpec: none" -Sha $Original.Sha) | Should -Not -Be (Get-Key $Original)
    }

    It 'changes when the checklist version changes' {
        Get-Key $Original 'checklist-2' | Should -Not -Be (Get-Key $Original)
    }

    It 'tells apart two commits that change only an image, in different ways' {
        Invoke-TestGit $RepoRoot switch --quiet --detach $Base | Out-Null
        $first = Get-Commit (Add-TestCommit $RepoRoot -Files @{ 'key/logo.png' = [byte[]](137, 80, 78, 71, 1) } -Message $Change)
        Invoke-TestGit $RepoRoot switch --quiet --detach $Base | Out-Null
        $second = Get-Commit (Add-TestCommit $RepoRoot -Files @{ 'key/logo.png' = [byte[]](137, 80, 78, 71, 2) } -Message $Change)
        Get-Key $first | Should -Not -Be (Get-Key $second)
    }
}
