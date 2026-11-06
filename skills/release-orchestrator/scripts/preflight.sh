#!/usr/bin/env bash
#
# preflight.sh — release readiness gate, driven by .release-orchestrator.json.
#
# Runs the machine-checkable checks before a release and renders a
# PASS / WARN / FAIL table. Exits non-zero if any HARD check fails, so the
# orchestrator can stop. WARN items are reported but never block. Manual
# attestations from the config are printed for a human to confirm.
#
# Usage:
#   preflight.sh [--next-version <tag>] [--repo <path>] [--config <path>]
#
#   --next-version  Also assert this tag is unused, locally and on origin.
#   --repo          Repository to check. Default: the git repo of the
#                   current directory.
#   --config        Config file. Default: <repo>/.release-orchestrator.json
#
# Requires: git, jq. Uses gh for the GitHub checks and PlistBuddy (macOS) for
# plist checks; a check whose tool is missing is reported as a warning.
#
# Exit codes: 0 = no hard check failed · 1 = one or more hard checks failed
#             2 = usage or environment error
#
# SPDX-License-Identifier: MIT

set -uo pipefail

usage() {
    sed -n '3,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

CONFIG=""
REPO=""
NEXT_VERSION=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --next-version) NEXT_VERSION="${2:-}"; shift 2 ;;
        --repo)         REPO="${2:-}"; shift 2 ;;
        --config)       CONFIG="${2:-}"; shift 2 ;;
        -h|--help)      usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

command -v git >/dev/null || { echo "ERROR: git not found." >&2; exit 2; }
command -v jq  >/dev/null || { echo "ERROR: jq not found." >&2; exit 2; }

# ── Resolve repo + config ────────────────────────────────────────────────
if [[ -z "${REPO}" ]]; then
    REPO="$(git rev-parse --show-toplevel 2>/dev/null)"
fi
if [[ -z "${REPO}" || ! -d "${REPO}" ]]; then
    echo "ERROR: Not inside a git repository. Run from the app's repo or pass --repo." >&2
    exit 2
fi
[[ -z "${CONFIG}" ]] && CONFIG="${REPO}/.release-orchestrator.json"
if [[ ! -f "${CONFIG}" ]]; then
    echo "ERROR: No config at ${CONFIG}. Run the skill's setup first." >&2
    exit 2
fi
if ! jq -e 'type == "object"' "${CONFIG}" >/dev/null 2>&1; then
    echo "ERROR: ${CONFIG} is not a valid JSON object." >&2
    exit 2
fi

cfg() { jq -r "$1 // empty" "${CONFIG}"; }

APP_NAME="$(cfg '.appName')"
RELEASE_BRANCH="$(cfg '.releaseBranch')"; [[ -z "${RELEASE_BRANCH}" ]] && RELEASE_BRANCH="main"
GH_REPO="$(cfg '.repo')"
TESTS_WORKFLOW="$(cfg '.preflight.testsWorkflow')"
APPCAST_URL="$(cfg '.publish.appcastURL')"
PLISTBUDDY="/usr/libexec/PlistBuddy"

# ── Result accumulation ──────────────────────────────────────────────────
HARD_FAIL=0
ROWS=()
row()  { ROWS+=("$1|$2|$3"); }                      # status | check | detail
pass() { row "PASS" "$1" "${2:-}"; }
warn() { row "WARN" "$1" "${2:-}"; }
fail() { row "FAIL" "$1" "${2:-}"; HARD_FAIL=1; }

# Show only the start of a value: enough to recognise, not enough to leak.
preview() {
    local v="$1"
    if [[ ${#v} -gt 12 ]]; then printf '%s…' "${v:0:12}"; else printf '%s' "${v}"; fi
}

# ── 1. Repo state (HARD) ─────────────────────────────────────────────────
BRANCH="$(git -C "${REPO}" rev-parse --abbrev-ref HEAD 2>/dev/null)"
if [[ "${BRANCH}" == "${RELEASE_BRANCH}" ]]; then pass "On ${RELEASE_BRANCH} branch"
else fail "On ${RELEASE_BRANCH} branch" "currently '${BRANCH}'"; fi

if [[ -z "$(git -C "${REPO}" status --porcelain 2>/dev/null)" ]]; then pass "Clean working tree"
else fail "Clean working tree" "uncommitted or untracked changes present"; fi

if git -C "${REPO}" fetch origin "${RELEASE_BRANCH}" --quiet 2>/dev/null; then
    LOCAL_SHA="$(git -C "${REPO}" rev-parse HEAD)"
    REMOTE_SHA="$(git -C "${REPO}" rev-parse "origin/${RELEASE_BRANCH}" 2>/dev/null)"
    if [[ "${LOCAL_SHA}" == "${REMOTE_SHA}" ]]; then pass "Synced with origin/${RELEASE_BRANCH}" "${LOCAL_SHA:0:7}"
    else fail "Synced with origin/${RELEASE_BRANCH}" "local ${LOCAL_SHA:0:7} != origin ${REMOTE_SHA:0:7}"; fi
else
    warn "Synced with origin/${RELEASE_BRANCH}" "could not fetch origin (offline?)"
fi

# ── 2. Target tag unused (HARD, only with --next-version) ────────────────
if [[ -n "${NEXT_VERSION}" ]]; then
    if git -C "${REPO}" tag -l "${NEXT_VERSION}" | grep -q .; then
        fail "Tag ${NEXT_VERSION} unused" "exists locally"
    elif git -C "${REPO}" ls-remote --tags origin "${NEXT_VERSION}" 2>/dev/null | grep -q .; then
        fail "Tag ${NEXT_VERSION} unused" "exists on origin"
    else
        pass "Tag ${NEXT_VERSION} unused"
    fi
fi

# ── 3. Plist values (HARD) ───────────────────────────────────────────────
# Each entry: { file, key, label?, equals? }. Without `equals` the key must
# be present and non-empty; with it the value must match exactly.
while IFS= read -r item; do
    [[ -z "${item}" ]] && continue
    p_file="$(jq -r '.file // empty' <<< "${item}")"
    p_key="$(jq -r '.key // empty' <<< "${item}")"
    p_equals="$(jq -r '.equals // empty' <<< "${item}")"
    p_label="$(jq -r '.label // empty' <<< "${item}")"
    [[ -z "${p_label}" ]] && p_label="${p_key} set"
    if [[ -z "${p_file}" || -z "${p_key}" ]]; then
        fail "${p_label}" "config entry needs both 'file' and 'key'"
    elif [[ ! -x "${PLISTBUDDY}" ]]; then
        warn "${p_label}" "PlistBuddy not available (plist checks need macOS)"
    elif [[ ! -f "${REPO}/${p_file}" ]]; then
        fail "${p_label}" "${p_file} not found"
    else
        p_value="$("${PLISTBUDDY}" -c "Print :${p_key}" "${REPO}/${p_file}" 2>/dev/null)"
        if [[ -z "${p_value}" ]]; then
            fail "${p_label}" "${p_key} is missing or empty in ${p_file}"
        elif [[ -n "${p_equals}" && "${p_value}" != "${p_equals}" ]]; then
            fail "${p_label}" "${p_key} does not match the expected value"
        else
            pass "${p_label}" "$(preview "${p_value}")"
        fi
    fi
done < <(jq -c '.preflight.plistChecks[]?' "${CONFIG}")

# ── 4. File content rules (HARD) ─────────────────────────────────────────
# Each entry: { file, label?, mustContain?, mustNotContain? } — fixed strings.
while IFS= read -r item; do
    [[ -z "${item}" ]] && continue
    f_file="$(jq -r '.file // empty' <<< "${item}")"
    f_must="$(jq -r '.mustContain // empty' <<< "${item}")"
    f_mustnot="$(jq -r '.mustNotContain // empty' <<< "${item}")"
    f_label="$(jq -r '.label // empty' <<< "${item}")"
    [[ -z "${f_label}" ]] && f_label="${f_file} content"
    if [[ -z "${f_file}" || ( -z "${f_must}" && -z "${f_mustnot}" ) ]]; then
        fail "${f_label}" "config entry needs 'file' and 'mustContain' or 'mustNotContain'"
    elif [[ ! -f "${REPO}/${f_file}" ]]; then
        fail "${f_label}" "${f_file} not found"
    elif [[ -n "${f_must}" ]] && ! grep -qF -- "${f_must}" "${REPO}/${f_file}"; then
        fail "${f_label}" "'${f_must}' not found in ${f_file}"
    elif [[ -n "${f_mustnot}" ]] && grep -qF -- "${f_mustnot}" "${REPO}/${f_file}"; then
        fail "${f_label}" "'${f_mustnot}' found in ${f_file} ($(grep -cF -- "${f_mustnot}" "${REPO}/${f_file}") place(s))"
    else
        pass "${f_label}"
    fi
done < <(jq -c '.preflight.fileChecks[]?' "${CONFIG}")

# ── 5. Files CI needs must be tracked (HARD) ─────────────────────────────
while IFS= read -r tracked; do
    [[ -z "${tracked}" ]] && continue
    if git -C "${REPO}" ls-files --error-unmatch "${tracked}" >/dev/null 2>&1; then
        pass "Tracked: ${tracked}"
    else
        fail "Tracked: ${tracked}" "not committed — CI only sees committed files"
    fi
done < <(jq -r '.preflight.trackedFiles[]?' "${CONFIG}")

# ── 6. Required CI secrets exist (HARD) ──────────────────────────────────
REQUIRED_SECRETS=()
while IFS= read -r secret; do
    [[ -n "${secret}" ]] && REQUIRED_SECRETS+=("${secret}")
done < <(jq -r '.preflight.requiredSecrets[]?' "${CONFIG}")

if [[ ${#REQUIRED_SECRETS[@]} -gt 0 ]]; then
    if [[ -z "${GH_REPO}" ]] || ! command -v gh >/dev/null; then
        warn "Release secrets configured" "needs 'repo' in the config and the gh CLI"
    elif SECRET_LIST="$(gh secret list --repo "${GH_REPO}" 2>/dev/null | awk '{print $1}')"; then
        MISSING=()
        for s in "${REQUIRED_SECRETS[@]}"; do
            grep -qx -- "${s}" <<< "${SECRET_LIST}" || MISSING+=("${s}")
        done
        if [[ ${#MISSING[@]} -eq 0 ]]; then pass "Release secrets configured" "${#REQUIRED_SECRETS[@]}/${#REQUIRED_SECRETS[@]}"
        else fail "Release secrets configured" "missing: ${MISSING[*]}"; fi
    else
        warn "Release secrets configured" "could not query gh secrets (auth or network)"
    fi
fi

# ── 7. Latest test run on the release branch is green (HARD) ─────────────
if [[ -n "${TESTS_WORKFLOW}" ]]; then
    CHECK="Latest ${TESTS_WORKFLOW} on ${RELEASE_BRANCH} is green"
    if [[ -z "${GH_REPO}" ]] || ! command -v gh >/dev/null; then
        warn "${CHECK}" "needs 'repo' in the config and the gh CLI"
    elif CI_JSON="$(gh run list --repo "${GH_REPO}" --workflow "${TESTS_WORKFLOW}" --branch "${RELEASE_BRANCH}" -L 1 --json conclusion,status 2>/dev/null)"; then
        CI_CONCL="$(jq -r '.[0].conclusion // "none"' <<< "${CI_JSON}")"
        CI_STATUS="$(jq -r '.[0].status // "none"' <<< "${CI_JSON}")"
        if [[ "${CI_CONCL}" == "success" ]]; then pass "${CHECK}"
        elif [[ "${CI_STATUS}" == "none" ]]; then warn "${CHECK}" "no run found"
        elif [[ "${CI_STATUS}" == "completed" ]]; then fail "${CHECK}" "last run: ${CI_CONCL}"
        else warn "${CHECK}" "in progress (${CI_STATUS})"; fi
    else
        warn "${CHECK}" "could not query gh runs (auth or network)"
    fi
fi

# ── 8. Live URLs reachable (WARN) ────────────────────────────────────────
url_ok() { curl -sIL --max-time 10 "$1" 2>/dev/null | grep -qE '^HTTP/[0-9.]+ 2[0-9][0-9]'; }
while IFS= read -r url; do
    [[ -z "${url}" ]] && continue
    if url_ok "${url}"; then pass "Reachable: ${url}"
    else warn "Reachable: ${url}" "no 2xx response"; fi
done < <(jq -r '.preflight.urls[]?' "${CONFIG}")

if [[ -n "${APPCAST_URL}" ]]; then
    if APPCAST_XML="$(curl -sL --max-time 10 "${APPCAST_URL}" 2>/dev/null)" && grep -q "<item>" <<< "${APPCAST_XML}"; then
        pass "Update feed live" "$(grep -c '<item>' <<< "${APPCAST_XML}") item(s)"
    else
        warn "Update feed live" "${APPCAST_URL} unreachable or has no items"
    fi
fi

# ── Render table ─────────────────────────────────────────────────────────
icon() { case "$1" in PASS) printf "✅";; WARN) printf "⚠️ ";; FAIL) printf "❌";; esac; }
PASS_N=0; WARN_N=0; FAIL_N=0
echo ""
echo "Release preflight — ${APP_NAME:-$(basename "${REPO}")}${NEXT_VERSION:+ → ${NEXT_VERSION}}"
echo "Repo: ${REPO}"
echo "─────────────────────────────────────────────────────────────────────────"
printf "  %-2s  %-40s  %s\n" "" "CHECK" "DETAIL"
echo "─────────────────────────────────────────────────────────────────────────"
for r in "${ROWS[@]}"; do
    IFS='|' read -r st ck dt <<< "$r"
    printf "  %-2s  %-40s  %s\n" "$(icon "$st")" "$ck" "$dt"
    case "$st" in
        PASS) PASS_N=$((PASS_N + 1)) ;;
        WARN) WARN_N=$((WARN_N + 1)) ;;
        FAIL) FAIL_N=$((FAIL_N + 1)) ;;
    esac
done
echo "─────────────────────────────────────────────────────────────────────────"
printf "  %d passed · %d warnings · %d blockers\n" "$PASS_N" "$WARN_N" "$FAIL_N"
echo ""

ATTESTATIONS="$(jq -r '.preflight.manualAttestations[]?' "${CONFIG}")"
if [[ -n "${ATTESTATIONS}" ]]; then
    echo "Manual attestation required (not machine-checkable):"
    while IFS= read -r line; do echo "  • ${line}"; done <<< "${ATTESTATIONS}"
    echo ""
fi

if [[ "${HARD_FAIL}" -ne 0 ]]; then
    echo "RESULT: BLOCKED — fix the ❌ blockers above before releasing."
    exit 1
fi
if [[ "${WARN_N}" -gt 0 ]]; then
    echo "RESULT: READY — no hard blockers. Review the ⚠️  warnings before shipping."
else
    echo "RESULT: READY — no hard blockers."
fi
exit 0
