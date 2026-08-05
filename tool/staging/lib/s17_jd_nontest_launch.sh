# Shared non-test Flutter launch for Journey D create/execute.
# Requires: S17_ROOT, result env var name, target dart library.
# Uses flutter run --no-pub on a desktop/web device; waits for result file.
# Flutter logs and progress survive under S17_JD_FLUTTER_LOG_DIR when set.

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

  local device="${S17_JD_FLUTTER_DEVICE:-macos}"
  # Inner containment only — stage deadlines must finish well before this.
  local timeout_sec="${S17_JD_NONTEST_TIMEOUT_SEC:-540}"
  local grace_sec="${S17_JD_NONTEST_TERMINATE_GRACE_SEC:-15}"
  local log_dir="${S17_JD_FLUTTER_LOG_DIR:-}"
  if [[ -z "$log_dir" ]]; then
    log_dir="$(dirname "$result_file")"
  fi
  mkdir -p "$log_dir"
  local stdout_log="${log_dir}/nontest_${surface}_flutter_stdout.txt"
  local stderr_log="${log_dir}/nontest_${surface}_flutter_stderr.txt"
  local progress_file="${S17_JD_PROGRESS_FILE:-${result_file}.progress.json}"
  export S17_JD_PROGRESS_FILE="$progress_file"

  rm -f "$result_file"
  echo "JD_NONTEST_RUNTIME=flutter_run device=${device} target=${target_lib}"
  echo "JD_NONTEST_LOG_DIR=${log_dir}"
  echo "JD_NONTEST_PROGRESS_FILE=${progress_file}"

  set +e
  set -m
  (
    cd "$S17_ROOT"
    flutter run -d "$device" -t "$target_lib" --no-pub
  ) >"$stdout_log" 2>"$stderr_log" &
  local run_pid=$!
  set +m

  python3 - "$result_file" "$run_pid" "$timeout_sec" "$grace_sec" "$stdout_log" "$stderr_log" "$progress_file" "$surface" <<'PY'
import json, os, pathlib, signal, sys, time

result = pathlib.Path(sys.argv[1])
run_pid = int(sys.argv[2])
deadline = time.time() + int(sys.argv[3])
grace = int(sys.argv[4])
stdout_log = pathlib.Path(sys.argv[5])
stderr_log = pathlib.Path(sys.argv[6])
progress = pathlib.Path(sys.argv[7])
surface = sys.argv[8]

def terminate():
    # Kill process group when possible so nested flutter/engine children die.
    try:
        os.killpg(run_pid, signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
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
        os.killpg(run_pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        try:
            os.kill(run_pid, signal.SIGKILL)
        except ProcessLookupError:
            return

def write_terminal_from_progress(reason: str, code: int):
    payload = {
        "ok": False,
        "classification": "B4D21D1_LAUNCHER_CONTAINMENT_TIMEOUT"
        if reason == "timeout"
        else "B4D21D1_LAUNCHER_PROCESS_DIED",
        "detail": reason,
        "surface": surface,
        "reached_main": False,
        "ports_mode": "hosted",
        "hosted_writes_executed": 0,
        "further_mutation_prohibited": True,
        "progress_file": str(progress),
    }
    if progress.is_file():
        try:
            prog = json.loads(progress.read_text())
            payload["current_stage"] = prog.get("current_stage")
            payload["current_status"] = prog.get("current_status")
            payload["marker"] = prog.get("marker") or prog.get("fixture_marker")
            payload["fixture_marker"] = payload.get("marker")
            payload["hosted_writes_executed"] = prog.get(
                "hosted_writes_executed", 0
            )
            stages = prog.get("stages")
            if isinstance(stages, list):
                payload["stages"] = stages
            # If a request may have been dispatched, force uncertain.
            if prog.get("request_dispatched") is True or prog.get(
                "current_status"
            ) in ("in_progress", "outcome_uncertain"):
                payload["classification"] = "B4D21D1_CREATE_OUTCOME_UNCERTAIN"
                payload["current_status"] = "outcome_uncertain"
        except Exception:
            pass
    if not result.is_file():
        result.write_text(json.dumps(payload, indent=2))
        try:
            progress.write_text(
                json.dumps({**payload, "terminal": True}, indent=2)
            )
        except Exception:
            pass
    return code

def exit_code_from_result():
    """Propagate create/execute failure; never treat ok:false as success."""
    try:
        data = json.loads(result.read_text())
        if data.get("ok") is True:
            return 0
        return 2
    except Exception:
        return 2

while time.time() < deadline:
    if result.is_file() and result.stat().st_size > 0:
        time.sleep(0.3)
        terminate()
        # Confirm flutter tree is gone.
        dead = False
        end = time.time() + grace
        while time.time() < end:
            try:
                os.kill(run_pid, 0)
            except ProcessLookupError:
                dead = True
                break
            time.sleep(0.1)
        if not dead:
            terminate()
        sys.exit(exit_code_from_result())
    try:
        os.kill(run_pid, 0)
    except ProcessLookupError:
        if result.is_file() and result.stat().st_size > 0:
            sys.exit(exit_code_from_result())
        print(
            "REFUSED: non-test flutter process exited before result file "
            f"stdout={stdout_log} stderr={stderr_log} progress={progress}",
            file=sys.stderr,
        )
        sys.exit(write_terminal_from_progress("process_died", 2))
    for log in (stdout_log, stderr_log):
        if log.exists() and "Resolving dependencies..." in log.read_text(
            errors="replace"
        ):
            print(
                "REFUSED: non-test flutter began dependency resolution (--no-pub required)",
                file=sys.stderr,
            )
            terminate()
            sys.exit(write_terminal_from_progress("dependency_resolution", 2))
    time.sleep(0.4)

print(
    f"REFUSED: timed out waiting for result file {result} progress={progress}",
    file=sys.stderr,
)
terminate()
sys.exit(write_terminal_from_progress("timeout", 3))
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
  # Honour terminal result ok flag for shell callers / Python outer.
  if ! python3 - "$result_file" <<'PY'
import json, sys
from pathlib import Path
try:
    ok = json.loads(Path(sys.argv[1]).read_text()).get("ok") is True
except Exception:
    ok = False
sys.exit(0 if ok else 2)
PY
  then
    return 2
  fi
  return 0
}
