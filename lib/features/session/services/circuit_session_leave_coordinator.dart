import 'package:flutter/material.dart';

/// Bridges [CircuitSessionView] leave behaviour to [SessionPlayerScreen].
class CircuitSessionLeaveCoordinator {
  const CircuitSessionLeaveCoordinator({
    required this.hasRecordedProgress,
    required this.confirmLeave,
  });

  final bool Function() hasRecordedProgress;
  final Future<void> Function(BuildContext context) confirmLeave;
}
