# Cache migration on Windows

The default `migrate` mode redirects future regenerable cache writes. It does
not move tool homes, delete existing data, or immediately reclaim C: space.
Read this procedure before changing settings. Examples require Windows
PowerShell 5.1 or PowerShell 7 and must be adapted to the selected tools.

## Classify the target

Use the installed tool's version and documentation to identify its effective
path, including environment, user, project, IDE, and command-line overrides.

- npm `cache` / `NPM_CONFIG_CACHE`: downloaded package cache, separate from
  the global install `prefix` and `.npmrc` authentication/configuration.
- pip `global.cache-dir` / `PIP_CACHE_DIR`: HTTP and wheel caches, separate
  from environments, installed packages, and `pip.ini`. `global.cache-dir` is
  a key applying to all pip commands, not a request for machine-wide scope.
- pnpm `store-dir` (newer versions also document `storeDir`): package store,
  separate from `PNPM_HOME` executables and global installs. Existing projects
  can depend on their original store layout. Preserve the old store; validate
  representative projects before any later tool-supported pruning. A store
  on another volume can require copies instead of hardlinks.
- Yarn 1 `cache-folder` / `YARN_CACHE_FOLDER`: package cache. Yarn 2+ uses
  `cacheFolder` and `enableGlobalCache`; when global caching is enabled,
  `cacheFolder` is ignored. Do not blindly apply Classic commands to modern
  Yarn, relocate `globalFolder` as if it were just a cache, or remove a
  committed `.yarn/cache` used for offline/Zero-Installs workflows.
- Hugging Face `HF_HUB_CACHE`: downloaded model/dataset/Space repositories.
  `HF_HOME` also contains tokens; keep `HF_HOME` and `HF_TOKEN_PATH` unchanged.
  `HF_ASSETS_CACHE` can contain downstream-generated data; `HF_XET_CACHE` also
  includes upload staging state. Inspect them separately and stop all writers;
  do not assume either is safe to discard. Offline or locally modified model
  data is not necessarily replaceable.
- Cargo `CARGO_HOME`: complete home, including `config`/`config.toml`,
  `credentials`/`credentials.toml`, `bin`, `.crates.toml`, `.crates2.json`,
  registry/git data, and other state. Keep it in place in cache-only mode.
  `CARGO_TARGET_DIR` selects build output, not the registry/git cache; do not
  silently substitute it or combine unrelated projects into one target tree.
- Gradle `GRADLE_USER_HOME`: complete home, including `gradle.properties`,
  `init.gradle(.kts)`, `init.d`, caches, daemon state, wrapper distributions,
  and downloaded JDKs. Keep it in place in cache-only mode. A project's local
  build-cache directory setting does not redirect all dependency caches.

Do not introduce broad home/location changes such as `RUSTUP_HOME`,
`PNPM_HOME`, `JAVA_HOME`, `HF_HOME`, or `XDG_CACHE_HOME` as cache-only fixes.

## Preflight and preserve existing state

Complete these steps for each selected tool; do not run every example as a batch.

1. Record tool versions, resolved executables, effective source directories,
   configuration file locations, and relevant Process/User/Machine environment
   values. Inspect overrides privately: config/debug output and backup files
   can contain credentials. Do not publish them in logs or commits.
2. Confirm exact absolute source and destination paths, file counts, byte sizes,
   and last modified times. Reject drive roots, overlapping trees, unexpected
   existing destinations, cloud-sync/network targets, and unresolved junctions
   or symlinks. Check destination free space, filesystem support, user write
   access, and ACLs. Never merge an existing destination blindly.
3. Stop terminals, IDE builds, package managers, notebooks, and background jobs
   that write these paths. For a Gradle home migration, stop daemons using the
   old effective home and every relevant Gradle/wrapper version (`--stop`).
4. Save a rollback record outside source/destination trees. Preserve whether
   each setting was absent, as well as its original scope/value. Back up any
   config file before editing it; avoid concurrent config edits. Choose one
   mechanism per tool, not both an environment variable and a config-file key.
5. For regenerable caches, either keep the old cache and allow a fresh cache
   only if re-downloads/offline effects are acceptable, or copy and verify it
   first. Do not change any home variable in this step. If copies contain
   links (common for Hugging Face), stop and use a tool-specific link-aware
   procedure; the bundled verifier intentionally refuses reparse points.

Use narrow read-only queries; skip missing tools rather than installing them:

```powershell
npm.cmd --version
npm.cmd config get cache
npm.cmd config get userconfig
python -m pip --version
python -m pip cache dir
# Inspect privately for file locations and overrides; can expose secrets:
python -m pip config debug
pnpm.cmd --version
pnpm.cmd store path
yarn.cmd --version
# Yarn 1 only:
yarn.cmd cache dir
# Yarn 2+ only:
yarn.cmd config get enableGlobalCache
yarn.cmd config get cacheFolder
yarn.cmd config get globalFolder
```

## Redirect selected caches

The following example uses environment variables only, for npm, pip, and Hub
downloads. Select only the tools requested. Create inspected, writable target
directories first. Keep both the original cache data and the original home
variables. No existing cache is copied or deleted by these commands.

Run this in the same PowerShell session after preflight. Use a new record name
for a new migration; never overwrite the original record on a retry.

```powershell
$ErrorActionPreference = 'Stop'
$changes = [ordered]@{
    NPM_CONFIG_CACHE = 'E:\DevCache\npm'
    PIP_CACHE_DIR = 'E:\DevCache\pip'
    HF_HUB_CACHE = 'E:\DevCache\huggingface\hub'
}
$record = Join-Path $env:LOCALAPPDATA 'CDE-clear\cache-env-before.clixml'
if (Test-Path -LiteralPath $record) {
    throw 'Rollback record exists. Verify or roll back that migration first.'
}
New-Item -ItemType Directory -Path (Split-Path $record) -Force | Out-Null
$saved = foreach ($name in $changes.Keys) {
    [pscustomobject]@{
        Name = $name
        User = [Environment]::GetEnvironmentVariable($name, 'User')
        Process = [Environment]::GetEnvironmentVariable($name, 'Process')
        Machine = [Environment]::GetEnvironmentVariable($name, 'Machine')
    }
}
$saved | Export-Clixml -LiteralPath $record
# The record is saved before the first configuration change.
foreach ($name in $changes.Keys) {
    [Environment]::SetEnvironmentVariable($name, $changes[$name], 'User')
    [Environment]::SetEnvironmentVariable($name, $changes[$name], 'Process')
}
```

If a write fails partway, stop and restore all recorded values using the rollback
block below. Machine values are recorded for diagnosis and never changed.
For a retry, use verification first; do not re-baseline the rollback record.

If config files are preferred instead, back up the resolved user config and
change just the selected key. These are alternatives to the matching environment
variables above, not additional commands. Check existing overriding variables.

```powershell
npm.cmd config set cache 'E:\DevCache\npm' --location=user
if ($LASTEXITCODE -ne 0) { throw 'npm configuration failed' }
python -m pip config --user set global.cache-dir 'E:\DevCache\pip'
if ($LASTEXITCODE -ne 0) { throw 'pip configuration failed' }
# Use the installed pnpm version's key spelling and user/global config scope.
# --global here selects pnpm's per-user global config, not a machine setting.
pnpm.cmd config set store-dir 'E:\DevCache\pnpm-store' --global
if ($LASTEXITCODE -ne 0) { throw 'pnpm configuration failed' }
# Yarn Classic (1.x) only, after backing up the resolved user .yarnrc:
yarn.cmd config set cache-folder 'E:\DevCache\yarn'
if ($LASTEXITCODE -ne 0) { throw 'Yarn configuration failed' }
```

For modern Yarn, inspect effective settings in each relevant project and follow
that version's documented cache configuration. Do not supply a universal
user-home command: global cache and project cache modes behave differently.

## Optional complete tool-home relocation

Only use this procedure after explicit authorization to migrate a complete
Cargo or Gradle home. Cache-only authorization does not cover it. Do not switch
to an empty home or selectively copy only caches. Keep Rustup's separate
`RUSTUP_HOME` unchanged unless separately requested.

1. Complete preflight above. Record original Process/User values of the selected
   home variable and any user PATH edits in a separate rollback record. Identify
   the actual old home from overrides, not just `%USERPROFILE%\.cargo` or
   `%USERPROFILE%\.gradle`. Stop if these sources disagree until resolved.
2. Copy the entire stopped home, including hidden configuration, credentials,
   binaries, and installation metadata, to a new dedicated destination. Protect
   credential files with access at least as restrictive as the source. Inspect
   ACLs privately (`Get-Acl`); a cross-volume copy may inherit broader access.
   If custom ACLs/streams, links, locked files, or access errors cannot be
   preserved/verified, stop without switching. Do not elevate automatically.
3. Verify the copy before changing variables. The example below works only for
   ordinary trees without reparse points. Inspect paths and inventory first;
   it deliberately fails if the destination already exists, including on retry.

```powershell
# Example only: replace both paths with the inspected, authorized home paths.
$source = 'C:\Users\YOUR-USER\.cargo'
$destination = 'E:\DevTools\cargo-home'
if (Test-Path -LiteralPath $destination) {
    throw 'Destination exists: verify the previous copy; do not merge or overwrite.'
}
# Inspect links including ancestors BEFORE copying; stop if any are found.
# /E includes empty directories. Never add /MIR, /PURGE, /MOVE, or /MOV.
robocopy.exe $source $destination /E /COPY:DAT /DCOPY:DAT /XJ /R:0 /W:0
$copyExit = $LASTEXITCODE
if ($copyExit -ge 8) { throw "Copy failed ($copyExit); configuration unchanged" }
# Run from the skill/repository root. Any mismatch is a terminating error.
.\scripts\Test-CacheCopy.ps1 -Source $source -Destination $destination
```

4. After content and permissions pass, set only the selected home variable to
   the verified destination, at User and Process scope. For Cargo, inspect
   `Get-Command cargo,rustc,rustup -All` and installed command locations; if PATH
   explicitly names the old `bin`, back up and update that exact user PATH entry
   without rewriting the whole PATH. Inspect absolute paths in configs and
   launchers. For Gradle, check `-g` / `--gradle-user-home`,
   `-Dgradle.user.home`, IDE settings, wrapper versions, and JDK paths.
5. Restart parent apps and terminals, then verify the effective paths,
   installed-command inventory, representative builds, and required offline
   behavior. Retain the old home until a separately authorized cleanup.

The verifier compares relative names (including hidden files and empty
directories), entry types, lengths, and SHA-256 hashes. It is read-only and
repeatable with unchanged stopped trees. It does not prove ACL, alternate-stream,
or runtime compatibility. Run it before tools start writing the new home; after
that, expected divergence requires review rather than overwriting either tree.

## Verify and roll back

Repeat these read-only checks after changes and after restarting the hosting
terminal/IDE/Codex app. Starting a child shell from an old parent alone does not
refresh its inherited environment. Check in representative project directories
as well, because project and command-line options can override user settings.

```powershell
foreach ($name in 'NPM_CONFIG_CACHE', 'PIP_CACHE_DIR', 'HF_HUB_CACHE',
                  'CARGO_HOME', 'GRADLE_USER_HOME', 'HF_HOME') {
    [pscustomobject]@{
        Name = $name
        Process = [Environment]::GetEnvironmentVariable($name, 'Process')
        User = [Environment]::GetEnvironmentVariable($name, 'User')
    }
}
npm.cmd config get cache
if ($LASTEXITCODE -ne 0) { throw 'npm path check failed' }
python -m pip cache dir
if ($LASTEXITCODE -ne 0) { throw 'pip path check failed' }
# If huggingface_hub is already installed; prints paths, never token contents:
python -c "from huggingface_hub import constants as c; print(c.HF_HUB_CACHE); print(c.HF_HOME); print(c.HF_TOKEN_PATH)"
if ($LASTEXITCODE -ne 0) { throw 'Hub path check failed or library unavailable' }
# If pnpm or Yarn Classic was changed:
# pnpm.cmd store path
# yarn.cmd cache dir
```

Compare with the recorded baseline: home/token locations must stay unchanged
in cache-only mode. Run an approved representative operation for each selected
tool and check that it writes under the intended destination. For a home
migration, compare `cargo install --list`, tool resolution and versions, then
build a known Rust project; for Gradle, run an existing wrapper build with a
temporary init script printing `gradle.gradleUserHomeDir` and verify expected
properties/init scripts and offline dependencies. A missing tool/library is a
skipped check, never a pass. Path queries alone do not prove runtime behavior.

Restore the environment example with the original record. Missing original
variables are restored as absent; do not invent default values. Use
`[NullString]::Value` when passing a recorded null to the .NET API so newer
PowerShell/.NET versions do not turn it into an empty string:

```powershell
$ErrorActionPreference = 'Stop'
$record = Join-Path $env:LOCALAPPDATA 'CDE-clear\cache-env-before.clixml'
$saved = Import-Clixml -LiteralPath $record
foreach ($entry in $saved) {
    if ($entry.Name -notin @('NPM_CONFIG_CACHE', 'PIP_CACHE_DIR', 'HF_HUB_CACHE')) {
        throw 'Unexpected variable in rollback record'
    }
}
foreach ($entry in $saved) {
    $userValue = $entry.User
    $processValue = $entry.Process
    if ($null -eq $userValue) { $userValue = [NullString]::Value }
    if ($null -eq $processValue) { $processValue = [NullString]::Value }
    [Environment]::SetEnvironmentVariable($entry.Name, $userValue, 'User')
    [Environment]::SetEnvironmentVariable($entry.Name, $processValue, 'Process')
}
```

For config-file changes, restore the recorded key/value in the same scope; if
originally absent, remove just that key using the tool's unset/delete command.
Restore a whole backup only after checking for intervening edits. For complete
homes, stop all writers first, inspect new-only configurations, credentials,
installed tools, and other state created since switching, and preserve/reconcile
that state before returning to the old home and original PATH. Never mirror the
old copy over a now-active destination. Restart apps, repeat effective-path and
build checks, and retain both trees and the rollback record for review. Rollback
does not delete either tree or recover disk space by itself.

## Repeatable repository checks

Run the fixture tests from the repository root. They use synthetic trees under
a fresh temporary directory and preserve their fixtures for inspection. Copy
tests never read real tool homes. Settings tests query installed npm/pip with
temporary Process-scope cache overrides, restore those values in `finally`,
and never set persistent environment variables. They can read the tools' normal
configuration. Missing executables are reported as skipped; unexpected command
errors fail the check.

```powershell
powershell.exe -NoProfile -File .\tests\Test-CacheCopy.Tests.ps1
powershell.exe -NoProfile -File .\tests\Test-CacheSettings.ps1
pwsh.exe -NoProfile -File .\tests\Test-CacheCopy.Tests.ps1
pwsh.exe -NoProfile -File .\tests\Test-CacheSettings.ps1
```

If Windows PowerShell blocks script execution, review these local test scripts
and add `-ExecutionPolicy Bypass` to that test process only. Do not change the
persistent execution policy. The Windows CI workflow runs both test scripts
with both shells.

## Official references

Use these primary sources to check the installed version's semantics:

- [Cargo home contents](https://doc.rust-lang.org/cargo/guide/cargo-home.html)
- [Gradle directory layout](https://docs.gradle.org/current/userguide/directory_layout.html)
- [Hugging Face environment variables](https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables)
- [npm configuration](https://docs.npmjs.com/cli/using-npm/config/)
- [pip cache management](https://pip.pypa.io/en/stable/topics/caching/)
- [pip configuration scope](https://pip.pypa.io/en/stable/cli/pip_config/)
- [pnpm configuration](https://pnpm.io/cli/config)
- [pnpm store settings](https://pnpm.io/settings)
- [Yarn Classic cache](https://classic.yarnpkg.com/lang/en/docs/cli/cache/)
- [Modern Yarn cache settings](https://yarnpkg.com/configuration/yarnrc/)
