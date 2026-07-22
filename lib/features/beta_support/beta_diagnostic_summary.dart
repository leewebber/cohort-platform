import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../auth/services/current_user_session.dart';
import '../../core/constants/app_version.dart';

class BetaDiagnosticSummary {
  const BetaDiagnosticSummary({
    required this.appVersion,
    required this.platform,
    required this.isCoach,
    required this.isAthlete,
    required this.hasActiveAssignment,
    required this.screenContext,
    required this.lastOperation,
  });

  final String appVersion;
  final String platform;
  final bool isCoach;
  final bool isAthlete;
  final bool? hasActiveAssignment;
  final String? screenContext;
  final String? lastOperation;

  String format() {
    final lines = <String>[
      'Cohort beta diagnostic summary',
      'App version: $appVersion',
      'Platform: $platform',
      'Coach role: $isCoach',
      'Athlete role: $isAthlete',
      if (hasActiveAssignment != null)
        'Active assignment: $hasActiveAssignment',
      if (screenContext != null && screenContext!.trim().isNotEmpty)
        'Screen: $screenContext',
      if (lastOperation != null && lastOperation!.trim().isNotEmpty)
        'Last operation: $lastOperation',
    ];
    return lines.join('\n');
  }

  static String reportTemplate({String? issueDescription}) {
    final summary = build(
      screenContext: 'Beta support',
      lastOperation: issueDescription,
    );
    return '${summary.format()}\n\nDescribe what happened:\n'
        '${issueDescription ?? ''}';
  }

  static BetaDiagnosticSummary build({
    String? screenContext,
    String? lastOperation,
    bool? hasActiveAssignment,
  }) {
    final session = CurrentUserSession.maybeInstance;
    return BetaDiagnosticSummary(
      appVersion: AppVersion.label,
      platform: _platformLabel(),
      isCoach: session?.isCoach ?? false,
      isAthlete: session?.isAthlete ?? false,
      hasActiveAssignment: hasActiveAssignment,
      screenContext: screenContext,
      lastOperation: lastOperation,
    );
  }

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
  }
}

class BetaSupportActions {
  BetaSupportActions._();

  static Future<void> copyDiagnosticSummary({
    String? screenContext,
    String? lastOperation,
    bool? hasActiveAssignment,
  }) async {
    final summary = BetaDiagnosticSummary.build(
      screenContext: screenContext,
      lastOperation: lastOperation,
      hasActiveAssignment: hasActiveAssignment,
    );
    await Clipboard.setData(ClipboardData(text: summary.format()));
  }

  static Future<void> copyReportTemplate({
    String? screenContext,
    String? issueDescription,
  }) async {
    await Clipboard.setData(
      ClipboardData(
        text: BetaDiagnosticSummary.reportTemplate(
          issueDescription: issueDescription,
        ),
      ),
    );
  }
}
