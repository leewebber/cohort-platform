import '../../domain/adaptation/adaptation_domain.dart';
import '../../features/adaptation/services/adaptation_policy_gate.dart';
import '../../features/authored_plan_package/plan_package_manifest.dart';
import '../../features/programme/models/programme_execution_context.dart';
import '../../features/session/models/prepared_execution_package.dart';
import '../../models/protocol_draft.dart';
import '../../models/session_block_type.dart';

typedef ProgrammeTimeApprovalLoader =
    Future<ApprovedTimeOption?> Function(ProgrammeExecutionContext context);

/// The immutable, assignment-scoped approval returned by the private reader.
class ApprovedTimeOption {
  ApprovedTimeOption.fromJson(Map<String, dynamic> json)
    : slotKey = json['slot_key'] as String,
      protocolId = json['protocol_id'] as String,
      packageHash = json['package_hash'] as String,
      fullMinutes = json['full_minutes'] as int,
      shortMinutes = json['short_minutes'] as int,
      omittedPosition = json['omitted_block_position'] as int,
      intent = SessionIntentDb.fromDb(json['session_intent'] as String),
      permission = PlanPackageAdaptationPermission(
        id: json['permission_key'] as String,
        changeKind: AdaptationChangeKind.removeOptionalAccessories,
        targetRef: json['slot_key'] as String,
        athleteAgreementRequired: true,
      );

  static const provenance = 'approval:private-time-option-v1';
  final String slotKey;
  final String protocolId;
  final String packageHash;
  final int fullMinutes;
  final int shortMinutes;
  final int omittedPosition;
  final SessionIntent? intent;
  final PlanPackageAdaptationPermission permission;

  /// Project the sealed policy for evaluation. The actual prepared blocks,
  /// identities, timers and strength prescriptions remain the original objects.
  ProtocolDraft authorize({
    required PreparedExecutionPackage package,
    required ProgrammeExecutionContext? context,
    required ProtocolDraft draft,
  }) {
    if (context == null ||
        context.packageSchemaVersion != 2 ||
        context.occurrenceId?.isNotEmpty != true ||
        context.packageSlotKey != slotKey ||
        context.assignmentId != package.assignmentId ||
        context.programmeVersionId != package.programmeVersionId ||
        context.programmedSessionKey != package.programmedSessionKey.value ||
        context.packageContentHash != packageHash ||
        package.packageContentHash != packageHash ||
        context.effectiveProtocolId != protocolId ||
        package.protocolId != protocolId ||
        draft.protocolId != protocolId ||
        intent != SessionIntent.upperBodyStrength ||
        fullMinutes <= shortMinutes ||
        shortMinutes <= 0 ||
        permission.id.isEmpty) {
      throw StateError('Private time approval does not match this session.');
    }
    final omitted = draft.blocks.singleWhere(
      (b) => b.position == omittedPosition,
    );
    if (omitted.blockType != SessionBlockType.accessory) {
      throw StateError('The approved omission is not an accessory block.');
    }
    return draft.copyWith(
      durationMin: fullMinutes,
      minimumViableDurationMin: shortMinutes,
      primarySessionIntent: intent,
      blocks: [
        for (final block in draft.blocks)
          block.copyWith(
            blockPriority: identical(block, omitted)
                ? BlockPriority.optional
                : BlockPriority.essential,
            adaptationPolicy: BlockAdaptationPolicy(
              canRemove: identical(block, omitted),
              canShorten: false,
              canReduceVolume: false,
              canReduceIntensity: false,
              canIncreaseRest: false,
              canSuperset: false,
              canReplaceExercises: false,
              canReplaceBlock: false,
            ),
          ),
      ],
    );
  }
}
