import 'dart:io';

/// Thin CLI wrapper — not the supported production launcher.
///
/// Supported path: `tool/staging/run_s17_journey_d_live_dart.sh` which invokes
/// the non-test Flutter executable (`flutter run --no-pub`) for hosted mode.
///
/// `dart run` of this file used to crash during FFI NativeCallable compilation
/// on the Flutter-bound graph. Newer Dart SDKs can hang in that compile
/// instead of exiting. The wrapper therefore fails closed immediately and
/// never imports the Flutter-bound Journey D entrypoint.
Future<void> main(List<String> args) async {
  stderr.writeln(
    'Crash when compiling: dart run tool/staging/bin/create_s17_journey_d_live.dart '
    'is not supported. NativeCallable / Flutter-bound orchestration is '
    'unreachable from this boundary. Use '
    'tool/staging/run_s17_journey_d_live_dart.sh.',
  );
  exit(64);
}
