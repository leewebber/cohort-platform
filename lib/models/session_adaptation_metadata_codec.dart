import '../domain/adaptation/adaptation_domain.dart';

/// Persistence keys for session adaptation metadata on `performance_protocols`.
abstract final class SessionAdaptationMetadataKeys {
  static const primarySessionIntent = 'primary_session_intent';
  static const secondarySessionIntents = 'secondary_session_intents';
  static const minimumViableDurationMin = 'minimum_viable_duration_min';
}

/// Parses, canonicalises, serialises, and validates session adaptation fields.
class SessionAdaptationMetadataCodec {
  const SessionAdaptationMetadataCodec._();

  static const emptySecondaries = <SessionIntent>[];

  static SessionIntent? parsePrimary(dynamic value) {
    if (value == null) return null;
    return SessionIntentDb.fromDb(value.toString());
  }

  static List<SessionIntent> parseSecondaryList(dynamic value) {
    if (value == null) return emptySecondaries;

    final rawItems = switch (value) {
      final List<dynamic> list => list,
      final String text when text.trim().isNotEmpty => text.split(','),
      _ => const <dynamic>[],
    };

    final parsed = <SessionIntent>[];
    for (final item in rawItems) {
      final intent = SessionIntentDb.fromDb(item?.toString());
      if (intent != null) {
        parsed.add(intent);
      }
    }
    return parsed;
  }

  static int? parseMinimumViableDurationMin(dynamic value) {
    if (value == null) return null;
    final parsed = value is int ? value : int.tryParse(value.toString());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  /// Deduplicates secondaries and removes any matching [primary].
  static List<SessionIntent> canonicalizeSecondaries({
    SessionIntent? primary,
    required List<SessionIntent> secondary,
  }) {
    final seen = <SessionIntent>{};
    final result = <SessionIntent>[];
    for (final intent in secondary) {
      if (primary != null && intent == primary) continue;
      if (seen.add(intent)) {
        result.add(intent);
      }
    }
    return List<SessionIntent>.unmodifiable(result);
  }

  static int? normalizeMinimumViableDurationMin(int? value) {
    if (value == null || value <= 0) return null;
    return value;
  }

  static void writeToMap({
    required Map<String, dynamic> target,
    SessionIntent? primarySessionIntent,
    required List<SessionIntent> secondarySessionIntents,
    int? minimumViableDurationMin,
  }) {
    if (primarySessionIntent != null) {
      target[SessionAdaptationMetadataKeys.primarySessionIntent] =
          primarySessionIntent.dbValue;
    }
    if (secondarySessionIntents.isNotEmpty) {
      target[SessionAdaptationMetadataKeys.secondarySessionIntents] =
          secondarySessionIntents.map((intent) => intent.dbValue).toList();
    }
    final minDuration =
        normalizeMinimumViableDurationMin(minimumViableDurationMin);
    if (minDuration != null) {
      target[SessionAdaptationMetadataKeys.minimumViableDurationMin] =
          minDuration;
    }
  }

  static void applyFromMap({
    required Map<String, dynamic> map,
    required void Function({
      SessionIntent? primarySessionIntent,
      List<SessionIntent> secondarySessionIntents,
      int? minimumViableDurationMin,
    }) apply,
  }) {
    if (!map.containsKey(SessionAdaptationMetadataKeys.primarySessionIntent) &&
        !map.containsKey(SessionAdaptationMetadataKeys.secondarySessionIntents) &&
        !map.containsKey(
          SessionAdaptationMetadataKeys.minimumViableDurationMin,
        )) {
      return;
    }

    final primary = parsePrimary(
      map[SessionAdaptationMetadataKeys.primarySessionIntent],
    );
    final secondary = parseSecondaryList(
      map[SessionAdaptationMetadataKeys.secondarySessionIntents],
    );
    final minDuration = parseMinimumViableDurationMin(
      map[SessionAdaptationMetadataKeys.minimumViableDurationMin],
    );

    apply(
      primarySessionIntent: primary,
      secondarySessionIntents: canonicalizeSecondaries(
        primary: primary,
        secondary: secondary,
      ),
      minimumViableDurationMin: minDuration,
    );
  }

  /// Removes adaptation columns from a merged map (e.g. partial legacy upserts).
  static void stripPendingPersistenceColumns(Map<String, dynamic> map) {
    map.remove(SessionAdaptationMetadataKeys.primarySessionIntent);
    map.remove(SessionAdaptationMetadataKeys.secondarySessionIntents);
    map.remove(SessionAdaptationMetadataKeys.minimumViableDurationMin);
  }
}

/// Validation messages for session adaptation metadata (authoring / load checks).
class SessionAdaptationMetadataValidation {
  const SessionAdaptationMetadataValidation._();

  static List<String> validate({
    SessionIntent? primarySessionIntent,
    required List<SessionIntent> secondarySessionIntents,
    int? minimumViableDurationMin,
    int? plannedDurationMin,
  }) {
    final messages = <String>[];

    final normalizedMin = SessionAdaptationMetadataCodec.normalizeMinimumViableDurationMin(
      minimumViableDurationMin,
    );
    if (minimumViableDurationMin != null &&
        minimumViableDurationMin <= 0 &&
        normalizedMin == null) {
      messages.add('Minimum viable duration must be greater than zero.');
    }

    final canonicalSecondaries =
        SessionAdaptationMetadataCodec.canonicalizeSecondaries(
      primary: primarySessionIntent,
      secondary: secondarySessionIntents,
    );
    if (canonicalSecondaries.length != secondarySessionIntents.length) {
      messages.add(
        'Secondary session intents must be unique and must not repeat the primary intent.',
      );
    }

    if (plannedDurationMin != null &&
        normalizedMin != null &&
        normalizedMin > plannedDurationMin) {
      messages.add(
        'Minimum viable duration ($normalizedMin min) exceeds planned session duration ($plannedDurationMin min).',
      );
    }

    return messages;
  }
}
