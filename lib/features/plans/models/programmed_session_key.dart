import '../../../models/programme_assignment.dart';
import 'plan_assignment.dart';
import 'plan_definition.dart';

/// Stable identity for a coach-authored programmed session.
///
/// Plan Library shape: `planId@planVersion:wN:dM`
/// Programme shape: `prog:{assignmentId}@{programmeVersionId}:wN:{dayKey}:sS:{protocolId}`
///
/// Same authoritative inputs ⇒ same programmed session structure.
class ProgrammedSessionKey {
  const ProgrammedSessionKey({
    required this.planId,
    required this.planVersion,
    required this.week,
    required this.day,
    this.dayKey,
    this.slotOrder,
    this.protocolId,
    this.programmeAssignmentId,
    this.packageContentHash,
    this.scheduleDate,
  });

  /// Plan Library plan id, or lineage code for programme-shaped keys.
  final String planId;

  /// Plan Library semver, or exact `programme_version_id` for programme keys.
  final String planVersion;
  final int week;

  /// Plan Library day ordinal, or day number parsed from [dayKey].
  final int day;

  /// Programme ordinal day key (`day_1`, …). Null for Plan Library keys.
  final String? dayKey;

  /// Programme slot order. Null for Plan Library keys.
  final int? slotOrder;

  /// Authored bank/session protocol id for programme keys.
  final String? protocolId;

  /// Materialised `programme_assignments.id` for programme keys.
  final String? programmeAssignmentId;

  /// Materialised package content hash provenance.
  final String? packageContentHash;

  /// Programme schedule date (materialisation start anchor for v1).
  final DateTime? scheduleDate;

  bool get isProgrammeShaped =>
      programmeAssignmentId != null && programmeAssignmentId!.isNotEmpty;

  String get value {
    if (isProgrammeShaped) {
      final keyDay = dayKey ?? 'day_$day';
      final slot = slotOrder ?? 1;
      final protocol = protocolId ?? '';
      return 'prog:$programmeAssignmentId@$planVersion:w$week:$keyDay:s$slot:$protocol';
    }
    return '$planId@$planVersion:w$week:d$day';
  }

  factory ProgrammedSessionKey.fromPlan({
    required PlanDefinition plan,
    required PlanAssignment assignment,
  }) {
    return ProgrammedSessionKey(
      planId: plan.planId,
      planVersion: plan.version,
      week: assignment.currentWeek,
      day: assignment.currentDay,
    );
  }

  /// Programme-shaped key from a materialised assignment + authored protocol.
  factory ProgrammedSessionKey.fromMaterialisedProgramme({
    required ProgrammeAssignment assignment,
    required String protocolId,
    required String packageContentHash,
    DateTime? scheduleDate,
  }) {
    final dayKey = assignment.currentDayKey.trim();
    final dayNumber = _dayNumberFromKey(dayKey);
    return ProgrammedSessionKey(
      planId: assignment.lineageCode,
      planVersion: assignment.programmeVersionId,
      week: assignment.currentWeek,
      day: dayNumber,
      dayKey: dayKey,
      slotOrder: assignment.currentSessionOrder,
      protocolId: protocolId.trim(),
      programmeAssignmentId: assignment.id,
      packageContentHash: packageContentHash.trim(),
      scheduleDate: scheduleDate ?? assignment.startedAt,
    );
  }

  factory ProgrammedSessionKey.parse(String raw) {
    if (raw.startsWith('prog:')) {
      return _parseProgramme(raw);
    }
    final at = raw.indexOf('@');
    final colon = raw.indexOf(':');
    if (at <= 0 || colon <= at) {
      throw FormatException('Invalid ProgrammedSessionKey: $raw');
    }
    final planId = raw.substring(0, at);
    final planVersion = raw.substring(at + 1, colon);
    final rest = raw.substring(colon + 1); // wN:dM
    final parts = rest.split(':');
    if (parts.length != 2 ||
        !parts[0].startsWith('w') ||
        !parts[1].startsWith('d')) {
      throw FormatException('Invalid ProgrammedSessionKey: $raw');
    }
    return ProgrammedSessionKey(
      planId: planId,
      planVersion: planVersion,
      week: int.parse(parts[0].substring(1)),
      day: int.parse(parts[1].substring(1)),
    );
  }

  static ProgrammedSessionKey _parseProgramme(String raw) {
    // prog:{assignmentId}@{versionId}:wN:day_K:sS:protocolId
    final body = raw.substring('prog:'.length);
    final at = body.indexOf('@');
    if (at <= 0) {
      throw FormatException('Invalid programme ProgrammedSessionKey: $raw');
    }
    final assignmentId = body.substring(0, at);
    final afterAt = body.substring(at + 1);
    final colon = afterAt.indexOf(':');
    if (colon <= 0) {
      throw FormatException('Invalid programme ProgrammedSessionKey: $raw');
    }
    final versionId = afterAt.substring(0, colon);
    final parts = afterAt.substring(colon + 1).split(':');
    if (parts.length < 4 ||
        !parts[0].startsWith('w') ||
        !parts[1].startsWith('day_') ||
        !parts[2].startsWith('s')) {
      throw FormatException('Invalid programme ProgrammedSessionKey: $raw');
    }
    final week = int.parse(parts[0].substring(1));
    final dayKey = parts[1];
    final slot = int.parse(parts[2].substring(1));
    final protocolId = parts.sublist(3).join(':');
    return ProgrammedSessionKey(
      planId: '',
      planVersion: versionId,
      week: week,
      day: _dayNumberFromKey(dayKey),
      dayKey: dayKey,
      slotOrder: slot,
      protocolId: protocolId,
      programmeAssignmentId: assignmentId,
    );
  }

  static int _dayNumberFromKey(String dayKey) {
    final match = RegExp(r'^day_([1-9][0-9]*)$').firstMatch(dayKey.trim());
    if (match == null) {
      throw FormatException('Invalid programme day key: $dayKey');
    }
    return int.parse(match.group(1)!);
  }

  @override
  bool operator ==(Object other) =>
      other is ProgrammedSessionKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;

  Map<String, dynamic> toPersistenceMap() => {
    'planId': planId,
    'planVersion': planVersion,
    'week': week,
    'day': day,
    'key': value,
    if (dayKey != null) 'dayKey': dayKey,
    if (slotOrder != null) 'slotOrder': slotOrder,
    if (protocolId != null) 'protocolId': protocolId,
    if (programmeAssignmentId != null)
      'programmeAssignmentId': programmeAssignmentId,
    if (packageContentHash != null) 'packageContentHash': packageContentHash,
    if (scheduleDate != null)
      'scheduleDate': scheduleDate!.toUtc().toIso8601String(),
  };

  factory ProgrammedSessionKey.fromPersistenceMap(Map<String, dynamic> map) {
    final key = map['key']?.toString();
    if (key != null && key.contains('@')) {
      final parsed = ProgrammedSessionKey.parse(key);
      final hash = map['packageContentHash']?.toString();
      final scheduleRaw = map['scheduleDate']?.toString();
      final schedule = scheduleRaw == null
          ? null
          : DateTime.tryParse(scheduleRaw)?.toUtc();
      if (hash == null && schedule == null && map['planId'] == null) {
        return parsed;
      }
      return ProgrammedSessionKey(
        planId: map['planId']?.toString().isNotEmpty == true
            ? map['planId'].toString()
            : parsed.planId,
        planVersion: parsed.planVersion,
        week: parsed.week,
        day: parsed.day,
        dayKey: parsed.dayKey,
        slotOrder: parsed.slotOrder,
        protocolId: parsed.protocolId,
        programmeAssignmentId: parsed.programmeAssignmentId,
        packageContentHash: hash ?? parsed.packageContentHash,
        scheduleDate: schedule ?? parsed.scheduleDate,
      );
    }
    return ProgrammedSessionKey(
      planId: map['planId']?.toString() ?? '',
      planVersion: map['planVersion']?.toString() ?? '1.0.0',
      week: (map['week'] as num?)?.toInt() ?? 1,
      day: (map['day'] as num?)?.toInt() ?? 1,
      dayKey: map['dayKey']?.toString(),
      slotOrder: (map['slotOrder'] as num?)?.toInt(),
      protocolId: map['protocolId']?.toString(),
      programmeAssignmentId: map['programmeAssignmentId']?.toString(),
      packageContentHash: map['packageContentHash']?.toString(),
    );
  }
}
