#!/usr/bin/env bash
# Fail-closed local-target safeguards for Sprint 1.2 disposable DB gates.
# shellcheck shell=bash

sprint12_die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Refuse any command line / env that could target hosted or linked projects.
# This harness is --workdir local-only: it never consumes SUPABASE_ACCESS_TOKEN.
sprint12_assert_no_hosted_intent() {
  local joined="$*"
  if [[ "$joined" == *"--linked"* ]]; then
    sprint12_die "Refusing --linked (hosted project contact forbidden)."
  fi
  if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
    # Do not print token contents.
    sprint12_die "Refusing SUPABASE_ACCESS_TOKEN in environment (local-only harness never uses hosted auth tokens)."
  fi
  if [[ "${SUPABASE_DB_URL:-}" =~ supabase\.co ]] || [[ "${DATABASE_URL:-}" =~ supabase\.co ]]; then
    sprint12_die "Refusing hosted supabase.co database URL in environment."
  fi
  if [[ "${DB_URL:-}${DATABASE_URL:-}${SUPABASE_DB_URL:-}" =~ (aws|gcp|azure|pooler\.supabase) ]]; then
    sprint12_die "Refusing non-local cloud/pooler database URL."
  fi
}

# Validate an optional explicit DB URL is loopback-only.
sprint12_assert_loopback_url() {
  local url="$1"
  [[ -n "$url" ]] || return 0
  if [[ "$url" =~ supabase\.co|pooler\.supabase ]]; then
    sprint12_die "Non-local database URL rejected: (redacted)"
  fi
  # Accept only loopback hosts.
  if [[ ! "$url" =~ @127\.0\.0\.1[:/] && ! "$url" =~ @localhost[:/] && ! "$url" =~ @\[::1\][:/] && ! "$url" =~ @::1[:/] ]]; then
    sprint12_die "Database URL host is not loopback (redacted)."
  fi
}

# Resolve exactly one running db container for the disposable project_id.
# Never fuzzy-matches other s12g* stacks. Fails if missing or ambiguous.
sprint12_resolve_exact_db_container() {
  local project_id="$1"
  local expected count matches

  [[ -n "$project_id" ]] || sprint12_die "Exact container resolve: project id unset."
  expected="supabase_db_${project_id}"

  matches="$(docker ps --format '{{.Names}}' | rg "^${expected}$" || true)"
  count="$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$count" != "1" ]]; then
    sprint12_die "Exact container '${expected}' missing or ambiguous (match_count=${count}). Refusing fuzzy discovery."
  fi
  # Defence in depth: resolved name must equal expected (no alternate selection).
  [[ "$matches" == "$expected" ]] || sprint12_die "Resolved container '${matches}' != expected '${expected}'."
  printf '%s\n' "$expected"
}

# Validate Docker container identity for this disposable project.
# Expected: supabase_db_<project_id>
sprint12_assert_local_container() {
  local container="$1"
  local expected_project_id="$2"

  [[ -n "$container" ]] || sprint12_die "DB container unset."
  [[ -n "$expected_project_id" ]] || sprint12_die "Expected project id unset."

  if [[ "$container" != "supabase_db_${expected_project_id}" ]]; then
    sprint12_die "Unexpected container '$container' (expected supabase_db_${expected_project_id})."
  fi

  if ! docker inspect "$container" >/dev/null 2>&1; then
    sprint12_die "Container '$container' not found locally."
  fi

  # Must be running on the local docker engine (inspect succeeds only for local daemon context).
  local running
  running="$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || echo false)"
  [[ "$running" == "true" ]] || sprint12_die "Container '$container' is not running."

  echo "TARGET: docker-container=${container} project=${expected_project_id} (local disposable; credentials redacted)"
}

sprint12_assert_command_is_local() {
  local joined="$*"
  sprint12_assert_no_hosted_intent "$joined"
  if [[ "$joined" == *"--linked"* ]]; then
    sprint12_die "linked mode forbidden"
  fi
}
