# Shared by the push review's Pester tests. Dot-source it in a test file's BeforeAll,
# then dot-source the hook's libraries from $HooksDirectory, so their functions and
# their $script: variables live in the test file's scope.
#
# Every test runs against a throwaway git repository in the temp folder, never this one.

$script:HooksDirectory = (Resolve-Path (Join-Path $PSScriptRoot '../../.githooks')).Path
$script:TestEmail = '1+test@users.noreply.github.com'
$script:NoSha = '0000000000000000000000000000000000000000'

function Invoke-TestGit {
    param(
        [Parameter(Mandatory)] [string] $Repository,
        [Parameter(ValueFromRemainingArguments)] [string[]] $Arguments
    )
    $output = & git -C $Repository @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $($output -join "`n")" }
    # Progress messages arrive on stderr; only standard output is returned.
    @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
}

function New-TestRepository([switch] $Bare) {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) "push-review-test-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $path | Out-Null
    if ($Bare) {
        Invoke-TestGit $path init --quiet --bare --initial-branch=main | Out-Null
        return $path
    }
    Invoke-TestGit $path init --quiet --initial-branch=main | Out-Null
    Invoke-TestGit $path config user.name 'Test Author' | Out-Null
    Invoke-TestGit $path config user.email $script:TestEmail | Out-Null
    Invoke-TestGit $path config commit.gpgsign false | Out-Null
    $path
}

function Remove-TestRepository([string] $Path) {
    if ($Path -and (Test-Path -LiteralPath $Path)) { Remove-Item -LiteralPath $Path -Recurse -Force }
}

function Add-TestCommit {
    # Writes the files (text, or bytes for images), commits everything and returns the
    # new commit's id. The message goes through a file, so quotes and newlines arrive
    # exactly as written.
    param(
        [Parameter(Mandatory)] [string] $Repository,
        [hashtable] $Files = @{},
        [string] $Message = "docs(plan): change a test file`n`nA test commit.`n`nTask: M0.1"
    )
    foreach ($path in $Files.Keys) {
        $fullPath = Join-Path $Repository $path
        New-Item -ItemType Directory -Force -Path (Split-Path $fullPath -Parent) | Out-Null
        if ($Files[$path] -is [byte[]]) { [System.IO.File]::WriteAllBytes($fullPath, $Files[$path]) }
        else { [System.IO.File]::WriteAllText($fullPath, $Files[$path], [System.Text.UTF8Encoding]::new($false)) }
    }
    Invoke-TestGit $Repository add --all | Out-Null
    $messageFile = Join-Path ([System.IO.Path]::GetTempPath()) "push-review-test-message-$([guid]::NewGuid().ToString('N'))"
    [System.IO.File]::WriteAllText($messageFile, $Message, [System.Text.UTF8Encoding]::new($false))
    try { Invoke-TestGit $Repository commit --quiet --allow-empty --file $messageFile | Out-Null }
    finally { Remove-Item -LiteralPath $messageFile }
    "$(Invoke-TestGit $Repository rev-parse HEAD)".Trim()
}

function New-TestCommit {
    # A commit as Get-Commit returns it, for checks that read only the message and emails.
    # Its id defaults to a real commit in the test repository, so checks that look up the
    # plan or the spec at that commit find them.
    param(
        [Parameter(Mandatory)] [string] $Message,
        [string] $Sha = $script:FixtureSha,
        [string] $AuthorName = 'Test Author',
        [string] $AuthorEmail = $script:TestEmail,
        [string] $CommitterEmail = $script:TestEmail
    )
    $text = $Message.TrimEnd()
    [pscustomobject]@{
        Sha            = $Sha
        Short          = $Sha.Substring(0, 9)
        AuthorName     = $AuthorName
        AuthorEmail    = $AuthorEmail
        CommitterEmail = $CommitterEmail
        Parents        = @()
        Tree           = ''
        Message        = $text
        Subject        = ($text -split "`n", 2)[0]
    }
}
