import '../models/programme_version_comparison_models.dart';

/// Deterministic Programme Version comparison engine (M10.2).
class ProgrammeVersionComparisonEngine {
  const ProgrammeVersionComparisonEngine._();

  static ProgrammeVersionComparisonSummary compare({
    required ProgrammeVersionComparisonSnapshot source,
    required ProgrammeVersionComparisonSnapshot target,
  }) {
    final identity = ProgrammeVersionComparisonIdentity(
      programmeLineageId: source.lineageId,
      programmeName: target.programmeName.isNotEmpty
          ? target.programmeName
          : source.programmeName,
      sourceVersionId: source.versionId,
      sourceVersionNumber: source.versionNumber,
      sourceLifecycleStatus: source.lifecycleStatus,
      targetVersionId: target.versionId,
      targetVersionNumber: target.versionNumber,
      targetLifecycleStatus: target.lifecycleStatus,
    );

    final metadataChanges = compareMetadata(source.metadata, target.metadata);
    final weekChanges = compareWeeks(source.weeks, target.weeks);
    final dayChanges = compareDays(source.days, target.days);
    final slotChanges = compareSlots(
      sourceSlots: source.slots,
      targetSlots: target.slots,
      sameVersion: source.versionId == target.versionId,
    );
    final sessionRevisionChanges =
        deriveSessionRevisionChanges(slotChanges);
    final exerciseChanges = compareExercises(source.exercises, target.exercises);
    final exerciseSetChange = buildExerciseSetChange(
      source.exercises,
      target.exercises,
      source.exerciseEnrichmentAuthoritative,
      target.exerciseEnrichmentAuthoritative,
    );

    final warnings = <String>[];
    final limitationNotes = <String>[];
    var isPartial = false;

    if (!source.exerciseEnrichmentAuthoritative) {
      isPartial = true;
      limitationNotes.add(
        source.exerciseEnrichmentLimitation ??
            'Exercise comparison for the source version is partial.',
      );
    }
    if (!target.exerciseEnrichmentAuthoritative) {
      isPartial = true;
      limitationNotes.add(
        target.exerciseEnrichmentLimitation ??
            'Exercise comparison for the target version is partial.',
      );
    }
    if (!source.sessionEnrichmentAuthoritative) {
      isPartial = true;
      limitationNotes.add(
        source.sessionEnrichmentLimitation ??
            'Session comparison for the source version is partial.',
      );
    }
    if (!target.sessionEnrichmentAuthoritative) {
      isPartial = true;
      limitationNotes.add(
        target.sessionEnrichmentLimitation ??
            'Session comparison for the target version is partial.',
      );
    }

    final structureMetrics = buildStructureMetrics(
      source: source,
      target: target,
      exerciseSetChange: exerciseSetChange,
    );

    final hasStructuralChanges = weekChanges.any((c) => c.changeType != ProgrammeChangeType.unchanged) ||
        dayChanges.any((c) => c.changeType != ProgrammeChangeType.unchanged);
    final hasSessionChanges = slotChanges.any(
      (change) =>
          change.changeType != ProgrammeChangeType.unchanged &&
          change.changeType != ProgrammeChangeType.added &&
          change.changeType != ProgrammeChangeType.removed,
    ) ||
        slotChanges.any((c) => c.changeType == ProgrammeChangeType.added) ||
        slotChanges.any((c) => c.changeType == ProgrammeChangeType.removed) ||
        sessionRevisionChanges.isNotEmpty;
    final hasExerciseChanges = exerciseSetChange.addedExercises.isNotEmpty ||
        exerciseSetChange.removedExercises.isNotEmpty ||
        exerciseChanges.any((c) => c.changeType == ProgrammeChangeType.modified);

    final isIdentical = metadataChanges.isEmpty &&
        weekChanges.every((c) => c.changeType == ProgrammeChangeType.unchanged) &&
        dayChanges.every((c) => c.changeType == ProgrammeChangeType.unchanged) &&
        slotChanges.every((c) => c.changeType == ProgrammeChangeType.unchanged) &&
        sessionRevisionChanges.isEmpty &&
        (!source.exerciseEnrichmentAuthoritative ||
            !target.exerciseEnrichmentAuthoritative ||
            (exerciseSetChange.addedExercises.isEmpty &&
                exerciseSetChange.removedExercises.isEmpty &&
                exerciseChanges.every((c) => c.changeType == ProgrammeChangeType.unchanged)));

    final classifications = buildClassifications(
      metadataChanges: metadataChanges,
      weekChanges: weekChanges,
      dayChanges: dayChanges,
      slotChanges: slotChanges,
      sessionRevisionChanges: sessionRevisionChanges,
      exerciseSetChange: exerciseSetChange,
      isIdentical: isIdentical,
      isPartial: isPartial,
    );

    return ProgrammeVersionComparisonSummary(
      identity: identity,
      metadataChanges: metadataChanges,
      weekChanges: weekChanges,
      dayChanges: dayChanges,
      slotChanges: slotChanges,
      sessionRevisionChanges: sessionRevisionChanges,
      exerciseChanges: exerciseChanges,
      exerciseSetChange: exerciseSetChange,
      structureMetrics: structureMetrics,
      classifications: classifications,
      isIdentical: isIdentical,
      hasStructuralChanges: hasStructuralChanges,
      hasSessionChanges: hasSessionChanges,
      hasExerciseChanges: hasExerciseChanges,
      warnings: warnings,
      limitationNotes: limitationNotes,
      summaryMessages: const [],
      isPartial: isPartial,
    );
  }

  static List<ProgrammeMetadataChange> compareMetadata(
    Map<String, String?> source,
    Map<String, String?> target,
  ) {
    final changes = <ProgrammeMetadataChange>[];
    final keys = {...source.keys, ...target.keys};

    for (final field in keys.toList()..sort()) {
      final sourceValue = _normaliseMetadataValue(source[field]);
      final targetValue = _normaliseMetadataValue(target[field]);
      if (sourceValue == targetValue) continue;

      changes.add(
        ProgrammeMetadataChange(
          field: field,
          sourceValue: sourceValue,
          targetValue: targetValue,
          changeType: sourceValue == null
              ? ProgrammeChangeType.added
              : targetValue == null
                  ? ProgrammeChangeType.removed
                  : ProgrammeChangeType.modified,
        ),
      );
    }

    return changes;
  }

  static List<ProgrammeWeekChange> compareWeeks(
    List<ProgrammeWeekReference> source,
    List<ProgrammeWeekReference> target,
  ) {
    final sourceByIndex = {for (final week in source) week.weekIndex: week};
    final targetByIndex = {for (final week in target) week.weekIndex: week};
    final indices = {...sourceByIndex.keys, ...targetByIndex.keys}.toList()
      ..sort();

    final changes = <ProgrammeWeekChange>[];
    for (final index in indices) {
      final sourceWeek = sourceByIndex[index];
      final targetWeek = targetByIndex[index];

      if (sourceWeek == null) {
        changes.add(
          ProgrammeWeekChange(
            changeType: ProgrammeChangeType.added,
            matchingBasis: 'weekIndex',
            targetWeek: targetWeek,
          ),
        );
        continue;
      }

      if (targetWeek == null) {
        changes.add(
          ProgrammeWeekChange(
            changeType: ProgrammeChangeType.removed,
            matchingBasis: 'weekIndex',
            sourceWeek: sourceWeek,
          ),
        );
        continue;
      }

      final changedFields = _changedFields(
        {
          'title': sourceWeek.title,
        },
        {
          'title': targetWeek.title,
        },
      );

      changes.add(
        ProgrammeWeekChange(
          changeType: changedFields.isEmpty
              ? ProgrammeChangeType.unchanged
              : ProgrammeChangeType.modified,
          matchingBasis: 'weekIndex',
          sourceWeek: sourceWeek,
          targetWeek: targetWeek,
          changedFields: changedFields,
        ),
      );
    }

    return changes;
  }

  static List<ProgrammeDayChange> compareDays(
    List<ProgrammeDayReference> source,
    List<ProgrammeDayReference> target,
  ) {
    StructuralDayKey keyFor(ProgrammeDayReference day) =>
        (weekIndex: day.weekIndex, dayKey: day.dayKey);

    final sourceByKey = {for (final day in source) keyFor(day): day};
    final targetByKey = {for (final day in target) keyFor(day): day};
    final keys = {...sourceByKey.keys, ...targetByKey.keys}.toList()
      ..sort((a, b) {
        final weekCompare = a.weekIndex.compareTo(b.weekIndex);
        if (weekCompare != 0) return weekCompare;
        return a.dayKey.compareTo(b.dayKey);
      });

    final changes = <ProgrammeDayChange>[];
    for (final key in keys) {
      final sourceDay = sourceByKey[key];
      final targetDay = targetByKey[key];

      if (sourceDay == null) {
        changes.add(
          ProgrammeDayChange(
            changeType: ProgrammeChangeType.added,
            matchingBasis: 'weekIndex+dayKey',
            targetDay: targetDay,
          ),
        );
        continue;
      }

      if (targetDay == null) {
        changes.add(
          ProgrammeDayChange(
            changeType: ProgrammeChangeType.removed,
            matchingBasis: 'weekIndex+dayKey',
            sourceDay: sourceDay,
          ),
        );
        continue;
      }

      final changedFields = _changedFields(
        {
          'title': sourceDay.title,
          'dayIndex': sourceDay.dayIndex.toString(),
        },
        {
          'title': targetDay.title,
          'dayIndex': targetDay.dayIndex.toString(),
        },
      );

      changes.add(
        ProgrammeDayChange(
          changeType: changedFields.isEmpty
              ? ProgrammeChangeType.unchanged
              : ProgrammeChangeType.modified,
          matchingBasis: 'weekIndex+dayKey',
          sourceDay: sourceDay,
          targetDay: targetDay,
          changedFields: changedFields,
        ),
      );
    }

    return changes;
  }

  static List<ProgrammeSlotChange> compareSlots({
    required List<ProgrammeSlotSnapshot> sourceSlots,
    required List<ProgrammeSlotSnapshot> targetSlots,
    required bool sameVersion,
  }) {
    final changes = <ProgrammeSlotChange>[];
    final unmatchedSource = <ProgrammeSlotSnapshot>[...sourceSlots];
    final unmatchedTarget = <ProgrammeSlotSnapshot>[...targetSlots];

    if (sameVersion) {
      final targetById = {for (final slot in targetSlots) slot.slotId: slot};
      for (final sourceSlot in sourceSlots) {
        final targetSlot = targetById[sourceSlot.slotId];
        if (targetSlot == null) continue;
        unmatchedSource.remove(sourceSlot);
        unmatchedTarget.remove(targetSlot);
        changes.add(
          _compareMatchedSlots(
            sourceSlot: sourceSlot,
            targetSlot: targetSlot,
            matchingBasis: ProgrammeSlotMatchingBasis.stableSlotId,
          ),
        );
      }
    } else {
      final targetById = {for (final slot in targetSlots) slot.slotId: slot};
      for (final sourceSlot in List<ProgrammeSlotSnapshot>.from(unmatchedSource)) {
        final targetSlot = targetById[sourceSlot.slotId];
        if (targetSlot == null) continue;
        unmatchedSource.remove(sourceSlot);
        unmatchedTarget.remove(targetSlot);
        changes.add(
          _compareMatchedSlots(
            sourceSlot: sourceSlot,
            targetSlot: targetSlot,
            matchingBasis: ProgrammeSlotMatchingBasis.stableSlotId,
          ),
        );
      }
    }

    final targetByStructure = {
      for (final slot in unmatchedTarget) _structuralSlotKey(slot): slot,
    };

    for (final sourceSlot in List<ProgrammeSlotSnapshot>.from(unmatchedSource)) {
      final key = _structuralSlotKey(sourceSlot);
      final targetSlot = targetByStructure[key];
      if (targetSlot == null) continue;

      unmatchedSource.remove(sourceSlot);
      unmatchedTarget.remove(targetSlot);
      targetByStructure.remove(key);
      changes.add(
        _compareMatchedSlots(
          sourceSlot: sourceSlot,
          targetSlot: targetSlot,
          matchingBasis: ProgrammeSlotMatchingBasis.structuralPosition,
        ),
      );
    }

    for (final sourceSlot in unmatchedSource) {
      changes.add(
        ProgrammeSlotChange(
          changeType: ProgrammeChangeType.removed,
          matchingBasis: ProgrammeSlotMatchingBasis.unmatched,
          sourceSlot: sourceSlot,
          sourcePosition: _positionLabel(sourceSlot),
        ),
      );
    }

    for (final targetSlot in unmatchedTarget) {
      changes.add(
        ProgrammeSlotChange(
          changeType: ProgrammeChangeType.added,
          matchingBasis: ProgrammeSlotMatchingBasis.unmatched,
          targetSlot: targetSlot,
          targetPosition: _positionLabel(targetSlot),
        ),
      );
    }

    changes.sort(_compareSlotChanges);
    return changes;
  }

  static ProgrammeSlotChange _compareMatchedSlots({
    required ProgrammeSlotSnapshot sourceSlot,
    required ProgrammeSlotSnapshot targetSlot,
    required ProgrammeSlotMatchingBasis matchingBasis,
  }) {
    final sourcePosition = _positionLabel(sourceSlot);
    final targetPosition = _positionLabel(targetSlot);
    final positionChanged = sourcePosition != targetPosition;

    if (matchingBasis == ProgrammeSlotMatchingBasis.stableSlotId &&
        positionChanged &&
        sourceSlot.protocolId == targetSlot.protocolId) {
      return ProgrammeSlotChange(
        changeType: ProgrammeChangeType.moved,
        matchingBasis: matchingBasis,
        sourceSlot: sourceSlot,
        targetSlot: targetSlot,
        changedFields: const ['position'],
        sourcePosition: sourcePosition,
        targetPosition: targetPosition,
      );
    }

    final changedFields = _changedSlotFields(sourceSlot, targetSlot);
    if (changedFields.isEmpty) {
      return ProgrammeSlotChange(
        changeType: ProgrammeChangeType.unchanged,
        matchingBasis: matchingBasis,
        sourceSlot: sourceSlot,
        targetSlot: targetSlot,
        sourcePosition: sourcePosition,
        targetPosition: targetPosition,
      );
    }

    if (changedFields.contains('protocolId')) {
      if (sourceSlot.sessionLineageId == targetSlot.sessionLineageId) {
        return ProgrammeSlotChange(
          changeType: ProgrammeChangeType.modified,
          matchingBasis: matchingBasis,
          sourceSlot: sourceSlot,
          targetSlot: targetSlot,
          changedFields: changedFields,
          sourcePosition: sourcePosition,
          targetPosition: targetPosition,
        );
      }

      return ProgrammeSlotChange(
        changeType: ProgrammeChangeType.replaced,
        matchingBasis: matchingBasis,
        sourceSlot: sourceSlot,
        targetSlot: targetSlot,
        changedFields: changedFields,
        sourcePosition: sourcePosition,
        targetPosition: targetPosition,
      );
    }

    if (positionChanged &&
        matchingBasis == ProgrammeSlotMatchingBasis.structuralPosition) {
      return ProgrammeSlotChange(
        changeType: ProgrammeChangeType.modified,
        matchingBasis: matchingBasis,
        sourceSlot: sourceSlot,
        targetSlot: targetSlot,
        changedFields: changedFields,
        sourcePosition: sourcePosition,
        targetPosition: targetPosition,
      );
    }

    return ProgrammeSlotChange(
      changeType: ProgrammeChangeType.modified,
      matchingBasis: matchingBasis,
      sourceSlot: sourceSlot,
      targetSlot: targetSlot,
      changedFields: changedFields,
      sourcePosition: sourcePosition,
      targetPosition: targetPosition,
    );
  }

  static List<SessionRevisionChange> deriveSessionRevisionChanges(
    List<ProgrammeSlotChange> slotChanges,
  ) {
    final byLineage = <String, SessionRevisionChange>{};

    for (final change in slotChanges) {
      if (change.changeType == ProgrammeChangeType.unchanged ||
          change.changeType == ProgrammeChangeType.added ||
          change.changeType == ProgrammeChangeType.removed) {
        continue;
      }

      final source = change.sourceSlot;
      final target = change.targetSlot;
      if (source == null || target == null) continue;
      if (source.protocolId == target.protocolId) continue;

      final lineageId = source.sessionLineageId == target.sessionLineageId
          ? source.sessionLineageId
          : '${source.sessionLineageId}->${target.sessionLineageId}';

      final existing = byLineage[lineageId];
      byLineage[lineageId] = SessionRevisionChange(
        sessionLineageId: source.sessionLineageId == target.sessionLineageId
            ? source.sessionLineageId
            : source.sessionLineageId,
        changeType: source.sessionLineageId == target.sessionLineageId
            ? ProgrammeChangeType.modified
            : ProgrammeChangeType.replaced,
        sourceProtocolId: source.protocolId,
        sourceRevisionNumber: source.sessionRevisionNumber,
        targetProtocolId: target.protocolId,
        targetRevisionNumber: target.sessionRevisionNumber,
        sourceSessionName: source.sessionName,
        targetSessionName: target.sessionName,
        sourceSlotReferences: [
          ...?existing?.sourceSlotReferences,
          _positionLabel(source),
        ],
        targetSlotReferences: [
          ...?existing?.targetSlotReferences,
          _positionLabel(target),
        ],
      );
    }

    final results = byLineage.values.toList()
      ..sort((a, b) => (a.sourceSessionName ?? '').compareTo(b.sourceSessionName ?? ''));
    return results;
  }

  static List<ExerciseReferenceChange> compareExercises(
    List<ExerciseReferenceChange> source,
    List<ExerciseReferenceChange> target,
  ) {
    final sourceById = {for (final item in source) item.exerciseId: item};
    final targetById = {for (final item in target) item.exerciseId: item};
    final ids = {...sourceById.keys, ...targetById.keys}.toList()..sort();

    return ids.map((exerciseId) {
      final sourceExercise = sourceById[exerciseId];
      final targetExercise = targetById[exerciseId];

      if (sourceExercise == null) {
        return ExerciseReferenceChange(
          exerciseId: exerciseId,
          exerciseName: targetExercise!.exerciseName,
          changeType: ProgrammeChangeType.added,
          sourceSessionRevisionIds: const [],
          targetSessionRevisionIds: targetExercise.targetSessionRevisionIds,
          sourceBlockLinkCount: 0,
          targetBlockLinkCount: targetExercise.targetBlockLinkCount,
        );
      }

      if (targetExercise == null) {
        return ExerciseReferenceChange(
          exerciseId: exerciseId,
          exerciseName: sourceExercise.exerciseName,
          changeType: ProgrammeChangeType.removed,
          sourceSessionRevisionIds: sourceExercise.sourceSessionRevisionIds,
          targetSessionRevisionIds: const [],
          sourceBlockLinkCount: sourceExercise.sourceBlockLinkCount,
          targetBlockLinkCount: 0,
        );
      }

      final changed = sourceExercise.sourceBlockLinkCount !=
              targetExercise.targetBlockLinkCount ||
          !_setEquals(
            sourceExercise.sourceSessionRevisionIds.toSet(),
            targetExercise.targetSessionRevisionIds.toSet(),
          );

      return ExerciseReferenceChange(
        exerciseId: exerciseId,
        exerciseName: targetExercise.exerciseName,
        changeType:
            changed ? ProgrammeChangeType.modified : ProgrammeChangeType.unchanged,
        sourceSessionRevisionIds: sourceExercise.sourceSessionRevisionIds,
        targetSessionRevisionIds: targetExercise.targetSessionRevisionIds,
        sourceBlockLinkCount: sourceExercise.sourceBlockLinkCount,
        targetBlockLinkCount: targetExercise.targetBlockLinkCount,
      );
    }).toList();
  }

  static ExerciseSetChange buildExerciseSetChange(
    List<ExerciseReferenceChange> source,
    List<ExerciseReferenceChange> target,
    bool sourceAuthoritative,
    bool targetAuthoritative,
  ) {
    if (!sourceAuthoritative || !targetAuthoritative) {
      return ExerciseSetChange(
        addedExercises: const [],
        removedExercises: const [],
        retainedExercises: const [],
        sourceExerciseCount: source.length,
        targetExerciseCount: target.length,
        netExerciseCountChange: 0,
      );
    }

    final sourceIds = source.map((e) => e.exerciseId).toSet();
    final targetIds = target.map((e) => e.exerciseId).toSet();

    final added = targetIds.difference(sourceIds).toList()..sort();
    final removed = sourceIds.difference(targetIds).toList()..sort();
    final retained = sourceIds.intersection(targetIds).toList()..sort();

    return ExerciseSetChange(
      addedExercises: added,
      removedExercises: removed,
      retainedExercises: retained,
      sourceExerciseCount: sourceIds.length,
      targetExerciseCount: targetIds.length,
      netExerciseCountChange: targetIds.length - sourceIds.length,
    );
  }

  static ProgrammeStructureMetrics buildStructureMetrics({
    required ProgrammeVersionComparisonSnapshot source,
    required ProgrammeVersionComparisonSnapshot target,
    required ExerciseSetChange exerciseSetChange,
  }) {
    final sourceTrainingDays =
        source.days.where((day) => day.dayKey.isNotEmpty).length;
    final targetTrainingDays =
        target.days.where((day) => day.dayKey.isNotEmpty).length;

    return ProgrammeStructureMetrics(
      sourceWeekCount: source.weeks.length,
      targetWeekCount: target.weeks.length,
      weekCountDelta: target.weeks.length - source.weeks.length,
      sourceTrainingDayCount: sourceTrainingDays,
      targetTrainingDayCount: targetTrainingDays,
      trainingDayCountDelta: targetTrainingDays - sourceTrainingDays,
      sourceSlotCount: source.slots.length,
      targetSlotCount: target.slots.length,
      slotCountDelta: target.slots.length - source.slots.length,
      sourceDistinctSessionRevisionCount: source.slots
          .map((slot) => slot.protocolId)
          .toSet()
          .length,
      targetDistinctSessionRevisionCount: target.slots
          .map((slot) => slot.protocolId)
          .toSet()
          .length,
      sessionRevisionCountDelta: target.slots
              .map((slot) => slot.protocolId)
              .toSet()
              .length -
          source.slots.map((slot) => slot.protocolId).toSet().length,
      sourceDistinctExerciseCount: exerciseSetChange.sourceExerciseCount,
      targetDistinctExerciseCount: exerciseSetChange.targetExerciseCount,
      exerciseCountDelta: exerciseSetChange.netExerciseCountChange,
    );
  }

  static List<ProgrammeComparisonClassification> buildClassifications({
    required List<ProgrammeMetadataChange> metadataChanges,
    required List<ProgrammeWeekChange> weekChanges,
    required List<ProgrammeDayChange> dayChanges,
    required List<ProgrammeSlotChange> slotChanges,
    required List<SessionRevisionChange> sessionRevisionChanges,
    required ExerciseSetChange exerciseSetChange,
    required bool isIdentical,
    required bool isPartial,
  }) {
    final classifications = <ProgrammeComparisonClassification>{};

    if (isPartial) {
      classifications.add(ProgrammeComparisonClassification.partialComparison);
    }

    if (isIdentical && !isPartial) {
      classifications.add(ProgrammeComparisonClassification.identical);
      return classifications.toList()..sort((a, b) => a.name.compareTo(b.name));
    }

    if (metadataChanges.isNotEmpty) {
      classifications.add(ProgrammeComparisonClassification.metadataChanged);
    }
    if (weekChanges.any((c) => c.changeType != ProgrammeChangeType.unchanged) ||
        dayChanges.any((c) => c.changeType != ProgrammeChangeType.unchanged)) {
      classifications.add(ProgrammeComparisonClassification.structureChanged);
    }
    if (slotChanges.any((c) => c.changeType == ProgrammeChangeType.added)) {
      classifications.add(ProgrammeComparisonClassification.sessionsAdded);
    }
    if (slotChanges.any((c) => c.changeType == ProgrammeChangeType.removed)) {
      classifications.add(ProgrammeComparisonClassification.sessionsRemoved);
    }
    if (slotChanges.any((c) => c.changeType == ProgrammeChangeType.moved)) {
      classifications.add(ProgrammeComparisonClassification.sessionsMoved);
    }
    if (sessionRevisionChanges.isNotEmpty) {
      classifications.add(
        ProgrammeComparisonClassification.sessionRevisionsUpdated,
      );
    }
    if (exerciseSetChange.addedExercises.isNotEmpty) {
      classifications.add(ProgrammeComparisonClassification.exercisesAdded);
    }
    if (exerciseSetChange.removedExercises.isNotEmpty) {
      classifications.add(ProgrammeComparisonClassification.exercisesRemoved);
    }

    return classifications.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  static Map<String, String?> extractComparableMetadata({
    required String name,
    String? description,
    int? durationWeeks,
    String? targetAthlete,
    String? difficulty,
    String? primaryGoal,
    String? equipmentRequirements,
    int? sessionsPerWeek,
  }) {
    return {
      'name': _normaliseMetadataValue(name),
      'description': _normaliseMetadataValue(description),
      'durationWeeks': durationWeeks?.toString(),
      'targetAthlete': _normaliseMetadataValue(targetAthlete),
      'difficulty': _normaliseMetadataValue(difficulty),
      'primaryGoal': _normaliseMetadataValue(primaryGoal),
      'equipmentRequirements': _normaliseMetadataValue(equipmentRequirements),
      'sessionsPerWeek': sessionsPerWeek?.toString(),
    };
  }

  static String? _normaliseMetadataValue(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _changedFields(
    Map<String, String?> source,
    Map<String, String?> target,
  ) {
    final fields = <String>[];
    for (final key in {...source.keys, ...target.keys}) {
      if (_normaliseMetadataValue(source[key]) !=
          _normaliseMetadataValue(target[key])) {
        fields.add(key);
      }
    }
    fields.sort();
    return fields;
  }

  static List<String> _changedSlotFields(
    ProgrammeSlotSnapshot source,
    ProgrammeSlotSnapshot target,
  ) {
    return _changedFields(
      {
        'protocolId': source.protocolId,
        'slotLabel': source.slotLabel,
        'timeOfDay': source.timeOfDay,
        'isOptional': source.isOptional.toString(),
        'completionExpectation': source.completionExpectation,
        'coachNote': source.coachNote,
        'athleteNote': source.athleteNote,
      },
      {
        'protocolId': target.protocolId,
        'slotLabel': target.slotLabel,
        'timeOfDay': target.timeOfDay,
        'isOptional': target.isOptional.toString(),
        'completionExpectation': target.completionExpectation,
        'coachNote': target.coachNote,
        'athleteNote': target.athleteNote,
      },
    );
  }

  static StructuralSlotKey _structuralSlotKey(ProgrammeSlotSnapshot slot) =>
      (weekIndex: slot.weekIndex, dayKey: slot.dayKey, slotIndex: slot.slotIndex);

  static String _positionLabel(ProgrammeSlotSnapshot slot) =>
      'Week ${slot.weekIndex} · ${slot.dayKey} · Slot ${slot.slotIndex}';

  static int _compareSlotChanges(ProgrammeSlotChange a, ProgrammeSlotChange b) {
    final sourceWeekA = a.sourceSlot?.weekIndex ?? a.targetSlot?.weekIndex ?? 0;
    final sourceWeekB = b.sourceSlot?.weekIndex ?? b.targetSlot?.weekIndex ?? 0;
    final weekCompare = sourceWeekA.compareTo(sourceWeekB);
    if (weekCompare != 0) return weekCompare;

    final dayA = a.sourceSlot?.dayIndex ?? a.targetSlot?.dayIndex ?? 0;
    final dayB = b.sourceSlot?.dayIndex ?? b.targetSlot?.dayIndex ?? 0;
    final dayCompare = dayA.compareTo(dayB);
    if (dayCompare != 0) return dayCompare;

    final slotA = a.sourceSlot?.slotIndex ?? a.targetSlot?.slotIndex ?? 0;
    final slotB = b.sourceSlot?.slotIndex ?? b.targetSlot?.slotIndex ?? 0;
    return slotA.compareTo(slotB);
  }

  static bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}
