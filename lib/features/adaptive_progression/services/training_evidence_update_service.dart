import '../../athlete_profile/models/athlete_profile.dart';
import '../../plans/models/plan_definition.dart';
import '../models/capability_timeline.dart';
import '../models/session_completion.dart';

/// Result of applying a session completion to athlete evidence.
class EvidenceUpdateResult {
  const EvidenceUpdateResult({
    required this.profile,
    required this.events,
  });

  final AthleteProfile profile;
  final List<CapabilityTimelineEvent> events;
}

/// Transforms [SessionCompletion] into updated capability baselines.
///
/// Deterministic only — small, capped adjustments consumed by the existing
/// [AthletePlanningInputBuilder] evidence mapping. No engine changes.
class TrainingEvidenceUpdateService {
  const TrainingEvidenceUpdateService();

  /// Default capabilities when the profile has no baselines yet.
  static const fallbackCapabilityIds = [
    'cohort.capability.relative_strength',
    'cohort.capability.aerobic_capacity',
    'cohort.capability.work_capacity',
    'cohort.capability.movement_competency',
  ];

  AthleteProfile apply({
    required AthleteProfile profile,
    required SessionCompletion completion,
    PlanDefinition? activePlan,
    DateTime? now,
  }) {
    return applyWithEvents(
      profile: profile,
      completion: completion,
      activePlan: activePlan,
      now: now,
    ).profile;
  }

  EvidenceUpdateResult applyWithEvents({
    required AthleteProfile profile,
    required SessionCompletion completion,
    PlanDefinition? activePlan,
    DateTime? now,
  }) {
    final targets = _targetCapabilityIds(profile: profile, plan: activePlan);
    final delta = _deterministicDelta(completion);
    final stamp = now ?? DateTime.now().toUtc();

    final byId = {
      for (final c in profile.baselineCapabilities) c.capabilityId: c,
    };

    final updated = <AthleteBaselineCapability>[];
    final events = <CapabilityTimelineEvent>[];

    for (final id in targets) {
      final current = byId[id]?.relativeLevel ?? _seedLevel(profile);
      final next = (current + delta).clamp(0.05, 0.95);
      updated.add(
        AthleteBaselineCapability(capabilityId: id, relativeLevel: next),
      );
      byId.remove(id);

      final direction = next > current + 0.0001
          ? CapabilityChangeDirection.up
          : next < current - 0.0001
          ? CapabilityChangeDirection.down
          : CapabilityChangeDirection.steady;

      events.add(
        CapabilityTimelineEvent(
          eventId: 'cap.$id.${stamp.millisecondsSinceEpoch}',
          recordedAt: stamp,
          capabilityId: id,
          label: CapabilityLabelCatalog.labelFor(id),
          direction: direction,
          fromLevel: current,
          toLevel: next,
          sourceCompletionId: completion.completionId,
        ),
      );
    }

    // Preserve unrelated baselines unchanged.
    updated.addAll(byId.values);

    return EvidenceUpdateResult(
      profile: profile.copyWith(
        baselineCapabilities: updated,
        updatedAt: stamp,
      ),
      events: events,
    );
  }

  List<String> _targetCapabilityIds({
    required AthleteProfile profile,
    PlanDefinition? plan,
  }) {
    if (plan != null && plan.capabilityPriorities.isNotEmpty) {
      return plan.capabilityPriorities;
    }
    if (profile.baselineCapabilities.isNotEmpty) {
      return profile.baselineCapabilities.map((c) => c.capabilityId).toList();
    }
    return fallbackCapabilityIds;
  }

  /// Small capped step from completion quality + optional RPE.
  double _deterministicDelta(SessionCompletion completion) {
    var delta = 0.01 + (0.02 * completion.completionRatio);

    final rpe = completion.sessionRpe;
    if (rpe != null) {
      if (rpe >= 5 && rpe <= 7) {
        delta += 0.005;
      } else if (rpe <= 3 || rpe >= 9) {
        delta *= 0.75;
      }
    }

    return double.parse(delta.toStringAsFixed(4));
  }

  double _seedLevel(AthleteProfile profile) {
    return switch (profile.experienceLevel) {
      AthleteExperienceLevel.beginner => 0.35,
      AthleteExperienceLevel.intermediate => 0.5,
      AthleteExperienceLevel.advanced => 0.65,
    };
  }
}
