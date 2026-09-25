import 'dart:convert';

import '../domain/programme_review_models.dart';
import 'programme_studio_copy.dart';

String classificationLabel(ProgrammeReviewClassification value) {
  return switch (value) {
    ProgrammeReviewClassification.productionPublished => 'Production-published',
    ProgrammeReviewClassification.internalPersonal => 'Internal / personal',
    ProgrammeReviewClassification.legacyWithheld => 'Legacy / withheld',
    ProgrammeReviewClassification.fixtureTestExample =>
      'Fixture / test / example',
    ProgrammeReviewClassification.plannedFamily =>
      ProgrammeStudioCopy.plannedBadge,
  };
}

String weekLabel({required int weekNumber, required int weekCount}) {
  return 'Week $weekNumber of $weekCount';
}

String weekdayLabel(ProgrammeReviewDay day) {
  return day.title ?? 'Day ${day.dayOrder}';
}

String authoredOrUnspecified(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return ProgrammeStudioCopy.notSpecified;
  }
  return trimmed;
}

String blockSectionLabel(String blockType) {
  return switch (blockType) {
    'warm_up' => 'Warm-up',
    'conditioning' => 'Conditioning',
    'cool_down' => 'Cooldown / recovery',
    'core' => 'Core',
    'strength' => 'Strength',
    'skill' => 'Skill',
    'accessory' => 'Accessory',
    _ => 'Main work',
  };
}

int blockSectionOrder(String blockType) {
  return switch (blockType) {
    'warm_up' => 0,
    'strength' || 'skill' || 'accessory' || 'custom' => 1,
    'core' => 2,
    'conditioning' => 3,
    'cool_down' => 4,
    _ => 1,
  };
}

String trainingDomain(ProgrammeReviewSession session) {
  for (final block in session.blocks) {
    if (block.blockType != 'warm_up' && block.blockType != 'cool_down') {
      return blockSectionLabel(block.blockType);
    }
  }
  if (session.blocks.isEmpty) {
    return session.title;
  }
  return blockSectionLabel(session.blocks.first.blockType);
}

String? safeWorkloadSummary(ProgrammeReviewSession session) {
  final summary = session.prescriptionSummary?.trim();
  if (summary != null &&
      summary.isNotEmpty &&
      !_isEngineeringReferral(summary)) {
    return summary;
  }
  for (final block in session.blocks) {
    final timer = humanTimerSummary(block.timerConfiguration);
    if (timer != null) {
      return timer;
    }
  }
  return null;
}

String? coachFacingNote(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty || _isEngineeringReferral(value)) {
    return null;
  }
  return value;
}

bool _isEngineeringReferral(String value) {
  return value.contains('APOLLO-') ||
      value.contains('executable protocol') ||
      value.contains('Executable authority');
}

String? humanTimerSummary(String? raw) {
  final decoded = _jsonMap(raw);
  if (decoded == null) {
    return null;
  }
  final parts = <String>[];
  final duration = decoded['duration_seconds'] ?? decoded['work_seconds'];
  final seconds = duration is int
      ? duration
      : int.tryParse(duration?.toString() ?? '');
  if (seconds != null && seconds > 0 && seconds % 60 == 0) {
    parts.add('${seconds ~/ 60} min');
  }
  final rounds = decoded['rounds'];
  if (rounds is int || rounds is String) {
    parts.add('$rounds rounds');
  }
  if (decoded['capture_strategy'] == 'fixed_work') {
    parts.add('Fixed-work capture');
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

String? movementLoadInstruction(ProgrammeReviewMovement movement) {
  final decoded = _jsonMap(movement.rawPrescription);
  if (decoded == null) {
    return null;
  }
  final load = decoded['load'];
  if (load is Map) {
    final type = load['type']?.toString();
    if (type == 'athleteSelected') {
      final unit = load['unit']?.toString();
      return unit == null || unit.isEmpty
          ? 'Load: athlete selected'
          : 'Load: athlete selected ($unit)';
    }
    if (type == 'freeText') {
      final text = load['text']?.toString();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
  }
  return null;
}

Map<String, dynamic>? _jsonMap(String? raw) {
  if (raw == null || raw.trim().isEmpty || !raw.trim().startsWith('{')) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {
    return null;
  }
  return null;
}
