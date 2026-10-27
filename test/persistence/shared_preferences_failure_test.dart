import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native preference refusal fails save/removal instead of reporting success',
    () async {
      var accepted = false;
      const channel = MethodChannel('plugins.flutter.io/shared_preferences');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') return <String, Object>{};
      if (call.method == 'setString' || call.method == 'remove') {
          return accepted;
      }
        throw StateError('Unexpected preference operation');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final store = await SharedPreferencesKvStore.create();
      await expectLater(
        store.writeString('timer', 'checkpoint'),
        throwsStateError,
      );
      await expectLater(store.remove('timer'), throwsStateError);
      accepted = true;
      await store.writeString('timer', 'checkpoint');
      expect(await store.readString('timer'), 'checkpoint');
      await store.remove('timer');
    },
  );
}
