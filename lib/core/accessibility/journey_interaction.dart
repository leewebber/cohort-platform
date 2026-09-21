import 'package:flutter/material.dart';

/// Shared interaction constraints for production Daily Journey controls.
abstract final class JourneyInteraction {
  static const double minTapSize = 48;
  static const double minPrimaryHeight = 54;
  static const Duration duplicateActionLock = Duration(milliseconds: 800);
}

class JourneyOnceTap {
  JourneyOnceTap({this.lock = JourneyInteraction.duplicateActionLock});

  final Duration lock;
  DateTime? _last;

  bool get isLocked {
    final last = _last;
    if (last == null) return false;
    return DateTime.now().difference(last) < lock;
  }

  bool tryAcquire() {
    if (isLocked) return false;
    _last = DateTime.now();
    return true;
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
