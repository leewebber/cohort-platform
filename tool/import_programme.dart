#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) {
  print(
    'Founder Programme Importer moved to pure-Dart package.\n'
    'Run from tool/importer:\n'
    '  cd tool/importer\n'
    '  dart run bin/import_programme.dart ${args.join(' ')}'.trim(),
  );
  exitCode = 64;
}
