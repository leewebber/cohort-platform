import 'package:flutter/material.dart';

import '../../../domain/running_workout/running_workout_codec.dart';
import '../../../domain/running_workout/running_workout_model.dart';
import '../../../models/strength_exercise_prescription.dart';
import '../../../models/strength_prescription_formatter.dart';
import 'native_session_source.dart';
import 'prescription_presentation.dart';
import 'retained_coaching_presentation.dart';

/// Read-only presentation of the exact selected native source, including pending
/// null-ID intent. Doses use existing typed models; no rendered prose is parsed.
class StructuredPrescriptionPreview extends StatelessWidget {
  const StructuredPrescriptionPreview({
    super.key,
    required this.source,
    required this.title,
    this.showTitle = true,
  });
  final Map<String, dynamic> source;
  final String title;
  final bool showTitle;

  Widget section(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  Widget items(List<String> values) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < values.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 28, child: Text('${i + 1}.')),
              Expanded(child: Text(values[i])),
            ],
          ),
        ),
    ],
  );

  Widget metric(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 24, bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final blocks = source['blocks'] as List;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          key: const ValueKey('athlete-prescription'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle)
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
            for (final raw in blocks) ...[
              if (raw['timer_config'] != null)
                running(context, raw as Map)
              else ...[
                if (raw['block_type'] == 'warm_up' ||
                    raw['block_type'] == 'cool_down')
                  section(
                    context,
                    raw['block_type'] == 'warm_up' ? 'Warm-up' : 'Finish',
                    [
                      items(coachingItems(raw['content'] as String?)),
                      for (final text in coachingItems(
                        raw['coach_notes'] as String?,
                      ))
                        Text(text),
                    ],
                  )
                else ...[
                  for (final text in coachingItems(raw['content'] as String?))
                    Text(text),
                  for (final text in coachingItems(
                    raw['coach_notes'] as String?,
                  ))
                    Text(text),
                ],
                for (final exercise in raw['exercises'])
                  strength(context, exercise as Map),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget strength(BuildContext context, Map exercise) {
    StrengthExercisePrescription p;
    try {
      p = StrengthExercisePrescription.fromJson(
        Map<String, dynamic>.from(exercise['prescription'] as Map),
      );
      if (p.validate(requireComplete: true).isNotEmpty) {
        throw const FormatException('Correct the prescribed dose.');
      }
    } catch (_) {
      return section(context, exercise['display_label_override'] as String, [
        const Text(
          'Correct this exercise prescription in Edit session before previewing its dose.',
        ),
      ]);
    }
    final rir = p.rirRange;
    final authoredRir = p.authoredDetails?['source_rir'] as String?;
    final rirText = rir == null
        ? (authoredRir == null || authoredRir == 'N/A'
              ? 'No requirement'
              : authoredRir)
        : rir.min == rir.max
        ? '${rir.min}'
        : '${rir.min}–${rir.max}';
    final rest = p.restSecondsRange;
    final restText = p.restSeconds != null
        ? '${p.restSeconds} sec'
        : rest != null
        ? '${rest.min}–${rest.max} sec'
        : 'Not prescribed';
    final capture = p.performanceCapture;
    final load = StrengthPrescriptionFormatter.formatLoad(p.load);
    final cue = p.coachCue;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise['display_label_override'] as String,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              StrengthPrescriptionFormatter.formatSetsReps(
                p.reps.type == StrengthRepType.duration
                    ? p.copyWith(perSide: false)
                    : p,
              ),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              children: [
                metric(context, 'Load', load ?? 'Not specified'),
                metric(context, 'Rest', restText),
                metric(context, 'RIR', rirText),
                if (p.restAfterGroupSecondsRange case final r?)
                  metric(context, 'Rest after group', '${r.min}–${r.max} sec'),
                if (p.holdSeconds != null)
                  metric(context, 'Extended hold', '${p.holdSeconds} sec'),
              ],
            ),
            // Logging conventions are operational guidance, kept once alongside load.
            if (capture?.loadLabel case final label?)
              Text(
                '$label${capture!.loadUnit == null ? '' : ' (${capture.loadUnit})'}',
              ),
            if (p.perSide) const Text('Both sides form one set.'),
            if (p.authoredDetails?['rest_location'] case final String location)
              Text(location),
            if (p.authoredDetails?['planned_load_increase'] == false)
              const Text('No planned load increase.'),
            if ((cue?.isNotEmpty ?? false) || (p.tempo?.isNotEmpty ?? false))
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Setup, tempo & coaching'),
                children: [
                  if (p.tempo?.isNotEmpty ?? false)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Tempo: ${p.tempo}'),
                    ),
                  if (cue?.isNotEmpty ?? false)
                    Align(alignment: Alignment.centerLeft, child: Text(cue!)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget running(BuildContext context, Map block) {
    RunningWorkout workout;
    try {
      workout = const RunningWorkoutCodec().decodeMap(
        Map<String, dynamic>.from(
          block['timer_config']['running_workout'] as Map,
        ),
      );
    } catch (_) {
      return const Text(
        'Correct the running steps in Edit session before previewing this workout.',
      );
    }
    final groups = groupRunningSteps(workout.steps);
    final steps = groups.expand((g) => g.steps);
    final milliseconds = steps.fold<int>(
      0,
      (n, s) => n + (s.duration.milliseconds ?? 0),
    );
    final millimetres = steps.fold<int>(
      0,
      (n, s) => n + (s.duration.millimetres ?? 0),
    );
    final notes = coachingItems(workout.notes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (workout.title != null && workout.title != title)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              workout.title!,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        Text(
          'Total ${formatRunSeconds(milliseconds ~/ 1000)}${millimetres == 0 ? '' : ' + ${millimetres / 1000000} km'}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (millimetres > 0)
          const Text(
            'Timed preparation and cooldown plus actual distance-test time. Confirm distance externally.',
          ),
        for (final group in groups)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.repeated
                        ? '${group.repetitions} repetitions'
                        : switch (group.steps.first.role) {
                            RunningStepRole.warmUp => 'Warm-up',
                            RunningStepRole.coolDown => 'Cooldown',
                            RunningStepRole.recovery => 'Recovery',
                            RunningStepRole.rest => 'Rest',
                            _ => 'Work',
                          },
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  step(
                    context,
                    group.steps.first,
                    prefix: group.repeated ? '${group.repetitions} × ' : '',
                  ),
                  if (group.repeated) ...[
                    step(context, group.steps[1]),
                    Text(
                      group.recoveryAfterLast
                          ? 'Recovery after every repetition, including the final one (${group.repetitions} recoveries).'
                          : 'Recovery between repetitions only (${group.repetitions - 1} recoveries); none after the final repetition.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (notes.isNotEmpty)
          section(context, 'Coaching notes', [items(notes)]),
        // The bootstrap aliases workout.notes into block.coach_notes. Read the
        // workout channel once; a separately edited block note remains visible.
        if (block['coach_notes'] != workout.notes)
          for (final note in coachingItems(block['coach_notes'] as String?))
            Text(note),
        for (final note in coachingItems(block['content'] as String?))
          Text(note),
      ],
    );
  }

  Widget step(
    BuildContext context,
    RunningAtomicStep step, {
    String prefix = '',
  }) {
    final guidance = effortGuidance(step.notes);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$prefix${runDuration(step.duration)} · ${step.label ?? 'Training step'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (step.target.kind != RunningTargetKind.none)
            Text(runTarget(step.target)),
          if (guidance.isNotEmpty) Text(guidance),
        ],
      ),
    );
  }
}
