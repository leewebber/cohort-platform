import 'package:cohort_platform/core/widgets/programme_adaptation_proposal_sheet.dart';
import 'package:cohort_platform/features/adaptation/models/programme_adaptation_proposal.dart';
import 'package:cohort_platform/features/home/widgets/athlete_programme_today_section.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/programme/models/athlete_programme_prepared_session.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Adapt Session appears only for eligible prepared programme session',
      (tester) async {
    final package = _eligiblePackage();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AthleteProgrammeTodaySection(
            athleteId: 'athlete.1',
            prepareOverride: (_) async => AthleteProgrammePrepareResult(
              status: AthleteProgrammePrepareStatus.prepared,
              package: package,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adapt Session'), findsOneWidget);
    expect(find.text('Begin'), findsOneWidget);
  });

  testWidgets('Adapt Session does not appear when prepare is not ready',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AthleteProgrammeTodaySection(
            athleteId: 'athlete.1',
            prepareOverride: (_) async => const AthleteProgrammePrepareResult(
              status: AthleteProgrammePrepareStatus.notMaterialised,
              message: 'Not ready',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adapt Session'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Accept Adaptation appears only for acceptable reviewable proposal',
      (tester) async {
    final proposal = _acceptableProposal();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProgrammeAdaptationProposalSheet(proposal: proposal),
        ),
      ),
    );

    expect(find.text('Accept Adaptation'), findsOneWidget);
    expect(find.text('Keep Original Session'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('SESSION-LEVEL CHANGES'), findsOneWidget);
    expect(find.text('EXERCISE-LEVEL CHANGES'), findsOneWidget);
    expect(find.textContaining('Exercise BP-001'), findsOneWidget);
    expect(find.textContaining('Exercise ACC-001'), findsOneWidget);
  });

  testWidgets('no-safe sheet has no Accept Adaptation control', (tester) async {
    final proposal = ProgrammeAdaptationProposal(
      proposalId: 'p2',
      outcome: ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
      reason: AdaptationReason.equipment,
      programmedSessionKey: const ProgrammedSessionKey(
        planId: 'x',
        planVersion: 'v',
        week: 1,
        day: 1,
      ),
      assignmentId: 'a',
      programmeVersionId: 'v',
      packageContentHash: 'h',
      protocolId: 'proto',
      preparedAt: DateTime.utc(2026, 8, 3),
      proposedAt: DateTime.utc(2026, 8, 3),
      sessionChanges: const [],
      exerciseChanges: const [],
      preservedIntent: null,
      derivationExplanation: 'No proposal was formed.',
      athleteFacingMessage:
          'Cohort could not safely adapt this session under your current '
          'constraint. Your prescribed programme has not changed, and your '
          'current prepared session remains available.',
      noSafeReason: ProgrammeAdaptationNoSafeReason.noLawfulExerciseSubstitute,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProgrammeAdaptationProposalSheet(proposal: proposal),
        ),
      ),
    );

    expect(find.textContaining('UNABLE TO ADAPT'), findsOneWidget);
    expect(find.text('Accept Adaptation'), findsNothing);
    expect(find.text('Keep Original Session'), findsOneWidget);
  });

  testWidgets('Accept Adaptation returns true from sheet', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showProgrammeAdaptationProposalSheet(
                    context,
                    _acceptableProposal(),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final accept = find.text('Accept Adaptation');
    await tester.ensureVisible(accept);
    await tester.pumpAndSettle();
    await tester.tap(accept);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}

ProgrammeAdaptationProposal _acceptableProposal() {
  const plan = SessionExecutionPlan(
    sessionId: 'proto',
    sessionTitle: 'Strength',
    blocks: [
      SessionExecutionBlock(
        blockId: 'b1',
        title: 'Main',
        blockType: SessionBlockType.strength,
        content: 'Work',
        workoutFormat: WorkoutFormat.none,
        position: 1,
      ),
    ],
    durationMin: 40,
  );
  return ProgrammeAdaptationProposal(
    proposalId: 'p1',
    outcome: ProgrammeAdaptationProposalOutcome.reviewable,
    reason: AdaptationReason.time,
    programmedSessionKey: const ProgrammedSessionKey(
      planId: 'x',
      planVersion: 'v',
      week: 1,
      day: 1,
    ),
    assignmentId: 'a',
    programmeVersionId: 'v',
    packageContentHash: 'h',
    protocolId: 'proto',
    preparedAt: DateTime.utc(2026, 8, 3),
    proposedAt: DateTime.utc(2026, 8, 3),
    sessionChanges: const [
      ProgrammeAdaptationMaterialChange(
        scope: ProgrammeAdaptationChangeScope.session,
        targetId: 'block-1',
        actionLabel: 'removeBlock',
        summary: 'Omit optional accessory block',
        beforeValue: 'included',
        afterValue: 'omitted',
      ),
    ],
    exerciseChanges: const [
      ProgrammeAdaptationMaterialChange(
        scope: ProgrammeAdaptationChangeScope.exercise,
        targetId: 'link-1',
        actionLabel: 'reduceVolume',
        summary: 'Exercise BP-001: sets 4 → 2',
        exerciseId: 'BP-001',
        beforeValue: '4 sets',
        afterValue: '2 sets',
      ),
      ProgrammeAdaptationMaterialChange(
        scope: ProgrammeAdaptationChangeScope.exercise,
        targetId: 'link-2',
        actionLabel: 'reduceVolume',
        summary: 'Exercise ACC-001: sets 3 → 2',
        exerciseId: 'ACC-001',
        beforeValue: '3 sets',
        afterValue: '2 sets',
      ),
    ],
    preservedIntent: 'upperBodyStrength',
    derivationExplanation: 'Derived from authored prescription.',
    athleteFacingMessage: 'Review the proposed adjustments below.',
    request: const AdaptationRequest(
      reason: AdaptationReason.time,
      availableMinutes: 40,
    ),
    originalPlanFingerprint: 'original',
    reviewedExecutablePlan: plan,
    reviewedPlanFingerprint: 'reviewed',
    snapshotId: 'snap.1',
  );
}

PreparedExecutionPackage _eligiblePackage() {
  return PreparedExecutionPackage(
    programmedSessionKey: const ProgrammedSessionKey(
      planId: 'lineage',
      planVersion: 'version.1',
      week: 1,
      day: 1,
      dayKey: 'day_1',
      slotOrder: 1,
      protocolId: 'proto.1',
      programmeAssignmentId: 'assignment.1',
      packageContentHash: 'hash.1',
    ),
    plan: const SessionExecutionPlan(
      sessionId: 'proto.1',
      sessionTitle: 'Strength A',
      blocks: [
        SessionExecutionBlock(
          blockId: 'b1',
          title: 'Main',
          blockType: SessionBlockType.strength,
          content: 'Work',
          workoutFormat: WorkoutFormat.none,
          position: 1,
        ),
      ],
    ),
    brief: const WorkoutSessionBrief(
      sessionName: 'Strength A',
      estimatedDurationMinutes: 60,
    ),
    preparedAt: DateTime.utc(2026, 8, 3),
    assignmentId: 'assignment.1',
    programmeVersionId: 'version.1',
    packageContentHash: 'hash.1',
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: 'proto.1',
  );
}
