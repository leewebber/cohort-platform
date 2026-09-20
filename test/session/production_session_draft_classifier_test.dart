import 'package:cohort_platform/features/session/models/production_session_draft.dart';
import 'package:cohort_platform/features/session/services/production_session_draft_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const classifier = ProductionSessionDraftClassifier();
  const authority = ProductionSessionDraftAuthority(
    athleteId: 'athlete-1',
    assignmentId: 'assign-1',
    programmeVersionId: 'ver-1',
    programmedSessionKey: 'key-1',
    occurrenceId: 'occ-1',
  );

  ProductionSessionDraft draft({
    String athleteId = 'athlete-1',
    String assignmentId = 'assign-1',
    String programmeVersionId = 'ver-1',
    String programmedSessionKey = 'key-1',
    String? occurrenceId = 'occ-1',
    int schemaVersion = 1,
    int trainingSessionId = 9,
  }) {
    return ProductionSessionDraft(
      schemaVersion: schemaVersion,
      athleteId: athleteId,
      assignmentId: assignmentId,
      programmeVersionId: programmeVersionId,
      programmedSessionKey: programmedSessionKey,
      packageContentHash: 'a' * 64,
      trainingSessionId: trainingSessionId,
      entryMode: 'live',
      occurrenceId: occurrenceId,
    );
  }

  test('compatible draft may restore', () {
    final value = classifier.classify(draft: draft(), authority: authority);
    expect(value, ProductionDraftRestoreClass.compatible);
    expect(classifier.mayRestore(value), isTrue);
  });

  test('foreign athlete is rejected', () {
    expect(
      classifier.classify(
        draft: draft(athleteId: 'other'),
        authority: authority,
      ),
      ProductionDraftRestoreClass.foreignAthlete,
    );
  });

  test('stale programme version is rejected', () {
    expect(
      classifier.classify(
        draft: draft(programmeVersionId: 'ver-old'),
        authority: authority,
      ),
      ProductionDraftRestoreClass.staleProgrammeVersion,
    );
  });

  test('stale occurrence is rejected', () {
    expect(
      classifier.classify(
        draft: draft(occurrenceId: 'occ-old'),
        authority: authority,
      ),
      ProductionDraftRestoreClass.staleOccurrence,
    );
  });

  test('completed hosted wins', () {
    expect(
      classifier.classify(
        draft: draft(),
        authority: ProductionSessionDraftAuthority(
          athleteId: 'athlete-1',
          assignmentId: 'assign-1',
          programmeVersionId: 'ver-1',
          programmedSessionKey: 'key-1',
          hostedCompleted: true,
        ),
      ),
      ProductionDraftRestoreClass.completedHosted,
    );
  });

  test('corrupt json is rejected', () {
    expect(
      classifier.classify(
        draft: draft(),
        authority: authority,
        jsonCorrupt: true,
      ),
      ProductionDraftRestoreClass.corrupt,
    );
  });

  test('future schema is unsupported', () {
    expect(
      classifier.classify(draft: draft(schemaVersion: 99), authority: authority),
      ProductionDraftRestoreClass.unsupportedFutureVersion,
    );
  });

  test('legacy missing identity is partial', () {
    expect(
      classifier.classify(
        draft: draft(schemaVersion: 0, trainingSessionId: 0),
        authority: authority,
      ),
      ProductionDraftRestoreClass.legacyPartial,
    );
  });

  test('draft json round-trips identity', () {
    final original = draft();
    final restored = ProductionSessionDraft.fromJson(original.toJson());
    expect(restored.athleteId, original.athleteId);
    expect(restored.packageContentHash, original.packageContentHash);
    expect(restored.trainingSessionId, original.trainingSessionId);
  });
}
