# Agent Skills

Skills for AI coding agents that read the [Agent Skills](https://agentskills.io) format: Claude Code, Cursor, Codex and others. Each skill is a folder with a `SKILL.md` and, where needed, reference files the agent loads on demand.

## Install

All skills:

```bash
npx skills add Sa74/skills
```

One skill:

```bash
npx skills add Sa74/skills --skill readme-writer
```

Add `-g` to install for every project instead of the current one.

## Skills

| Skill | Use it for |
|---|---|
| [`principal-apple-engineer`](skills/principal-apple-engineer) | Principal-level engineering across macOS, iOS, iPadOS, tvOS, watchOS and visionOS: architecture, Swift, per-platform guidance, design systems, testing and distribution. 12 reference files. |
| [`macos-staff-engineer`](skills/macos-staff-engineer) | Working rules and a decision framework for an indie macOS app: architecture defaults, system-extension and kernel-level guidance, Swift Testing, DMG and App Store distribution. |
| [`readme-writer`](skills/readme-writer) | Writing or modernising a README for any kind of project, with a library of visual patterns. |
| [`break-the-template`](skills/break-the-template) | Turning template-shaped work (articles, pages, decks, docs) into something people want to read or use. |
| [`localization-professional`](skills/localization-professional) | Localising macOS and iOS app UI across Tamil, English (US, UK, AU), Spanish (Spain, Latin America) and German (DE, AT, CH), with a strict no-transliteration rule for Tamil. |
| [`release-orchestrator`](skills/release-orchestrator) | Shipping an app release end to end: release notes, version bump, readiness checks, your release command, the CI build, publishing and the update-feed check. Asks about your setup on first use. |
| [`github-ga4-release-dashboard`](skills/github-ga4-release-dashboard) | A local HTML dashboard of release downloads from GitHub Releases, with optional active users by version from Google Analytics 4 (which covers Firebase Analytics). No other release hosts or analytics tools. Asks about your setup on first use. |

`release-orchestrator` and `github-ga4-release-dashboard` need `gh` and `jq`. Each keeps its settings in one config file that it writes after asking you a few questions; nothing about your project is built into the skill.

## Licence

[MIT](LICENSE)
