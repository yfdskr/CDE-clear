# CDE-clear

`CDE-clear` is a Codex skill for safely freeing disk space on Windows PCs. It focuses on practical C:/D:/E: drive cleanup, cache discovery, package-manager cache removal, and moving future cache growth away from the system drive.

The skill is intentionally conservative: it inspects first, separates safe cleanup from risky cleanup, and avoids deleting personal files, installed applications, browser profiles, system folders, or active projects without explicit user direction.

## What It Helps With

- Scan fixed drives and summarize free/used space.
- Find large user-level folders under `AppData`, `Documents`, `ProgramData`, temp folders, and developer cache locations.
- Offer cleanup modes instead of guessing what the user wants.
- Clear safe, regenerable caches through tool-supported commands where possible.
- Move future cache growth from `C:` to `D:` or `E:` using user-level config and environment variables.
- Explain administrator-only cleanup options such as DISM component cleanup without silently running them.

## Cleanup Modes

- `scan`: inventory only; no deletion or configuration changes.
- `safe`: temp files, package-manager caches, and browser cache candidates.
- `dev`: npm, pip, pnpm, Yarn, Gradle, Maven, NuGet, Cargo, Conda, Hugging Face, Playwright, Cypress, Android build caches, and identified project build artifacts.
- `app`: app-specific cache inspection for browsers, chat apps, Adobe, Lenovo, WPS, OpenAI/Codex, game launchers, and updaters.
- `migrate`: redirect identified caches to another drive such as `E:\DevCache`, preserving existing data and tool homes by default.
- `deep`: explain or provide administrator commands for Windows component cleanup, update cleanup, hibernation, restore points, and Storage Sense.

## Installation

Install with the Skills CLI:

```bash
npx skills add https://github.com/yfdskr/CDE-clear -g -a codex -y
```

You can also specify the skill explicitly:

```bash
npx skills add https://github.com/yfdskr/CDE-clear --skill cde-clear -g -a codex -y
```

## Usage

After installation, ask Codex for cleanup help naturally:

```text
Use $cde-clear to scan my C/D/E drives and tell me what is safe to clean.
```

```text
Use $cde-clear to redirect future npm and pip caches to E:, keeping existing data and tool homes unchanged.
```

```text
Use $cde-clear in safe mode. Clean only regenerable caches and report before/after free space.
```

## Cache Migration Safety

Cache-only migration keeps `CARGO_HOME`, `GRADLE_USER_HOME`, and `HF_HOME`
unchanged: they also contain configuration, credentials, installed tools, or
other state. Use cache-specific settings such as `HF_HUB_CACHE` instead of
switching complete homes to empty directories. Existing caches stay in place;
redirecting future writes does not immediately free space.

Follow [the migration procedure](references/cache-migration.md) for variable
classification, version-specific pnpm/Yarn guidance, preflight checks, original
data protection, verification, and rollback. Complete tool-home relocation
requires an explicit request, a stopped and verified full copy, and retention
of the original home. A generic cache-migration request does not authorize it.

Run repeatable, isolated PowerShell verification tests from the repository root:

```powershell
powershell.exe -NoProfile -File .\tests\Test-CacheCopy.Tests.ps1
powershell.exe -NoProfile -File .\tests\Test-CacheSettings.ps1
pwsh.exe -NoProfile -File .\tests\Test-CacheCopy.Tests.ps1
pwsh.exe -NoProfile -File .\tests\Test-CacheSettings.ps1
```

Tests use synthetic files and do not change persistent user configuration.
They verify copy integrity, failure cases, effective npm/pip cache paths, and
restoration of temporary process values. Missing executables are reported as
skipped. They do not perform live tool-home migrations. If local Windows
PowerShell policy blocks these reviewed tests, use `-ExecutionPolicy Bypass`
for that test process only; no persistent execution-policy change is needed.

## Repository Layout

```text
SKILL.md
agents/
  openai.yaml
references/
  cache-migration.md
scripts/
  Test-CacheCopy.ps1
tests/
  Test-CacheCopy.Tests.ps1
  Test-CacheSettings.ps1
README.md
LICENSE
```

## Notes

This repository contains only the `cde-clear` skill. The separate `skill-advisor` skill now lives at:

```text
https://github.com/yfdskr/skill-advisor
```

## License

MIT
