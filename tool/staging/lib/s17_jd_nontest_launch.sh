# Shared non-test Flutter launch for Journey D create/execute.
# Requires: S17_ROOT, result env var name, target dart library.
# Uses flutter run --no-pub on a desktop/web device; waits for result file.

s17_jd_nontest_flutter_run() {
  local target_lib="$1"
  local result_env_name="$2"
  local surface="$3"
  local result_file="${!result_env_name:-}"

  if [[ -z "$result_file" ]]; then
    echo "REFUSED: $result_env_name required before non-test launch" >&2
    return 2
  fi
  if [[ -z "${S17_ROOT:-}" ]]; then
    echo "REFUSED: S17_ROOT required" >&2
    return 2
  fi
  if ! command -v flutter >/dev/null 2>&1; then
    echo "REFUSED: flutter runtime required for Journey D non-test executable" >&2
    return 2
  fi

  # Prefer macos (plugins registered, headless-friendly). Allow override.
  local device="${S17_JD_FLUTTER_DEVICE:-macos}"
  local timeout_sec="${S17_JD_NONTEST_TIMEOUT_SEC:-600}"
  local grace_sec="${S17_JD_NONTEST_TERMINATE_GRACE_SEC:-15}"
  local log_dir
  log_dir="$(dirname "$result_file")"
  local stdout_log="${log_dir}/nontest_${surface}_flutter_stdout.txt"
  local stderr_log="${log_dir}/nontest_${surface}_flutter_stderr.txt"

  rm -f "$result_file"
  echo "JD_NONTEST_RUNTIME=flutter_run device=${device} target=${target_lib}"

  set +e
  set -m
  (
    cd "$S17_ROOT"
    flutter run -d "$device" -t "$target_lib" --no-pub
  ) >"$stdout_log" 2>"$stderr_log" &
  local run_pid=$!
  set +m

  python3 - "$result_file" "$run_pid" "$timeout_sec" "$grace_sec" "$stdout_log" "$stderr_log" <<'PY'
import os, pathlib, signal, sys, time

result = pathlib.Path(sys.argv[1])
run_pid = int(sys.argv[2])
deadline = time.time() + int(sys.argv[3])
grace = int(sys.argv[4])
stdout_log = pathlib.Path(sys.argv[5])
stderr_log = pathlib.Path(sys.argv[6])

def terminate():
    try:
        os.kill(run_pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    end = time.time() + grace
    while time.time() < end:
        try:
            os.kill(run_pid, 0)
        except ProcessLookupError:
            return
        time.sleep(0.2)
    try:
        os.kill(run_pid, signal.SIGKILL)
    except ProcessLookupError:
        return

while time.time() < deadline:
    if result.is_file() and result.stat().st_size > 0:
        # Allow writer to finish flush.
        time.sleep(0.3)
        terminate()
        # Prefer result file presence; flutter run may exit non-zero after exit().
        sys.exit(0)
    # Fail fast if flutter died without a result.
    try:
        os.kill(run_pid, 0)
    except ProcessLookupError:
        print(
            "REFUSED: non-test flutter process exited before result file "
            f"stdout={stdout_log} stderr={stderr_log}",
            file=sys.stderr,
        )
        sys.exit(2)
    # Guard: must not begin dependency resolution.
    for log in (stdout_log, stderr_log):
        if log.exists() and "Resolving dependencies..." in log.read_text(errors="replace"):
            print(
                "REFUSED: non-test flutter began dependency resolution (--no-pub required)",
                file=sys.stderr,
            )
            terminate()
            sys.exit(2)
    time.sleep(0.4)

print(
    f"REFUSED: timed out waiting for result file {result}",
    file=sys.stderr,
)
terminate()
sys.exit(3)
PY
  local py_ec=$?
  set -e
  if [[ "$py_ec" -ne 0 ]]; then
    return "$py_ec"
  fi
  if [[ ! -f "$result_file" ]]; then
    echo "REFUSED: non-test launch produced no result file" >&2
    return 2
  fi
  return 0
}
