# Runs external programs (git, gitleaks, dotnet) for the push review.
#
# Every call goes through Invoke-Native so that a failing or hanging tool stops the
# review instead of being read as "nothing found". Stdout and stderr are read separately.

$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Format-Duration([TimeSpan] $Duration) {
    if ($Duration.TotalMinutes -ge 1) { return "$([Math]::Round($Duration.TotalMinutes)) minutes" }
    "$([Math]::Round($Duration.TotalSeconds)) seconds"
}

function Resolve-Executable([string] $Name) {
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) {
        throw "'$Name' isn't installed or isn't on the PATH. The push review needs it (docs/review/push-review.md)."
    }
    $command.Source
}

function Invoke-Native {
    param(
        [Parameter(Mandatory)] [string] $FilePath,
        [string[]] $ArgumentList = @(),
        [string] $WorkingDirectory = (Get-Location).Path,
        [string] $StandardInput,
        [TimeSpan] $Timeout = [TimeSpan]::FromMinutes(30)
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new($FilePath)
    foreach ($argument in $ArgumentList) { $startInfo.ArgumentList.Add($argument) }
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    # Standard input is always redirected and closed after any input is written, so a
    # child never waits on, or reads, the hook's own input from git.
    $startInfo.RedirectStandardInput = $true
    $startInfo.StandardInputEncoding = $script:Utf8NoBom
    $startInfo.StandardOutputEncoding = $script:Utf8NoBom
    $startInfo.StandardErrorEncoding = $script:Utf8NoBom

    $process = [System.Diagnostics.Process]::Start($startInfo)
    try {
        # Both streams are drained asynchronously: reading one to the end while the other
        # fills its pipe buffer would deadlock on large outputs such as full diffs.
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if ($StandardInput) { $process.StandardInput.Write($StandardInput) }
        $process.StandardInput.Close()
        if (-not $process.WaitForExit($Timeout)) {
            $process.Kill($true)
            throw "'$([System.IO.Path]::GetFileName($FilePath)) $($ArgumentList | Select-Object -First 3)' didn't finish within $(Format-Duration $Timeout)."
        }
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut   = $stdoutTask.GetAwaiter().GetResult()
            StdErr   = $stderrTask.GetAwaiter().GetResult()
        }
    }
    finally {
        $process.Dispose()
    }
}
