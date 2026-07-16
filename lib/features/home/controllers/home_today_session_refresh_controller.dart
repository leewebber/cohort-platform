import 'package:flutter/foundation.dart';

typedef HomeTodaySessionRefreshCallback = void Function({required String source});

/// Lightweight refresh trigger owned by [HomeScreen] and attached by
/// [HomeTodaySessionSection].
class HomeTodaySessionRefreshController {
  HomeTodaySessionRefreshCallback? _onRefreshRequested;

  /// Binds the Today section state. Detach in [State.dispose].
  void attach(HomeTodaySessionRefreshCallback onRefreshRequested) {
    _onRefreshRequested = onRefreshRequested;
  }

  void detach() {
    _onRefreshRequested = null;
  }

  bool get hasListener => _onRefreshRequested != null;

  /// Requests a fresh programme resolution for the Today card.
  void requestRefresh({required String source}) {
    debugPrint(
      '[HomeRefresh] requested source=$source '
      'callbackAttached=${_onRefreshRequested != null}',
    );
    _onRefreshRequested?.call(source: source);
  }
}
