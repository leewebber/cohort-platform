import 'package:flutter/material.dart';

/// Shared interaction constraints for production Daily Journey controls.
abstract final class JourneyInteraction {
  static const double minTapSize = 48;
  static const double minPrimaryHeight = 54;
  static const Duration duplicateActionLock = Duration(milliseconds: 800);
}

class JourneyOnceTap {
  JourneyOnceTap();

  var _busy = false;

  bool tryAcquire() {
    if (_busy) return false;
    _busy = true;
    return true;
  }

  void releaseNextFrame(VoidCallback onReleased) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _busy = false;
      onReleased();
    });
  }
}

class JourneyMinTap extends StatelessWidget {
  const JourneyMinTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: JourneyInteraction.minTapSize,
        minHeight: JourneyInteraction.minTapSize,
      ),
      child: child,
    );
  }
}
