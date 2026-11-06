---
name: release-orchestrator
description: >
  Ship an app release end to end from a git repo that releases through GitHub.
  Drafts user-facing release notes from merged work, recommends a semantic
  version bump, runs a config-driven readiness gate, runs your release command
  (or a built-in bump, tag and push), waits for the CI build, publishes,
  verifies the update feed, and reports what shipped. On first use it
  interviews the user about their setup (repo, branch, version source,
  release and publish commands, checks) and saves the answers to
  .release-orchestrator.json. USE THIS when the user wants to release, ship
  or publish a new version, cut a release, draft release notes, or check
  release readiness. Works well for macOS apps shipped as notarized builds
  with a Sparkle update feed, and for any project that tags releases on
  GitHub.
---

# Release Orchestrator

Drives a release from "the notes don't exist yet" to "published, update feed
live, summary delivered". It wraps the pipeline the project already has: you
write the notes and make the calls; the project's own scripts and CI do the
building.

Everything project-specific lives in one file at the repo root,
`.release-orchestrator.json`. Nothing in this skill is hard-coded to a project.

## Modes

- **Full release** (default) — steps 0 to 10.
- **`preflight`** — run only the readiness gate (step 2), report, stop.
- **`setup`** — run only the setup interview (step 0), to create or change the
  config.

## Step 0 — Setup (first run, or when asked)

Look for `.release-orchestrator.json` at the repo root
(`git rev-parse --show-toplevel`).

- **Present and complete** → continue to step 1.
- **Missing, or missing a field a later step needs** → run the setup interview
  in `references/setup.md` before anything else.

The interview in short:

1. **Detect first.** Run the detection commands in `references/setup.md` so
   every question arrives with a proposed answer.
2. **Ask everything in one batch**, using your question tool if you have one.
   Do not drip questions one at a time.
3. **Never ask for a secret value.** Ask only for the *names* of CI secrets,
   and for file paths. If the user offers a password, token or key, tell them
   not to paste it.
4. **Write the config, show it, and get a yes** before using it.
5. Suggest committing it so the next release, and teammates, reuse it.

In `setup` mode, stop here.

## Ground rules

- **Work in the repo root, on the release branch** (`releaseBranch`). If the
  repo is on another branch, dirty, or out of sync with origin: stop and
  report. Do not check out, stash or pull on your own; the user decides how to
  reconcile.
- **Notes are committed and pushed before the release runs.** Step 6 always
  comes before step 7.
- **Notes never contain raw material.** No PR titles, branch names, file
  paths, ticket ids or internal jargon.
- **One approval gate, then run to the end.** See step 5.

## Step 1 — Locate and check

```bash
cd "$(git rev-parse --show-toplevel)"
git rev-parse --abbrev-ref HEAD              # must be releaseBranch
git status --porcelain                        # must be empty
git fetch origin <releaseBranch> && git rev-parse HEAD origin/<releaseBranch>   # must match
```

## Step 2 — Preflight gate

Run the bundled script from this skill's directory:

```bash
"<this skill's directory>/scripts/preflight.sh"
# Once the new tag is known (after step 5):
"<this skill's directory>/scripts/preflight.sh" --next-version <tag>
```

Show the table to the user. Then:

- **Any ❌ blocker → stop.** Say exactly what is red and what fixes it.
- **Red CI that the user says is a known flaky test:** re-run only the failed
  jobs (`gh run rerun <run-id> --failed --repo <repo>`), wait for green, run
  preflight again. A real compile or test failure is a real block. Never
  re-run to hide one.
- **⚠️ warnings → report and continue.** Mention them in the gate message
  (step 5) and again in the final brief. Do not ask whether to proceed.
- In `preflight` mode, stop here.

## Step 3 — Gather change material (input only)

```bash
LAST_TAG=$(git tag --sort=-creatordate | head -1)
LAST_DATE=$(git log -1 --format=%cI "$LAST_TAG")
git log "$LAST_TAG"..HEAD --no-merges --format='%s%n%b'
gh pr list --repo <repo> --base <releaseBranch> --state merged \
   --search "merged:>=${LAST_DATE%T*}" --json number,title,body,labels -L 50
```

If there is no tag yet, use the full history. This is source material for
understanding what changed *for users*. None of it goes into the notes
verbatim.

## Step 4 — Draft the notes

Follow `references/release-notes-style.md`. It covers structure, the
one-line-per-bullet limit, the "only claim what ships" rule, and the two tones
(`notes.tone`: `witty` or `plain`). If the notes file has its own authoring
rules at the top, those win.

Draft the block content only, with no version heading yet. Do not ask about it
yet; it goes into the single gate in step 5.

## Step 5 — Recommend the bump, then the one gate

Read the current version with the configured command (`version.read`) and
compute the three candidates:

- `major`: `(M+1).0.0` · `minor`: `M.(m+1).0` · `patch`: `M.m.(p+1)`

Recommend from the drafted notes:

- A real user-facing feature under `### New` → **minor**.
- Only fixes and improvements → **patch**.
- A breaking change or a deliberate milestone → **major**. Rare, and the
  user's call.
- While the version is `0.x`, sizeable features still usually stay `minor`.
  Say so, so the choice is informed.

**The gate — exactly one interaction:**

1. Send the full drafted notes as their own plain message first. Text that
   shares a turn with a question dialog can be hidden behind it.
2. Then ask two questions together: approve or edit the notes, and choose the
   bump level (recommendation first). If the user already named the level
   when invoking the skill, skip the second question.
3. Include any preflight warnings in the same message.

Edits to the notes loop back into the same gate. Answering it *is* the
decision to ship: once both answers are in, lock the version and tag
(`<tagPrefix><version>`), re-run preflight with `--next-version <tag>`, and
run every remaining step without asking again. Do not add a second "confirm
push?" question.

## Step 6 — Write, commit and push the notes

Insert the approved block at the top of the entries in `notes.file`, above the
previous newest version, under a heading `## <tag>`. Keep any comment header
at the top of the file where it is.

Show the diff for visibility, then:

```bash
git add <notes.file>
git commit -m "<notes.commitMessage with {tag} filled in>"
git push origin <releaseBranch>
```

## Step 7 — Run the release

**If `release.command` is set**, run it with `{level}`, `{version}` and `{tag}`
filled in, and stream its output. On macOS, prefix long runs with
`caffeinate -dimsu` so the machine stays awake.

**If it is empty**, do the built-in release:

```bash
<version.bump with {version} filled in>
git commit -am "chore: bump version to <version>"
git tag <tag>
git push --atomic origin <releaseBranch> <tag>
```

If `build.workflow` is empty, nothing builds on the tag. Create the GitHub
release yourself from the approved notes:

```bash
gh release create <tag> --repo <repo> --title "<tag>" --notes-file <file with the approved block>
```

## Step 8 — Wait for the build

When `build.workflow` is set, the tag push starts it. Wait until the release
has assets, up to `build.timeoutMinutes`:

```bash
until [ "$(gh release view <tag> --repo <repo> --json assets --jq '.assets|length' 2>/dev/null)" -gt 0 ]; do sleep 60; done
gh run list --repo <repo> --workflow <build.workflow> -L 1 --json status,conclusion
```

- **Build failed** → stop and report. Never publish a failed build.
- **Release command exited before the build finished** → the tag is already
  pushed and only publishing is pending. Keep waiting, then continue with
  step 9.
- **A release-only build step failed** (a step that debug builds and tests
  never run): fix it on the release branch, then move the tag onto the fix so
  CI rebuilds the fixed commit. Re-running the same tag rebuilds the broken
  one.

  ```bash
  git push origin :refs/tags/<tag>                       # safe only while nothing is published
  git tag -f <tag> <fix-sha> && git push origin <tag>
  ```

## Step 9 — Publish and verify

If `publish.command` is set, run it with `{tag}` filled in.

Verify what the config describes:

```bash
# Public releases repo, if publish.releasesRepo is set
gh release view <tag> --repo <publish.releasesRepo> --json assets,publishedAt \
   --jq '{published: .publishedAt, assets: [.assets[].name]}'

# Update feed, if publish.appcastURL is set (the query string defeats caches)
curl -s "<publish.appcastURL>?cb=$RANDOM" -H "Cache-Control: no-cache" | grep -c "<version>"
```

A feed count of 0 right after publishing is usually CDN cache lag. Confirm the
assets exist on the release first, then retry the feed after a minute before
calling it a failure.

## Step 10 — Brief

Report, concisely:

- **Shipped:** `<tag>` (was `<previous>`).
- **What's new:** the published notes.
- **Downloads:** the asset URLs.
- **Update feed:** updated or not applicable.
- **Warnings:** any preflight ⚠️ items still open.

If the `github-ga4-release-dashboard` skill is installed, mention it for tracking uptake.

## Failure handling

- **Preflight blocker** → never proceed. Report what is red.
- **User declines the gate** → stop and leave the tree as found. If the notes
  were already written, `git checkout -- <notes.file>`.
- **Release command fails before pushing** → nothing shipped. Report its
  error.
- **Build fails after the tag is pushed** → the tag exists with no assets. Do
  not publish. Offer to re-run the workflow or re-point the tag (step 8).
