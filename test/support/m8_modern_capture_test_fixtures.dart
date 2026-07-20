import 'package:cohort_platform/features/founder_acceptance/founder_acceptance_content.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/active_performance_draft.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';

class M8ModernCaptureTestFixtures {
  const M8ModernCaptureTestFixtures._();

  static SessionExecutionPlan singleBlockPlan() {
    return FounderAcceptanceContent.executionPlan(singleBlock: true);
  }

  static SessionExecutionPlan fullCapturePlan() {
    return FounderAcceptanceContent.executionPlan();
  }

  static SessionExecutionController executionController(
    SessionExecutionPlan plan,
  ) {
    return SessionExecutionController(
      plan: plan,
      sessionKey: 'm8-fixture:${plan.sessionId}',
      memoryStore: AthleteSessionMemoryStore.instance,
    );
  }

  static PerformanceCaptureController performanceController(
    SessionExecutionPlan plan,
  ) {
    return PerformanceCaptureController.initializeFromExecutionPlan(
      plan: plan,
      athleteId: 'founder-test-athlete',
      trainingSessionId: 9001,
    );
  }

  static BlockPerformanceDraft completionBlockDraft() {
    final controller = performanceController(singleBlockPlan());
    return controller.draft.blockDrafts.first;
  }
}
