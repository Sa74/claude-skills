# Analytics setup (Google Analytics 4)

The dashboard reads GA4 with a service account. There are two routes. Start
with the Data API; switch to the BigQuery export if the access grant will not
go through.

There is no REST endpoint for Firebase Analytics itself. An app that reports
through Firebase is read through the GA4 property linked to that Firebase
project.

## Shared steps

1. In Google Cloud, open the project behind the GA4 property.
2. Create a **service account**. It needs no project roles for the Data API
   route.
3. Create a **JSON key** for it and save the file somewhere outside any git
   repo, for example `~/.config/release-dashboard/service-account.json`.
4. Lock the file down:

   ```bash
   chmod 600 ~/.config/release-dashboard/service-account.json
   ```

5. Find the **GA4 property id**: GA4 Admin → Property settings. It is a
   number.

## Route A — GA4 Data API (`"source": "ga4-data-api"`)

Best when you want full property history and have no BigQuery export.

1. In Google Cloud, enable the **Google Analytics Data API** for the project.
2. In GA4 Admin → Property access management, add the service account's email
   address with the **Viewer** role.

The standard (free) GA4 tier is enough; the dashboard makes three small
queries per run.

**If GA4 will not accept the service account's email** ("this email doesn't
match a Google Account"), or the grant never takes effect:

- Wait and retry. New service accounts can take a while to be recognised.
- Add the service account to a Google Group and grant the group Viewer.
  Groups pass the email check; a new group can also need time before GA4
  accepts it.
- Or use Route B, which avoids GA4's access screen entirely.

## Route B — BigQuery export (`"source": "ga4-bigquery"`)

Best when Route A's grant is stuck. Access is granted through ordinary Google
Cloud IAM, which always works for service accounts.

1. GA4 Admin → Product links → BigQuery links → link a BigQuery project and
   turn on the daily export.
2. In Google Cloud IAM, grant the service account **BigQuery Data Viewer** and
   **BigQuery Job User** on that project.
3. If the export lives in a different project from the key file, set
   `analytics.bigQueryProject` in the config.

Trade-offs:

- **The export only counts forward.** Tables start on the day you link it;
  there is no backfill.
- The first table appears about a day after linking. Until then the dashboard
  shows "access pending".
- The dataset is named `analytics_<property id>`. The dashboard derives that
  from the property id.

## Check access without rendering the dashboard

The script prints its analytics status on the last line of its output:

```bash
"<this skill's directory>/scripts/build_dashboard.sh" --no-open
```

- `analytics=ok` — working. An empty table means no rows in the window.
- `analytics=pending` — signed in, but no access to the data yet. The grant
  has not landed, or the BigQuery dataset does not exist yet.
- `analytics=error` — the HTML shows Google's message. Check the property id
  and the key file.

## Key hygiene

- **Never paste a key into a chat, an issue or a commit.** A pasted key is an
  exposed key, even if the account currently has no access: delete it in
  Google Cloud (IAM → Service accounts → Keys) and create a new one.
- Give the service account read access only. It never needs Owner or Editor.
- Keep the key file readable by you alone (`chmod 600`). The dashboard warns
  when other users on the machine can read it.
- Rotate the key if the machine or a backup of it leaves your control.
