import 'package:flutter/widgets.dart';

typedef HomeTodaySessionRefreshCallback =
    void Function({required String source});

typedef AthleteProgrammeSurfaceReload =
    Future<void> Function({required String source});

/// Lightweight refresh trigger owned by [HomeScreen] / the athlete shell.
///
/// Today-card listeners stay fire-and-forget. Surface listeners await the
/// authoritative calendar / Home / programme reload after a committed swap or
/// completion so sibling tabs cannot keep stale occurrence state.
class HomeTodaySessionRefreshController {
  final Map<Object, HomeTodaySessionRefreshCallback> _listeners = {};
  final Map<Object, AthleteProgrammeSurfaceReload> _surfaceReloads = {};

  /// Binds a Today section. Detach the same [owner] in [State.dispose].
  void attach(
    HomeTodaySessionRefreshCallback onRefreshRequested, {
    Object? owner,
  }) {
    _listeners[owner ?? onRefreshRequested] = onRefreshRequested;
  }

  void detach([Object? owner]) {
    if (owner != null) {
      _listeners.remove(owner);
      _listeners.removeWhere((_, callback) => identical(callback, owner));
      return;
    }
    _listeners.clear();
  }

  void attachSurface(Object owner, AthleteProgrammeSurfaceReload reload) {
    _surfaceReloads[owner] = reload;
  }

  void detachSurface(Object owner) {
    _surfaceReloads.remove(owner);
  }

  bool get hasListener => _listeners.isNotEmpty;

  bool get hasSurfaceListeners => _surfaceReloads.isNotEmpty;

  /// Requests a fresh programme resolution for every Today card.
  void requestRefresh({required String source}) {
    debugPrint(
      '[HomeRefresh] requested source=$source '
      'callbackAttached=${_listeners.isNotEmpty}',
    );
    for (final callback in List<HomeTodaySessionRefreshCallback>.from(
      _listeners.values,
    )) {
      callback(source: source);
    }
  }

  /// Reloads every attached Home / Calendar / Current Programme surface from
  /// the committed store, then refreshes the Today prepare projection.
  Future<void> reloadAuthoritativeSurfaces({required String source}) async {
    debugPrint(
      '[HomeRefresh] authoritative reload source=$source '
      'surfaces=${_surfaceReloads.length} '
      'todayAttached=${_listeners.isNotEmpty}',
    );
    final reloads = _surfaceReloads.values
        .map((reload) => reload(source: source))
        .toList(growable: false);
    await Future.wait(reloads);
  }
}

/// Makes the shell-owned refresh controller available to Calendar preview
/// and Active Session without inventing a second occurrence authority.
class AthleteProgrammeSurfaceRefreshScope extends InheritedWidget {
  const AthleteProgrammeSurfaceRefreshScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final HomeTodaySessionRefreshController controller;

  static HomeTodaySessionRefreshController? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<AthleteProgrammeSurfaceRefreshScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(AthleteProgrammeSurfaceRefreshScope oldWidget) {
    return oldWidget.controller != controller;
  }
}
