# F3 and F6 of the push review (docs/review/push-review.md, Part 1): personal data, and
# forbidden files and values. Every personal string here is fictional, as in the spec.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:RepoRoot = New-TestRepository
    . (Join-Path $HooksDirectory 'lib/Process.ps1')
    . (Join-Path $HooksDirectory 'lib/Git.ps1')
    . (Join-Path $HooksDirectory 'lib/FixedChecks.ps1')

    $script:FixtureSha = Add-TestCommit $RepoRoot -Files @{ 'README.md' = "# Test`n" }

    function New-PersonalStringsList([string[]] $Lines) {
        $path = Join-Path $RepoRoot ".git/info/personal-strings-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
        Set-Content -LiteralPath $path -Value $Lines -Encoding utf8NoBOM
        $path
    }
}

AfterAll { Remove-TestRepository $RepoRoot }

Describe 'F3: reading the personal-strings list' {
    BeforeAll {
        $script:Entries = @(Read-PersonalStrings (New-PersonalStringsList @(
                    '# Fictional entries'
                    ''
                    'Maria Rivera'
                    '+48 000 000 000'
                    '12-34'
                )))
    }

    It 'skips comments and blank lines, and keeps each entry''s line number' {
        $Entries.LineNumber | Should -Be @(3, 4, 5)
    }

    It 'compares a phone number by its last nine digits' {
        $Entries[1].IsPhone | Should -BeTrue
        $Entries[1].Needle | Should -Be '000000000'
    }

    It 'treats fewer than seven digits as text, not a phone number' {
        $Entries[2].IsPhone | Should -BeFalse
    }

    It 'finds <Text>' -ForEach @(
        @{ Text = 'Written by MARIA RIVERA'; Line = 3 }
        @{ Text = 'Call 000-000-000 after six'; Line = 4 }
        @{ Text = '"phone": "+48000000000"'; Line = 4 }
        @{ Text = 'version 12-34'; Line = 5 }
    ) {
        (Find-PersonalString $Text $Entries).LineNumber | Should -Be $Line
    }

    It 'finds nothing in <Text>' -ForEach @(
        @{ Text = 'Written by Diego Rivera' }
        @{ Text = 'version 12.34' }
    ) {
        Find-PersonalString $Text $Entries | Should -BeNullOrEmpty
    }
}

Describe 'F3: checking commits' {
    BeforeAll {
        $script:ListPath = New-PersonalStringsList @('# Fictional entries', 'Maria Rivera', 'maria@example.com', '+48 000 000 000')
        $sha = Add-TestCommit $RepoRoot -Files @{
            'notes/maria rivera.md' = "# Notes`n`nAsk on 000 000 000.`n"
        } -Message "docs(plan): add notes`n`nWritten for maria@example.com.`n`nTask: M0.1"
        $script:Failures = @(Test-PersonalData @(Get-Commit $sha) $ListPath)
    }

    It 'fails when the list is missing, rather than passing' {
        (Test-PersonalData @(Get-Commit $FixtureSha) (Join-Path $RepoRoot '.git/info/no-such-list')).Problem |
            Should -Be 'the personal-strings list is missing, so personal data can''t be checked'
    }

    It 'fails when the list has no entries' {
        (Test-PersonalData @(Get-Commit $FixtureSha) (New-PersonalStringsList @('# only a comment', ''))).Problem |
            Should -Be 'the personal-strings list has no entries'
    }

    It 'finds the message line, the file name and the added line' {
        $Failures | ForEach-Object { $_.Where } | Should -Be @(
            'commit message, line 3'
            'file name notes/maria rivera.md'
            'notes/maria rivera.md:3'
        )
    }

    It 'names the line of the list, never its value' {
        $Failures | ForEach-Object { $_.Problem } | Should -Be @(
            'matches personal-strings line 3'
            'matches personal-strings line 2'
            'matches personal-strings line 4'
        )
    }

    It 'hides a failure whose place or message holds a listed value' {
        $shown = @(Hide-PersonalData $Failures $ListPath)
        $shown | ForEach-Object { "$($_.Where) $($_.Problem)" } | Should -Not -Match 'maria|000 000'
        $shown[1].Where | Should -Be '(not shown)'
        $shown[1].Problem | Should -Be 'contains personal data (personal-strings line 2)'
    }

    It 'leaves other failures as they are' {
        $other = New-Failure 'F4' 'abc123456' 'subject' "'Fix bug' doesn't match the pattern"
        (Hide-PersonalData @($other) $ListPath).Where | Should -Be 'subject'
    }
}

Describe 'F6: forbidden files' {
    It 'refuses <Path>' -ForEach @(
        @{ Path = '.env' }
        @{ Path = 'src/.env.local' }
        @{ Path = 'keys/id_rsa.pub' }
        @{ Path = 'certs/dev.pfx' }
        @{ Path = 'certs/dev.pem' }
        @{ Path = 'MealPlanner.slnx.user' }
        @{ Path = 'src/MealPlanner.Server/bin/Release/mealplanner.dll' }
        @{ Path = 'src/MealPlanner.Server/obj/project.assets.json' }
    ) {
        Test-ForbiddenPath $Path | Should -Not -BeNullOrEmpty
    }

    It 'allows <Path>' -ForEach @(
        @{ Path = 'src/MealPlanner.Server/Program.cs' }
        @{ Path = 'docs/environment.md' }
        @{ Path = 'src/robin/binder.cs' }
        @{ Path = 'bin' }
    ) {
        Test-ForbiddenPath $Path | Should -BeNullOrEmpty
    }
}

Describe 'F6: secret-looking JSON keys' {
    It 'finds <Key> with a value' -ForEach @(
        @{ Key = 'password' }, @{ Key = 'api-key' }, @{ Key = 'api_key' }, @{ Key = 'apiKey' },
        @{ Key = 'client_secret' }, @{ Key = 'Connection-String' }, @{ Key = 'Token' }
    ) {
        Find-SecretValues @{ $Key = 'x' } '' | Should -Be $Key
    }

    It 'finds a key deep inside objects and arrays, by its full path' {
        $json = '{ "Parameters": { "servers": [ { "name": "a" }, { "password": 1234 } ] } }' | ConvertFrom-Json -AsHashtable
        Find-SecretValues $json '' | Should -Be 'Parameters.servers[1].password'
    }

    It 'ignores a key whose value is <Case>' -ForEach @(
        @{ Case = 'empty'; Value = '' }
        @{ Case = 'true'; Value = $true }
        @{ Case = 'null'; Value = $null }
    ) {
        Find-SecretValues @{ password = $Value } '' | Should -BeNullOrEmpty
    }
}

Describe 'F6: checking commits' {
    BeforeAll {
        $script:Settings = "{`n  // a comment`n  ""Parameters"": { ""postgres-password"": ""local-dev-only"", },`n}`n"
    }

    It 'refuses a JSON file with a secret value' {
        $sha = Add-TestCommit $RepoRoot -Files @{ 'src/App/appsettings.json' = $Settings }
        $failure = @(Test-ForbiddenContent @(Get-Commit $sha))
        $failure | Should -HaveCount 1
        $failure[0].Where | Should -Be 'src/App/appsettings.json, key Parameters.postgres-password'
    }

    It 'accepts the key once allowed-secrets.txt names its file and path' {
        $sha = Add-TestCommit $RepoRoot -Files @{
            '.githooks/allowed-secrets.txt' = "# Why it's safe`nsrc/Allowed/appsettings.json Parameters.postgres-password`n"
            'src/Allowed/appsettings.json'  = $Settings
            'src/Other/appsettings.json'    = $Settings
        }
        (Test-ForbiddenContent @(Get-Commit $sha)).Where | Should -Be 'src/Other/appsettings.json, key Parameters.postgres-password'
    }

    It 'skips NuGet lock files, whose keys are package ids' {
        # A package's dependencies map ids to versions, so this key holds a value.
        $lock = '{ "version": 2, "dependencies": { "net11.0": { "Microsoft.Extensions.Hosting": { "type": "Transitive", "resolved": "11.0.0", ' +
            '"dependencies": { "Microsoft.Extensions.Configuration.UserSecrets": "11.0.0" } } } } }'
        $sha = Add-TestCommit $RepoRoot -Files @{ 'src/App/packages.lock.json' = $lock }
        Test-ForbiddenContent @(Get-Commit $sha) | Should -BeNullOrEmpty
        # The same content under another name is flagged, so the skip is what lets it pass.
        $other = Add-TestCommit $RepoRoot -Files @{ 'src/App/versions.json' = $lock }
        (Test-ForbiddenContent @(Get-Commit $other)).Where |
            Should -Be 'src/App/versions.json, key dependencies.net11.0.Microsoft.Extensions.Hosting.dependencies.Microsoft.Extensions.Configuration.UserSecrets'
    }

    It 'refuses a JSON file it can''t parse' {
        $sha = Add-TestCommit $RepoRoot -Files @{ 'src/App/broken.json' = '{ "password": ' }
        (Test-ForbiddenContent @(Get-Commit $sha)).Problem | Should -Be "isn't valid JSON, so its keys can't be checked"
    }
}
