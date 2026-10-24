#requires -Version 5.1
# Standalone fixture tests; no Pester/module installation required.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$verify = Join-Path (Split-Path $PSScriptRoot) 'scripts\Test-CacheCopy.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('cde-clear-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $fixture | Out-Null
$passed = 0

function Assert-Rejected([scriptblock]$Action, [string]$Reason) {
    $rejected = $false
    try { & $Action | Out-Null } catch {
        if ($_.Exception.Message -notlike "*$Reason*") { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw "Expected rejection: $Reason" }
    $script:passed++
}

$source = Join-Path $fixture 'source [original]'
$destination = Join-Path $fixture 'destination [copy]'
foreach ($root in @($source, $destination)) {
    New-Item -ItemType Directory -Path $root | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'empty') | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'bin') | Out-Null
    Set-Content -LiteralPath (Join-Path $root 'config.toml') -Value 'fixture-config'
    Set-Content -LiteralPath (Join-Path $root 'credentials.toml') -Value 'FAKE-TOKEN'
    Set-Content -LiteralPath (Join-Path $root '.crates2.json') -Value '{"fixture":true}'
    Set-Content -LiteralPath (Join-Path $root 'bin\tool.exe') -Value 'fixture-binary'
    $hidden = Get-Item -LiteralPath (Join-Path $root '.crates2.json') -Force
    $hidden.Attributes = $hidden.Attributes -bor [IO.FileAttributes]::Hidden
}
$originalHash = (Get-FileHash -LiteralPath (Join-Path $source 'credentials.toml')).Hash
1..2 | ForEach-Object {
    $result = & $verify -Source $source -Destination $destination
    if (-not $result.Verified -or $result.Entries -ne 6) { throw 'Valid copy failed' }
    $script:passed++
}

# Same byte length, different content must fail; counts/sizes alone are insufficient.
Set-Content -LiteralPath (Join-Path $destination 'credentials.toml') -Value 'FAKE-OTHER'
Assert-Rejected { & $verify -Source $source -Destination $destination } 'SHA-256 mismatch'
Copy-Item -LiteralPath (Join-Path $source 'credentials.toml') -Destination $destination -Force

# Preserve missing/extra entries and empty directory semantics.
$empty = Join-Path $destination 'empty'
$renamed = Join-Path $destination 'different-empty'
Rename-Item -LiteralPath $empty -NewName 'different-empty'
Assert-Rejected { & $verify -Source $source -Destination $destination } 'relative path'
Rename-Item -LiteralPath $renamed -NewName 'empty'
Set-Content -LiteralPath (Join-Path $destination 'extra.txt') -Value 'extra'
Assert-Rejected { & $verify -Source $source -Destination $destination } 'entry count'
$short = Join-Path $fixture 'missing-files'
New-Item -ItemType Directory -Path $short | Out-Null
Assert-Rejected { & $verify -Source $source -Destination $short } 'entry count'
Assert-Rejected { & $verify -Source $source -Destination $source } 'non-overlapping'
Assert-Rejected { & $verify -Source $source -Destination (Join-Path $source 'bin') } 'non-overlapping'
Assert-Rejected { & $verify -Source (Join-Path $source 'bin') -Destination $source } 'non-overlapping'
Assert-Rejected { & $verify -Source '.' -Destination $destination } 'absolute local'
Assert-Rejected { & $verify -Source ([IO.Path]::GetPathRoot($source)) -Destination $destination } 'Drive roots'
Assert-Rejected { & $verify -Source (Join-Path $source 'config.toml') -Destination $destination } 'directories'
Assert-Rejected { & $verify -Source $source -Destination (Join-Path $fixture 'absent') } 'does not exist'

# Junction creation does not require Developer Mode or administrator privileges.
$linked = Join-Path $fixture 'linked-source'
$linkTarget = Join-Path $fixture 'junction-target'
New-Item -ItemType Directory -Path (Join-Path $linkTarget 'bin') -Force | Out-Null
# Windows PowerShell 5.1 expands brackets in New-Item's junction target.
# Keep bracket paths in the content tests and use a plain target for links.
New-Item -ItemType Junction -Path $linked -Target $linkTarget | Out-Null
Assert-Rejected { & $verify -Source $linked -Destination $destination } 'Reparse points'
Assert-Rejected { & $verify -Source (Join-Path $linked 'bin') -Destination $destination } 'Reparse points'
$childLink = Join-Path $short 'nested-link'
New-Item -ItemType Junction -Path $childLink -Target $linkTarget | Out-Null
Assert-Rejected { & $verify -Source $short -Destination $destination } 'Reparse points'

if ((Get-FileHash -LiteralPath (Join-Path $source 'credentials.toml')).Hash -ne $originalHash) {
    throw 'Source was modified'
}
$passed++
Write-Output "PASS: $passed checks on PowerShell $($PSVersionTable.PSVersion)"
Write-Output "Fixtures retained at: $fixture"
