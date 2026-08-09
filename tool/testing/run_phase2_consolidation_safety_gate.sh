#!/usr/bin/env bash
# Phase 2.3 — Consolidation Safety Gate (authoritative local command).
#
# Proves Phase 1 protected behavioural invariants remain intact before/after
# consolidation work. Local-only: no staging or production contact.
#
# Not included (run separately when prerequisites exist):
#   ./tool/testing/run_phase2_harness_tests.sh
#   ./tool/testing/run_phase2_diagnosis_tests.sh
#
# Policy: every later Phase 2 consolidation sprint must pass this gate.
# A green gate is necessary but does not alone prove code is dead or safe
# to delete — see docs/architecture/Phase_2_Consolidation_Safety_Gate_v1.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

MANIFEST="$ROOT/docs/architecture/Phase_2_Consolidation_Safety_Gate_v1.md"
if [[ ! -f "$MANIFEST" ]]; then
  echo "SAFETY_GATE=FAIL missing invariant manifest: $MANIFEST" >&2
  exit 2
fi

PASS_COUNT=0
FAIL_COUNT=0
declare -a FAILURES=()

run_group() {
  local name="$1"
  shift
  echo
  echo "======== SAFETY_GATE_GROUP=$name ========"
  echo "CMD: flutter test $*"
  if flutter test "$@"; then
    echo "SAFETY_GATE_GROUP=$name RESULT=PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    local code=$?
    echo "SAFETY_GATE_GROUP=$name RESULT=FAIL exit=$code" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAILURES+=("$name")
    return "$code"
  fi
}

# Fail closed: required evidence paths must exist before execution.
REQUIRED_PATHS=(
  test/architecture/architecture_dependency_test.dart
  test/architecture/programme_scheduling_ownership_dependency_test.dart
  test/architecture/phase2_consolidation_safety_tripwires_test.dart
  test/phase6/coaching_integrity_test.dart
  test/application/adaptation/programme_adaptation_acceptance_service_test.dart
  test/application/adaptation/programme_adaptation_proposal_service_test.dart
  test/application/adaptation/programme_adaptation_reversion_service_test.dart
  test/application/adaptation/programme_adaptation_hardening_1_6e_test.dart
  test/application/adaptation/equipment_adaptation_b4d19_test.dart
  test/features/home/programme_adapt_flow_widget_test.dart
  test/programme/athlete_programme_completion_self_test_2_test.dart
  test/staging/s17_staging_guard_test.dart
)

echo "PHASE2_CONSOLIDATION_SAFETY_GATE=start"
echo "ROOT=$ROOT"
echo "MANIFEST=$MANIFEST"

for rel in "${REQUIRED_PATHS[@]}"; do
  if [[ ! -f "$ROOT/$rel" ]]; then
    echo "SAFETY_GATE=FAIL missing required evidence: $rel" >&2
    exit 2
  fi
done
echo "REQUIRED_EVIDENCE=present count=${#REQUIRED_PATHS[@]}"

set +e
run_group "architectural_boundaries" \
  test/architecture/architecture_dependency_test.dart \
  test/architecture/architecture_ownership_test.dart \
  test/architecture/programme_scheduling_ownership_dependency_test.dart \
  test/architecture/phase2_consolidation_safety_tripwires_test.dart

run_group "coaching_integrity" \
  test/phase6/coaching_integrity_test.dart

run_group "adaptation_contracts" \
  test/application/adaptation/programme_adaptation_proposal_service_test.dart \
  test/application/adaptation/programme_adaptation_acceptance_service_test.dart \
  test/application/adaptation/programme_adaptation_reversion_service_test.dart \
  test/application/adaptation/programme_adaptation_hardening_1_6e_test.dart \
  test/application/adaptation/equipment_adaptation_b4d19_test.dart

run_group "programme_adapt_ui_contract" \
  test/features/home/programme_adapt_flow_widget_test.dart

run_group "completion_identity" \
  test/programme/athlete_programme_completion_self_test_2_test.dart

run_group "staging_production_isolation" \
  test/staging/s17_staging_guard_test.dart
set -e

echo
echo "======== SAFETY_GATE_SUMMARY ========"
echo "groups_passed=$PASS_COUNT"
echo "groups_failed=$FAIL_COUNT"
if [[ "$FAIL_COUNT" -eq 0 ]]; then
  echo "PHASE2_CONSOLIDATION_SAFETY_GATE=PASS"
  echo "Protected invariants: INV-01..INV-20 (see $MANIFEST)"
  exit 0
fi

echo "PHASE2_CONSOLIDATION_SAFETY_GATE=FAIL" >&2
for g in "${FAILURES[@]}"; do
  echo "  failed_group=$g" >&2
done
exit 1
