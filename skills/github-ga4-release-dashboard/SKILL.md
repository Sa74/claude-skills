---
name: github-ga4-release-dashboard
description: >
  Generate a self-contained local HTML dashboard of how an app's releases are
  doing, from two sources only: GitHub Releases (download counts per asset
  type) and, optionally, Google Analytics 4 (active users by app version,
  installs and tracked events, through the Data API or the BigQuery export).
  Apps that report through Firebase Analytics are covered by their linked GA4
  property. Other release hosts and analytics tools are not supported. Nothing
  is hosted; data is fetched fresh on each run. On first use it interviews the user about their
  setup (releases repo, asset types, optional analytics) and saves the answers
  to a config file. USE THIS when the user wants a release or adoption
  dashboard, download stats, per-version uptake, "how is the release doing",
  or to refresh the dashboard.
---

# Release Dashboard (GitHub + Google Analytics 4)

An on-demand local report of how releases are performing. It fetches live
data, bakes it into one offline HTML file, and opens it. Nothing is hosted.
Run it again to refresh.

## What it works with

- **Releases and downloads: GitHub Releases only**, read through the `gh`
  command. This is the only required source.
- **Usage data, optional: Google Analytics 4 only**, through its Data API or
  its BigQuery export. An app that reports through Firebase Analytics is read
  through the GA4 property linked to its Firebase project.
- **Not supported:** other release hosts (GitLab, the App Store) and other
  analytics tools (Mixpanel, Amplitude, PostHog, TelemetryDeck). If the user
  is on one of those, say so up front; do not start the setup.

The "active users by version" panel needs GA4's app-version field, which is
filled only for apps reporting through the Firebase SDK. A website-only GA4
property shows an empty version table; tracked events still work.

Everything project-specific lives in one config file. Nothing in this skill is
hard-coded to a project.

## Step 0 — Setup (first run, or when asked)

The config lives at `~/.config/release-dashboard/config.json` (or
`$XDG_CONFIG_HOME/release-dashboard/config.json`). Keep it outside any git
repo: it points at a credentials file.

- **Present** → go to "Run it".
- **Missing, or the user asks for `setup`** → run this interview first.

### Detect before asking

```bash
git remote get-url origin 2>/dev/null                       # a likely releases repo
gh api "repos/<owner/name>/releases?per_page=5" --jq '.[].assets[].name'   # real asset names
```

Use the asset names to propose asset groups, for example one group per file
extension.

### Ask in one batch

Present each detected value as the default. Use your question tool if you have
one; do not drip questions one at a time.

1. What is the product called?
2. Which GitHub repo holds the releases (`owner/name`)? Private is fine if
   `gh` can read it.
3. Which asset groups should get their own column? (Confirm the proposal.)
4. How many releases should the table show? (Default 12.)
5. Do you want analytics? `none`, `ga4-data-api`, or `ga4-bigquery`.
   If yes:
   - the numeric GA4 property id
   - the **path** to the service-account key file
   - optionally, the install event and a start date for counting installs
   - optionally, events to track, each with a display label
6. Where should the HTML file go? (Default: next to the config.)

If the user wants analytics but has no service account yet, walk them through
`references/analytics-setup.md` first.

### Credential rules

- **Ask for the path to the key file, never its contents.** If the user pastes
  a private key or token into the conversation, tell them to treat it as
  exposed and replace it.
- Do not read the key file's contents back to the user or copy them anywhere.
- After writing the config, tighten permissions on both files:

  ```bash
  chmod 600 ~/.config/release-dashboard/config.json "<path to key file>"
  ```

### Write, show, confirm

Write the config, show it to the user, and get a yes before the first run.

## Run it

Run the bundled script from this skill's directory:

```bash
"<this skill's directory>/scripts/build_dashboard.sh"
```

Options: `--config <path>` for a second product, `--output <file>`, and
`--no-open` to skip opening the file.

Afterwards, tell the user the file path and the one-line summary the script
prints (releases, total downloads, analytics status). Pass on any warning it
prints, such as a key file other users can read.

## What it shows

1. **Releases and downloads** (always). The most recent releases with
   download counts per asset group and in total. Needs only `gh`.
2. **Adoption: active users by version** (with analytics). Distinct active
   users per app version over the last 28 days, with each version's share.
3. **Installs** (with analytics, when `installEvent` and `installsSince` are
   set). Distinct users who fired the install event since that date, shown
   beside the download total. The difference is updates, repeat downloads and
   automated traffic.
4. **Tracked events** (with analytics, when `events` is set). 28-day counts
   for the events you name, such as a sign-up or a failure signal.

Each layer fails on its own. If analytics is not configured or not yet
granted, the releases table still renders and the analytics panel says why.

## Config reference

```json
{
  "productName": "Example App",
  "releasesRepo": "example-org/example-app-releases",
  "maxReleases": 12,
  "assetGroups": [
    { "label": "Apple silicon", "match": "arm64.*\\.dmg$" },
    { "label": "DMG (other)", "match": "\\.dmg$" },
    { "label": "ZIP", "match": "\\.zip$" }
  ],
  "outputFile": "~/.config/release-dashboard/dashboard.html",
  "analytics": {
    "source": "ga4-data-api",
    "propertyId": "123456789",
    "credentialsFile": "~/.config/release-dashboard/service-account.json",
    "installEvent": "first_open",
    "installsSince": "2025-01-01",
    "events": [
      { "label": "Sign-ups", "event": "sign_up" },
      { "label": "Export failures", "event": "export_failed" }
    ]
  }
}
```

| Field | Required | Meaning |
|---|---|---|
| `productName` | no | Dashboard title. Defaults to the repo name. |
| `releasesRepo` | yes | GitHub `owner/name` whose releases are counted. |
| `maxReleases` | no | Rows in the releases table. Default 12. |
| `assetGroups` | no | Columns in the table. `match` is a regular expression tested against each asset's file name. **An asset counts toward the first group it matches**, so put narrower patterns first. Assets matching no group still count in Total. |
| `outputFile` | no | Where to write the HTML. Default: `dashboard.html` next to the config. |
| `analytics.source` | no | `none` (default), `ga4-data-api`, or `ga4-bigquery`. |
| `analytics.propertyId` | with analytics | Numeric GA4 property id. |
| `analytics.credentialsFile` | with analytics | Path to a service-account key file. |
| `analytics.bigQueryProject` | no | Project holding the GA4 export. Defaults to the key file's project. |
| `analytics.installEvent` | no | Event that marks an install, usually `first_open`. |
| `analytics.installsSince` | no | Start date for counting installs, `YYYY-MM-DD`. |
| `analytics.events` | no | Events for the tracked-events panel. |

## Reading the analytics panel

- **"Analytics access pending"** — sign-in worked, but the service account
  cannot read the data yet. See `references/analytics-setup.md`.
- **"Analytics query failed"** — the message shown is Google's. A wrong
  property id or a bad key file are the usual causes.
- **No rows** — normal for a new property, or for an app where analytics is
  opt-in and few users have turned it on.
- **BigQuery export only counts forward.** Tables start on the day the export
  was linked, so installs and events before that date are not there.

## Requirements

`gh` (authenticated) and `jq`. The analytics layer also uses `curl` and
`openssl`, both present on macOS. No `gcloud`, `bq` or Python needed.
