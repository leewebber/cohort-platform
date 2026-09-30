import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/spacing.dart';
import 'package:cohort_platform/core/widgets/local_preview_banner.dart';
import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/models/interval_work_result.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/screens/session_finish_review_screen.dart';
import 'package:cohort_platform/features/performance/widgets/completed_session_result_view.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/structured_running_execution.dart';
import 'package:cohort_platform/features/session/screens/structured_running_timer_screen.dart';
import 'package:cohort_platform/features/session/services/structured_running_controller.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';

/// Fixture-only B3 slice 3 preview. It is not imported by production `main`.
///
///   flutter run -d web-server --web-hostname 127.0.0.1 --web-port 4196 \
///     -t lib/main_b3_slice3_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const B3Slice3PreviewApp());
}

enum _PreviewSurface {
  calculatedWork('1 · Calculated work target'),
  recovery('2 · Recovery isolation'),
  capture('3 · Repetition capture'),
  review('4 · Review Session'),
  history('5 · History + correction'),
  unavailable('6 · Pace unavailable'),
  skipped('7 · Skipped work');

  const _PreviewSurface(this.label);
  final String label;
}

class B3Slice3PreviewApp extends StatelessWidget {
  const B3Slice3PreviewApp({super.key, this.initialSurfaceIndex = 0});

  final int initialSurfaceIndex;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: cohortTheme,
      home: _B3Slice3PreviewScreen(initialSurfaceIndex: initialSurfaceIndex),
    );
  }
}

class _B3Slice3PreviewScreen extends StatefulWidget {
  const _B3Slice3PreviewScreen({required this.initialSurfaceIndex});

  final int initialSurfaceIndex;

  @override
  State<_B3Slice3PreviewScreen> createState() => _B3Slice3PreviewScreenState();
}

class _B3Slice3PreviewScreenState extends State<_B3Slice3PreviewScreen> {
  late final _B3PreviewFixture _calculated = _B3PreviewFixture.calculated();
  late final _B3PreviewFixture _intentOnly = _B3PreviewFixture.intentOnly();
  late final PerformanceCaptureController _capture = _calculated.controller();
  late final PerformanceCaptureController _review = _calculated.controller(
    states: const [
      (state: IntervalWorkState.completed, pace: 240.0),
      (state: IntervalWorkState.paceUnavailable, pace: null),
      (state: IntervalWorkState.skipped, pace: null),
    ],
    completeBlock: true,
  );
  late TrainingSessionRecord _history = _calculated.record(
    states: const [
      (state: IntervalWorkState.completed, pace: 240.0),
      (state: IntervalWorkState.completed, pace: 243.0),
      (state: IntervalWorkState.completed, pace: 246.0),
    ],
    status: TrainingSessionRecordStatus.completed,
  );
  late final TrainingSessionRecord _skipped = _calculated.record(
    states: const [
      (state: IntervalWorkState.completed, pace: 240.0),
      (state: IntervalWorkState.paceUnavailable, pace: null),
      (state: IntervalWorkState.skipped, pace: null),
    ],
    status: TrainingSessionRecordStatus.partiallyCompleted,
  );
  late final InMemoryPerformanceRecordStore _historyStore =
      InMemoryPerformanceRecordStore()..put(_history);
  late _PreviewSurface _surface =
      _PreviewSurface.values[widget.initialSurfaceIndex.clamp(
        0,
        _PreviewSurface.values.length - 1,
      )];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LocalPreviewBanner(),
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: DropdownButtonFormField<_PreviewSurface>(
                      key: const ValueKey('b3-preview-surface'),
                      isExpanded: true,
                      initialValue: _surface,
                      decoration: const InputDecoration(
                        labelText: 'Founder review flow',
                      ),
                      items: [
                        for (final item in _PreviewSurface.values)
                          DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _surface = value);
                      },
                    ),
                  ),
                ),
                Expanded(child: _surfaceBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _surfaceBody() => switch (_surface) {
    _PreviewSurface.calculatedWork => StructuredRunningTimerScreen(
      key: const ValueKey('preview-calculated-work'),
      execution: _calculated.execution,
      onCheckpoint: (_) async => true,
    ),
    _PreviewSurface.recovery => StructuredRunningTimerScreen(
      key: const ValueKey('preview-recovery'),
      execution: _calculated.execution,
      initialCursor: _calculated.recoveryCursor(),
      onCheckpoint: (_) async => true,
    ),
    _PreviewSurface.capture => Scaffold(
      appBar: AppBar(title: const Text('Review repetitions')),
      body: ListView(
        padding: const EdgeInsets.all(CohortSpacing.lg),
        children: [
          const Text(
            'Resolve each work repetition before the block can complete.',
          ),
          const SizedBox(height: CohortSpacing.md),
          BlockResultEditor(
            blockDraft: _capture.draft.blockDrafts.single,
            onResultChanged: (result) => setState(
              () => _capture.updateBlockResultData(
                _calculated.execution.sessionBlockId,
                result,
              ),
            ),
            onAddSet: (_) {},
            onUpdateSet: (_, _, _) {},
            onDuplicateSet: (_, _) {},
            onRemoveSet: (_, _) {},
          ),
        ],
      ),
    ),
    _PreviewSurface.review => SessionFinishReviewScreen(
      performanceController: _review,
      executionController: SessionExecutionController(
        plan: _calculated.plan,
        sessionKey: 'local-controlled-review',
      ),
      trainingSessionId: 9304,
      athleteId: 'local-preview-athlete',
    ),
    _PreviewSurface.history => Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: CompletedSessionResultView(
        record: _history,
        athleteHistory: [_history],
        performanceRecordStore: _historyStore,
        statusMessage:
            'Targets are frozen. Editing an actual does not change the target.',
        onRecordCorrected: (record) => setState(() => _history = record),
      ),
    ),
    _PreviewSurface.unavailable => StructuredRunningTimerScreen(
      key: const ValueKey('preview-pace-unavailable'),
      execution: _intentOnly.execution,
      onCheckpoint: (_) async => true,
    ),
    _PreviewSurface.skipped => Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: CompletedSessionResultView(
        record: _skipped,
        athleteHistory: [_skipped],
        statusMessage: 'Skipped work makes this session partially completed.',
      ),
    ),
  };
}

typedef _PreviewActual = ({IntervalWorkState state, double? pace});

class _B3PreviewFixture {
  const _B3PreviewFixture({required this.plan, required this.execution});

  static const _blockId = '123e4567-e89b-42d3-a456-426614174000';
  static const _packageHash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  final SessionExecutionPlan plan;
  final VerifiedStructuredRunningExecution execution;

  factory _B3PreviewFixture.calculated() => _build(calculated: true);

  factory _B3PreviewFixture.intentOnly() => _build(calculated: false);

  static _B3PreviewFixture _build({required bool calculated}) {
    const timer = TimerConfiguration(
      workSeconds: 12,
      restSeconds: 8,
      rounds: 3,
    );
    const plan = SessionExecutionPlan(
      sessionId: 'local-controlled-running-preview',
      sessionTitle: 'Controlled structured run',
      blocks: [
        SessionExecutionBlock(
          blockId: _blockId,
          title: 'Structured intervals',
          blockType: SessionBlockType.conditioning,
          content: 'Run smoothly at the authored effort. Recover easily.',
          workoutFormat: WorkoutFormat.intervals,
          position: 1,
          timerConfiguration: timer,
        ),
      ],
    );
    final workout = const RunningWorkoutProjector()
        .project(
          format: WorkoutFormat.intervals,
          configuration: timer,
          sourceRef: _blockId,
        )
        .workout!;
    final steps = workout.steps.whereType<RunningRepeatGroup>().single.steps;
    final stepIds = steps.map((step) => step.stepId).toList(growable: false);
    final workStepId = steps
        .singleWhere((step) => step.role == RunningStepRole.work)
        .stepId;
    final bindings = stepIds
        .map((stepId) => (stepId: stepId, sessionBlockId: _blockId))
        .toList(growable: false);
    final authority = AuthoredRunningExecutionAuthority.fromCanonicalJson({
      'schema_version': 1,
      'workout_id': workout.workoutId,
      'step_ids': stepIds,
      'executable_step_bindings': [
        for (final stepId in stepIds)
          {'step_id': stepId, 'session_block_id': _blockId},
      ],
      'execution_mapping_sha256': RunningExecutionMappingHash.compute(
        workoutId: workout.workoutId,
        bindings: bindings,
      ),
      'advisory_attachments': [
        {
          'attachment_id': 'LOCAL-TARGET',
          'step_ids': [workStepId],
        },
      ],
    });
    final target = calculated
        ? {
            'schema_version': 1,
            'authority': 'advisory',
            'attachment_id': 'LOCAL-TARGET',
            'scope': {
              'workout_id': workout.workoutId,
              'step_ids': [workStepId],
            },
            'frozen_at_utc': '2026-09-29T02:00:00.000Z',
            'freeze_source': 'in_app_start',
            'policy': _policy,
            'state': 'calculated',
            'benchmark': {
              'athlete_id': 'local-preview-athlete',
              'distance_metres': 5000,
              'elapsed_duration_milliseconds': 1200000,
              'duration_basis': 'elapsed_including_pauses',
              'source_kind': 'local_controlled_fixture',
            },
            'calculated_exact_range': {
              'unit': 'milliseconds_per_kilometre',
              'faster': {'numerator': 229600, 'denominator': 1},
              'slower': {'numerator': 250400, 'denominator': 1},
            },
          }
        : {
            'schema_version': 1,
            'authority': 'advisory',
            'attachment_id': 'LOCAL-TARGET',
            'scope': {
              'workout_id': workout.workoutId,
              'step_ids': [workStepId],
            },
            'frozen_at_utc': '2026-09-29T02:00:00.000Z',
            'freeze_source': 'in_app_start',
            'policy': _policy,
            'state': 'intent_only',
            'reason': 'no_eligible_completed_test',
          };
    final snapshot = RunningTargetSnapshotAggregate.fromJson({
      'schema_version': 1,
      'authority': 'advisory',
      'occurrence_id': 'local-preview-occurrence',
      'athlete_id': 'local-preview-athlete',
      'assignment_id': 'local-preview-assignment',
      'programme_version_id': 'local-preview-version',
      'session_slot_id': 'local-preview-slot',
      'package_content_hash': _packageHash,
      'workout_id': workout.workoutId,
      'frozen_at_utc': '2026-09-29T02:00:00.000Z',
      'freeze_source': 'in_app_start',
      'targets': [target],
    });
    return _B3PreviewFixture(
      plan: plan,
      execution: VerifiedStructuredRunningExecution.fromLaunch(
        plan: plan,
        authority: authority,
        frozenSnapshot: snapshot,
      ),
    );
  }

  static const _policy = {
    'policy_id': 'LOCAL-CONTROLLED-POLICY',
    'policy_version': 1,
    'method_id': 'PERCENT-BENCHMARK-SPEED',
    'method_version': 1,
    'minimum_speed_basis_points': 8123,
    'maximum_speed_basis_points': 9345,
    'freshness_local_civil_days': 90,
    'benchmark_eligibility': {
      'cohort_completed_tests_eligible': true,
      'manual_completed_tests_eligible': true,
      'external_completed_tests_eligible': false,
    },
    'display_rounding': {
      'increment_milliseconds_per_kilometre': 1000,
      'direction': 'nearest',
    },
  };

  PerformanceCaptureController controller({
    List<_PreviewActual>? states,
    bool completeBlock = false,
  }) {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: plan,
      athleteId: 'local-preview-athlete',
      trainingSessionId: 9304,
    )..bindStructuredRunning(execution: execution, allowInitialize: true);
    if (states != null) {
      var result =
          controller.draft.blockDrafts.single.resultData as IntervalResultData;
      for (var index = 0; index < states.length; index++) {
        final actual = states[index];
        result = result.replaceInterval(
          result.intervals[index].copyWith(
            state: actual.state,
            paceSecondsPerKm: actual.pace,
            clearPace: actual.pace == null,
          ),
        );
      }
      controller.updateBlockResultData(execution.sessionBlockId, result);
    }
    if (completeBlock) controller.markBlockComplete(execution.sessionBlockId);
    return controller;
  }

  TrainingSessionRecord record({
    required List<_PreviewActual> states,
    required TrainingSessionRecordStatus status,
  }) {
    final controller = this.controller(states: states, completeBlock: true);
    return const PerformanceRecordMapper().fromDraft(
      controller.buildPersistableDraft(status: status),
    );
  }

  StructuredRunningCursor recoveryCursor() {
    final controller = StructuredRunningController.fresh(execution: execution)
      ..start()
      ..elapse(const Duration(seconds: 13))
      ..pause();
    final cursor = controller.cursor;
    controller.dispose();
    return cursor;
  }
}
