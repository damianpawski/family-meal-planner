# Git access for the push review. Paths are kept as UTF-8 text (core.quotepath=off), and
# a failing git command throws, because "no output" must never be read as "no problems".

$script:GitExe = Resolve-Executable 'git'

function Invoke-Git {
    param(
        [Parameter(Mandatory)] [string[]] $Arguments,
        [string] $StandardInput,
        [switch] $AllowFailure
    )
    $result = Invoke-Native -FilePath $script:GitExe -ArgumentList (@('-c', 'core.quotepath=off') + $Arguments) `
        -WorkingDirectory $script:RepoRoot -StandardInput $StandardInput
    if ($result.ExitCode -ne 0 -and -not $AllowFailure) {
        throw "git $($Arguments -join ' ') failed ($($result.ExitCode)): $($result.StdErr.Trim())"
    }
    $result
}

function Get-GitLines([string[]] $Arguments) {
    (Invoke-Git $Arguments).StdOut -split "`n" | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ -ne '' }
}

function Get-Commit([string] $Sha) {
    # NUL-separated fields, with the raw message last because it can contain anything.
    $fields = (Invoke-Git @('show', '-s', '--format=%H%x00%an%x00%ae%x00%ce%x00%P%x00%T%x00%B', $Sha)).StdOut -split "`0", 7
    $message = $fields[6].TrimEnd()
    [pscustomobject]@{
        Sha            = $fields[0]
        Short          = $fields[0].Substring(0, 9)
        AuthorName     = $fields[1]
        AuthorEmail    = $fields[2]
        CommitterEmail = $fields[3]
        Parents        = @($fields[4] -split ' ' | Where-Object { $_ })
        Tree           = $fields[5]
        Message        = $message
        Subject        = ($message -split "`n", 2)[0].TrimEnd("`r")
    }
}

function Get-Trailers([string] $Message) {
    # git's own parser, so trailers are read exactly the way git and GitHub read them.
    $parsed = (Invoke-Git @('interpret-trailers', '--parse') -StandardInput ($Message + "`n")).StdOut
    foreach ($line in ($parsed -split "`n")) {
        if ($line -match '^(?<key>[^:]+):\s*(?<value>.*)$') {
            [pscustomobject]@{ Key = $Matches.key.Trim(); Value = $Matches.value.Trim() }
        }
    }
}

function Get-CommitPatch([string] $Sha, [int] $Context = 0) {
    # --root shows the first commit against the empty tree; merges (not expected with
    # rebase-only merging) are compared with their first parent.
    (Invoke-Git @('diff-tree', '-p', '--root', '-r', '--no-commit-id', '--no-color', '--no-ext-diff',
        '--diff-merges=first-parent', "--unified=$Context", $Sha)).StdOut
}

function Get-AddedLines([string] $Sha) {
    # Each added line with the file it belongs to and its line number in the new file.
    # File headers are only read between "diff --git" and the first hunk, so an added line
    # that happens to start with "++ " isn't mistaken for one.
    $file = $null
    $inHeader = $false
    $lineNumber = 0
    foreach ($line in ((Get-CommitPatch $Sha) -split "`n")) {
        if ($line.StartsWith('diff --git ')) {
            $inHeader = $true
            $file = $null
        }
        elseif ($inHeader -and $line.StartsWith('+++ ')) {
            # git ends the name with a tab when it contains a space.
            $file = if ($line -eq '+++ /dev/null') { $null } else { $line.Substring(6).TrimEnd("`r", "`t") }
        }
        elseif ($line -match '^@@ -\d+(?:,\d+)? \+(?<start>\d+)') {
            $inHeader = $false
            $lineNumber = [int]$Matches.start
        }
        elseif (-not $inHeader -and $file -and $line.StartsWith('+')) {
            [pscustomobject]@{ File = $file; Line = $lineNumber; Text = $line.Substring(1).TrimEnd("`r") }
            $lineNumber++
        }
    }
}

function Get-ChangedFiles([string] $Sha) {
    # Files the commit adds, modifies, renames or copies, with their new paths. Deleted files
    # can't leak anything new, so they're left out.
    $lines = Get-GitLines @('diff-tree', '--root', '-r', '--no-commit-id', '--name-status', '-M',
        '--diff-merges=first-parent', $Sha)
    foreach ($line in $lines) {
        $parts = $line -split "`t"
        $status = $parts[0].Substring(0, 1)
        if ($status -ne 'D') {
            [pscustomobject]@{ Status = $status; Path = $parts[-1] }
        }
    }
}

function Get-FileAtCommit([string] $Sha, [string] $Path) {
    $result = Invoke-Git @('show', "${Sha}:$Path") -AllowFailure
    if ($result.ExitCode -eq 0) { $result.StdOut } else { $null }
}

function New-TemporaryWorktree([string] $Sha, [string] $Name) {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) "push-review-$Name-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    Invoke-Git @('worktree', 'add', '--detach', '--quiet', $path, $Sha) | Out-Null
    $path
}

function Remove-TemporaryWorktree([string] $Path) {
    if ($Path -and (Test-Path $Path)) {
        Invoke-Git @('worktree', 'remove', '--force', $Path) -AllowFailure | Out-Null
    }
    Invoke-Git @('worktree', 'prune') -AllowFailure | Out-Null
}
