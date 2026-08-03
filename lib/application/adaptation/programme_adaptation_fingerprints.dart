import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';

/// Stable fingerprints for proposal freshness and acceptance validation.
class ProgrammeAdaptationFingerprints {
  const ProgrammeAdaptationFingerprints._();

  static String plan(SessionExecutionPlan plan) {
    final blockBits = plan.blocks
        .map((b) {
          final rx = b.linkedExercises
              .map((p) {
                final sets = p.prescription?.sets;
                final reps = p.prescription?.reps;
                final rest = p.prescription?.restSeconds;
                return '${p.exerciseId}:$sets:$reps:$rest';
              })
              .join(',');
          return '${b.blockId}:${b.title}:$rx';
        })
        .join(';');
    return '${plan.protocol?.protocolId ?? ''}|${plan.durationMin ?? ''}|'
        '${plan.blocks.length}|$blockBits';
  }

  static String package(PreparedExecutionPackage package) {
    return [
      package.programmedSessionKey.value,
      package.assignmentId ?? '',
      package.programmeVersionId ?? '',
      package.packageContentHash ?? '',
      package.protocolId ?? '',
      package.dayKey ?? '',
      '${package.slotOrder ?? ''}',
      package.acceptedAdaptation?.decisionId ?? '',
      package.preparedAt.toUtc().toIso8601String(),
      plan(package.plan),
    ].join('|');
  }
}
