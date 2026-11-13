import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../features/authored_plan_package/plan_package_manifest.dart';
import '../../features/authored_plan_package/plan_package_schema.dart';
import '../../features/programme/models/programme_execution_context.dart';
import '../../features/session/models/session_execution_plan.dart';
import '../../models/session_block.dart';
import '../../models/session_block_exercise_link.dart';
import 'approved_equipment_substitution.dart';
import 'approved_recovery_option.dart';
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

  static const _recoveryVersion = '7e1d15e7-20ee-46d4-b5e9-0d6449010330';

  Future<ApprovedRecoveryOption?> loadApprovedRecovery(
    ProgrammeExecutionContext context,
  ) async {
    if (context.programmeVersionId != _recoveryVersion ||
        context.sessionSlotId.trim().isEmpty ||
        context.occurrenceId?.trim().isNotEmpty != true) {
      return null;
    }
    final raw = await (_client ?? SupabaseService.client).rpc(
      'read_my_approved_recovery_option_v1',
      params: {
        'p_assignment_id': context.assignmentId,
        'p_version_id': context.programmeVersionId,
        'p_slot_id': context.sessionSlotId,
        'p_occurrence_id': context.occurrenceId,
        'p_protocol_id': context.effectiveProtocolId,
      },
    );
    if (raw == null) return null;
    final row = Map<String, dynamic>.from(raw as Map);
    final omission = ApprovedAccessoryOmission.fromJson(row);

    // Rebuild the expected original from the server's seal, independently of
    // the prepared or cached plan that RecoveryReview must verify.
    final plan = SessionExecutionPlan(
      sessionId: omission.protocolId,
      sessionTitle: row['session_title'] as String,
      programmeContextLabel: row['programme_name'] as String,
      durationMin: row['duration_min'] as int?,
      coachNotes: row['coach_notes'] as String?,
      blocks: [
        for (final block
            in (row['blocks'] as List).cast<Map<String, dynamic>>())
          SessionExecutionBlock.fromSessionBlock(
            SessionBlock.fromRow(
              block,
              linkedExercises: [
                for (final link
                    in (block['exercises'] as List)
                        .cast<Map<String, dynamic>>())
                  SessionBlockExerciseLink.fromRow(link),
              ],
            ),
            // All three sealed links carry an authored display label.
            exercisesById: const {},
          ),
      ],
    );
    return ApprovedRecoveryOption(
      athleteId: row['athlete_id'] as String,
      assignmentId: row['assignment_id'] as String,
      versionId: row['version_id'] as String,
      slotId: row['slot_id'] as String,
      occurrenceId: row['occurrence_id'] as String,
      scheduledDate: row['scheduled_date'] as String,
      scopeSealHash: row['scope_seal_hash'] as String,
      omission: omission,
      originalPlan: plan,
    );
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
