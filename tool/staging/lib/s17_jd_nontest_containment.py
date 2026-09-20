"""Process-group isolation helpers for Journey D non-test flutter run.

When `set -m` fails (non-interactive `flutter test`), the waiter and
`flutter run` share a process group. `killpg(flutter_pid)` then SIGTERMs the
waiter itself, so a successful result file is reported as launcher failure.
"""

from __future__ import annotations


def should_signal_process_group(waiter_pgid: int, child_pgid: int) -> bool:
    """True only when flutter owns a distinct process group from the waiter."""
    return child_pgid != waiter_pgid


def launcher_exit_after_waiter(py_ec: int, result_ok: bool) -> int:
    """Honour a successful result even if the waiter died during SIGTERM cleanup."""
    if result_ok:
        return 0
    if py_ec != 0:
        return py_ec
    return 2
