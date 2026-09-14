#!/usr/bin/env bash
# Journey D Flutter package gate (creator + execute harnesses).
#
# Separates package preparation from guarded live invocation:
#   prepare  — ensure pubspec.lock → .dart_tool/package_config.json (may run pub get)
#   require  — fail closed if package configuration is missing/stale (no network)
#
# Live/execute launchers must invoke Flutter with --no-pub after this gate.
#
# Freshness is lockfile-relative, not pubspec.yaml mtime. A version/build
# stamp in pubspec.yaml (for example 1.0.0+5) does not change the resolved
# package graph. `flutter pub get` is a no-op in that case and will not
# rewrite package_config.json, so comparing yaml mtime to the generated
# config is a false stale. Unresolved dependency edits must update
# pubspec.lock; a lockfile newer than package_config remains stale.

s17_jd_flutter_package_paths() {
  if [[ -z "${S17_ROOT:-}" ]]; then
    echo "REFUSED: S17_ROOT required for Flutter package gate" >&2
    return 2
  fi
  JD_PUBSPEC="${S17_ROOT}/pubspec.yaml"
  JD_LOCKFILE="${S17_ROOT}/pubspec.lock"
  JD_PACKAGE_CONFIG="${S17_ROOT}/.dart_tool/package_config.json"
}

# Returns 0 when committed lockfile + package_config are present and not stale.
s17_jd_flutter_package_config_ok() {
  s17_jd_flutter_package_paths || return 2
  if [[ ! -f "$JD_PUBSPEC" ]]; then
    echo "REFUSED: missing pubspec.yaml at package root" >&2
    return 2
  fi
  if [[ ! -f "$JD_LOCKFILE" ]]; then
    echo "REFUSED: missing pubspec.lock (committed lockfile required)" >&2
    return 2
  fi
  if [[ ! -f "$JD_PACKAGE_CONFIG" ]]; then
    echo "REFUSED: missing .dart_tool/package_config.json" >&2
    return 2
  fi
  # Stale only when the lockfile (resolved graph) is newer than generated config.
  if [[ "$JD_LOCKFILE" -nt "$JD_PACKAGE_CONFIG" ]]; then
    echo "REFUSED: stale package_config relative to pubspec.lock" >&2
    return 2
  fi
  if ! grep -q '"name": "cohort_platform"' "$JD_PACKAGE_CONFIG"; then
    echo "REFUSED: package_config does not name cohort_platform" >&2
    return 2
  fi
  return 0
}

# Prepare using the committed lockfile. No lockfile regeneration intent.
# Invoked before hosted contact; failure refuses before mutation.
s17_jd_flutter_package_prepare() {
  s17_jd_flutter_package_paths || return 2
  if ! command -v flutter >/dev/null 2>&1; then
    echo "REFUSED: flutter runtime required for package preparation" >&2
    return 2
  fi
  if s17_jd_flutter_package_config_ok 2>/dev/null; then
    echo "JD_FLUTTER_PACKAGES=ready"
    return 0
  fi
  echo "JD_FLUTTER_PACKAGES=preparing"
  # Use lockfile; do not upgrade. Network only for package fetch if cache incomplete.
  if ! (
    cd "$S17_ROOT"
    flutter pub get
  ); then
    echo "REFUSED: flutter pub get failed during package preparation" >&2
    return 2
  fi
  # pub get may no-op without rewriting package_config.json. Stamp the
  # generated artifact so --no-pub require sees a lock-consistent config.
  if [[ -f "$JD_PACKAGE_CONFIG" ]]; then
    touch "$JD_PACKAGE_CONFIG"
  fi
  if ! s17_jd_flutter_package_config_ok; then
    echo "REFUSED: package_config still invalid after flutter pub get" >&2
    return 2
  fi
  echo "JD_FLUTTER_PACKAGES=prepared"
  return 0
}

# Require already-valid package_config; never runs pub get.
s17_jd_flutter_package_require() {
  if ! s17_jd_flutter_package_config_ok; then
    echo "REFUSED: Flutter package configuration missing or stale before --no-pub invoke" >&2
    return 2
  fi
  echo "JD_FLUTTER_PACKAGES=required_ok"
  return 0
}
