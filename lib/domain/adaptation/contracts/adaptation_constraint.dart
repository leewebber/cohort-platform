import 'adaptation_constraint_kind.dart';
import '../vocabulary/adaptation_constraint_scope.dart';
import '../vocabulary/adaptation_constraint_severity.dart';

/// A hard or soft limit derived from athlete input, programme context, or policy.
class AdaptationConstraint {
  const AdaptationConstraint({
    required this.kind,
    required this.scope,
    required this.severity,
    required this.isHard,
    this.availableMinutes,
    this.availableEquipment = const {},
    this.trainingEnvironment,
    this.recoveryStateLabel,
    this.affectedBlockIds = const [],
    this.affectedExerciseIds = const [],
    this.affectedEquipmentTokens = const {},
    this.notes,
  });

  final AdaptationConstraintKind kind;
  final AdaptationConstraintScope scope;
  final AdaptationConstraintSeverity severity;
  final bool isHard;

  final int? availableMinutes;
  final Set<String> availableEquipment;
  final String? trainingEnvironment;
  final String? recoveryStateLabel;
  final List<String> affectedBlockIds;
  final List<String> affectedExerciseIds;
  final Set<String> affectedEquipmentTokens;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'kind': kind.dbValue,
      'scope': scope.dbValue,
      'severity': severity.dbValue,
      'is_hard': isHard,
      if (availableMinutes != null) 'available_minutes': availableMinutes,
      if (availableEquipment.isNotEmpty)
        'available_equipment': availableEquipment.toList(),
      if (trainingEnvironment != null)
        'training_environment': trainingEnvironment,
      if (recoveryStateLabel != null) 'recovery_state_label': recoveryStateLabel,
      if (affectedBlockIds.isNotEmpty) 'affected_block_ids': affectedBlockIds,
      if (affectedExerciseIds.isNotEmpty)
        'affected_exercise_ids': affectedExerciseIds,
      if (affectedEquipmentTokens.isNotEmpty)
        'affected_equipment_tokens': affectedEquipmentTokens.toList(),
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }

  factory AdaptationConstraint.fromJson(Map<String, dynamic> json) {
    return AdaptationConstraint(
      kind: AdaptationConstraintKindDb.fromDb(json['kind']?.toString()) ??
          AdaptationConstraintKind.unknown,
      scope: AdaptationConstraintScopeDb.fromDb(json['scope']?.toString()) ??
          AdaptationConstraintScope.session,
      severity:
          AdaptationConstraintSeverityDb.fromDb(json['severity']?.toString()) ??
              AdaptationConstraintSeverity.moderate,
      isHard: json['is_hard'] == true,
      availableMinutes: json['available_minutes'] as int?,
      availableEquipment: _stringSet(json['available_equipment']),
      trainingEnvironment: json['training_environment']?.toString(),
      recoveryStateLabel: json['recovery_state_label']?.toString(),
      affectedBlockIds: _stringList(json['affected_block_ids']),
      affectedExerciseIds: _stringList(json['affected_exercise_ids']),
      affectedEquipmentTokens: _stringSet(json['affected_equipment_tokens']),
      notes: json['notes']?.toString(),
    );
  }

  static Set<String> _stringSet(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toSet();
    }
    return {};
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }
}
