import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../features/authored_plan_package/plan_package_manifest.dart';
import '../../features/authored_plan_package/plan_package_schema.dart';
import '../../features/programme/models/programme_execution_context.dart';
import 'approved_equipment_substitution.dart';
import 'approved_time_option.dart';

/// Reads the exact authored version through the athlete's existing RLS scope.
class ProgrammeAdaptationPermissionReader {
  const ProgrammeAdaptationPermissionReader({this._client});

  final SupabaseClient? _client;

  Future<List<PlanPackageAdaptationPermission>> load(
    String versionId,
  ) async => _parse(
    await (_client ?? SupabaseService.client)
        .from('programme_version_adaptation_permissions')
        .select(
          'permission_key,change_kind,target_ref,athlete_agreement_required',
        )
        .eq('version_id', versionId),
  );

  Future<ApprovedEquipmentSubstitution?> loadApprovedEquipment(
    ProgrammeExecutionContext context,
  ) async {
    if (context.occurrenceId == null || context.packageSlotKey == null) {
      return null;
    }
    final raw = await (_client ?? SupabaseService.client).rpc(
      'read_my_approved_equipment_substitution_v1',
      params: {
        'p_assignment_id': context.assignmentId,
        'p_version_id': context.programmeVersionId,
        'p_occurrence_id': context.occurrenceId,
        'p_slot_key': context.packageSlotKey,
      },
    );
    return raw == null
        ? null
        : ApprovedEquipmentSubstitution.fromJson(
            Map<String, dynamic>.from(raw as Map),
          );
  }

  Future<ApprovedTimeOption?> loadApprovedTime(
    ProgrammeExecutionContext context,
  ) async {
    if (context.occurrenceId == null || context.packageSlotKey == null) {
      return null;
    }
    final raw = await (_client ?? SupabaseService.client).rpc(
      'read_my_approved_time_option_v1',
      params: {
        'p_assignment_id': context.assignmentId,
        'p_version_id': context.programmeVersionId,
        'p_occurrence_id': context.occurrenceId,
        'p_slot_key': context.packageSlotKey,
      },
    );
    return raw == null
        ? null
        : ApprovedTimeOption.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  List<PlanPackageAdaptationPermission> _parse(List rows) => [
    for (final row in rows)
      if (row case {
        'permission_key': final String key,
        'change_kind': final String changeKind,
        'target_ref': final String target,
        'athlete_agreement_required': true,
      })
        if (PlanPackageSchema.adaptationKindFromYaml(changeKind)
            case final kind?
            when key.trim().isNotEmpty && target.trim().isNotEmpty)
          PlanPackageAdaptationPermission(
            id: key,
            changeKind: kind,
            targetRef: target,
            athleteAgreementRequired: true,
          ),
  ];
}
