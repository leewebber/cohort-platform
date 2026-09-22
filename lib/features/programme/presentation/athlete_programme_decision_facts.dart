import '../../../models/programme_vocabulary.dart';
import '../models/programme_catalog_entry.dart';
import 'athlete_programme_decision_copy.dart';

/// Authored catalogue facts for athlete discovery, detail, and comparison.
///
/// Does not invent emphasis, formats, progression, or rest from names.
class AthleteProgrammeDecisionFacts {
  const AthleteProgrammeDecisionFacts({
    required this.versionId,
    required this.title,
    required this.catalogueAvailable,
    required this.isCurrentProgramme,
    this.primaryGoal,
    this.intendedLevel,
    this.durationWeeks,
    this.sessionsPerWeek,
    this.equipment,
    this.summary,
    this.trainingEmphasis,
    this.sessionFormats,
    this.progression,
    this.recovery,
  });

  final String versionId;
  final String title;
  final String? primaryGoal;
  final String? intendedLevel;
  final int? durationWeeks;
  final int? sessionsPerWeek;
  final String? equipment;
  final String? summary;
  final String? trainingEmphasis;
  final String? sessionFormats;
  final String? progression;
  final String? recovery;
  final bool catalogueAvailable;
  final bool isCurrentProgramme;

  static const omitted = AthleteProgrammeDecisionCopy.notProvided;

  factory AthleteProgrammeDecisionFacts.fromEntry(
    ProgrammeCatalogEntry entry, {
    required bool isCurrentProgramme,
  }) {
    final name = entry.name.trim();
    return AthleteProgrammeDecisionFacts(
      versionId: entry.versionId,
      title: name.isEmpty ? 'Programme' : name,
      primaryGoal: _optional(entry.primaryGoal),
      intendedLevel: _optional(entry.difficulty),
      durationWeeks: entry.durationWeeks,
      sessionsPerWeek: entry.sessionsPerWeek,
      equipment: _optional(entry.equipmentRequirements),
      summary: _optional(entry.description),
      catalogueAvailable: _isAvailable(entry),
      isCurrentProgramme: isCurrentProgramme,
    );
  }

  String get goalLabel => primaryGoal ?? omitted;
  String get levelLabel => intendedLevel ?? omitted;
  String get durationLabel => durationDisplay ?? omitted;
  String get frequencyLabel => frequencyDisplay ?? omitted;
  String get equipmentLabel => equipment ?? omitted;
  String get summaryLabel => summary ?? omitted;
  String get statusLabel => isCurrentProgramme
      ? AthleteProgrammeDecisionCopy.currentProgramme
      : (catalogueAvailable
            ? AthleteProgrammeDecisionCopy.available
            : AthleteProgrammeDecisionCopy.unavailable);
  String get emphasisLabel => trainingEmphasis ?? omitted;
  String get formatsLabel => sessionFormats ?? omitted;
  String get progressionLabel => progression ?? omitted;
  String get recoveryLabel => recovery ?? omitted;

  String? get durationDisplay =>
      durationWeeks == null ? null : '$durationWeeks weeks';
  String? get frequencyDisplay =>
      sessionsPerWeek == null ? null : '$sessionsPerWeek sessions / week';

  bool get hasSupportingInformation =>
      trainingEmphasis != null ||
      sessionFormats != null ||
      progression != null ||
      recovery != null;

  List<(String, String?)> get supportingFacts => [
    ('Training emphasis', trainingEmphasis),
    ('Session formats', sessionFormats),
    ('Progression', progression),
    ('Recovery', recovery),
  ];

  String glanceValue(String? authored) =>
      authored ?? AthleteProgrammeDecisionCopy.notSpecified;

  static String compareValue(String? authored) =>
      authored ?? AthleteProgrammeDecisionCopy.notSpecified;

  static String? _optional(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static bool _isAvailable(ProgrammeCatalogEntry entry) {
    return entry.lifecycleStatus == ProgrammeLifecycleStatus.published &&
        entry.approvedForGlobal &&
        entry.archivedAt == null &&
        !entry.hasBlockingValidationErrors;
  }
}
