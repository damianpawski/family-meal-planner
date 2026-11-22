# The fixed checks F1 to F6 from docs/review/push-review.md, Part 1. No AI: the same
# commits always get the same answer. Each check returns its failures; an empty result
# means the check passed.

function New-Failure([string] $Check, [string] $Commit, [string] $Where, [string] $Problem) {
    [pscustomobject]@{ Check = $Check; Commit = $Commit; Where = $Where; Problem = $Problem }
}

# --- F1: secrets ------------------------------------------------------------------------

function Test-Secrets([object[]] $Commits) {
    $gitleaks = Resolve-Executable 'gitleaks'
    $workDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "push-review-gitleaks-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $workDirectory | Out-Null
    try {
        # gitleaks would otherwise read .gitleaks.toml and .gitleaksignore from the working
        # folder, where an uncommitted allowlist could pass a push that CI then fails. So
        # the configuration comes from the newest commit being pushed (the default rules
        # when it has none), and the ignore list from an empty folder.
        $config = Join-Path $workDirectory 'gitleaks.toml'
        $committed = Get-FileAtCommit $Commits[-1].Sha '.gitleaks.toml'
        $content = if ($committed) { $committed } else { "[extend]`nuseDefault = true`n" }
        [System.IO.File]::WriteAllText($config, $content, $script:Utf8NoBom)
        $report = Join-Path $workDirectory 'report.json'

        # --no-walk limits git log to exactly these commits, so history already on the
        # remote isn't scanned again. A false positive gets a narrow allowlist in
        # .gitleaks.toml; inline "gitleaks:allow" comments are ignored, so a commit can't
        # exempt itself.
        $result = Invoke-Native -FilePath $gitleaks -WorkingDirectory $script:RepoRoot -ArgumentList @(
            'git', '--log-opts', "--no-walk $($Commits.Sha -join ' ')", '--ignore-gitleaks-allow',
            '--config', $config, '--gitleaks-ignore-path', $workDirectory,
            '--redact', '--no-banner', '--no-color', '--log-level', 'error',
            '--report-format', 'json', '--report-path', $report, '--exit-code', '1', $script:RepoRoot)
        if ($result.ExitCode -eq 0) { return }
        if ($result.ExitCode -ne 1 -or -not (Test-Path $report)) {
            throw "gitleaks failed ($($result.ExitCode)): $($result.StdErr.Trim())"
        }
        foreach ($leak in (Get-Content $report -Raw | ConvertFrom-Json)) {
            New-Failure 'F1' $leak.Commit.Substring(0, 9) "$($leak.File):$($leak.StartLine)" "possible secret (gitleaks rule '$($leak.RuleID)')"
        }
    }
    finally {
        Remove-Item -LiteralPath $workDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- F2: noreply emails -----------------------------------------------------------------

$script:NoreplyPattern = '^\d+\+[^@\s]+@users\.noreply\.github\.com$'
$script:DependabotEmail = '49699333+dependabot[bot]@users.noreply.github.com'
# GitHub itself commits Dependabot's changes, so it is their committer.
$script:GitHubCommitterEmail = 'noreply@github.com'

function Test-Emails([object[]] $Commits, [string] $ExpectedEmail, [switch] $AllowDependabot) {
    # The addresses themselves are never printed: a rejected one is most likely the
    # private address this check exists to keep out of logs and transcripts.
    if ($ExpectedEmail -notmatch $script:NoreplyPattern) {
        New-Failure 'F2' '-' 'git config user.email' "isn't a GitHub noreply address (<id>+<user>@users.noreply.github.com)"
        return
    }
    foreach ($commit in $Commits) {
        $accepted = @{ Author = @($ExpectedEmail); Committer = @($ExpectedEmail) }
        if ($AllowDependabot -and $commit.AuthorName -eq 'dependabot[bot]') {
            $accepted.Author += $script:DependabotEmail
            $accepted.Committer += $script:DependabotEmail, $script:GitHubCommitterEmail
        }
        foreach ($role in 'Author', 'Committer') {
            if ($commit."${role}Email" -notin $accepted[$role]) {
                New-Failure 'F2' $commit.Short "$($role.ToLower()) email" "isn't the expected noreply address"
            }
        }
    }
}

# --- F3: personal data ------------------------------------------------------------------

function Read-PersonalStrings([string] $Path) {
    $lineNumber = 0
    foreach ($line in (Get-Content -LiteralPath $Path -Encoding utf8)) {
        $lineNumber++
        $entry = $line.Trim()
        if ($entry -eq '' -or $entry.StartsWith('#')) { continue }
        $digits = $entry -replace '\D', ''
        # A phone number is compared by its last nine digits, so spacing, punctuation and a
        # +country code don't matter: "+48 000 000 000" matches "000000000".
        $isPhone = $digits.Length -ge 7 -and $entry -match '^[\d\s+\-().\/]+$'
        [pscustomobject]@{
            LineNumber = $lineNumber
            IsPhone    = $isPhone
            Needle     = if ($isPhone) { $digits.Substring([Math]::Max(0, $digits.Length - 9)) } else { $entry }
        }
    }
}

function Find-PersonalString([string] $Text, [object[]] $Entries) {
    $digits = $null
    foreach ($entry in $Entries) {
        if ($entry.IsPhone) {
            if ($null -eq $digits) { $digits = $Text -replace '\D', '' }
            if ($digits.Contains($entry.Needle)) { return $entry }
        }
        elseif ($Text.IndexOf($entry.Needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $entry
        }
    }
}

function Test-PersonalData([object[]] $Commits, [string] $ListPath) {
    if (-not (Test-Path -LiteralPath $ListPath)) {
        New-Failure 'F3' '-' $ListPath 'the personal-strings list is missing, so personal data can''t be checked'
        return
    }
    $entries = @(Read-PersonalStrings $ListPath)
    if ($entries.Count -eq 0) {
        New-Failure 'F3' '-' $ListPath 'the personal-strings list has no entries'
        return
    }

    # The output names the entry by its line in the list, never by its value, so the
    # personal data doesn't end up in a terminal log or an agent transcript.
    foreach ($commit in $Commits) {
        $messageLine = 0
        foreach ($line in ($commit.Message -split "`n")) {
            $messageLine++
            if ($match = Find-PersonalString $line $entries) {
                New-Failure 'F3' $commit.Short "commit message, line $messageLine" "matches personal-strings line $($match.LineNumber)"
            }
        }
        foreach ($file in (Get-ChangedFiles $commit.Sha)) {
            if ($match = Find-PersonalString $file.Path $entries) {
                New-Failure 'F3' $commit.Short "file name $($file.Path)" "matches personal-strings line $($match.LineNumber)"
            }
        }
        foreach ($added in (Get-AddedLines $commit.Sha)) {
            if ($match = Find-PersonalString $added.Text $entries) {
                New-Failure 'F3' $commit.Short "$($added.File):$($added.Line)" "matches personal-strings line $($match.LineNumber)"
            }
        }
    }
}

function Hide-PersonalData([object[]] $Failures, [string] $ListPath) {
    # A failure's location or message can itself hold personal data: a file named after
    # someone, or a commit subject that F4 quotes. Such a failure is shown only by its
    # check, its commit and the line of the list it matched, so the value never reaches
    # the terminal. Without a list (in CI) there is nothing to hide.
    $entries = if (Test-Path -LiteralPath $ListPath) { @(Read-PersonalStrings $ListPath) } else { @() }
    foreach ($failure in $Failures) {
        $match = if ($entries) { Find-PersonalString "$($failure.Where) $($failure.Problem)" $entries }
        if ($match) {
            New-Failure $failure.Check $failure.Commit '(not shown)' "contains personal data (personal-strings line $($match.LineNumber))"
        }
        else {
            $failure
        }
    }
}

# --- F4: commit message format ----------------------------------------------------------

# The subject patterns from docs/conventions.md#subject. -cmatch, not -match: PowerShell
# matches case-insensitively by default, and the pattern relies on [a-z] meaning lowercase.
$script:SubjectPattern = '^(feat|fix|test|docs|build|ci|refactor|chore)(\((server|client|ui|data|apphost|spec|plan|adr|review|deps|deps-dev|repo)\))?!?: [a-z].*[^.]$'
$script:RevertPattern = '^Revert ".+"$'
# Dependabot's subjects (docs/conventions.md#dependabot): either case of "bump", both scopes.
$script:DependabotPattern = '^(build|ci)\((deps|deps-dev)\): [Bb]ump .+[^.]$'
$script:MaxSubjectLength = 72

function Test-SpecIds([string] $Value, [string] $Sha) {
    if ($Value -eq 'none') { return }
    $documents = (Get-FileAtCommit $Sha 'spec/spec.md') + "`n" + (Get-FileAtCommit $Sha 'spec/sync-contract.md')
    foreach ($id in ($Value -split ',' | ForEach-Object { $_.Trim() })) {
        if ($id -cnotmatch '^([A-Z]+-\d+[a-z]?|[XC]\d+)$') {
            "'$id' isn't a spec id (like SEC-02), a worked example (like X13 or C1), or 'none'"
        }
        elseif ($documents -notmatch "(?m)^\|\s*$([regex]::Escape($id))\s*\|") {
            "'$id' doesn't exist in spec/spec.md or spec/sync-contract.md"
        }
    }
}

function Test-TaskId([string] $Value, [string] $Sha) {
    if ($Value -cnotmatch '^M(?<milestone>\d+[a-z]?)\.(?<task>\d+)$') {
        return "'$Value' isn't a task id like M0.6"
    }
    $plan = "docs/plan/M$($Matches.milestone).md"
    $task = $Matches.task
    $content = Get-FileAtCommit $Sha $plan
    if ($null -eq $content) { return "$plan doesn't exist" }
    if ($content -notmatch "(?m)^### $task\. ") { return "$plan has no task $task" }
}

function Test-CommitFormat([object[]] $Commits) {
    foreach ($commit in $Commits) {
        $subject = $commit.Subject
        $fail = { param($where, $problem) New-Failure 'F4' $commit.Short $where $problem }

        if ($commit.AuthorName -eq 'dependabot[bot]') {
            # Dependabot can't write our body or trailers, so only its subject is checked.
            if ($subject -cnotmatch $script:DependabotPattern) { & $fail 'subject' "'$subject' isn't a Dependabot subject in the agreed format" }
            continue
        }

        $isRevert = $subject -cmatch $script:RevertPattern
        if (-not $isRevert -and $subject -cnotmatch $script:SubjectPattern) {
            & $fail 'subject' "'$subject' doesn't match the pattern in docs/conventions.md#subject"
        }
        if ($subject.Length -gt $script:MaxSubjectLength) {
            & $fail 'subject' "the subject has $($subject.Length) characters; the limit is $script:MaxSubjectLength"
        }

        $lines = $commit.Message -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
        if ($lines.Count -gt 1 -and $lines[1] -ne '') {
            & $fail 'message' 'the second line must be blank'
        }

        # git only reads trailers from the last paragraph, so that paragraph is the trailer
        # block when there are any, and the body is everything between it and the subject.
        $trailers = @(Get-Trailers $commit.Message)
        $paragraphs = @($commit.Message -split '\r?\n\s*\r?\n' | Where-Object { $_.Trim() })
        $bodyCount = $paragraphs.Count - 1 - [int]($trailers.Count -gt 0)
        if ($bodyCount -lt 1) {
            & $fail 'body' 'there is no body; it must say why the change is made'
        }
        if ($isRevert) { continue }

        $type = if ($subject -cmatch '^(?<type>[a-z]+)') { $Matches.type } else { '' }
        $values = @{}
        foreach ($trailer in $trailers) { $values[$trailer.Key] = $trailer.Value }

        if ($type -in 'feat', 'fix', 'test') {
            if (-not $values['Spec']) {
                & $fail 'trailers' "a $type commit needs 'Spec:' (ids, or 'none')"
            }
            else {
                foreach ($problem in (Test-SpecIds $values['Spec'] $commit.Sha)) { & $fail 'Spec trailer' $problem }
            }
        }
        if (-not $values['Task'] -and -not $values['Issue']) {
            & $fail 'trailers' "the commit needs 'Task:' (like M0.6) or 'Issue:' (like #12)"
        }
        if ($values['Task'] -and ($problem = Test-TaskId $values['Task'] $commit.Sha)) {
            & $fail 'Task trailer' $problem
        }
        if ($values['Issue'] -and $values['Issue'] -cnotmatch '^#\d+$') {
            & $fail 'Issue trailer' "'$($values['Issue'])' isn't an issue reference like #12"
        }
        if ($subject -cmatch '^[a-z]+(\([a-z-]+\))?!:' -and -not $values['BREAKING-CHANGE']) {
            & $fail 'trailers' "a subject with '!' needs a 'BREAKING-CHANGE:' trailer"
        }
    }
}

# --- F5: every commit builds and its unit tests pass ------------------------------------

# This file's own path, captured when it's loaded: its content is part of F5's cache key.
$script:FixedChecksFile = $PSCommandPath

function Test-Build([object[]] $Commits, [string] $StateDirectory) {
    $dotnet = $null
    $buildSetup = $null
    $builtDirectory = Join-Path $StateDirectory 'built-trees'
    foreach ($commit in $Commits) {
        $solution = Get-GitLines @('ls-tree', '--name-only', $commit.Sha) | Where-Object { $_ -match '\.slnx?$' } | Select-Object -First 1
        if (-not $solution) {
            Write-Host "  F5 $($commit.Short): skipped, no solution file yet (documents only)"
            continue
        }
        # A tree that built and passed before isn't built again, as long as nothing else
        # that decides the result has changed: the SDK in use and this check's own script
        # (its build and test commands). Packages are pinned by the tree's lock files.
        $dotnet ??= Resolve-Executable 'dotnet'
        $buildSetup ??= "$((Invoke-Native -FilePath $dotnet -ArgumentList @('--version') -WorkingDirectory $script:RepoRoot).StdOut.Trim())`n" +
            (Get-FileHash -LiteralPath $script:FixedChecksFile -Algorithm SHA256).Hash
        $marker = Join-Path $builtDirectory ([Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData(
                    [System.Text.Encoding]::UTF8.GetBytes("$($commit.Tree)`n$buildSetup"))).ToLower())
        if (Test-Path $marker) {
            Write-Host "  F5 $($commit.Short): passed before for this exact content and build setup"
            continue
        }

        Write-Host "  F5 $($commit.Short): building in a clean worktree..."
        $worktree = New-TemporaryWorktree $commit.Sha 'build'
        try {
            $build = Invoke-Native -FilePath $dotnet -WorkingDirectory $worktree -Timeout ([TimeSpan]::FromMinutes(20)) `
                -ArgumentList @('build', $solution, '--configuration', 'Release', '--nologo', '--verbosity', 'quiet')
            if ($build.ExitCode -ne 0) {
                New-Failure 'F5' $commit.Short $solution "the build failed:`n$(Get-Tail $build.StdOut)"
                continue
            }
            $testProjects = Get-GitLines @('ls-tree', '-r', '--name-only', $commit.Sha, '--', 'tests') |
                Where-Object { $_ -match '(UnitTests|ComponentTests)\.csproj$' }
            $testsPassed = $true
            foreach ($project in $testProjects) {
                # --project is Microsoft.Testing.Platform's form, which global.json selects.
                $test = Invoke-Native -FilePath $dotnet -WorkingDirectory $worktree -Timeout ([TimeSpan]::FromMinutes(20)) `
                    -ArgumentList @('test', '--project', $project, '--configuration', 'Release', '--no-build')
                if ($test.ExitCode -ne 0) {
                    $testsPassed = $false
                    New-Failure 'F5' $commit.Short $project "tests failed:`n$(Get-Tail $test.StdOut)"
                }
            }
            if ($testsPassed) {
                New-Item -ItemType Directory -Force -Path $builtDirectory | Out-Null
                New-Item -ItemType File -Force -Path $marker | Out-Null
            }
        }
        finally {
            Remove-TemporaryWorktree $worktree
        }
    }
}

function Get-Tail([string] $Text, [int] $Lines = 30) {
    (($Text -split "`n") | Select-Object -Last $Lines) -join "`n"
}

# --- F6: forbidden files and values -----------------------------------------------------

# Key names are compared with separators removed, so api-key, api_key, apiKey and
# Connection-String all match. client_secret matches through "secret".
$script:SecretKeyPattern = 'password|secret|token|apikey|connectionstring'

function Test-ForbiddenPath([string] $Path) {
    $name = Split-Path $Path -Leaf
    $segments = $Path -split '/'
    if ($name -eq '.env' -or $name -like '.env.*') { return 'environment file' }
    if ($name -like 'id_rsa*') { return 'SSH key' }
    if ([System.IO.Path]::GetExtension($name) -in '.pfx', '.p12', '.pem', '.key') { return 'certificate or key file' }
    if ([System.IO.Path]::GetExtension($name) -eq '.user') { return 'per-user IDE file' }
    if ($segments.Count -gt 1 -and ($segments[0..($segments.Count - 2)] -contains 'bin' -or $segments[0..($segments.Count - 2)] -contains 'obj')) {
        return 'build output (bin/ or obj/)'
    }
}

function Read-AllowedSecrets([string] $Sha) {
    $content = Get-FileAtCommit $Sha '.githooks/allowed-secrets.txt'
    if (-not $content) { return @() }
    foreach ($line in ($content -split "`n")) {
        $entry = $line.Trim()
        if ($entry -eq '' -or $entry.StartsWith('#')) { continue }
        $parts = $entry -split '\s+', 2
        if ($parts.Count -eq 2) { "$($parts[0])`t$($parts[1])" }
    }
}

function Find-SecretValues([object] $Node, [string] $Path) {
    # The full path of every key whose name looks secret and that holds a value: text that
    # isn't empty, or a number. true, false and null can't be secrets; objects and arrays
    # are walked into, so a value on its own line or deep inside is found too.
    if ($Node -is [System.Collections.IDictionary]) {
        foreach ($key in $Node.Keys) {
            $keyPath = if ($Path) { "$Path.$key" } else { "$key" }
            $value = $Node[$key]
            $holdsValue = ($value -is [string] -and $value -ne '') -or ($value -is [ValueType] -and $value -isnot [bool])
            if (($key -replace '[-_.\s]', '') -match $script:SecretKeyPattern -and $holdsValue) { $keyPath }
            Find-SecretValues $value $keyPath
        }
    }
    elseif ($Node -is [System.Collections.IList]) {
        for ($index = 0; $index -lt $Node.Count; $index++) { Find-SecretValues $Node[$index] "$Path[$index]" }
    }
}

function Test-ForbiddenContent([object[]] $Commits) {
    foreach ($commit in $Commits) {
        $allowed = @(Read-AllowedSecrets $commit.Sha)
        foreach ($file in (Get-ChangedFiles $commit.Sha)) {
            if ($reason = Test-ForbiddenPath $file.Path) {
                New-Failure 'F6' $commit.Short $file.Path "forbidden file: $reason"
            }
            if ($file.Path -notlike '*.json') { continue }
            # NuGet writes packages.lock.json: its keys are package ids and its values versions
            # and hashes, so a package such as Microsoft.Extensions.Configuration.UserSecrets
            # would look like a secret. gitleaks (F1) still scans these files.
            if ((Split-Path $file.Path -Leaf) -eq 'packages.lock.json') { continue }

            # The whole file as committed is parsed, not just the added lines, so a secret
            # can't hide in a multi-line value. Comments and trailing commas are accepted,
            # as appsettings files use them.
            try { $json = Get-FileAtCommit $commit.Sha $file.Path | ConvertFrom-Json -AsHashtable }
            catch {
                New-Failure 'F6' $commit.Short $file.Path "isn't valid JSON, so its keys can't be checked"
                continue
            }
            foreach ($keyPath in (Find-SecretValues $json '')) {
                if ("$($file.Path)`t$keyPath" -notin $allowed) {
                    New-Failure 'F6' $commit.Short "$($file.Path), key $keyPath" "the key has a value; secrets don't belong in JSON files (exceptions: .githooks/allowed-secrets.txt)"
                }
            }
        }
    }
}
