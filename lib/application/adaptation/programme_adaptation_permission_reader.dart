import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../features/authored_plan_package/plan_package_manifest.dart';
import '../../features/authored_plan_package/plan_package_schema.dart';

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

  Future<List<PlanPackageAdaptationPermission>> loadThursdayTrial({
    required String assignmentId,
    required String versionId,
    required String slotKey,
  }) async => _parse(
    await (_client ?? SupabaseService.client).rpc(
          'read_m31_thursday_trial_permission',
          params: {
            'p_assignment_id': assignmentId,
            'p_version_id': versionId,
            'p_slot_key': slotKey,
          },
        )
        as List,
  );

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
