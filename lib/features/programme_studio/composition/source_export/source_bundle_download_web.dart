import 'dart:convert';
import 'dart:js_interop';

import 'canonical_source_bundle.dart';

@JS('document.createElement')
external _DownloadAnchor _createElement(String tag);
@JS('document.body.appendChild')
external JSObject _appendChild(JSObject child);

extension type _DownloadAnchor(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
  external void remove();
}

void downloadSourceBundle(CanonicalSourceBundle bundle) {
  final anchor = _createElement('a')
    ..href =
        'data:application/x-tar;base64,${base64Encode(bundle.archiveBytes)}'
    ..download = bundle.filename;
  _appendChild(anchor);
  try {
    anchor.click();
  } finally {
    anchor.remove();
  }
}
