import 'dart:typed_data';

void downloadEditableWorkspace(String text) =>
    throw UnsupportedError('Use the Chrome preview for workspace files.');
Future<String?> chooseEditableWorkspace() async =>
    throw UnsupportedError('Use the Chrome preview for workspace files.');

Future<Uint8List?> chooseCanonicalSources() async => throw UnsupportedError(
  'Use the Chrome preview for canonical source archives.',
);
