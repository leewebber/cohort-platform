#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

Future<void> main(List<String> args) async {
  final root = _workspaceRoot();
  final forwardedArgs = args
      .map(
        (argument) =>
            argument == '--dry-run' ? argument : File(argument).absolute.path,
      )
      .toList(growable: false);
  final process = await Process.start(
    Platform.resolvedExecutable,
    ['run', 'tool/import_programme.dart', ...forwardedArgs],
    workingDirectory: root.path,
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
}

Directory _workspaceRoot() {
  var directory = Directory.current.absolute;
  while (directory.parent.path != directory.path) {
    final entrypoint = File('${directory.path}/tool/import_programme.dart');
    final package = File('${directory.path}/pubspec.yaml');
    if (entrypoint.existsSync() && package.existsSync()) return directory;
    directory = directory.parent;
  }
  throw StateError('Could not locate Cohort Platform workspace root.');
}
