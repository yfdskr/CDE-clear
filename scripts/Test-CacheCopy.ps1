#requires -Version 5.1
<#
.SYNOPSIS
Read-only verification of a stopped, ordinary directory tree copied elsewhere.
.DESCRIPTION
Checks relative file/directory names, lengths, and SHA-256 content hashes.
Refuses overlapping trees and reparse points, including linked ancestors.
Does not verify ACLs, alternate streams, or tool behavior. Never changes settings.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CheckedRoot([string]$Path) {
    if (-not [IO.Path]::IsPathRooted($Path) -or $Path -notmatch '^[A-Za-z]:[\\/]') {
        throw 'Use an absolute local drive path.'
    }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    if ($full -eq [IO.Path]::GetPathRoot($full).TrimEnd('\', '/')) {
        throw 'Drive roots are not supported.'
    }
    $item = Get-Item -LiteralPath $full -Force
    if (-not $item.PSIsContainer) { throw 'Both roots must be directories.' }
    $ancestor = $item
    while ($null -ne $ancestor) {
        if ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw 'Reparse points require a tool-specific copy and verification plan.'
        }
        $ancestor = $ancestor.Parent
    }
    return $item.FullName.TrimEnd('\', '/')
}

function Get-TreeManifest([string]$Root) {
    $manifest = @{}
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force)) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw 'Reparse points require a tool-specific copy and verification plan.'
            }
            $relative = $item.FullName.Substring($Root.Length + 1)
            if ($item.PSIsContainer) {
                $manifest[$relative] = 'Directory'
                $pending.Push($item.FullName)
            } else {
                $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
                $manifest[$relative] = "File:$($item.Length):$hash"
            }
        }
    }
    return ,$manifest
}

$sourceRoot = Get-CheckedRoot $Source
$destinationRoot = Get-CheckedRoot $Destination
if ($sourceRoot.Equals($destinationRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $sourceRoot.StartsWith($destinationRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
    $destinationRoot.StartsWith($sourceRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Source and destination must be distinct, non-overlapping trees.'
}
$before = Get-TreeManifest $sourceRoot
$after = Get-TreeManifest $destinationRoot
if ($before.Count -ne $after.Count) { throw 'Copy differs: entry count mismatch.' }
foreach ($key in $before.Keys) {
    if (-not $after.ContainsKey($key) -or $before[$key] -cne $after[$key]) {
        throw 'Copy differs: relative path, entry type, length, or SHA-256 mismatch.'
    }
}
[pscustomobject]@{
    Verified = $true
    Entries = $before.Count
    Source = $sourceRoot
    Destination = $destinationRoot
}
