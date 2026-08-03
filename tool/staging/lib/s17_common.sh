#!/usr/bin/env bash
# Shared bash helpers for Sprint 1.7 Athlete D staging tooling.
# shellcheck shell=bash

s17_require_confirmation() {
  if [[ "${CONFIRM_COHORT_STAGING:-}" != "1" ]]; then
    echo "REFUSED: set CONFIRM_COHORT_STAGING=1 after positively confirming Cohort Staging." >&2
    exit 2
  fi
}

s17_require_commands() {
  local c
  for c in "$@"; do
    if ! command -v "$c" >/dev/null 2>&1; then
      echo "REFUSED: required command not found: $c" >&2
      exit 2
    fi
  done
}

s17_assert_outside_worktrees() {
  local path="$1"
  python3 - <<PY
from pathlib import Path
import sys
sys.path.insert(0, "${ROOT}/tool/staging/lib")
from s17_staging_guard import StagingGuardError, assert_outside_git_worktrees
try:
    assert_outside_git_worktrees(Path("${path}"), [Path("${ROOT}")])
except StagingGuardError as e:
    print(str(e), file=sys.stderr)
    raise SystemExit(2)
PY
}

# Confirms Cohort Staging identity.
# Offline/local test hook: set S17_PROJECTS_JSON_FILE to a projects-list JSON fixture
# to avoid hosted management contact during B4a local verification.
s17_confirm_staging_identity() {
  python3 - <<'PY'
import json, os, subprocess, sys
from pathlib import Path

root = Path(os.environ.get("S17_ROOT") or Path.cwd())
sys.path.insert(0, str(root / "tool/staging/lib"))
from s17_staging_guard import (
    StagingGuardError,
    ensure_confirmation,
    parse_projects_json,
    select_staging_project,
)

try:
    ensure_confirmation()
    fixture = os.environ.get("S17_PROJECTS_JSON_FILE", "").strip()
    if fixture:
        raw = Path(fixture).read_text()
    else:
        raw = subprocess.check_output(
            ["supabase", "projects", "list", "-o", "json"], text=True
        )
    projects = parse_projects_json(raw)
    selected = select_staging_project(projects)
    if selected.get("production_linked"):
        # Soft warning only when fixture/list shows production linked elsewhere.
        print(
            "WARN: production candidate reports linked=true in projects list; "
            "continue only if this worktree is staging-linked.",
            file=sys.stderr,
        )
    print(
        "STAGING_CONFIRMED "
        f"name={selected['name']} "
        f"ref_prefix={selected['ref_prefix']} "
        f"region={selected['region']} "
        f"status={selected['status']}"
    )
except StagingGuardError as e:
    print(str(e), file=sys.stderr)
    raise SystemExit(2)
PY
}
