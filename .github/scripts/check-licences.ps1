#Requires -Version 7.4
<#
.SYNOPSIS
    Checks every package's licence against ADR 12's lists (docs/adr/0012-licence-and-supply-chain.md).

.DESCRIPTION
    Run after a restore; it reads the restored packages, transitive ones included. Every
    project under src/ is checked against .github/licences/allowed-app.json, then the whole
    solution, tests/ included, against allowed-test.json, which also allows MPL-2.0. A
    licence that can't be determined, or isn't on the list, fails the check with a
    non-zero exit code. CI runs this script, and it runs the same way locally.
#>
$ErrorActionPreference = 'Stop'

# The projects are listed by folder, as ADR 12 splits the lists, so a project's name
# can't put it on the wrong one.
$appProjects = Join-Path ([System.IO.Path]::GetTempPath()) "licence-check-app-projects-$PID.json"
Push-Location (Join-Path $PSScriptRoot '../..')
try {
    Get-ChildItem src -Recurse -Filter *.csproj | ForEach-Object FullName | ConvertTo-Json -AsArray | Set-Content $appProjects
    dotnet tool restore
    if ($LASTEXITCODE -eq 0) {
        dotnet nuget-license --json-input $appProjects --include-transitive --error-only --allowed-license-types .github/licences/allowed-app.json
    }
    if ($LASTEXITCODE -eq 0) {
        dotnet nuget-license --input MealPlanner.slnx --include-transitive --error-only --allowed-license-types .github/licences/allowed-test.json
    }
    $exitCode = $LASTEXITCODE
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $appProjects -ErrorAction SilentlyContinue
}
exit $exitCode
