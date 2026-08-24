# yfdskr Skills

Personal Codex skills for practical Windows maintenance, skill discovery, and project workflow support.

This repository is organized as a multi-skill collection:

```text
skills/
  cde-clear/
    SKILL.md
    agents/openai.yaml
  skill-advisor/
    SKILL.md
    agents/openai.yaml
    scripts/list-local-skills.ps1
```

## Available Skills

### CDE-clear

`cde-clear` helps safely free disk space on Windows PCs, especially C/D/E drive cleanup, cache removal, and user-level cache relocation.

Use it when you want to:

- Scan C/D/E drives and understand where space is used.
- Clean safe, regenerable caches.
- Review developer caches such as npm, pip, Gradle, pnpm, Yarn, Maven, NuGet, Cargo, Conda, Playwright, Cypress, and Hugging Face.
- Move future cache growth away from `C:` to another drive such as `D:` or `E:`.
- Get conservative Windows cleanup guidance without accidentally deleting personal files or application data.

Install:

```bash
npx skills add https://github.com/yfdskr/skills --skill cde-clear -g -a codex -y
```

Usage examples:

```text
Use $cde-clear to scan my C/D/E drives and tell me what is safe to clean.
```

```text
Use $cde-clear to move future npm, pip, and Gradle caches away from C: to E:.
```

### Skill Advisor

`skill-advisor` recommends, organizes, and presents installed skills for a user's task. It helps users avoid manually remembering which skills they have installed.

Use it when you want to:

- Decide which installed skills fit a task.
- View installed skills as a compact skill map.
- Group skills by category, such as planning, research, frontend, automation, review, or system configuration.
- Understand which broad project phase a skill helps with: discovery, planning, build, review, or operate.
- Ask before using local skills, searching remote skills, or installing anything new.

Install:

```bash
npx skills add https://github.com/yfdskr/skills --skill skill-advisor -g -a codex -y
```

Usage examples:

```text
Use $skill-advisor to recommend which skills fit this task.
```

```text
Use $skill-advisor to organize my installed skills by category and project phase.
```

```text
Use $skill-advisor to check whether I already have a skill for this workflow before searching online.
```

## Install From a Direct Skill Path

If your Skills CLI prefers a direct GitHub tree URL, use these forms:

```bash
npx skills add https://github.com/yfdskr/skills/tree/main/skills/cde-clear -g -a codex -y
npx skills add https://github.com/yfdskr/skills/tree/main/skills/skill-advisor -g -a codex -y
```

## Notes

- `cde-clear` is Windows-first and intentionally conservative.
- `skill-advisor` is an advisory routing skill. It should not install, configure, delete, publish, or call external services without user confirmation.
- The old `yfdskr/CDE-clear` repository name has been replaced by this multi-skill repository. Use `https://github.com/yfdskr/skills` for new installs.

## License

MIT
