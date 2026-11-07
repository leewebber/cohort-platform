import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../features/authored_plan_package/plan_package_manifest.dart';
import '../../features/authored_plan_package/plan_package_schema.dart';

/// Reads the exact authored version through the athlete's existing RLS scope.
class ProgrammeAdaptationPermissionReader {
  const ProgrammeAdaptationPermissionReader({this._client});

  final SupabaseClient? _client;

  Future<List<PlanPackageAdaptationPermission>> load(String versionId) async {
    final rows = await (_client ?? SupabaseService.client)
        .from('programme_version_adaptation_permissions')
        .select(
          'permission_key,change_kind,target_ref,athlete_agreement_required',
        )
        .eq('version_id', versionId);
    return [
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
}
