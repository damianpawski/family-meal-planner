# Runs external programs (git, gitleaks, dotnet, claude) for the push review.
#
# Every call goes through these functions so that a failing or hanging tool stops the
# review instead of being read as "nothing found". Stdout and stderr are read
# separately, and stdout can be written to a file byte for byte, which image blobs need.
# Start-Native and Wait-Native are separate so that several programs can run at once.

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

function Start-Native {
    param(
        [Parameter(Mandatory)] [string] $FilePath,
        [string[]] $ArgumentList = @(),
        [string] $WorkingDirectory = (Get-Location).Path,
        [string] $StandardInput,
        [string] $OutputFile
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
    $startInfo.StandardErrorEncoding = $script:Utf8NoBom
    if (-not $OutputFile) { $startInfo.StandardOutputEncoding = $script:Utf8NoBom }

    # The output file is opened first, so a bad path fails before any process is running.
    $outputStream = if ($OutputFile) { [System.IO.File]::Create($OutputFile) } else { $null }
    $process = [System.Diagnostics.Process]::Start($startInfo)

    # Both streams are drained asynchronously: reading one to the end while the other
    # fills its pipe buffer would deadlock on large outputs such as full diffs.
    $handle = [pscustomobject]@{
        Process      = $process
        Description  = "$([System.IO.Path]::GetFileName($FilePath)) $($ArgumentList | Select-Object -First 3)"
        OutputStream = $outputStream
        StdOutTask   = if ($outputStream) { $process.StandardOutput.BaseStream.CopyToAsync($outputStream) } else { $process.StandardOutput.ReadToEndAsync() }
        StdErrTask   = $process.StandardError.ReadToEndAsync()
    }

    if ($StandardInput) { $process.StandardInput.Write($StandardInput) }
    $process.StandardInput.Close()
    $handle
}

function Wait-Native {
    param(
        [Parameter(Mandatory)] [object] $Handle,
        [TimeSpan] $Timeout = [TimeSpan]::FromMinutes(30)
    )
    try {
        if (-not $Handle.Process.WaitForExit($Timeout)) {
            $Handle.Process.Kill($true)
            # The killed process closes its output, so the copy into the output file ends;
            # let it end before the file is disposed. Its result no longer matters.
            try { [void]$Handle.StdOutTask.Wait([TimeSpan]::FromSeconds(10)) } catch { }
            throw "'$($Handle.Description)' didn't finish within $(Format-Duration $Timeout)."
        }
        $Handle.StdOutTask.GetAwaiter().GetResult() | Out-Null
        [pscustomobject]@{
            ExitCode = $Handle.Process.ExitCode
            StdOut   = if ($Handle.OutputStream) { '' } else { $Handle.StdOutTask.Result }
            StdErr   = $Handle.StdErrTask.GetAwaiter().GetResult()
        }
    }
    finally {
        if ($Handle.OutputStream) { $Handle.OutputStream.Dispose() }
        $Handle.Process.Dispose()
    }
}

function Invoke-Native {
    param(
        [Parameter(Mandatory)] [string] $FilePath,
        [string[]] $ArgumentList = @(),
        [string] $WorkingDirectory = (Get-Location).Path,
        [string] $StandardInput,
        [string] $OutputFile,
        [TimeSpan] $Timeout = [TimeSpan]::FromMinutes(30)
    )
    $handle = Start-Native -FilePath $FilePath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory `
        -StandardInput $StandardInput -OutputFile $OutputFile
    Wait-Native -Handle $handle -Timeout $Timeout
}
