param(
    [string[]]$Roots = @(
        "$env:USERPROFILE\.agents\skills",
        "$env:USERPROFILE\.codex\skills",
        (Join-Path (Get-Location) ".agents\skills"),
        (Join-Path (Get-Location) ".codex\skills")
    )
)

function Get-SkillCategory {
    param(
        [string]$Name,
        [string]$Description
    )

    $text = "$Name $Description".ToLowerInvariant()

    if ($text -match "web|website|frontend|front-end|react|next|nextjs|\bui\b|\bux\b|design|sites|tailwind|\bcss\b") {
        return "Web and Frontend"
    }
    if ($text -match "image|visual|visualize|canvas|diagram|chart|graph|media") {
        return "Visual and Media"
    }
    if ($text -match "automation|automate|hook|loop|plugin|sdk|api|gmail|calendar|slack|github|agent") {
        return "Automation and Integrations"
    }
    if ($text -match "prd|roadmap|project|planning|plan|product|requirement|spec") {
        return "Planning and PM"
    }
    if ($text -match "review|test|testing|quality|audit|security|lint|\bpr\b|pull request|bug") {
        return "Review and Quality"
    }
    if ($text -match "clear|cleanup|clean|config|settings|statusline|cli|install|migrate|shell|computer|browser|chrome") {
        return "System and Configuration"
    }
    if ($text -match "research|paper|literature|scholar|docs|document|writing|write|readme|citation") {
        return "Research and Writing"
    }

    return "General"
}

function Get-SkillPhase {
    param(
        [string]$Name,
        [string]$Description
    )

    $text = "$Name $Description".ToLowerInvariant()

    if ($text -match "prd|roadmap|planning|plan|requirement|spec|architecture|design") {
        return "Planning"
    }
    if ($text -match "build|create|implement|develop|web|frontend|react|next|ui|api|sdk|automation|hook") {
        return "Build"
    }
    if ($text -match "review|test|testing|audit|quality|security|lint|bug|accessibility|a11y") {
        return "Review"
    }
    if ($text -match "find|search|research|discover|docs|document|paper|literature|scholar") {
        return "Discovery"
    }
    if ($text -match "deploy|hosting|monitor|cleanup|clear|config|settings|install|update|migrate|statusline") {
        return "Operate"
    }

    return "General"
}

$seen = @{}

foreach ($root in $Roots) {
    if (-not (Test-Path -LiteralPath $root)) {
        continue
    }

    Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $skillFile = Join-Path $_.FullName "SKILL.md"
        if (-not (Test-Path -LiteralPath $skillFile)) {
            return
        }

        $lines = Get-Content -LiteralPath $skillFile -TotalCount 80 -ErrorAction SilentlyContinue
        $name = $_.Name
        $description = ""
        $inFrontmatter = $false
        $frontmatterStarted = $false

        for ($index = 0; $index -lt $lines.Count; $index++) {
            $line = $lines[$index]
            if ($line -eq "---") {
                if (-not $frontmatterStarted) {
                    $frontmatterStarted = $true
                    $inFrontmatter = $true
                    continue
                }
                break
            }

            if (-not $inFrontmatter) {
                continue
            }

            if ($line -match "^\s*name:\s*['""]?(.+?)['""]?\s*$") {
                $name = $Matches[1]
            }

            if ($line -match "^\s*description:\s*['""]?(.+?)['""]?\s*$") {
                $description = $Matches[1]
                if ($description -in @(">-", "|-", ">", "|")) {
                    $descriptionLines = @()
                    for ($next = $index + 1; $next -lt $lines.Count; $next++) {
                        $nextLine = $lines[$next]
                        if ($nextLine -eq "---" -or $nextLine -match "^\S") {
                            break
                        }
                        if ($nextLine.Trim().Length -gt 0) {
                            $descriptionLines += $nextLine.Trim()
                        }
                    }
                    $description = ($descriptionLines -join " ")
                }
            }
        }

        $key = "$name|$($_.FullName)"
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            [pscustomobject]@{
                Name = $name
                Category = (Get-SkillCategory -Name $name -Description $description)
                Phase = (Get-SkillPhase -Name $name -Description $description)
                Description = $description
                Path = $_.FullName
            }
        }
    }
}
