import 'dart:async';

import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/screens/session_finish_review_screen.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/m8_modern_capture_test_fixtures.dart';

class _DelayedSaveCoordinator extends PerformanceRecordSaveCoordinator {
  _DelayedSaveCoordinator(this.gate);

  final Completer<void> gate;
  int calls = 0;

  @override
  Future<PerformanceCompletionResult> completeSession({
    required controller,
    required int trainingSessionId,
    required String athleteId,
    programmeContext,
    forcedStatus,
    String? idempotencyKey,
  }) async {
    calls++;
    await gate.future;
    return PerformanceCompletionResult(
      record: const PerformanceRecordMapper().fromDraft(
        controller.buildPersistableDraft(
          status: controller.resolveCompletionStatus(),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'SessionFinishReviewScreen prevents a second save while pending',
    (tester) async {
      final plan = M8ModernCaptureTestFixtures.singleBlockPlan();
      final performance = M8ModernCaptureTestFixtures.performanceController(
        plan,
      )..markBlockComplete(plan.blocks.single.blockId);
      final gate = Completer<void>();
      final coordinator = _DelayedSaveCoordinator(gate);

      await tester.pumpWidget(
        MaterialApp(
          home: SessionFinishReviewScreen(
            performanceController: performance,
            executionController:
                M8ModernCaptureTestFixtures.executionController(plan),
            trainingSessionId: 9001,
            athleteId: 'founder-test-athlete',
            saveCoordinator: coordinator,
          ),
        ),
      );

      await tester.tap(find.text('Save and finish'));
      await tester.pump();
      await tester.tap(find.text('Save and finish'));
      await tester.pump();

      expect(coordinator.calls, 1);
      gate.complete();
      await tester.pumpAndSettle();
    },
  );
}
