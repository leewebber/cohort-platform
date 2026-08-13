import 'dart:async';

import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/screens/session_finish_review_screen.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/programme/models/athlete_programme_completion.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/session/models/session_execution_status.dart';
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

class _RetrySaveCoordinator extends PerformanceRecordSaveCoordinator {
  int calls = 0;
  final List<String?> idempotencyKeys = [];

  @override
  Future<PerformanceCompletionResult> completeSession({
    required PerformanceCaptureController controller,
    required int trainingSessionId,
    required String athleteId,
    ProgrammeExecutionContext? programmeContext,
    forcedStatus,
    String? idempotencyKey,
  }) async {
    calls++;
    idempotencyKeys.add(idempotencyKey);
    final record = const PerformanceRecordMapper().fromDraft(
      controller.buildPersistableDraft(
        status: controller.resolveCompletionStatus(),
      ),
    );
    if (calls == 1) {
      return PerformanceCompletionResult(
        record: record,
        progressionFailed: true,
        progressionMessage: 'Network uncertain',
        programmeCompletion: const AthleteProgrammeCompletionResult(
          status: AthleteProgrammeCompletionStatus.networkUncertain,
          code: 'network_uncertain',
        ),
      );
    }
    return PerformanceCompletionResult(
      record: record,
      programmeCompletion: AthleteProgrammeCompletionResult(
        status: AthleteProgrammeCompletionStatus.alreadyCommitted,
        code: 'idempotent_replay',
        record: record,
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

  testWidgets(
    'programme completion failure stays active, visible, and retries same identity',
    (tester) async {
      final plan = M8ModernCaptureTestFixtures.singleBlockPlan();
      final performance = M8ModernCaptureTestFixtures.performanceController(
        plan,
      )..markBlockComplete(plan.blocks.single.blockId);
      final execution = M8ModernCaptureTestFixtures.executionController(plan)
        ..startSession()
        ..markBlockComplete(plan.blocks.single.blockId);
      final coordinator = _RetrySaveCoordinator();

      await tester.pumpWidget(
        MaterialApp(
          home: SessionFinishReviewScreen(
            performanceController: performance,
            executionController: execution,
            trainingSessionId: 9001,
            athleteId: 'founder-test-athlete',
            programmeContext: _programmeContext(),
            saveCoordinator: coordinator,
          ),
        ),
      );

      await tester.tap(find.text('Save and finish'));
      await tester.pumpAndSettle();

      expect(find.textContaining('still confirming'), findsOneWidget);
      expect(execution.state.sessionStatus, SessionExecutionStatus.inProgress);
      expect(find.text('SESSION COMPLETE'), findsNothing);

      await tester.tap(find.text('Save and finish'));
      await tester.pumpAndSettle();

      expect(coordinator.calls, 2);
      expect(coordinator.idempotencyKeys[0], isNotNull);
      expect(coordinator.idempotencyKeys[1], coordinator.idempotencyKeys[0]);
      expect(execution.state.sessionStatus, SessionExecutionStatus.completed);
      expect(find.text('SESSION COMPLETE'), findsOneWidget);
    },
  );
}

ProgrammeExecutionContext _programmeContext() {
  return const ProgrammeExecutionContext(
    assignmentId: 'assignment-1',
    programmeVersionId: 'version-1',
    sessionSlotId: 'slot-1',
    weekNumber: 1,
    dayKey: 'day_1',
    sessionOrder: 1,
    plannedProtocolId: 'protocol-1',
    effectiveProtocolId: 'protocol-1',
    packageContentHash:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    programmedSessionKey: 'prog:assignment-1@version-1:w1:day_1:s1:protocol-1',
  );
}
