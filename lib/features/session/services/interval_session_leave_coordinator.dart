import 'package:flutter/material.dart';

/// Bridges [IntervalSessionView] leave behaviour to [SessionPlayerScreen].
class IntervalSessionLeaveCoordinator {
  const IntervalSessionLeaveCoordinator({
    required this.hasRecordedProgress,
    required this.confirmLeave,
  });

  final bool Function() hasRecordedProgress;
  final Future<void> Function(BuildContext context) confirmLeave;
}
