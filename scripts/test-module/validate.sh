#!/bin/bash
# Validation script: lint, static analysis, and log checks.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODULE_DIR="${PROJECT_ROOT}/scripts/test-module"
LOG_ROOT="${PROJECT_ROOT}/logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="${LOG_ROOT}/validation_${TIMESTAMP}"
REPORT_MD="${REPORT_DIR}/report.md"
REPORT_JSON="${REPORT_DIR}/report.json"

mkdir -p "${REPORT_DIR}"

note() {
  echo "$1" >> "${REPORT_MD}"
}

json_append() {
  local name="$1"
  local status="$2"
  local details="$3"
  local escaped
  escaped="${details//\"/\\\"}"
  printf '{"name":"%s","status":"%s","details":"%s"},\n' \
    "${name}" "${status}" "${escaped}" >> "${REPORT_JSON}.tmp"
}

note "# Validation Report"
note ""
note "Timestamp: ${TIMESTAMP}"
note ""

: > "${REPORT_JSON}.tmp"

# 1) ShellCheck
if command -v shellcheck >/dev/null 2>&1; then
  note "## ShellCheck"
  if shellcheck "${PROJECT_ROOT}/scripts/test-module"/*.sh "${PROJECT_ROOT}/scripts/podman-automation.sh" \
      > "${REPORT_DIR}/shellcheck.txt" 2>&1; then
    note "- status: ok"
    json_append "shellcheck" "ok" "no issues"
  else
    note "- status: issues"
    note "- details: ${REPORT_DIR}/shellcheck.txt"
    json_append "shellcheck" "issues" "see shellcheck.txt"
  fi
else
  note "## ShellCheck"
  note "- status: skipped (shellcheck not installed)"
  json_append "shellcheck" "skipped" "not installed"
fi

# 2) YAML lint
if command -v yamllint >/dev/null 2>&1; then
  note "## yamllint"
  if yamllint -d relaxed "${PROJECT_ROOT}/docker-compose.yaml" \
      > "${REPORT_DIR}/yamllint.txt" 2>&1; then
    note "- status: ok"
    json_append "yamllint" "ok" "no issues"
  else
    note "- status: issues"
    note "- details: ${REPORT_DIR}/yamllint.txt"
    json_append "yamllint" "issues" "see yamllint.txt"
  fi
else
  note "## yamllint"
  note "- status: skipped (yamllint not installed)"
  json_append "yamllint" "skipped" "not installed"
fi

# 3) Hadolint for Dockerfiles
if command -v hadolint >/dev/null 2>&1; then
  note "## hadolint"
  HADOLINT_OUT="${REPORT_DIR}/hadolint.txt"
  : > "${HADOLINT_OUT}"
  find "${PROJECT_ROOT}" -name Dockerfile -type f -print0 | \
    xargs -0 -I {} sh -c 'hadolint "$1" >> "$2" || true' _ {} "${HADOLINT_OUT}"
  if [ -s "${HADOLINT_OUT}" ]; then
    note "- status: issues"
    note "- details: ${HADOLINT_OUT}"
    json_append "hadolint" "issues" "see hadolint.txt"
  else
    note "- status: ok"
    json_append "hadolint" "ok" "no issues"
  fi
else
  note "## hadolint"
  note "- status: skipped (hadolint not installed)"
  json_append "hadolint" "skipped" "not installed"
fi

# 4) Python static checks (optional)
if command -v ruff >/dev/null 2>&1; then
  note "## ruff"
  if ruff check "${MODULE_DIR}/log-analyzer.py" > "${REPORT_DIR}/ruff.txt" 2>&1; then
    note "- status: ok"
    json_append "ruff" "ok" "no issues"
  else
    note "- status: issues"
    note "- details: ${REPORT_DIR}/ruff.txt"
    json_append "ruff" "issues" "see ruff.txt"
  fi
else
  note "## ruff"
  note "- status: skipped (ruff not installed)"
  json_append "ruff" "skipped" "not installed"
fi

# 5) Log analysis on latest run
note "## Log analysis"
LATEST_RUN="$(ls -dt "${LOG_ROOT}"/test_run_* "${LOG_ROOT}"/scheduled_* 2>/dev/null | head -1 || true)"
if [ -z "${LATEST_RUN}" ]; then
  note "- status: skipped (no log runs found)"
  json_append "log-analysis" "skipped" "no logs"
else
  if command -v python3 >/dev/null 2>&1; then
    python3 "${MODULE_DIR}/log-analyzer.py" "${LATEST_RUN}" > "${REPORT_DIR}/log-analyzer.txt" 2>&1 || true
    note "- status: completed"
    note "- run: ${LATEST_RUN}"
    note "- details: ${REPORT_DIR}/log-analyzer.txt"
    json_append "log-analysis" "completed" "${LATEST_RUN}"
  else
    note "- status: skipped (python3 not installed)"
    note "- run: ${LATEST_RUN}"
    json_append "log-analysis" "skipped" "python3 not installed"
  fi
fi

# Finalize JSON
{
  echo '{'
  echo '  "timestamp": "'"${TIMESTAMP}"'",'
  echo '  "results": ['
  sed '$s/,$//' "${REPORT_JSON}.tmp"
  echo '  ]'
  echo '}'
} > "${REPORT_JSON}"
rm -f "${REPORT_JSON}.tmp"

note ""
note "Report JSON: ${REPORT_JSON}"
