import 'package:flutter/material.dart';

/// Bridges [StrengthSessionView] leave behaviour to [SessionPlayerScreen].
class StrengthSessionLeaveCoordinator {
  const StrengthSessionLeaveCoordinator({
    required this.hasRecordedProgress,
    required this.confirmLeave,
  });

  final bool Function() hasRecordedProgress;
  final Future<void> Function(BuildContext context) confirmLeave;
}
