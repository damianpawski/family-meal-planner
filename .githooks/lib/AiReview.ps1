# The AI review from docs/review/push-review.md, Part 2: four passes, each a separate
# headless Claude Code run with read-only tools in a checkout of the pushed commits. The
# hook, not the AI, decides the outcome: it checks each answer, caches it by commit
# content, and applies the author's review notes.

$script:PassQuestions = [ordered]@{
    sensitive = @('S1', 'S2', 'S3')
    developer = @('D1', 'D2', 'D3', 'D4', 'D5', 'D6')
    architect = @('A1', 'A2', 'A3', 'A4')
    reader    = @('R1', 'R2', 'R3', 'R4')
}
$script:PassTitles = @{ sensitive = 'Sensitive data'; developer = 'Senior developer'; architect = 'Architect'; reader = 'Outside reader' }
$script:ReviewDefinition = @('docs/review/push-review.md', '.claude/agents/push-reviewer.md', '.githooks/review-result.schema.json')
$script:ImageExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.ico')
$script:PassTimeout = [TimeSpan]::FromMinutes(30)

# --- Cache keys ---------------------------------------------------------------------------

function Get-ChecklistVersion([string] $TipSha) {
    # The review is defined by these files as pushed; changing any of them is a new checklist.
    $ids = foreach ($path in $script:ReviewDefinition) {
        $result = Invoke-Git @('rev-parse', "${TipSha}:$path") -AllowFailure
        if ($result.ExitCode -ne 0) { throw "$path isn't in the commits being pushed, so the AI review can't run." }
        $result.StdOut.Trim()
    }
    $ids -join ','
}

function Remove-ReviewNotes([string] $Message) {
    ((($Message -split "`n") | Where-Object { $_ -notmatch '^Review-note:' }) -join "`n").TrimEnd()
}

function Get-ReviewKey([object] $Commit, [string] $ChecklistVersion) {
    # Same content, same message (review notes aside) and same checklist: same answer.
    # Leaving review notes out means adding one can't trigger a fresh review.
    $patchId = ((Invoke-Git @('patch-id', '--stable') -StandardInput (Get-CommitPatch $Commit.Sha 3)).StdOut -split ' ')[0].Trim()
    if (-not $patchId) { $patchId = "empty:$($Commit.Tree)" }
    $text = "$patchId`n$ChecklistVersion`n$(Remove-ReviewNotes $Commit.Message)"
    [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($text))).ToLower()
}

# --- Running a pass -----------------------------------------------------------------------

function New-ReviewBundle([object[]] $Commits, [string] $Directory) {
    New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    $text = [System.Text.StringBuilder]::new()
    [void]$text.AppendLine('# Commits to review, oldest first').AppendLine()
    $index = 0
    foreach ($commit in $Commits) {
        $index++
        $images = @(Get-ChangedFiles $commit.Sha | Where-Object { [System.IO.Path]::GetExtension($_.Path).ToLower() -in $script:ImageExtensions })
        foreach ($image in $images) {
            Save-Blob $commit.Sha $image.Path (Join-Path $Directory "images/$($commit.Short)/$($image.Path)")
        }
        $stat = (Invoke-Git @('diff-tree', '--root', '-r', '--no-commit-id', '--stat=120', '--diff-merges=first-parent', $commit.Sha)).StdOut
        # Lock files are listed in the stat but their diffs are left out: they're generated,
        # long, and not reviewed line by line (R2 doesn't count them either).
        $patch = (Invoke-Git @('diff-tree', '-p', '--root', '-r', '--no-commit-id', '--no-color', '--no-ext-diff',
                '--diff-merges=first-parent', $commit.Sha, '--', '.', ':(exclude,glob)**/packages.lock.json')).StdOut

        [void]$text.AppendLine("## Commit $index of $($Commits.Count): $($commit.Sha)").AppendLine()
        [void]$text.AppendLine("Author: $($commit.AuthorName)").AppendLine()
        [void]$text.AppendLine('### Message').AppendLine().AppendLine('````text').AppendLine($commit.Message).AppendLine('````').AppendLine()
        [void]$text.AppendLine('### Files changed').AppendLine().AppendLine('````text').AppendLine($stat.TrimEnd()).AppendLine('````').AppendLine()
        if ($images) {
            [void]$text.AppendLine('### Images added or changed').AppendLine()
            foreach ($image in $images) { [void]$text.AppendLine("- $($image.Path): images/$($commit.Short)/$($image.Path)") }
            [void]$text.AppendLine()
        }
        [void]$text.AppendLine('### Diff').AppendLine().AppendLine('````diff').AppendLine($patch.TrimEnd()).AppendLine('````').AppendLine()
    }
    [System.IO.File]::WriteAllText((Join-Path $Directory 'commits.md'), $text.ToString(), $script:Utf8NoBom)
}

function Write-AgentDefinition([string] $TipSha, [string] $Path) {
    # --restricted ignores everything under .claude/, which is what keeps settings or hooks
    # in the pushed commits from running. So the agent is handed over with --agents, built
    # from .claude/agents/push-reviewer.md as pushed. It carries no tool list: --tools sets
    # the tools, and an agent's own list would also hide the channel through which Claude
    # Code returns the structured result.
    $markdown = Get-FileAtCommit $TipSha '.claude/agents/push-reviewer.md'
    if ($markdown -notmatch '(?s)^---\r?\n(?<front>.*?)\r?\n---\r?\n(?<body>.*)$') {
        throw '.claude/agents/push-reviewer.md has no front matter.'
    }
    $body = $Matches.body.Trim()
    $fields = @{}
    foreach ($line in ($Matches.front -split '\r?\n')) {
        $key, $value = $line -split ':\s*', 2
        $fields[$key.Trim()] = "$value".Trim()
    }
    $agent = @{
        description = $fields.description
        prompt      = $body
        model       = $fields.model
    }
    @{ $fields.name = $agent } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

function Start-ReviewPass([string] $Pass, [object[]] $Commits, [string] $Worktree, [string] $Bundle, [string] $Schema) {
    $prompt = @"
Run the '$Pass' pass of the push review: questions $($script:PassQuestions[$Pass] -join ', ') in docs/review/push-review.md.
Commits to review, oldest first: $($Commits.Sha -join ', ').
Their messages, changed files and diffs are in $Bundle/commits.md; added or changed images are under $Bundle/images/.
The working folder is a checkout of the newest commit being pushed.
"@
    # --restricted confines the file tools to the checkout and the bundle and ignores all
    # settings files; --tools leaves only reading and searching. No shell, no edits, no
    # network.
    Start-Native -FilePath $script:ClaudeExe -WorkingDirectory $Worktree -ArgumentList @(
        '--print', $prompt,
        '--agents', (Join-Path $Bundle 'agents.json'), '--agent', 'push-reviewer',
        '--restricted', '--tools', 'Read,Grep,Glob', '--strict-mcp-config', '--permission-prompts', 'none',
        '--add-dir', $Bundle,
        '--no-session-persistence', '--output-format', 'json', '--json-schema', $Schema)
}

function Resolve-ReviewedCommit([string] $Reference, [object[]] $Commits) {
    $reference = "$Reference".Trim().ToLower()
    if ($reference.Length -lt 7) { return $null }
    $Commits | Where-Object { $_.Sha.StartsWith($reference) } | Select-Object -First 1
}

function Read-ReviewPass([string] $Pass, [object] $Run, [object[]] $Commits) {
    # Returns the pass's result, or the reason it can't be used. An answer the hook can't
    # check counts as a FAIL, never as a PASS. The reason is printed, so for the
    # sensitive-data pass it never quotes the run's own text, which may repeat what the
    # reviewer found.
    $quote = { param($text) if ($Pass -eq 'sensitive') { '(not shown for the sensitive-data pass)' } else { $text } }
    if ($Run.ExitCode -ne 0) {
        return [pscustomobject]@{ Error = "Claude Code exited with $($Run.ExitCode): $(& $quote (Get-Tail $Run.StdErr 5))"; Result = $null }
    }
    try { $output = $Run.StdOut | ConvertFrom-Json }
    catch { return [pscustomobject]@{ Error = 'its output isn''t JSON'; Result = $null } }
    if ($output.is_error -or -not $output.structured_output) {
        $text = "$($output.result)".Trim()
        if ($text.Length -gt 200) { $text = $text.Substring(0, 200) + '…' }
        return [pscustomobject]@{ Error = "it returned no structured result: $(& $quote $text)"; Result = $null }
    }

    $result = $output.structured_output
    $problems = [System.Collections.Generic.List[string]]::new()
    if ($result.pass -ne $Pass) { $problems.Add("it answered for pass '$($result.pass)'") }
    foreach ($finding in @($result.findings)) {
        if ($finding.id -notin $script:PassQuestions[$Pass]) { $problems.Add("finding id '$($finding.id)' isn't a $Pass question") }
        if (-not (Resolve-ReviewedCommit $finding.commit $Commits)) { $problems.Add("finding $($finding.id) names commit '$($finding.commit)', which isn't being reviewed") }
        if ($finding.severity -eq 'FAIL' -and -not "$($finding.evidence)".Trim()) { $problems.Add("FAIL $($finding.id) has no evidence") }
    }
    $hasFail = @($result.findings | Where-Object severity -EQ 'FAIL').Count -gt 0
    if ($hasFail -ne ($result.verdict -eq 'FAIL')) { $problems.Add("its verdict $($result.verdict) contradicts its findings") }
    foreach ($commit in $Commits) {
        $covered = @($result.commits | Where-Object { (Resolve-ReviewedCommit $_.commit $Commits).Sha -eq $commit.Sha }).Count -gt 0
        if (-not $covered) { $problems.Add("it has no summary for commit $($commit.Short)") }
    }

    if ($problems.Count -gt 0) {
        return [pscustomobject]@{ Error = "its answer can't be used: $($problems -join '; ')"; Result = $null }
    }
    [pscustomobject]@{ Error = $null; Result = $result }
}

function Split-ReviewByCommit([string] $Pass, [object] $Result, [object[]] $Commits) {
    foreach ($commit in $Commits) {
        $findings = @($Result.findings | Where-Object { (Resolve-ReviewedCommit $_.commit $Commits).Sha -eq $commit.Sha })
        $entry = $Result.commits | Where-Object { (Resolve-ReviewedCommit $_.commit $Commits).Sha -eq $commit.Sha } | Select-Object -First 1
        [pscustomobject]@{
            Pass          = $Pass
            ReviewedSha   = $commit.Sha
            Verdict       = if (@($findings | Where-Object severity -EQ 'FAIL').Count -gt 0) { 'FAIL' } else { 'PASS' }
            Findings      = $findings
            Summary       = if ($entry) { $entry.summary } else { '' }
            TalkingPoints = if ($entry) { $entry.talkingPoints } else { '' }
            PassSummary   = $Result.summary
        }
    }
}

# --- The review ---------------------------------------------------------------------------

function Get-ReviewNotes([object] $Commit) {
    foreach ($trailer in (Get-Trailers $Commit.Message | Where-Object Key -EQ 'Review-note')) {
        $id, $reason = $trailer.Value -split ',', 2
        [pscustomobject]@{ Id = $id.Trim(); Reason = "$reason".Trim() }
    }
}

function Invoke-AiReview([object[]] $Commits, [string] $TipSha, [string] $StateDirectory) {
    $script:ClaudeExe = Resolve-Executable 'claude'
    $checklistVersion = Get-ChecklistVersion $TipSha
    $cacheDirectory = Join-Path $StateDirectory 'cache'
    New-Item -ItemType Directory -Force -Path $cacheDirectory | Out-Null

    $keys = @{}
    foreach ($commit in $Commits) { $keys[$commit.Sha] = Get-ReviewKey $commit $checklistVersion }
    $cacheFile = { param($commit, $pass) Join-Path $cacheDirectory "$($keys[$commit.Sha]).$pass.json" }

    $errors = [System.Collections.Generic.List[string]]::new()
    $toReview = [ordered]@{}
    foreach ($pass in $script:PassQuestions.Keys) {
        $missing = @()
        foreach ($commit in $Commits) {
            if (-not (Test-Path (& $cacheFile $commit $pass))) { $missing += $commit }
        }
        if ($missing) { $toReview[$pass] = $missing }
    }

    if ($toReview.Count -gt 0) {
        $passNames = $toReview.Keys -join ', '
        Write-Host "  Asking the reviewer ($passNames). This takes a few minutes..."
        $worktree = $null
        $runs = [ordered]@{}
        $bundle = Join-Path ([System.IO.Path]::GetTempPath()) "push-review-bundle-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
        try {
            $worktree = New-TemporaryWorktree $TipSha 'ai'
            New-ReviewBundle @($Commits | Where-Object { $_.Sha -in @($toReview.Values | ForEach-Object { $_.Sha }) }) $bundle
            Write-AgentDefinition $TipSha (Join-Path $bundle 'agents.json')
            $schema = Get-FileAtCommit $TipSha '.githooks/review-result.schema.json'

            # The passes run at the same time and share one deadline, so a hung run can't
            # hold the push for longer than the timeout.
            $deadline = [DateTime]::UtcNow + $script:PassTimeout
            foreach ($pass in $toReview.Keys) { $runs[$pass] = Start-ReviewPass $pass $toReview[$pass] $worktree $bundle $schema }
            foreach ($pass in @($toReview.Keys)) {
                try {
                    $remaining = $deadline - [DateTime]::UtcNow
                    if ($remaining -lt [TimeSpan]::Zero) { $remaining = [TimeSpan]::Zero }
                    $run = $runs[$pass]
                    $runs.Remove($pass)
                    $read = Read-ReviewPass $pass (Wait-Native $run -Timeout $remaining) $toReview[$pass]
                }
                catch {
                    $read = [pscustomobject]@{ Error = $_.Exception.Message; Result = $null }
                }
                if ($read.Error) {
                    $errors.Add("$($script:PassTitles[$pass]) review couldn't be used: $($read.Error)")
                    continue
                }
                foreach ($record in (Split-ReviewByCommit $pass $read.Result $toReview[$pass])) {
                    $commit = $Commits | Where-Object Sha -EQ $record.ReviewedSha
                    $record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (& $cacheFile $commit $pass) -Encoding utf8NoBOM
                }
            }
        }
        finally {
            # Runs still listed weren't waited for, because something failed first; they
            # must not outlive the checkout they're reading.
            foreach ($run in $runs.Values) {
                if (-not $run.Process.HasExited) { $run.Process.Kill($true) }
                $run.Process.Dispose()
            }
            Remove-TemporaryWorktree $worktree
            Remove-Item -LiteralPath $bundle -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Records are matched to commits by key, not by id: a cached record may come from an
    # earlier commit with the same content, before a rebase changed its id.
    $outcome = foreach ($commit in $Commits) {
        $commitRecords = @(foreach ($pass in $script:PassQuestions.Keys) {
                $file = & $cacheFile $commit $pass
                if (Test-Path $file) { Get-Content $file -Raw | ConvertFrom-Json }
            })
        $notes = @(Get-ReviewNotes $commit)
        $raised = @($commitRecords | ForEach-Object { $_.Findings } | Where-Object severity -EQ 'FAIL')
        $blocking = @($raised | Where-Object { $_.id -notin @($notes | Where-Object Reason | ForEach-Object Id) })
        $unmatched = @($notes | Where-Object { -not $_.Reason -or $_.Id -notin $raised.id })
        [pscustomobject]@{
            Commit    = $commit
            Records   = $commitRecords
            Notes     = $notes
            Blocking  = $blocking
            Unmatched = $unmatched
            Complete  = $commitRecords.Count -eq $script:PassQuestions.Count
        }
    }

    [pscustomobject]@{
        Passed   = $errors.Count -eq 0 -and -not ($outcome | Where-Object { $_.Blocking.Count -gt 0 -or -not $_.Complete })
        Errors   = $errors
        Outcome  = $outcome
    }
}

# --- Output -------------------------------------------------------------------------------

function Format-Finding([object] $Finding, [switch] $Public) {
    # Outside the local report (in the terminal, and so in an agent's transcript, and in
    # the PR description), a sensitive-data finding shows only its id and place, in case
    # the reviewer quoted what it found despite being told not to.
    $where = if ($Finding.line -gt 0) { "$($Finding.file):$($Finding.line)" } else { $Finding.file }
    if ($Public -and $Finding.id -like 'S*') { return "$($Finding.severity) $($Finding.id) $where, details in the local report" }
    "$($Finding.severity) $($Finding.id) $where`n      $($Finding.evidence)`n      Fix: $($Finding.fix)"
}

function Write-AiReview([object] $Review) {
    foreach ($problem in $Review.Errors) { Write-Host "  BLOCKED: $problem" -ForegroundColor Red }
    foreach ($item in $Review.Outcome) {
        $verdicts = foreach ($pass in $script:PassQuestions.Keys) {
            $record = $item.Records | Where-Object Pass -EQ $pass
            $label = if (-not $record) { 'not run' } elseif ($record.Verdict -eq 'FAIL') { 'FAIL' } else { 'PASS' }
            "$pass $label"
        }
        Write-Host "  $($item.Commit.Short) $($item.Commit.Subject)"
        Write-Host "      $($verdicts -join ' · ')"
        foreach ($finding in $item.Blocking) { Write-Host "    $(Format-Finding $finding -Public)" -ForegroundColor Red }
        foreach ($note in $item.Notes | Where-Object { $_ -notin $item.Unmatched }) { Write-Host "    Review-note accepted: $($note.Id), $($note.Reason)" -ForegroundColor Yellow }
        foreach ($note in $item.Unmatched) {
            Write-Host "    Review-note '$($note.Id)' has no effect: it needs a reason and must name a FAIL the stored review raised for this commit." -ForegroundColor Yellow
        }
        $flags = @($item.Records | ForEach-Object { $_.Findings } | Where-Object severity -EQ 'FLAG')
        foreach ($finding in $flags) { Write-Host "    $(Format-Finding $finding -Public)" -ForegroundColor Yellow }
    }
}

function Write-ReviewReport([object] $Review, [string] $Branch, [string] $StateDirectory) {
    $now = Get-Date
    $path = Join-Path $StateDirectory "$($now.ToString('yyyy-MM-dd-HHmmss'))-$($Branch -replace '[^\w.-]', '-').md"
    $text = [System.Text.StringBuilder]::new()
    $result = if ($Review.Passed) { 'PASS' } else { 'FAIL' }
    [void]$text.AppendLine("# Push review: $Branch, $($now.ToString('yyyy-MM-dd HH:mm'))").AppendLine()
    [void]$text.AppendLine("Result: **$result**").AppendLine()
    foreach ($problem in $Review.Errors) { [void]$text.AppendLine("- Blocked: $problem") }

    foreach ($item in $Review.Outcome) {
        [void]$text.AppendLine().AppendLine("## $($item.Commit.Short) $($item.Commit.Subject)").AppendLine()
        foreach ($pass in $script:PassQuestions.Keys) {
            $record = $item.Records | Where-Object Pass -EQ $pass
            if (-not $record) { [void]$text.AppendLine("### $($script:PassTitles[$pass]): not run").AppendLine(); continue }
            [void]$text.AppendLine("### $($script:PassTitles[$pass]): $($record.Verdict)").AppendLine()
            [void]$text.AppendLine($record.Summary).AppendLine()
            [void]$text.AppendLine("_Pass summary:_ $($record.PassSummary)").AppendLine()
            foreach ($finding in $record.Findings) { [void]$text.AppendLine("- $((Format-Finding $finding) -replace "`n\s+", ' ')") }
            if ($record.TalkingPoints) { [void]$text.AppendLine().AppendLine('**Talking points**').AppendLine().AppendLine($record.TalkingPoints) }
            [void]$text.AppendLine()
        }
        foreach ($note in $item.Notes) { [void]$text.AppendLine("- Review-note: $($note.Id), $($note.Reason)") }
    }

    # What goes into the PR description: summaries, FLAGs, NITs and review notes, without
    # the talking points, which are for the author only, and without the details of
    # sensitive-data findings (Format-Finding -Public).
    [void]$text.AppendLine().AppendLine('## For the PR description').AppendLine()
    foreach ($item in $Review.Outcome) {
        [void]$text.AppendLine("**$($item.Commit.Short) $($item.Commit.Subject)**").AppendLine()
        foreach ($record in $item.Records) {
            $summary = if ($record.Pass -eq 'sensitive') { '' } else { " $($record.Summary)" }
            [void]$text.AppendLine("- $($script:PassTitles[$record.Pass]): $($record.Verdict).$summary")
        }
        foreach ($finding in @($item.Records | ForEach-Object { $_.Findings } | Where-Object severity -In 'FLAG', 'NIT')) {
            [void]$text.AppendLine("- $((Format-Finding $finding -Public) -replace "`n\s+", ' ')")
        }
        foreach ($note in $item.Notes) { [void]$text.AppendLine("- Review-note: $($note.Id), $($note.Reason)") }
        [void]$text.AppendLine()
    }
    [System.IO.File]::WriteAllText($path, $text.ToString(), $script:Utf8NoBom)
    $path
}
