import 'package:cohort_platform/core/services/user_session_cache.dart';
import 'package:cohort_platform/features/programme/debug/programme_debug_resolution_cache.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/active_session_state.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/session_execution_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserSessionCache.clearAll clears debug resolution and session memory',
      () {
    ProgrammeDebugResolutionCache.store(
      const ResolvedTodaySession(
        kind: ResolvedTodaySessionKind.executable,
        weekNumber: 1,
        dayKey: 'day_1',
      ),
    );

    AthleteSessionMemoryStore.instance.write(
      ActiveSessionState(
        sessionKey: '1:BW-001',
        plan: SessionExecutionPlan(
          sessionId: 'BW-001',
          sessionTitle: 'Test',
          blocks: const [],
        ),
        blockStates: const [],
        activeBlockIndex: 0,
        completedBlockIds: const {},
        expandedBlockIds: const {},
        sessionStatus: SessionExecutionStatus.inProgress,
      ),
    );

    UserSessionCache.clearAll();

    expect(ProgrammeDebugResolutionCache.lastResolution, isNull);
    expect(AthleteSessionMemoryStore.instance.read('1:BW-001'), isNull);
  });
}
