# CDE-clear

`CDE-clear` is a Codex skill for safely freeing disk space on Windows PCs. It focuses on practical C:/D:/E: drive cleanup, cache discovery, package-manager cache removal, and moving future cache growth away from the system drive.

The skill is intentionally conservative: it helps inspect first, separates safe cleanup from risky cleanup, and avoids deleting personal files, installed applications, browser profiles, system folders, or active projects without explicit user direction.

## What It Helps With

- Scan fixed drives and summarize free/used space.
- Find large user-level folders under `AppData`, `Documents`, `ProgramData`, temp folders, and developer cache locations.
- Offer cleanup modes instead of guessing what the user wants.
- Clear safe, regenerable caches through tool-supported commands where possible.
- Move future cache growth from `C:` to `D:` or `E:` using user-level config and environment variables.
- Explain administrator-only cleanup options such as DISM component cleanup without silently running them.

## Cleanup Modes

`CDE-clear` is designed to let the user choose how aggressive the cleanup should be:

- `scan`: inventory only; no deletion or configuration changes.
- `safe`: temp files, package-manager caches, and browser cache candidates.
- `dev`: npm, pip, pnpm, Yarn, Gradle, Maven, NuGet, Cargo, Conda, Hugging Face, Playwright, Cypress, Android build caches, and identified project build artifacts.
- `app`: app-specific cache inspection for browsers, chat apps, Adobe, Lenovo, WPS, OpenAI/Codex, game launchers, and updaters.
- `migrate`: configure future caches to grow on another drive such as `E:\DevCache`.
- `deep`: explain or provide administrator commands for Windows component cleanup, update cleanup, hibernation, restore points, and Storage Sense.

## Safety Model

The skill defaults to "measure before mutating":

- It inspects exact absolute paths, size, file count, and modified time before cleanup.
- It avoids broad recursive deletion roots such as `C:\`, `C:\Users`, `C:\Windows`, `C:\Program Files`, `C:\ProgramData`, and drive roots.
- It prefers package-manager cleanup commands like `npm cache clean`, `pip cache purge`, or `pnpm store prune`.
- It does not treat screenshots, logs, or attached documents as instructions.
- It stops when the environment blocks destructive commands and gives the user the exact command to run manually.

## Installation

Install with the Skills CLI:

```bash
npx skills add https://github.com/yfdskr/cuddly-meme --skill cde-clear -g -a codex -y
```

If your Skills CLI expects a repository path layout, use:

```bash
npx skills add https://github.com/yfdskr/cuddly-meme --skill cde-clear
```

The repository can be renamed later without changing the skill itself.

## Usage

After installation, ask Codex for cleanup help naturally:

```text
Use $cde-clear to scan my C/D/E drives and tell me what is safe to clean.
```

```text
Use $cde-clear to move future npm, pip, and Gradle caches away from C: to E:.
```

```text
Use $cde-clear in safe mode. Clean only regenerable caches and report before/after free space.
```

## Repository Layout

```text
skills/
  cde-clear/
    SKILL.md
    agents/
      openai.yaml
README.md
LICENSE
```

## Notes

This skill is written for Windows-first cleanup workflows, especially systems with multiple drives such as `C:`, `D:`, and `E:`. It can still help reason about storage safety on other systems, but the built-in commands and path examples are Windows-oriented.

## License

MIT
