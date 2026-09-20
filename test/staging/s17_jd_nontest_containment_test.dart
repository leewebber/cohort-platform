import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;
  final helper = '$root/tool/staging/lib/s17_jd_nontest_containment.py';
  final launcher = '$root/tool/staging/lib/s17_jd_nontest_launch.sh';

  test('same process group must not be killpg targets', () async {
    final result = await Process.run('python3', [
      '-c',
      '''
import sys
sys.path.insert(0, r"$root/tool/staging/lib")
from s17_jd_nontest_containment import should_signal_process_group
assert should_signal_process_group(100, 100) is False
assert should_signal_process_group(100, 200) is True
print("PGID_GUARD_OK")
''',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout.toString(), contains('PGID_GUARD_OK'));
  });

  test('ok:true result wins over waiter SIGTERM exit codes', () async {
    final result = await Process.run('python3', [
      '-c',
      '''
import sys
sys.path.insert(0, r"$root/tool/staging/lib")
from s17_jd_nontest_containment import launcher_exit_after_waiter
assert launcher_exit_after_waiter(143, True) == 0
assert launcher_exit_after_waiter(15, True) == 0
assert launcher_exit_after_waiter(2, True) == 0
assert launcher_exit_after_waiter(143, False) == 143
assert launcher_exit_after_waiter(0, False) == 2
print("OK_TRUE_WINS")
''',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout.toString(), contains('OK_TRUE_WINS'));
  });

  test('launcher sources containment helper and guards shared process groups', () {
    expect(File(helper).existsSync(), isTrue);
    final src = File(launcher).readAsStringSync();
    expect(src, contains('s17_jd_nontest_containment'));
    expect(src, contains('should_signal_process_group'));
    expect(src, contains('Successful result wins over waiter SIGTERM'));
    expect(src, isNot(contains('os.killpg(run_pid, signal.SIGTERM)')));
  });
}
