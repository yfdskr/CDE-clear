#requires -Version 5.1
# Read-only tool queries with temporary Process-scope overrides; no User writes.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# npm 12 redacts UUID-shaped values, including otherwise harmless cache paths.
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('cde-clear-settings-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
$names = @('NPM_CONFIG_CACHE', 'PIP_CACHE_DIR')
$saved = @{}
foreach ($name in $names) {
    $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$homes = @('CARGO_HOME', 'GRADLE_USER_HOME', 'HF_HOME', 'HF_TOKEN_PATH')
$homeValues = @{}
foreach ($name in $homes) {
    $homeValues[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$passed = 0
$skipped = 0
try {
    $npmCache = Join-Path $fixture 'npm'
    $pipCache = Join-Path $fixture 'pip'
    New-Item -ItemType Directory -Path $npmCache, $pipCache | Out-Null
    [Environment]::SetEnvironmentVariable('NPM_CONFIG_CACHE', $npmCache, 'Process')
    [Environment]::SetEnvironmentVariable('PIP_CACHE_DIR', $pipCache, 'Process')
    1..2 | ForEach-Object {
        if (Get-Command npm.cmd -ErrorAction SilentlyContinue) {
            $actual = (& npm.cmd config get cache | Out-String).Trim()
            if ($LASTEXITCODE -ne 0 -or $actual -ne $npmCache) {
                throw 'npm effective cache path mismatch'
            }
            $script:passed++
        } else {
            Write-Output 'SKIP: npm.cmd unavailable'
            $script:skipped++
        }
        if (Get-Command python -ErrorAction SilentlyContinue) {
            $actual = (& python -m pip cache dir | Out-String).Trim()
            if ($LASTEXITCODE -ne 0 -or $actual -ne $pipCache) {
                throw 'pip effective cache path mismatch (or pip unavailable/disabled)'
            }
            $script:passed++
        } else {
            Write-Output 'SKIP: python unavailable'
            $script:skipped++
        }
    }
} finally {
    foreach ($name in $names) {
        $value = $saved[$name]
        if ($null -eq $value) { $value = [NullString]::Value }
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }
}
foreach ($name in $names + $homes) {
    $expected = if ($names -contains $name) { $saved[$name] } else { $homeValues[$name] }
    if ([Environment]::GetEnvironmentVariable($name, 'Process') -cne $expected) {
        throw "Process value was not preserved: $name"
    }
    $passed++
}
# Exercise the documented serialized rollback for both absent and existing values.
$testName = 'CDE_CLEAR_TEST_ROLLBACK'
$original = [Environment]::GetEnvironmentVariable($testName, 'Process')
try {
    foreach ($baseline in @($null, 'previous-cache')) {
        $record = Join-Path $fixture 'rollback.clixml'
        [pscustomobject]@{ Name = $testName; Process = $baseline } |
            Export-Clixml -LiteralPath $record
        [Environment]::SetEnvironmentVariable($testName, 'changed-cache', 'Process')
        $entry = Import-Clixml -LiteralPath $record
        $value = $entry.Process
        if ($null -eq $value) { $value = [NullString]::Value }
        [Environment]::SetEnvironmentVariable($entry.Name, $value, 'Process')
        if ([Environment]::GetEnvironmentVariable($testName, 'Process') -cne $baseline) {
            throw 'Serialized rollback did not restore absence or previous value'
        }
        $passed++
    }
} finally {
    if ($null -eq $original) { $original = [NullString]::Value }
    [Environment]::SetEnvironmentVariable($testName, $original, 'Process')
}
Write-Output "PASS: $passed checks; SKIP: $skipped; PowerShell $($PSVersionTable.PSVersion)"
Write-Output "Fixtures retained at: $fixture"
