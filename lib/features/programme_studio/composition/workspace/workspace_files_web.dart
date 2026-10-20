import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import '../source_intake/canonical_source_intake.dart'
    show canonicalArchiveMaxBytes;
export '../../local_files/studio_json_files_web.dart';

@JS('document.createElement')
external JSObject _element(String tag);
@JS('document.body.appendChild')
external JSObject _append(JSObject child);
extension type _Picker(JSObject _) implements JSObject {
  external set type(String value);
  external set accept(String value);
  external set hidden(bool value);
  external set onchange(JSFunction? value);
  external set oncancel(JSFunction? value);
  external _PickedList? get files;
  external void click();
  external void remove();
}
extension type _PickedList(JSObject _) implements JSObject {
  external int get length;
  external _Picked? item(int index);
}
extension type _Picked(JSObject _) implements JSObject {
  external int get size;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}
Future<Uint8List?> chooseCanonicalSources() {
  final done = Completer<Uint8List?>();
  final input = _Picker(_element('input'))
    ..type = 'file'
    ..accept = '.tar'
    ..hidden = true;
  void release() {
    input.onchange = null;
    input.oncancel = null;
    input.remove();
  }

  input.oncancel = ((JSAny? _) {
    release();
    if (!done.isCompleted) done.complete(null);
  }).toJS;
  input.onchange = ((JSAny? _) {
    Future<void>(() async {
      try {
        final files = input.files;
        if (files == null || files.length != 1) {
          done.complete(null);
          return;
        }
        final file = files.item(0)!;
        if (file.size > canonicalArchiveMaxBytes) {
          throw const FormatException(
            'Canonical source archive exceeds 8 MiB.',
          );
        }
        done.complete((await file.arrayBuffer().toDart).toDart.asUint8List());
      } catch (e, st) {
        done.completeError(e, st);
      } finally {
        release();
      }
    });
  }).toJS;
  _append(input);
  try {
    input.click();
  } catch (e, st) {
    release();
    done.completeError(e, st);
  }
  return done.future;
}
