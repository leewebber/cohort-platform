import '../../../core/presentation/retained_strength_coaching_items.dart';
import '../../../models/session_block_type.dart';
import '../models/session_execution_plan.dart';

/// Athlete copy for the strength runner. This projection never edits the plan,
/// derives a dose from prose, or participates in saving execution evidence.
class StrengthWorkoutInstructions {
  const StrengthWorkoutInstructions._();

  static bool appliesTo(
    SessionExecutionPlan plan,
    SessionExecutionBlock block,
  ) =>
      block.timerConfiguration?.runningWorkout == null &&
      (block.blockType.supportsStructuredStrengthPrescription ||
          ((block.blockType == SessionBlockType.warmUp ||
                  block.blockType == SessionBlockType.coolDown) &&
              plan.blocks.any(
                (item) => item.blockType.supportsStructuredStrengthPrescription,
              )));

  static String sessionTitle(SessionExecutionPlan plan) =>
      plan.sessionTitle == plan.sessionId &&
          plan.blocks.any((block) => appliesTo(plan, block))
      ? 'Strength workout'
      : plan.sessionTitle;

  static String title(String value) => _reviewedCopy[value] ?? value;

  static List<String> blockLines(SessionExecutionBlock block) {
    final copy = lines(block.content);
    if (block.blockType != SessionBlockType.warmUp) return copy;
    return [for (final (index, line) in copy.indexed) '${index + 1}. $line'];
  }

  static List<String> lines(String? value) => [
    for (final line in (value ?? '').split('\n').map((line) => line.trim()))
      if (line.isNotEmpty && !_metadataLine.hasMatch(line))
        ...(retainedStrengthCoachingItems[line] ??
            [_reviewedCopy[line] ?? line]),
  ];

  static String? cue(String? value) {
    final text = lines(value).join('\n');
    if (text.isEmpty) return null;
    // The full sentence is internal. Removing it leaves the exact setup,
    // logging instruction and any following weekly load limit in place.
    return text
        .replaceAll(' Membership and dose explicitly selected.', '')
        .replaceAll(', no invented upper bound;', ';')
        .replaceAll(' At least 3 RIR; no invented upper RIR bound.', '')
        .replaceAll(
          '; no invented load or cross-machine equivalence.',
          '. Do not assume the same resistance on another machine.',
        );
  }

  static String? tempo(String? value) {
    final text = lines(value).join('\n');
    return text.isEmpty ? null : text;
  }

  static final _metadataLine = RegExp(
    r'^(?:protocol[_ ]id|(?:block|exercise|programme|session)[_ ]id|source[_ ](?:id|occurrence[_ ]id|dose[_ ]status|tempo[_ ]reference)|authored[_ ]details|provenance|review[_ ]status)\s*[:=]',
    caseSensitive: false,
  );

  static const _reviewedCopy = {
    'Monday selected strength': 'Monday strength',
    'Thursday selected strength': 'Thursday strength',
    'Five minutes of easy walking to warm up.':
        'Walk at an easy pace for 5 minutes.',
    'Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift':
        'Lower under control for about 2 seconds, with no forced pause. Lift purposefully.',
    '~2 seconds up, 1-second top pause, ~2 seconds down; full comfortable range (retained proposed tempo)':
        '~2 seconds up, 1-second top pause, ~2 seconds down; full comfortable range',
    'Use this week’s exact sets, rests and repetitions in reserve. The selected consolidation, lower-body control and taper instructions manage strength workload alongside the running.':
        'Use this week’s exact sets, rests and repetitions in reserve.',
    'Shoulder-width overhand grip; strict. Bodyweight initially; no invented body mass or zero-kg actual. Added load requires the exact supported weighted identity and explicit selection; assistance remains separate.':
        'Use a shoulder-width overhand grip and strict form. Use bodyweight initially. Record the reps you perform. Add load only when a supported weighted version is explicitly selected. Assistance is a separate option.',
    'Standing square stance; cable at chest height, both hands on handle; press without torso rotation. Each side has 10 reps; both sides form one set. No failure requirement or invented RIR.':
        'Stand square with the cable at chest height and both hands on the handle. Press without rotating your torso. Do 10 reps each side for one set. You don’t need to train to failure.',
  };
}
