import 'dart:js_interop';

@JS('globalThis.addEventListener')
external void _addEventListener(String type, JSFunction listener);
@JS('globalThis.removeEventListener')
external void _removeEventListener(String type, JSFunction listener);

extension type _BeforeUnload(JSObject _) implements JSObject {
  external void preventDefault();
  external set returnValue(String value);
}

/// Browsers choose whether to display their generic leave-page prompt. This
/// provides no recovery/storage and deliberately makes no delivery guarantee.
void Function() watchUnsavedReload(bool Function() hasChanges) {
  final listener = ((JSObject event) {
    if (hasChanges()) {
      final unload = _BeforeUnload(event);
      unload.preventDefault();
      unload.returnValue = '';
    }
  }).toJS;
  _addEventListener('beforeunload', listener);
  return () => _removeEventListener('beforeunload', listener);
}
