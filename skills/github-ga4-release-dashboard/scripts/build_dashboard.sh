#!/usr/bin/env bash
#
# build_dashboard.sh — generate a self-contained local HTML dashboard of how
# an app's releases are doing, from GitHub Releases and (optionally) Google
# Analytics 4. Fetches live data, bakes it into one file, opens it. Hosted
# nowhere. Re-run to refresh.
#
# Data layers (a layer that fails never breaks the others):
#   • Releases + download counts per asset group — GitHub (needs only gh).
#   • Active users by app version, installs, tracked events — Google
#     Analytics 4, through the Data API or the BigQuery export (optional).
#
# Usage:
#   build_dashboard.sh [--config <path>] [--output <file>] [--no-open]
#
#   --config   Config file. Default:
#              ${XDG_CONFIG_HOME:-~/.config}/release-dashboard/config.json
#   --output   HTML file to write. Default: "outputFile" from the config,
#              else dashboard.html next to the config.
#   --no-open  Do not open the file afterwards.
#
# Requires: gh (authenticated), jq. The analytics layer also uses curl and
# openssl. No gcloud, bq or Python needed.
#
# Exit codes: 0 = dashboard written · 1 = GitHub data could not be fetched
#             2 = usage, config or environment error
#
# SPDX-License-Identifier: MIT

set -uo pipefail

usage() {
    sed -n '3,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

CONFIG=""
OUT_HTML=""
OPEN_AFTER=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)  CONFIG="${2:-}"; shift 2 ;;
        --output)  OUT_HTML="${2:-}"; shift 2 ;;
        --no-open) OPEN_AFTER=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

command -v gh >/dev/null || { echo "ERROR: gh not found." >&2; exit 2; }
command -v jq >/dev/null || { echo "ERROR: jq not found." >&2; exit 2; }

# ── Config ───────────────────────────────────────────────────────────────
[[ -z "${CONFIG}" ]] && CONFIG="${XDG_CONFIG_HOME:-${HOME}/.config}/release-dashboard/config.json"
if [[ ! -f "${CONFIG}" ]]; then
    echo "ERROR: No config at ${CONFIG}. Run the skill's setup first." >&2
    exit 2
fi
if ! jq -e 'type == "object"' "${CONFIG}" >/dev/null 2>&1; then
    echo "ERROR: ${CONFIG} is not a valid JSON object." >&2
    exit 2
fi

cfg() { jq -r "$1 // empty" "${CONFIG}"; }
expand_home() { case "$1" in "~/"*) printf '%s' "${HOME}/${1#\~/}" ;; *) printf '%s' "$1" ;; esac; }
html_escape() { sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'; }
esc() { printf '%s' "$1" | html_escape; }

PRODUCT="$(cfg '.productName')"
REPO="$(cfg '.releasesRepo')"
MAX_RELEASES="$(cfg '.maxReleases')"; [[ "${MAX_RELEASES}" =~ ^[0-9]+$ ]] || MAX_RELEASES=12
ASSET_GROUPS="$(jq -c '.assetGroups // []' "${CONFIG}")"

if [[ ! "${REPO}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "ERROR: \"releasesRepo\" must be owner/name (got '${REPO}')." >&2
    exit 2
fi
if ! jq -e '[ .[] | (.label | type == "string") and (.match as $m | try ("" | test($m) | true) catch false) ] | all' \
        >/dev/null 2>&1 <<< "${ASSET_GROUPS}"; then
    echo "ERROR: each \"assetGroups\" entry needs a \"label\" and a valid regex \"match\"." >&2
    exit 2
fi
[[ -z "${PRODUCT}" ]] && PRODUCT="${REPO#*/}"

if [[ -z "${OUT_HTML}" ]]; then
    OUT_HTML="$(cfg '.outputFile')"
    [[ -z "${OUT_HTML}" ]] && OUT_HTML="$(dirname "${CONFIG}")/dashboard.html"
fi
OUT_HTML="$(expand_home "${OUT_HTML}")"
mkdir -p "$(dirname "${OUT_HTML}")" || { echo "ERROR: cannot create $(dirname "${OUT_HTML}")." >&2; exit 2; }

GEN_AT="$(date '+%Y-%m-%d %H:%M %Z')"

# ── Layer 1: GitHub releases + download counts ───────────────────────────
echo "Fetching releases from ${REPO}…" >&2
if ! RELEASES_JSON="$(gh api "repos/${REPO}/releases?per_page=100" 2>/dev/null)"; then
    echo "ERROR: could not read releases of ${REPO}. Check the name and 'gh auth status'." >&2
    exit 1
fi

# Normalise to [{tag, published, prerelease, groups:[n…], total}], newest
# first, drafts dropped. An asset counts toward the first group it matches.
RELEASES="$(jq --argjson groups "${ASSET_GROUPS}" '
  def group_of($name): first( $groups | to_entries[] | select(.value.match as $m | $name | test($m)) | .key ) // -1;
  [ .[] | select(.draft == false) | . as $rel
    | { tag: .tag_name,
        published: ((.published_at // .created_at // "") | split("T")[0]),
        prerelease: .prerelease,
        groups: [ range(0; $groups | length) as $i
                  | ([ $rel.assets[] | select(group_of(.name) == $i) | .download_count ] | add // 0) ],
        total: ([ .assets[].download_count ] | add // 0) } ]' <<< "${RELEASES_JSON}")" || {
    echo "ERROR: unexpected response from the GitHub releases API." >&2
    exit 1
}

REL_COUNT="$(jq 'length' <<< "${RELEASES}")"
MAX_DL="$(jq '[ .[].total ] | max // 1' <<< "${RELEASES}")"; [[ "${MAX_DL}" -lt 1 ]] && MAX_DL=1
TOTAL_DL="$(jq '[ .[].total ] | add // 0' <<< "${RELEASES}")"
LATEST_TAG="$(jq -r '.[0].tag // "—"' <<< "${RELEASES}")"
GROUP_COUNT="$(jq 'length' <<< "${ASSET_GROUPS}")"

GROUP_HEAD=""
while IFS= read -r label; do
    [[ -z "${label}" ]] && continue
    GROUP_HEAD+="<th class=\"num\">$(esc "${label}")</th>"
done < <(jq -r '.[].label' <<< "${ASSET_GROUPS}")

REL_ROWS=""
while IFS=$'\t' read -r -a cols; do
    [[ ${#cols[@]} -lt 4 ]] && continue
    tag="${cols[0]}"; day="${cols[1]}"; prerelease="${cols[2]}"; total="${cols[3]}"
    pct=$(( total * 100 / MAX_DL ))
    badge=""; [[ "${prerelease}" == "true" ]] && badge='<span class="badge pre">pre</span>'
    REL_ROWS+="<tr><td class=\"tag\">$(esc "${tag}")${badge}</td><td class=\"date\">$(esc "${day}")</td>"
    i=4
    while [[ ${i} -lt ${#cols[@]} ]]; do
        REL_ROWS+="<td class=\"num\">${cols[${i}]}</td>"
        i=$(( i + 1 ))
    done
    REL_ROWS+="<td class=\"num strong\">${total}</td>"
    REL_ROWS+="<td class=\"barcell\"><div class=\"bar\" style=\"width:${pct}%\"></div></td></tr>"
done < <(jq -r --argjson max "${MAX_RELEASES}" \
    '.[:$max][] | ([.tag, (if .published == "" then "—" else .published end), (.prerelease | tostring), .total] + .groups) | @tsv' <<< "${RELEASES}")
[[ -z "${REL_ROWS}" ]] && REL_ROWS="<tr><td colspan=\"$(( GROUP_COUNT + 4 ))\" class=\"empty\">No releases found.</td></tr>"

# ── Layer 2: Google Analytics 4 (optional) ───────────────────────────────
A_SOURCE="$(cfg '.analytics.source')"; [[ -z "${A_SOURCE}" ]] && A_SOURCE="none"
A_PROPERTY="$(cfg '.analytics.propertyId')"
A_CREDS="$(expand_home "$(cfg '.analytics.credentialsFile')")"
A_BQ_PROJECT="$(cfg '.analytics.bigQueryProject')"
A_INSTALL_EVENT="$(cfg '.analytics.installEvent')"
A_INSTALLS_SINCE="$(cfg '.analytics.installsSince')"

A_STATUS="unconfigured"     # unconfigured | ok | pending | error
A_DETAIL=""
ADOPTION_TSV=""             # lines: version<TAB>users
INSTALLS=""
EVENTS_TSV=""               # lines: event<TAB>count
EVENTS_STATUS="unconfigured"

EVENT_NAMES=()
EVENT_LABELS=()
while IFS=$'\t' read -r ev_name ev_label; do
    [[ -z "${ev_name}" ]] && continue
    EVENT_NAMES+=("${ev_name}"); EVENT_LABELS+=("${ev_label:-${ev_name}}")
done < <(jq -r '.analytics.events[]? | [.event, (.label // .event)] | @tsv' "${CONFIG}")

b64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }

# Mint an OAuth access token for a service account. $1 = key file, $2 = scope.
mint_sa_token() {
    local sa="$1" scope="$2" iss key now claim hb cb sig
    iss="$(jq -r '.client_email // empty' "${sa}" 2>/dev/null)"
    key="$(jq -r '.private_key // empty' "${sa}" 2>/dev/null)"
    [[ -z "${iss}" || -z "${key}" ]] && return 1
    now="$(date +%s)"
    claim="$(jq -cn --arg iss "${iss}" --arg scope "${scope}" --argjson iat "${now}" --argjson exp "$(( now + 3600 ))" \
        '{iss: $iss, scope: $scope, aud: "https://oauth2.googleapis.com/token", iat: $iat, exp: $exp}')"
    hb="$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | b64url)"
    cb="$(printf '%s' "${claim}" | b64url)"
    sig="$(printf '%s' "${hb}.${cb}" | openssl dgst -sha256 -sign <(printf '%s' "${key}") -binary 2>/dev/null | b64url)"
    [[ -z "${sig}" ]] && return 1
    curl -s --max-time 15 -X POST https://oauth2.googleapis.com/token \
        -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
        --data-urlencode "assertion=${hb}.${cb}.${sig}" | jq -r '.access_token // empty'
}

# Record a failed analytics response. Missing access is "pending", not an error.
analytics_failed() {
    local response="$1" reason
    reason="$(jq -r '.error.errors[0].reason // .error.status // empty' <<< "${response}" 2>/dev/null)"
    A_DETAIL="$(jq -r '.error.message // "the query did not complete"' <<< "${response}" 2>/dev/null | head -c 240)"
    case "${reason}" in
        notFound|accessDenied|PERMISSION_DENIED|NOT_FOUND) A_STATUS="pending" ;;
        *) A_STATUS="error" ;;
    esac
}

events_valid=1
if [[ ${#EVENT_NAMES[@]} -gt 0 ]]; then
    for ev in "${EVENT_NAMES[@]}"; do
        [[ "${ev}" =~ ^[A-Za-z0-9_]{1,40}$ ]] || events_valid=0
    done
fi

if [[ "${A_SOURCE}" != "none" ]]; then
    if [[ "${A_SOURCE}" != "ga4-data-api" && "${A_SOURCE}" != "ga4-bigquery" ]]; then
        A_STATUS="error"; A_DETAIL="\"analytics.source\" must be none, ga4-data-api or ga4-bigquery."
    elif [[ ! "${A_PROPERTY}" =~ ^[0-9]+$ ]]; then
        A_STATUS="error"; A_DETAIL="\"analytics.propertyId\" must be the numeric GA4 property id."
    elif [[ -z "${A_CREDS}" || ! -f "${A_CREDS}" ]]; then
        A_STATUS="error"; A_DETAIL="\"analytics.credentialsFile\" does not point to a file."
    elif [[ -n "${A_INSTALL_EVENT}" && ! "${A_INSTALL_EVENT}" =~ ^[A-Za-z0-9_]{1,40}$ ]]; then
        A_STATUS="error"; A_DETAIL="\"analytics.installEvent\" may only contain letters, digits and underscores."
    elif [[ -n "${A_INSTALLS_SINCE}" && ! "${A_INSTALLS_SINCE}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        A_STATUS="error"; A_DETAIL="\"analytics.installsSince\" must be a date, YYYY-MM-DD."
    elif [[ "${events_valid}" -ne 1 ]]; then
        A_STATUS="error"; A_DETAIL="\"analytics.events\" names may only contain letters, digits and underscores."
    else
        perms="$(stat -f '%Lp' "${A_CREDS}" 2>/dev/null || stat -c '%a' "${A_CREDS}" 2>/dev/null)"
        if [[ -n "${perms}" && "${perms: -2}" != "00" ]]; then
            echo "WARNING: ${A_CREDS} is readable by other users (mode ${perms}). Run: chmod 600 \"${A_CREDS}\"" >&2
        fi
        command -v curl >/dev/null && command -v openssl >/dev/null || {
            A_STATUS="error"; A_DETAIL="The analytics layer needs curl and openssl."
        }
    fi

    if [[ "${A_STATUS}" == "unconfigured" && "${A_SOURCE}" == "ga4-data-api" ]]; then
        echo "Querying the GA4 Data API (property ${A_PROPERTY})…" >&2
        TOKEN="$(mint_sa_token "${A_CREDS}" "https://www.googleapis.com/auth/analytics.readonly")"
        run_report() {
            curl -s --max-time 25 -X POST \
                "https://analyticsdata.googleapis.com/v1beta/properties/${A_PROPERTY}:runReport" \
                -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d "$1"
        }
        report_ok() { jq -e 'type == "object" and (has("error") | not)' >/dev/null 2>&1 <<< "$1"; }
        if [[ -z "${TOKEN}" ]]; then
            A_STATUS="error"; A_DETAIL="Could not get an access token. Check the service-account key file."
        else
            REPORT="$(run_report '{"dateRanges":[{"startDate":"28daysAgo","endDate":"today"}],
                "dimensions":[{"name":"appVersion"}],"metrics":[{"name":"activeUsers"}],
                "orderBys":[{"metric":{"metricName":"activeUsers"},"desc":true}]}')"
            if report_ok "${REPORT}"; then
                A_STATUS="ok"; A_DETAIL="active users, last 28 days (GA4 Data API)"
                ADOPTION_TSV="$(jq -r '.rows[]? | [.dimensionValues[0].value, .metricValues[0].value] | @tsv' <<< "${REPORT}")"
                if [[ -n "${A_INSTALL_EVENT}" && -n "${A_INSTALLS_SINCE}" ]]; then
                    BODY="$(jq -cn --arg since "${A_INSTALLS_SINCE}" --arg ev "${A_INSTALL_EVENT}" \
                        '{dateRanges: [{startDate: $since, endDate: "today"}], dimensions: [{name: "eventName"}],
                          metrics: [{name: "totalUsers"}],
                          dimensionFilter: {filter: {fieldName: "eventName", stringFilter: {value: $ev}}}}')"
                    INSTALLS="$(run_report "${BODY}" | jq -r '.rows[0].metricValues[0].value // empty' 2>/dev/null)"
                fi
                if [[ ${#EVENT_NAMES[@]} -gt 0 ]]; then
                    BODY="$(printf '%s\n' "${EVENT_NAMES[@]}" | jq -Rcn \
                        '{dateRanges: [{startDate: "28daysAgo", endDate: "today"}], dimensions: [{name: "eventName"}],
                          metrics: [{name: "eventCount"}],
                          dimensionFilter: {filter: {fieldName: "eventName", inListFilter: {values: [inputs]}}}}')"
                    EV_REPORT="$(run_report "${BODY}")"
                    if report_ok "${EV_REPORT}"; then
                        EVENTS_STATUS="ok"
                        EVENTS_TSV="$(jq -r '.rows[]? | [.dimensionValues[0].value, .metricValues[0].value] | @tsv' <<< "${EV_REPORT}")"
                    else
                        EVENTS_STATUS="error"
                    fi
                fi
            else
                analytics_failed "${REPORT}"
            fi
        fi
    fi

    if [[ "${A_STATUS}" == "unconfigured" && "${A_SOURCE}" == "ga4-bigquery" ]]; then
        [[ -z "${A_BQ_PROJECT}" ]] && A_BQ_PROJECT="$(jq -r '.project_id // empty' "${A_CREDS}" 2>/dev/null)"
        if [[ ! "${A_BQ_PROJECT}" =~ ^[A-Za-z0-9_:.-]+$ ]]; then
            A_STATUS="error"; A_DETAIL="No BigQuery project. Set \"analytics.bigQueryProject\"."
        else
            BQ_TABLE="\`${A_BQ_PROJECT}.analytics_${A_PROPERTY}.events_*\`"
            echo "Querying BigQuery ${A_BQ_PROJECT}.analytics_${A_PROPERTY}…" >&2
            TOKEN="$(mint_sa_token "${A_CREDS}" "https://www.googleapis.com/auth/bigquery.readonly")"
            bq_query() {
                curl -s --max-time 30 -X POST \
                    "https://bigquery.googleapis.com/bigquery/v2/projects/${A_BQ_PROJECT}/queries" \
                    -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
                    -d "$(jq -n --arg q "$1" '{query: $q, useLegacySql: false, timeoutMs: 25000}')"
            }
            bq_ok() { jq -e '.jobComplete == true' >/dev/null 2>&1 <<< "$1"; }
            LAST_28="_TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY))"
            if [[ -z "${TOKEN}" ]]; then
                A_STATUS="error"; A_DETAIL="Could not get an access token. Check the service-account key file."
            else
                REPORT="$(bq_query "SELECT app_info.version AS ver, COUNT(DISTINCT user_pseudo_id) AS users
                    FROM ${BQ_TABLE} WHERE ${LAST_28} AND app_info.version IS NOT NULL
                    GROUP BY ver ORDER BY users DESC")"
                if bq_ok "${REPORT}"; then
                    A_STATUS="ok"; A_DETAIL="active users, last 28 days (BigQuery export)"
                    ADOPTION_TSV="$(jq -r '.rows[]? | [.f[0].v, .f[1].v] | @tsv' <<< "${REPORT}")"
                    if [[ -n "${A_INSTALL_EVENT}" && -n "${A_INSTALLS_SINCE}" ]]; then
                        INSTALLS="$(bq_query "SELECT COUNT(DISTINCT user_pseudo_id) FROM ${BQ_TABLE}
                            WHERE _TABLE_SUFFIX >= '${A_INSTALLS_SINCE//-/}' AND event_name = '${A_INSTALL_EVENT}'" \
                            | jq -r 'if .jobComplete == true then (.rows[0].f[0].v // empty) else empty end' 2>/dev/null)"
                    fi
                    if [[ ${#EVENT_NAMES[@]} -gt 0 ]]; then
                        IN_LIST="$(printf "'%s'," "${EVENT_NAMES[@]}")"; IN_LIST="${IN_LIST%,}"
                        EV_REPORT="$(bq_query "SELECT event_name, COUNT(*) FROM ${BQ_TABLE}
                            WHERE ${LAST_28} AND event_name IN (${IN_LIST}) GROUP BY event_name")"
                        if bq_ok "${EV_REPORT}"; then
                            EVENTS_STATUS="ok"
                            EVENTS_TSV="$(jq -r '.rows[]? | [.f[0].v, .f[1].v] | @tsv' <<< "${EV_REPORT}")"
                        else
                            EVENTS_STATUS="error"
                        fi
                    fi
                else
                    analytics_failed "${REPORT}"
                fi
            fi
        fi
    fi
fi

# Adoption panel
case "${A_STATUS}" in
    ok)
        A_TOTAL=0
        while IFS=$'\t' read -r ver users; do
            [[ "${users}" =~ ^[0-9]+$ ]] && A_TOTAL=$(( A_TOTAL + users ))
        done <<< "${ADOPTION_TSV}"
        A_ROWS=""
        while IFS=$'\t' read -r ver users; do
            [[ -z "${ver}" || ! "${users}" =~ ^[0-9]+$ ]] && continue
            share=0; [[ "${A_TOTAL}" -gt 0 ]] && share=$(( users * 100 / A_TOTAL ))
            hl=""; [[ "${ver}" == "${LATEST_TAG}" || "${ver}" == "${LATEST_TAG#v}" ]] && hl=" latest"
            A_ROWS+="<tr><td class=\"tag${hl}\">$(esc "${ver}")</td><td class=\"num strong\">${users}</td>"
            A_ROWS+="<td class=\"num\">${share}%</td><td class=\"barcell\"><div class=\"bar g\" style=\"width:${share}%\"></div></td></tr>"
        done <<< "${ADOPTION_TSV}"
        [[ -z "${A_ROWS}" ]] && A_ROWS='<tr><td colspan="4" class="empty">No app-version rows in the last 28 days.</td></tr>'
        ADOPTION="<table class=\"grid\"><thead><tr><th>Version</th><th class=\"num\">Active users</th><th class=\"num\">Share</th><th></th></tr></thead><tbody>${A_ROWS}</tbody></table><p class=\"sub\">$(esc "${A_DETAIL}") · total ${A_TOTAL}</p>" ;;
    pending)
        ADOPTION="<div class=\"card-note\"><strong>Analytics access pending.</strong> The service account could sign in but cannot read the data yet. Grant it access (see the skill's analytics setup guide), then re-run.<br><span class=\"sub\">$(esc "${A_DETAIL}")</span></div>" ;;
    error)
        ADOPTION="<div class=\"card-note err\"><strong>Analytics query failed.</strong><br>$(esc "${A_DETAIL}")</div>" ;;
    *)
        ADOPTION='<div class="card-note"><strong>Analytics not configured.</strong> Download counts above are the adoption signal. To add active users by version, run the skill&rsquo;s setup and choose an analytics source.</div>' ;;
esac

# Tracked events panel (only when events are configured)
EVENTS_SECTION=""
if [[ ${#EVENT_NAMES[@]} -gt 0 ]]; then
    if [[ "${EVENTS_STATUS}" == "ok" ]]; then
        E_MAX=1; E_COUNTS=()
        for ev in "${EVENT_NAMES[@]}"; do
            n="$(awk -F'\t' -v e="${ev}" '$1 == e { print $2 }' <<< "${EVENTS_TSV}" | head -1)"
            [[ "${n}" =~ ^[0-9]+$ ]] || n=0
            E_COUNTS+=("${n}"); [[ "${n}" -gt "${E_MAX}" ]] && E_MAX="${n}"
        done
        E_ROWS=""; i=0
        while [[ ${i} -lt ${#EVENT_NAMES[@]} ]]; do
            pct=$(( E_COUNTS[i] * 100 / E_MAX ))
            E_ROWS+="<tr><td class=\"tag\">$(esc "${EVENT_LABELS[${i}]}")</td><td class=\"num strong\">${E_COUNTS[${i}]}</td>"
            E_ROWS+="<td class=\"barcell\"><div class=\"bar w\" style=\"width:${pct}%\"></div></td>"
            E_ROWS+="<td class=\"date\">$(esc "${EVENT_NAMES[${i}]}")</td></tr>"
            i=$(( i + 1 ))
        done
        EVENTS_BODY="<table class=\"grid\"><thead><tr><th>Signal</th><th class=\"num\">28-day count</th><th></th><th>Event</th></tr></thead><tbody>${E_ROWS}</tbody></table>"
    elif [[ "${EVENTS_STATUS}" == "error" ]]; then
        EVENTS_BODY='<div class="card-note err"><strong>Event query failed.</strong> The adoption query worked, so check the event names in the config.</div>'
    else
        EVENTS_BODY='<div class="card-note">Waiting for analytics. This panel fills in once the adoption panel above has data.</div>'
    fi
    EVENTS_SECTION="<section><h2><span class=\"dot\" style=\"background:var(--warn)\"></span>Tracked events</h2>${EVENTS_BODY}</section>"
fi

# Tiles. Installs come from analytics; everything else in the download total
# is updates, repeat downloads and automated traffic.
TILES="<div class=\"stat\"><div class=\"v\">$(esc "${LATEST_TAG}")</div><div class=\"k\">Latest release</div></div>"
TILES+="<div class=\"stat\"><div class=\"v\">${REL_COUNT}</div><div class=\"k\">Releases</div></div>"
if [[ "${INSTALLS}" =~ ^[0-9]+$ ]]; then
    OTHER=$(( TOTAL_DL - INSTALLS )); [[ "${OTHER}" -lt 0 ]] && OTHER=0
    TILES+="<div class=\"stat\"><div class=\"v\">${INSTALLS}</div><div class=\"k\">Installs (analytics)</div></div>"
    TILES+="<div class=\"stat\"><div class=\"v\">${OTHER}</div><div class=\"k\">Other download traffic (est.)</div></div>"
fi
TILES+="<div class=\"stat\"><div class=\"v\">${TOTAL_DL}</div><div class=\"k\">All downloads</div></div>"

# ── Render HTML ──────────────────────────────────────────────────────────
PRODUCT_HTML="$(esc "${PRODUCT}")"
REPO_HTML="$(esc "${REPO}")"

cat > "${OUT_HTML}" <<HTMLEOF
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${PRODUCT_HTML} — Release Dashboard</title>
<style>
  :root{--bg:#0b0d10;--card:#15181d;--line:#262b33;--txt:#e6e9ee;--mut:#8b94a3;
        --acc:#4c8dff;--grn:#39c07a;--warn:#e0a23b;--err:#e0564b;}
  *{box-sizing:border-box} html{color-scheme:dark}
  body{margin:0;background:var(--bg);color:var(--txt);
       font:14px/1.5 -apple-system,BlinkMacSystemFont,"SF Pro Text",Segoe UI,sans-serif;
       -webkit-font-smoothing:antialiased;padding:32px}
  .wrap{max-width:980px;margin:0 auto}
  header{display:flex;align-items:baseline;justify-content:space-between;gap:16px;
         border-bottom:1px solid var(--line);padding-bottom:16px;margin-bottom:24px}
  h1{font-size:20px;font-weight:600;margin:0;letter-spacing:-.01em}
  .gen{color:var(--mut);font-size:12px;white-space:nowrap}
  .stats{display:flex;flex-wrap:wrap;gap:12px;margin:0 0 24px}
  .stat{flex:1 1 150px;background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px 16px}
  .stat .v{font-size:24px;font-weight:600;letter-spacing:-.02em;overflow-wrap:anywhere}
  .stat .k{color:var(--mut);font-size:12px;text-transform:uppercase;letter-spacing:.04em}
  section{background:var(--card);border:1px solid var(--line);border-radius:12px;
          padding:18px 20px;margin-bottom:20px;overflow-x:auto}
  section h2{font-size:14px;font-weight:600;margin:0 0 14px;display:flex;align-items:center;gap:8px}
  section h2 .dot{width:7px;height:7px;border-radius:50%;background:var(--acc)}
  table.grid{width:100%;border-collapse:collapse}
  table.grid th{text-align:left;color:var(--mut);font-weight:500;font-size:11px;
               text-transform:uppercase;letter-spacing:.04em;padding:0 10px 8px;border-bottom:1px solid var(--line)}
  table.grid th.num{text-align:right}
  table.grid td{padding:9px 10px;border-bottom:1px solid var(--line)}
  table.grid tr:last-child td{border-bottom:none}
  td.tag{font-weight:600} td.tag.latest::after{content:"latest";font-size:10px;color:var(--grn);
         margin-left:7px;border:1px solid var(--grn);border-radius:5px;padding:1px 5px;vertical-align:middle}
  td.date{color:var(--mut)} td.num{text-align:right;font-variant-numeric:tabular-nums}
  td.num.strong{font-weight:600} td.empty{color:var(--mut);text-align:center;padding:18px}
  .barcell{width:30%} .bar{height:9px;border-radius:5px;background:var(--acc);min-width:2px}
  .bar.g{background:var(--grn)} .bar.w{background:var(--warn)}
  .badge{font-size:10px;border-radius:5px;padding:1px 5px;margin-left:7px;vertical-align:middle}
  .badge.pre{background:#3a2f12;color:var(--warn);border:1px solid var(--warn)}
  .sub{color:var(--mut);font-size:12px;margin:12px 2px 0}
  .card-note{color:var(--mut);font-size:13px;line-height:1.7}
  .card-note.err{color:var(--err)}
  footer{color:var(--mut);font-size:11px;text-align:center;margin-top:8px}
</style></head>
<body><div class="wrap">
  <header>
    <h1>${PRODUCT_HTML} — Release Dashboard</h1>
    <span class="gen">generated ${GEN_AT}</span>
  </header>

  <div class="stats">${TILES}</div>

  <section>
    <h2><span class="dot"></span>Releases &amp; downloads <span class="sub" style="margin:0 0 0 4px">— ${REPO_HTML}</span></h2>
    <table class="grid">
      <thead><tr><th>Tag</th><th>Published</th>${GROUP_HEAD}<th class="num">Total</th><th></th></tr></thead>
      <tbody>${REL_ROWS}</tbody>
    </table>
    <p class="sub">Download counts come from GitHub and include updates, repeat downloads and automated traffic. Total covers every asset on the release. Bar = total relative to the most-downloaded release.</p>
  </section>

  <section>
    <h2><span class="dot" style="background:var(--grn)"></span>Adoption — active users by version</h2>
    ${ADOPTION}
  </section>

  ${EVENTS_SECTION}

  <footer>Local file · not hosted · re-run the github-ga4-release-dashboard skill to refresh.</footer>
</div></body></html>
HTMLEOF

echo "Wrote ${OUT_HTML}" >&2
echo "  releases=${REL_COUNT} · total_downloads=${TOTAL_DL} · analytics=${A_STATUS}" >&2
if [[ "${OPEN_AFTER}" -eq 1 ]]; then
    if command -v open >/dev/null; then open "${OUT_HTML}"
    elif command -v xdg-open >/dev/null; then xdg-open "${OUT_HTML}" >/dev/null 2>&1; fi
fi
echo "${OUT_HTML}"
