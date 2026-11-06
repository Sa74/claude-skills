# Setup interview and config reference

Run this when `.release-orchestrator.json` is missing or incomplete, or when
the user asks for `setup`. Goal: one batch of questions, each with a proposed
answer, then one config file.

## 1. Detect before asking

Run these from the repo root and keep the results as proposed answers.

```bash
git remote get-url origin                                  # → owner/name
git symbolic-ref --short refs/remotes/origin/HEAD          # → default branch
git tag --sort=-creatordate | head -5                      # → tag prefix and version style
ls .github/workflows 2>/dev/null                           # → build and test workflows
ls scripts 2>/dev/null | grep -iE 'release|publish|appcast|notar'   # → existing release scripts
ls | grep -iE '^(RELEASE_NOTES|CHANGELOG|HISTORY)'         # → notes file
find . -maxdepth 2 -name '*.xcodeproj' -not -path './build/*'       # → Xcode project
find . -maxdepth 3 -name Info.plist -not -path '*/build/*' | head   # → plists worth checking
gh secret list --repo <owner/name>                         # → secret NAMES (values are never shown)
```

For an Xcode project, check where the version lives:

```bash
grep -m1 'MARKETING_VERSION' <Project>.xcodeproj/project.pbxproj
/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' <path>/Info.plist   # update feed, if the app uses Sparkle
```

## 2. Ask in one batch

Present the detected value as the default for each. Skip a question when
detection already gave a certain answer and say what you assumed.

**Project**
1. What is the app called?
2. Which GitHub repo holds the tags and CI (`owner/name`)?
3. Which branch do releases run from?
4. What prefix do tags use (`v`, or none)?

**Version and notes**
5. Where does the version live? (Confirm the proposed read command.)
6. Which file holds the release notes, and which tone: `witty` or `plain`?

**Release**
7. Do you have a release script? If yes, the exact command. If no, the
   built-in flow needs a command that writes a new version (see recipes).
8. Which workflow builds the release when a tag is pushed, and how long can it
   take?

**Publish (all optional)**
9. Is there a publish command to run once the build has assets?
10. Is there a separate public releases repo?
11. Is there an update feed URL to verify (for example a Sparkle appcast)?

**Readiness checks (all optional)**
12. Which workflow must be green on the release branch before releasing?
13. Which CI secret names must exist? (Names only.)
14. Which plist keys must be set, or equal a known value?
15. Any file rules, such as a build setting that must or must not appear?
16. Any files CI needs that must be committed?
17. Any URLs that should be reachable?
18. Anything a human must confirm by hand before each release?

**Never collect secret values.** Secret names, file paths and public keys are
fine. Passwords, tokens and private keys are not. If the user starts to paste
one, stop them.

## 3. Write, show, confirm

Write `.release-orchestrator.json` at the repo root, show it, and ask for a
yes. Then suggest committing it:

```bash
git add .release-orchestrator.json
git commit -m "chore: add release-orchestrator config"
```

To change it later, run the skill in `setup` mode or edit the file.

## Config reference

```json
{
  "appName": "Example App",
  "repo": "example-org/example-app",
  "releaseBranch": "main",
  "tagPrefix": "v",

  "version": {
    "read": "grep -m1 'MARKETING_VERSION' ExampleApp.xcodeproj/project.pbxproj | sed 's/.*= //; s/;.*//'",
    "bump": "sed -i '' -E 's/(MARKETING_VERSION = )[^;]+;/\\1{version};/' ExampleApp.xcodeproj/project.pbxproj"
  },

  "notes": {
    "file": "RELEASE_NOTES.md",
    "tone": "witty",
    "commitMessage": "chore: release notes for {tag}"
  },

  "release": {
    "command": "make release BUMP={level}"
  },

  "build": {
    "workflow": "release.yml",
    "timeoutMinutes": 45
  },

  "publish": {
    "command": "scripts/publish.sh {tag}",
    "releasesRepo": "example-org/example-app-releases",
    "appcastURL": "https://example.com/updates/appcast.xml"
  },

  "preflight": {
    "testsWorkflow": "ci.yml",
    "requiredSecrets": ["SIGNING_CERTIFICATE_P12", "SIGNING_CERTIFICATE_PASSWORD", "NOTARY_APPLE_ID", "NOTARY_TEAM_ID"],
    "plistChecks": [
      { "file": "Info.plist", "key": "SUFeedURL", "label": "Update feed URL set" },
      { "file": "Info.plist", "key": "SUPublicEDKey", "equals": "<your public update key>", "label": "Update signing key matches" }
    ],
    "fileChecks": [
      { "file": "ExampleApp.xcodeproj/project.pbxproj", "mustNotContain": "CODE_SIGN_IDENTITY = \"-\";", "label": "No ad-hoc signing left in the project" }
    ],
    "trackedFiles": ["Config/Release.plist"],
    "urls": ["https://example.com"],
    "manualAttestations": ["Installer tested on a clean user account"]
  }
}
```

| Field | Required | Meaning |
|---|---|---|
| `appName` | yes | Shown in the preflight table and the brief. |
| `repo` | yes | GitHub `owner/name` holding tags, CI and the built release. |
| `releaseBranch` | yes | Branch releases run from. Default `main`. |
| `tagPrefix` | yes | Prefix before the version in tags. Use `""` for none. |
| `version.read` | yes | Command that prints the current version, such as `1.4.2`. |
| `version.bump` | only without `release.command` | Command that writes the new version. `{version}` is replaced. |
| `notes.file` | yes | Release notes file. Blocks are headed `## <tag>`. |
| `notes.tone` | yes | `witty` or `plain`. See `release-notes-style.md`. |
| `notes.commitMessage` | yes | Commit message for the notes. `{tag}` is replaced. Add your CI's skip marker here if a docs-only commit should not re-run tests. |
| `release.command` | no | Your release script. `{level}`, `{version}` and `{tag}` are replaced. It must bump the version, tag and push. Leave empty for the built-in flow. |
| `build.workflow` | no | Workflow file that builds on a tag push. Empty means no build; the skill creates the GitHub release from the notes. |
| `build.timeoutMinutes` | no | How long to wait for release assets. Default 45. |
| `publish.command` | no | Runs once the build has assets. `{tag}` is replaced. |
| `publish.releasesRepo` | no | Public repo to verify the published release in. |
| `publish.appcastURL` | no | Update feed to verify. Also checked by preflight. |
| `preflight.*` | no | Each list is optional. An absent list is simply not checked. |

`plistChecks` keys use PlistBuddy syntax, so nested keys are written
`Parent:Child`. `fileChecks` strings are matched literally, not as patterns.

## Recipes for `version.read` and `version.bump`

**Xcode project (`MARKETING_VERSION` in the project file)**

```bash
# read
grep -m1 'MARKETING_VERSION' App.xcodeproj/project.pbxproj | sed 's/.*= //; s/;.*//'
# bump
sed -i '' -E 's/(MARKETING_VERSION = )[^;]+;/\1{version};/' App.xcodeproj/project.pbxproj
```

To raise the build number in the same step, append
`&& xcrun agvtool next-version -all`.

**package.json**

```bash
# read
node -p "require('./package.json').version"
# bump
npm version {version} --no-git-tag-version
```

**Cargo.toml**

```bash
# read
grep -m1 '^version' Cargo.toml | sed 's/.*"\(.*\)".*/\1/'
# bump
sed -i '' -E '1,/^version/ s/^version = ".*"/version = "{version}"/' Cargo.toml
```

**Plain VERSION file**

```bash
# read
cat VERSION
# bump
printf '%s\n' '{version}' > VERSION
```

On Linux, `sed -i` takes no empty argument: use `sed -i -E` in place of
`sed -i '' -E`.
