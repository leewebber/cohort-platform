import 'fit_workout_representation.dart';

/// Documented FIT training_file -> workout file_id correspondence. These fields
/// are NOT Garmin Training/Activity JSON IDs, nor evidence of authenticated origin.
class FitTrainingFileReference {
  const FitTrainingFileReference({
    required this.manufacturer,
    required this.product,
    required this.serialNumber,
    required this.timeCreated,
  });
  final int manufacturer;
  final int product;
  final int serialNumber;
  final int timeCreated;
  Map<String, dynamic> toJson() => {
    'type': 5,
    'manufacturer': manufacturer,
    'product': product,
    'serial_number': serialNumber,
    'time_created': timeCreated,
  };
  String get key => fitManifestDigest(toJson());
  bool get isValid =>
      manufacturer >= 0 &&
      manufacturer < 65535 &&
      product >= 0 &&
      product < 65535 &&
      serialNumber > 0 &&
      serialNumber <= 0xffffffff &&
      timeCreated > 0 &&
      timeCreated < 0xffffffff;
}

/// Sanitised observation; no route/location/raw payload fields. All identifiers
/// and ownership claims here are synthetic harness inputs, not provider auth.
class SyntheticActivityObservation {
  SyntheticActivityObservation({
    required this.athleteId,
    required this.activityKey,
    this.trainingFile,
    this.proposedWorkoutId,
    this.proposedScheduleId,
    this.name,
    this.startedAt,
    this.timerMilliseconds,
    this.elapsedMilliseconds,
    this.distanceMillimetres,
    this.averageHeartRateBpm,
  }) {
    if (athleteId.trim().isEmpty ||
        activityKey.trim().isEmpty ||
        (trainingFile != null && !trainingFile!.isValid) ||
        [
          timerMilliseconds,
          elapsedMilliseconds,
          distanceMillimetres,
        ].whereType<int>().any((n) => n < 0) ||
        (timerMilliseconds != null &&
            elapsedMilliseconds != null &&
            timerMilliseconds! > elapsedMilliseconds!) ||
        (averageHeartRateBpm != null &&
            (averageHeartRateBpm! < 1 || averageHeartRateBpm! > 250)) ||
        (startedAt != null && !startedAt!.isUtc)) {
      throw const FormatException(
        'Supply owned, valid synthetic identifiers and actual metrics; preserve missing values.',
      );
    }
  }
  final String athleteId;
  final String
  activityKey; // Local fixture dedup key; portal identity unverified.
  final FitTrainingFileReference? trainingFile;
  final String? proposedWorkoutId;
  final String? proposedScheduleId;
  final String? name;
  final DateTime? startedAt;
  final int? timerMilliseconds;
  final int? elapsedMilliseconds;
  final int? distanceMillimetres;
  final int? averageHeartRateBpm;
  Map<String, dynamic> toJson() => {
    'fixture_only': true,
    'athlete_id': athleteId,
    'activity_key': activityKey,
    'training_file': trainingFile?.toJson(),
    'proposed_workout_id': proposedWorkoutId,
    'proposed_schedule_id': proposedScheduleId,
    'name': name,
    'started_at': startedAt?.toIso8601String(),
    'actuals': {
      'timer_milliseconds': timerMilliseconds,
      'elapsed_milliseconds': elapsedMilliseconds,
      'distance_millimetres': distanceMillimetres,
      'average_heart_rate_bpm': averageHeartRateBpm,
    },
  };
  String get digest => fitManifestDigest(toJson());
}

class LocalDeliveryFixture {
  LocalDeliveryFixture({
    required Map<String, dynamic> frozenExport,
    this.trainingFile,
    this.proposedWorkoutId,
    this.proposedScheduleId,
  }) : manifestDigest = fitManifestDigest(frozenExport),
       scope = freezeFitValue(frozenExport['scope']) as Map<String, dynamic> {
    if (frozenExport['schema'] != 'cohort_local_frozen_fit_export_v1' ||
        [
          'athlete_id',
          'assignment_id',
          'programme_version_id',
          'occurrence_id',
          'session_slot_id',
          'package_hash',
          'protocol_id',
          'block_id',
          'workout_id',
        ].any(
          (k) => scope[k] is! String || (scope[k] as String).isEmpty,
        ) ||
        (trainingFile != null && !trainingFile!.isValid)) {
      throw const FormatException(
        'Bind a synthetic delivery to the complete frozen export identity.',
      );
    }
  }
  final String manifestDigest;
  final Map<String, dynamic> scope;
  final FitTrainingFileReference? trainingFile;
  final String? proposedWorkoutId;
  final String? proposedScheduleId;
  String get owner => scope['athlete_id'] as String;
  Map<String, dynamic> toJson() => {
    'manifest_digest': manifestDigest,
    'scope': scope,
    'training_file': trainingFile?.toJson(),
    'proposed_workout_id': proposedWorkoutId,
    'proposed_schedule_id': proposedScheduleId,
  };
}

enum LocalAssociationStatus {
  unmatched,
  proposedIdentifiersOnly,
  documentedFitReferenceCandidate,
  ambiguous,
  conflictingIdentifiers,
  conflictingReturns,
  confirmedByAthlete,
}

class LocalAssociationAssessment {
  LocalAssociationAssessment(
    this.status,
    Iterable<String> candidates, {
    required this.observationDigest,
    required this.duplicate,
  }) : candidateManifestDigests = List.unmodifiable(candidates);
  final LocalAssociationStatus status;
  final List<String> candidateManifestDigests;
  final String observationDigest;
  final bool duplicate;
  bool get requiresAthleteConfirmation =>
      status != LocalAssociationStatus.confirmedByAthlete;
  // There is deliberately no completion port in this local evidence harness.
  bool get authorisesProgrammeCompletion => false;
}

/// In-memory deterministic fixture harness. No network, persistence, authentication,
/// completion, correction or advancement capabilities. Proposed API IDs only suggest.
class LocalActivityAssociationHarness {
  final _deliveries = <String, LocalDeliveryFixture>{};
  final _observations = <String, SyntheticActivityObservation>{};
  final _conflicts = <String>{};
  final _confirmations = <String, String>{};
  String _key(String owner, String activity) =>
      fitManifestDigest([owner, activity]);

  void registerDelivery(LocalDeliveryFixture fixture) {
    final prior = _deliveries[fixture.manifestDigest];
    if (prior != null &&
        fitManifestDigest(prior.toJson()) !=
            fitManifestDigest(fixture.toJson())) {
      throw const FormatException(
        'Delivery identity is immutable; retain the original receipt.',
      );
    }
    _deliveries.putIfAbsent(fixture.manifestDigest, () => fixture);
  }

  LocalAssociationAssessment observe({
    required String athleteId,
    required SyntheticActivityObservation activity,
  }) {
    if (activity.athleteId != athleteId) {
      throw const FormatException(
        'Activity owner does not match the signed-in fixture owner.',
      );
    }
    final key = _key(athleteId, activity.activityKey);
    final prior = _observations[key];
    final duplicate = prior?.digest == activity.digest;
    if (prior != null && !duplicate) {
      // No authoritative provider revision/order contract: never last-arrival wins.
      _conflicts.add(key);
    }
    _observations.putIfAbsent(key, () => activity);
    return _assess(key, duplicate: duplicate);
  }

  LocalAssociationAssessment inspect({
    required String athleteId,
    required String activityKey,
  }) => _assess(_key(athleteId, activityKey));

  LocalAssociationAssessment _assess(String key, {bool duplicate = false}) {
    final activity = _observations[key];
    if (activity == null) {
      throw const FormatException('Observe an owned activity first.');
    }
    LocalAssociationAssessment result(
      LocalAssociationStatus status,
      Iterable<String> ids,
    ) => LocalAssociationAssessment(
      status,
      ids,
      observationDigest: activity.digest,
      duplicate: duplicate,
    );
    if (_conflicts.contains(key)) {
      return result(LocalAssociationStatus.conflictingReturns, []);
    }
    final owned = _deliveries.values
        .where((d) => d.owner == activity.athleteId)
        .toList();
    final fileMatches = activity.trainingFile == null
        ? <LocalDeliveryFixture>[]
        : owned
              .where((d) => d.trainingFile?.key == activity.trainingFile!.key)
              .toList();
    final hints = <Set<String>>[];
    if (activity.proposedWorkoutId != null) {
      hints.add(
        owned
            .where((d) => d.proposedWorkoutId == activity.proposedWorkoutId)
            .map((d) => d.manifestDigest)
            .toSet(),
      );
    }
    if (activity.proposedScheduleId != null) {
      hints.add(
        owned
            .where((d) => d.proposedScheduleId == activity.proposedScheduleId)
            .map((d) => d.manifestDigest)
            .toSet(),
      );
    }
    if (hints.length > 1 &&
        hints.every((h) => h.isNotEmpty) &&
        hints.reduce((a, b) => a.intersection(b)).isEmpty) {
      return result(LocalAssociationStatus.conflictingIdentifiers, []);
    }
    var candidates = fileMatches.map((d) => d.manifestDigest).toSet();
    if (activity.trainingFile != null) {
      if (candidates.isEmpty && hints.any((h) => h.isNotEmpty)) {
        return result(LocalAssociationStatus.conflictingIdentifiers, []);
      }
      if (hints.any(
        (h) => h.isNotEmpty && h.intersection(candidates).isEmpty,
      )) {
        return result(LocalAssociationStatus.conflictingIdentifiers, []);
      }
      // Proposed hints never resolve ambiguity in a documented reference.
    } else if (hints.isNotEmpty) {
      candidates = hints.first;
      for (final h in hints.skip(1)) {
        candidates = candidates.intersection(h);
      }
      if (hints.length > 1 &&
          candidates.isEmpty &&
          hints.any((h) => h.isNotEmpty)) {
        return result(LocalAssociationStatus.conflictingIdentifiers, []);
      }
    }
    final confirmed = _confirmations[key];
    if (confirmed != null) {
      return result(LocalAssociationStatus.confirmedByAthlete, [confirmed]);
    }
    final sorted = candidates.toList()..sort();
    if (sorted.length > 1) {
      return result(LocalAssociationStatus.ambiguous, sorted);
    }
    if (sorted.isEmpty) return result(LocalAssociationStatus.unmatched, []);
    return result(
      activity.trainingFile != null
          ? LocalAssociationStatus.documentedFitReferenceCandidate
          : LocalAssociationStatus.proposedIdentifiersOnly,
      sorted,
    );
  }

  /// Explicit local fixture decision, not a provider match or completion command.
  LocalAssociationAssessment confirm({
    required String athleteId,
    required String activityKey,
    required String manifestDigest,
    required String expectedObservationDigest,
  }) {
    final key = _key(athleteId, activityKey);
    final assessment = _assess(key);
    final target = _deliveries[manifestDigest];
    if (target == null ||
        target.owner != athleteId ||
        assessment.observationDigest != expectedObservationDigest ||
        {
          LocalAssociationStatus.conflictingReturns,
          LocalAssociationStatus.conflictingIdentifiers,
        }.contains(assessment.status) ||
        (assessment.candidateManifestDigests.isNotEmpty &&
            !assessment.candidateManifestDigests.contains(manifestDigest)) ||
        (_confirmations[key] != null &&
            _confirmations[key] != manifestDigest)) {
      throw const FormatException(
        'Review the current owned evidence; conflicting or stale associations cannot be confirmed.',
      );
    }
    _confirmations[key] = manifestDigest;
    return _assess(key);
  }
}
