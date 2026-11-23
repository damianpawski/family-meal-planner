# Which commits a push includes (docs/review/push-review.md, Part 3, "Which commits"):
# the ones no branch on the remote has yet. Get-PushedRefs is taken from push-review.ps1
# itself, so these tests run the hook's own code without running the whole hook.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:RepoRoot = New-TestRepository
    . (Join-Path $HooksDirectory 'lib/Process.ps1')
    . (Join-Path $HooksDirectory 'lib/Git.ps1')

    $hook = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $HooksDirectory 'push-review.ps1'), [ref]$null, [ref]$null)
    $function = $hook.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-PushedRefs' }, $true)
    . ([scriptblock]::Create($function.Extent.Text))

    $script:Remote = New-TestRepository -Bare
    Invoke-TestGit $RepoRoot remote add origin $Remote | Out-Null
    $script:Main1 = Add-TestCommit $RepoRoot -Files @{ 'a.txt' = 'one' }
    $script:Main2 = Add-TestCommit $RepoRoot -Files @{ 'a.txt' = 'two' }
    Invoke-TestGit $RepoRoot push --quiet origin main | Out-Null

    function Get-PushedCommit([string[]] $RefLines, [string] $Remote = 'origin') {
        # The hook reads git's ref lines from standard input, and the remote's name from
        # its own parameters ($RemoteName and $Range, which the function sees through
        # PowerShell's dynamic scoping).
        $RemoteName = $Remote
        $Range = $null
        $standardInput = [Console]::In
        [Console]::SetIn([System.IO.StringReader]::new(($RefLines -join "`n") + "`n"))
        try { @(Get-PushedRefs | Where-Object { $_.Shas.Count -gt 0 }) }
        finally { [Console]::SetIn($standardInput) }
    }
}

AfterAll {
    Remove-TestRepository $RepoRoot
    Remove-TestRepository $Remote
}

Describe 'Which commits a push includes' {
    It 'checks only the new commits on a branch''s first push, not the history under it' {
        Invoke-TestGit $RepoRoot switch --quiet -c first-push $Main2 | Out-Null
        $one = Add-TestCommit $RepoRoot -Files @{ 'b.txt' = 'one' }
        $two = Add-TestCommit $RepoRoot -Files @{ 'b.txt' = 'two' }
        $refs = Get-PushedCommit "refs/heads/first-push $two refs/heads/first-push $NoSha"
        $refs.Branch | Should -Be 'first-push'
        $refs.Shas | Should -Be @($one, $two)
    }

    It 'checks only the commits added since the branch''s last push' {
        Invoke-TestGit $RepoRoot switch --quiet -c update $Main2 | Out-Null
        $pushed = Add-TestCommit $RepoRoot -Files @{ 'c.txt' = 'one' }
        Invoke-TestGit $RepoRoot push --quiet origin update | Out-Null
        $new = Add-TestCommit $RepoRoot -Files @{ 'c.txt' = 'two' }
        (Get-PushedCommit "refs/heads/update $new refs/heads/update $pushed").Shas | Should -Be @($new)
    }

    It 'leaves out main''s newer commits when a branch is rebased onto them' {
        Invoke-TestGit $RepoRoot switch --quiet -c rebased $Main1 | Out-Null
        $old = Add-TestCommit $RepoRoot -Files @{ 'd.txt' = 'one' }
        Invoke-TestGit $RepoRoot push --quiet origin rebased | Out-Null
        Invoke-TestGit $RepoRoot rebase --quiet $Main2 | Out-Null
        $rebased = "$(Invoke-TestGit $RepoRoot rev-parse HEAD)".Trim()
        $rebased | Should -Not -Be $old
        (Get-PushedCommit "refs/heads/rebased $rebased refs/heads/rebased $old").Shas | Should -Be @($rebased)
    }

    It 'checks nothing when a branch is deleted' {
        Get-PushedCommit "(delete) $NoSha refs/heads/update $Main2" | Should -BeNullOrEmpty
    }

    It 'checks nothing when every commit is already on the remote' {
        Get-PushedCommit "refs/heads/copy $Main2 refs/heads/copy $NoSha" | Should -BeNullOrEmpty
    }

    It 'checks every reachable commit when the push goes to a URL rather than a named remote' {
        (Get-PushedCommit "refs/heads/main $Main2 refs/heads/main $NoSha" -Remote $Remote).Shas | Should -Be @($Main1, $Main2)
    }
}
