import '../../adaptive_progression/models/capability_timeline.dart';
import '../../adaptive_progression/models/session_completion.dart';
import '../models/progress_summary.dart';

/// Athlete-facing radar dimension (product language).
enum CapabilityRadarDimension {
  strength,
  endurance,
  threshold,
  power,
  durability,
  mobility,
  discipline,
}

extension CapabilityRadarDimensionLabel on CapabilityRadarDimension {
  String get athleteLabel => switch (this) {
    CapabilityRadarDimension.strength => 'Strength',
    CapabilityRadarDimension.endurance => 'Endurance',
    CapabilityRadarDimension.threshold => 'Threshold',
    CapabilityRadarDimension.power => 'Power',
    CapabilityRadarDimension.durability => 'Durability',
    CapabilityRadarDimension.mobility => 'Mobility',
    CapabilityRadarDimension.discipline => 'Discipline',
  };
}

/// One axis on the capability radar.
class CapabilityRadarAxis {
  const CapabilityRadarAxis({
    required this.dimension,
    required this.available,
    this.normalisedValue,
  });

  final CapabilityRadarDimension dimension;

  /// False when evidence is missing — chart shows scaffolding only.
  final bool available;

  /// 0.0–1.0 when [available]; null when awaiting evidence.
  final double? normalisedValue;

  String get label => dimension.athleteLabel;
}

/// Immutable radar model for Progress UI (no coaching logic in widgets).
class CapabilityRadarModel {
  const CapabilityRadarModel({required this.axes});

  final List<CapabilityRadarAxis> axes;

  bool get hasAnyEvidence => axes.any((a) => a.available);

  static const emptyScaffold = CapabilityRadarModel(
    axes: [
      CapabilityRadarAxis(
        dimension: CapabilityRadarDimension.strength,
        available: false,
      ),
      CapabilityRadarAxis(
        dimension: CapabilityRadarDimension.endurance,
        available: false,
      ),
      CapabilityRadarAxis(
        dimension: CapabilityRadarDimension.threshold,
        available: false,
      ),
      CapabilityRadarAxis(
        dimension: CapabilityRadarDimension.power,
        available: false,
      ),
      CapabilityRadarAxis(
        dimension: CapabilityRadarDimension.durability,
        available: false,
      ),
      CapabilityRadarAxis(
        dimension: CapabilityRadarDimension.mobility,
        available: false,
      ),
      CapabilityRadarAxis(
        dimension: CapabilityRadarDimension.discipline,
        available: false,
      ),
    ],
  );
}

/// Evidence-backed Progress metric card (only when supported).
class ProgressMetricCardModel {
  const ProgressMetricCardModel({
    required this.id,
    required this.title,
    required this.currentLabel,
    this.previousLabel,
    this.direction,
    this.lastUpdated,
  });

  final String id;
  final String title;
  final String currentLabel;
  final String? previousLabel;
  final CapabilityChangeDirection? direction;
  final DateTime? lastUpdated;
}

/// Deterministic projection: capability evidence → radar + metric cards.
///
/// Does not invent scores. Unsupported dimensions stay unavailable.
class CapabilityRadarProjectionService {
  const CapabilityRadarProjectionService();

  /// Ontology capability ids that feed each athlete-facing dimension.
  static const Map<CapabilityRadarDimension, List<String>> dimensionSources = {
    CapabilityRadarDimension.strength: [
      'cohort.capability.relative_strength',
      'cohort.capability.pushing_strength',
      'cohort.capability.pulling_strength',
    ],
    CapabilityRadarDimension.endurance: [
      'cohort.capability.aerobic_capacity',
      'cohort.capability.strength_endurance',
    ],
    CapabilityRadarDimension.threshold: [
      'cohort.capability.threshold',
    ],
    CapabilityRadarDimension.power: [
      'cohort.capability.work_capacity',
    ],
    CapabilityRadarDimension.durability: [
      'cohort.capability.resilience',
    ],
    CapabilityRadarDimension.mobility: [
      'cohort.capability.movement_competency',
    ],
    CapabilityRadarDimension.discipline: <String>[],
  };

  CapabilityRadarModel project({
    List<CapabilityTimelineEvent>? timeline,
    ProgressCompliance? compliance,
  }) {
    final events = timeline ?? CapabilityTimelineStore.all;
    final axes = <CapabilityRadarAxis>[];

    for (final dimension in CapabilityRadarDimension.values) {
      if (dimension == CapabilityRadarDimension.discipline) {
        axes.add(_disciplineAxis(compliance));
        continue;
      }

      final sources = dimensionSources[dimension] ?? const [];
      final levels = <double>[];
      for (final id in sources) {
        final level = _latestLevel(events, id);
        if (level != null) levels.add(level);
      }

      if (levels.isEmpty) {
        axes.add(
          CapabilityRadarAxis(dimension: dimension, available: false),
        );
      } else {
        final avg = levels.reduce((a, b) => a + b) / levels.length;
        axes.add(
          CapabilityRadarAxis(
            dimension: dimension,
            available: true,
            normalisedValue: avg.clamp(0.0, 1.0),
          ),
        );
      }
    }

    return CapabilityRadarModel(axes: List.unmodifiable(axes));
  }

  List<ProgressMetricCardModel> metricCards({
    List<CapabilityTimelineEvent>? timeline,
    ProgressCompliance? compliance,
  }) {
    final events = [...(timeline ?? CapabilityTimelineStore.all)]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final cards = <ProgressMetricCardModel>[];

    void addFromCapability(String capabilityId, String title) {
      final latest = events.where((e) => e.capabilityId == capabilityId);
      if (latest.isEmpty) return;
      final event = latest.first;
      if (event.toLevel == null) return;
      final previous = latest.length > 1 ? latest.elementAt(1) : null;
      cards.add(
        ProgressMetricCardModel(
          id: capabilityId,
          title: title,
          currentLabel: _formatLevel(event.toLevel!),
          previousLabel: previous?.toLevel != null
              ? _formatLevel(previous!.toLevel!)
              : previous?.fromLevel != null
              ? _formatLevel(previous!.fromLevel!)
              : null,
          direction: event.direction,
          lastUpdated: event.recordedAt,
        ),
      );
    }

    addFromCapability(
      'cohort.capability.relative_strength',
      'Lower Body Strength',
    );
    addFromCapability('cohort.capability.threshold', 'Threshold Pace');
    addFromCapability(
      'cohort.capability.aerobic_capacity',
      'Aerobic Endurance',
    );
    addFromCapability(
      'cohort.capability.pulling_strength',
      'Pulling Strength',
    );

    if (compliance != null &&
        (SessionCompletionStore.all.isNotEmpty || compliance.completed > 0)) {
      cards.add(
        ProgressMetricCardModel(
          id: 'discipline',
          title: 'Training Discipline',
          currentLabel: '${compliance.percentage}%',
          previousLabel: null,
          direction: compliance.percentage >= 70
              ? CapabilityChangeDirection.up
              : compliance.percentage >= 40
              ? CapabilityChangeDirection.steady
              : CapabilityChangeDirection.down,
          lastUpdated: SessionCompletionStore.latest?.completedAt,
        ),
      );
    }

    return List.unmodifiable(cards);
  }

  CapabilityRadarAxis _disciplineAxis(ProgressCompliance? compliance) {
    if (compliance == null ||
        (compliance.planned <= 0 && SessionCompletionStore.all.isEmpty)) {
      return const CapabilityRadarAxis(
        dimension: CapabilityRadarDimension.discipline,
        available: false,
      );
    }
    return CapabilityRadarAxis(
      dimension: CapabilityRadarDimension.discipline,
      available: true,
      normalisedValue: (compliance.percentage / 100.0).clamp(0.0, 1.0),
    );
  }

  double? _latestLevel(List<CapabilityTimelineEvent> events, String id) {
    final matches = events.where((e) => e.capabilityId == id).toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    if (matches.isEmpty) return null;
    final level = matches.first.toLevel ?? matches.first.fromLevel;
    if (level == null) return null;
    // Timeline levels may already be 0–1 or 0–10; normalise gently.
    if (level > 1.0) return (level / 10.0).clamp(0.0, 1.0);
    return level.clamp(0.0, 1.0);
  }

  String _formatLevel(double level) {
    if (level > 1.0) return level.toStringAsFixed(1);
    return '${(level * 100).round()}%';
  }
}
