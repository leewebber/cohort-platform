import 'package:cohort_platform/features/performance/models/active_performance_draft.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/session/models/production_restore_outcome.dart';
import 'package:cohort_platform/features/session/models/production_session_draft.dart';
import 'package:cohort_platform/features/session/models/production_session_ui_cursor.dart';
import 'package:cohort_platform/features/session/presentation/production_restore_athlete_copy.dart';
import 'package:cohort_platform/features/session/services/production_restore_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = ProductionRestoreResolver();

  ProductionRestoreRequest request({
    ProductionSessionDraft? identity,
    ActivePerformanceDraft? actuals,
    ProductionSessionUiCursor? cursor,
    bool hostedCompleted = false,
    bool unavailable = false,
    bool transientNetworkFailure = false,
    bool jsonCorrupt = false,
    String athleteId = 'athlete-1',
    String assignmentId = 'assign-1',
    String programmeVersionId = 'ver-1',
  }) {
    return ProductionRestoreRequest(
      athleteId: athleteId,
      assignmentId: assignmentId,
      programmeVersionId: programmeVersionId,
      programmedSessionKey: 'key-1',
      packageContentHash: 'a' * 64,
      occurrenceId: 'occ-1',
      trainingSessionId: 9,
      hostedCompleted: hostedCompleted,
      unavailable: unavailable,
      transientNetworkFailure: transientNetworkFailure,
      jsonCorrupt: jsonCorrupt,
      persistedIdentity: identity,
      actuals: actuals,
      cursor: cursor,
    );
  }

  ProductionSessionDraft identity({
    String athleteId = 'athlete-1',
    int schemaVersion = 1,
    int trainingSessionId = 9,
  }) {
    return ProductionSessionDraft(
      schemaVersion: schemaVersion,
      athleteId: athleteId,
      assignmentId: 'assign-1',
      programmeVersionId: 'ver-1',
      programmedSessionKey: 'key-1',
      packageContentHash: 'a' * 64,
      trainingSessionId: trainingSessionId,
      entryMode: 'live',
      occurrenceId: 'occ-1',
    );
  }

  ActivePerformanceDraft actuals({
    String athleteId = 'athlete-1',
    String? assignmentId = 'assign-1',
    String? programmeId = 'ver-1',
    int trainingSessionId = 9,
  }) {
    return ActivePerformanceDraft(
      recordId: 'rec-1',
      athleteId: athleteId,
      trainingSessionId: trainingSessionId,
      sourceProtocolId: 'protocol-1',
      sessionSnapshot: const SessionPerformanceSnapshot(
        sourceProtocolId: 'protocol-1',
        sessionTitle: 'Session',
      ),
      status: TrainingSessionRecordStatus.inProgress,
      startedAt: DateTime.utc(2026, 9, 20),
      assignmentId: assignmentId,
      programmeId: programmeId,
    );
  }

  test('no draft may begin fresh and memory cannot authorize', () {
    final decision = resolver.resolve(request());
    expect(decision.outcome, ProductionRestoreOutcome.noDraft);
    expect(decision.mayBeginFresh, isTrue);
    expect(decision.mayEnterWithRestoredActuals, isFalse);
  });

  test('compatible identity plus actuals is resumable', () {
    final decision = resolver.resolve(
      request(identity: identity(), actuals: actuals()),
    );
    expect(decision.outcome, ProductionRestoreOutcome.resumable);
    expect(decision.mayEnterWithRestoredActuals, isTrue);
  });

  test('hosted completion wins over local draft', () {
    final decision = resolver.resolve(
      request(
        identity: identity(),
        actuals: actuals(),
        hostedCompleted: true,
      ),
    );
    expect(decision.outcome, ProductionRestoreOutcome.completedHosted);
    expect(decision.mayEnterWithRestoredActuals, isFalse);
  });

  test('foreign athlete is rejected', () {
    final decision = resolver.resolve(
      request(identity: identity(athleteId: 'other'), actuals: actuals()),
    );
    expect(decision.outcome, ProductionRestoreOutcome.foreignAthlete);
    expect(
      decision.athleteMessage,
      ProductionRestoreAthleteCopy.foreignAthleteTitle,
    );
    expect(decision.athleteMessage, isNot(contains('Sign in required')));
  });

  test('foreign actuals are rejected even without identity', () {
    final decision = resolver.resolve(
      request(actuals: actuals(athleteId: 'other')),
    );
    expect(decision.outcome, ProductionRestoreOutcome.foreignAthlete);
  });

  test('stale programme version is rejected', () {
    final decision = resolver.resolve(
      request(actuals: actuals(programmeId: 'old-ver')),
    );
    expect(decision.outcome, ProductionRestoreOutcome.staleProgrammeVersion);
  });

  test('stale assignment is rejected', () {
    final decision = resolver.resolve(
      request(actuals: actuals(assignmentId: 'old-assign')),
    );
    expect(decision.outcome, ProductionRestoreOutcome.staleOccurrence);
  });

  test('corrupt json is rejected', () {
    expect(
      resolver.resolve(request(jsonCorrupt: true)).outcome,
      ProductionRestoreOutcome.corrupt,
    );
  });

  test('unavailable format fails closed', () {
    expect(
      resolver.resolve(request(unavailable: true)).outcome,
      ProductionRestoreOutcome.unavailable,
    );
  });

  test('transient network without draft stays pending', () {
    expect(
      resolver
          .resolve(request(transientNetworkFailure: true))
          .outcome,
      ProductionRestoreOutcome.transientFailure,
    );
  });

  test('training session conflict is rejected', () {
    expect(
      resolver
          .resolve(request(actuals: actuals(trainingSessionId: 99)))
          .outcome,
      ProductionRestoreOutcome.conflict,
    );
  });

  test('unsupported identity version still restores matching actuals', () {
    final decision = resolver.resolve(
      request(identity: identity(schemaVersion: 99), actuals: actuals()),
    );
    expect(decision.outcome, ProductionRestoreOutcome.unsupportedVersion);
    expect(decision.mayEnterWithRestoredActuals, isTrue);
    expect(decision.restoreCursor, isFalse);
  });

  test('legacy synthesized identity is partially recoverable', () {
    final decision = resolver.resolve(request(actuals: actuals()));
    expect(
      decision.outcome,
      ProductionRestoreOutcome.legacyPartiallyRecoverable,
    );
    expect(decision.mayEnterWithRestoredActuals, isTrue);
  });

  test('unsupported cursor version does not block actuals', () {
    final decision = resolver.resolve(
      request(
        identity: identity(),
        actuals: actuals(),
        cursor: const ProductionSessionUiCursor(
          schemaVersion: 99,
          athleteId: 'athlete-1',
          assignmentId: 'assign-1',
          trainingSessionId: 9,
          activeBlockId: 'block-2',
        ),
      ),
    );
    expect(decision.mayEnterWithRestoredActuals, isTrue);
    expect(decision.restoreCursor, isFalse);
    expect(decision.cursor, isNull);
  });

  test('valid cursor is restored', () {
    const cursor = ProductionSessionUiCursor(
      schemaVersion: 1,
      athleteId: 'athlete-1',
      assignmentId: 'assign-1',
      trainingSessionId: 9,
      occurrenceId: 'occ-1',
      activeBlockId: 'block-2',
      expandedBlockIds: {'block-2'},
    );
    final decision = resolver.resolve(
      request(identity: identity(), actuals: actuals(), cursor: cursor),
    );
    expect(decision.restoreCursor, isTrue);
    expect(decision.cursor?.activeBlockId, 'block-2');
  });

  test('foreign cursor is ignored', () {
    final decision = resolver.resolve(
      request(
        identity: identity(),
        actuals: actuals(),
        cursor: const ProductionSessionUiCursor(
          schemaVersion: 1,
          athleteId: 'other',
          assignmentId: 'assign-1',
          trainingSessionId: 9,
        ),
      ),
    );
    expect(decision.restoreCursor, isFalse);
  });
}
