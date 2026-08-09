#!/usr/bin/env bash
# Phase 2.2 — explicit Journey D diagnosis / nontest-launcher test group.
#
# Not part of the default `flutter test` suite (tagged `diagnosis`, skipped by
# dart_test.yaml). Requires a working Flutter nontest launcher (typically
# macos desktop). May be ENV-BLOCKED if the device/runtime is unavailable.
#
# No staging or production contact is intended; proofs use loopback / init-only
# modes. Do not set CONFIRM_COHORT_STAGING for hosted mutation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

export S17_JD_FLUTTER_DEVICE="${S17_JD_FLUTTER_DEVICE:-macos}"

echo "PHASE2_DIAGNOSIS_GROUP=start"
echo "S17_JD_FLUTTER_DEVICE=$S17_JD_FLUTTER_DEVICE"
flutter test --tags diagnosis --run-skipped \
  test/staging/s17_jd_supabase_init_diagnosis_test.dart \
  test/staging/s17_jd_creator_timeout_diagnosis_test.dart
echo "PHASE2_DIAGNOSIS_GROUP=pass"
