import 'plan_assignment.dart';
import 'plan_definition.dart';

/// Stable identity for a coach-authored programmed session within a Plan version.
///
/// Same planId + planVersion + week + day ⇒ same programmed session structure.
class ProgrammedSessionKey {
  const ProgrammedSessionKey({
    required this.planId,
    required this.planVersion,
    required this.week,
    required this.day,
  });

  final String planId;
  final String planVersion;
  final int week;
  final int day;

  String get value => '$planId@$planVersion:w$week:d$day';

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

  factory ProgrammedSessionKey.parse(String raw) {
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
  };

  factory ProgrammedSessionKey.fromPersistenceMap(Map<String, dynamic> map) {
    final key = map['key']?.toString();
    if (key != null && key.contains('@')) {
      return ProgrammedSessionKey.parse(key);
    }
    return ProgrammedSessionKey(
      planId: map['planId']?.toString() ?? '',
      planVersion: map['planVersion']?.toString() ?? '1.0.0',
      week: (map['week'] as num?)?.toInt() ?? 1,
      day: (map['day'] as num?)?.toInt() ?? 1,
    );
  }
}
