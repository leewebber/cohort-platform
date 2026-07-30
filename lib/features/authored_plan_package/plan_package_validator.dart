import '../../models/programme_vocabulary.dart';
import '../adaptation/services/adaptation_policy_gate.dart';
import 'plan_package_manifest.dart';
import 'plan_package_validation_issue.dart';

/// Semantic validation for a parsed [PlanPackageManifest].
///
/// Pure: no database, network, Coach Brain, or generation side effects.
class PlanPackageValidator {
  const PlanPackageValidator();

  List<PlanPackageValidationIssue> validate(PlanPackageManifest manifest) {
    final issues = <PlanPackageValidationIssue>[];

    _validateUniqueIdentities(manifest, issues);
    _validatePhases(manifest, issues);
    _validateWeekOrdering(manifest, issues);
    _validateDaysAndSlots(manifest, issues);
    _validateSessionReferences(manifest, issues);
    _validateAssessmentsAndComparisons(manifest, issues);
    _validateAdaptationsAndInvariants(manifest, issues);
    _validateAuthoredProgressionCompleteness(manifest, issues);
    _validateNoMutableBuilderSemantics(manifest, issues);

    return List.unmodifiable(issues);
  }

  void _validateUniqueIdentities(
    PlanPackageManifest manifest,
    List<PlanPackageValidationIssue> issues,
  ) {
    _assertUnique(
      manifest.sessions.map((s) => s.sessionKey),
      'sessions',
      'session_key',
      issues,
    );
    _assertUnique(
      manifest.sessions.map((s) => s.protocolId),
      'sessions',
      'protocol_id',
      issues,
    );

    _assertUnique(
      manifest.phases.map((p) => p.phaseKey),
      'phases',
      'phase_key',
      issues,
    );
    _assertUnique(
      manifest.phases.map((p) => p.phaseOrder),
      'phases',
      'phase_order',
      issues,
    );

    _assertUnique(
      manifest.weeks.map((w) => w.weekNumber),
      'weeks',
      'week_number',
      issues,
    );

    final slotKeys = <String>[];
    for (final week in manifest.weeks) {
      for (final day in week.days) {
        for (final slot in day.slots) {
          slotKeys.add(slot.slotKey);
        }
      }
    }
    _assertUnique(slotKeys, 'slots', 'slot_key', issues);

    _assertUnique(
      manifest.adaptationPermissions.map((a) => a.id),
      'adaptation_permissions',
      'id',
      issues,
    );
    _assertUnique(
      manifest.protectedInvariants.map((i) => i.id),
      'protected_invariants',
      'id',
      issues,
    );
    _assertUnique(
      manifest.assessments.map((a) => a.id),
      'assessments',
      'id',
      issues,
    );
    _assertUnique(
      manifest.performanceEvidenceRequirements.map((e) => e.id),
      'performance_evidence_requirements',
      'id',
      issues,
    );
    _assertUnique(
      manifest.comparisonIdentities.map((c) => c.id),
      'comparison_identities',
      'id',
      issues,
    );
  }

  void _validatePhases(
    PlanPackageManifest manifest,
    List<PlanPackageValidationIssue> issues,
  ) {
    if (manifest.phases.isEmpty) return;

    final orders = manifest.phases.map((p) => p.phaseOrder).toList()..sort();
    for (var i = 0; i < orders.length; i++) {
      if (orders[i] != i + 1) {
        issues.add(
          const PlanPackageValidationIssue(
            path: 'phases',
            code: 'phase_order_gap',
            message: 'phase_order values must be contiguous starting at 1.',
          ),
        );
        break;
      }
    }

    final phaseKeys = manifest.phases.map((p) => p.phaseKey).toSet();
    for (var wi = 0; wi < manifest.weeks.length; wi++) {
      final week = manifest.weeks[wi];
      final phaseKey = week.phaseKey;
      if (phaseKey != null && !phaseKeys.contains(phaseKey)) {
        issues.add(
          PlanPackageValidationIssue(
            path: 'weeks[$wi].phase_key',
            code: 'broken_reference',
            message: 'Week references unknown phase_key "$phaseKey".',
          ),
        );
      }
    }
  }

  void _validateWeekOrdering(
    PlanPackageManifest manifest,
    List<PlanPackageValidationIssue> issues,
  ) {
    if (manifest.weeks.isEmpty) {
      issues.add(
        const PlanPackageValidationIssue(
          path: 'weeks',
          code: 'incomplete_structure',
          message:
              'Programme must declare at least one week; compilation will not '
              'invent schedule structure.',
        ),
      );
      return;
    }

    final numbers = manifest.weeks.map((w) => w.weekNumber).toList()..sort();
    for (var i = 0; i < numbers.length; i++) {
      if (numbers[i] != i + 1) {
        issues.add(
          const PlanPackageValidationIssue(
            path: 'weeks',
            code: 'week_order_gap',
            message: 'week_number values must be contiguous starting at 1.',
          ),
        );
        break;
      }
    }

    final duration = manifest.programme.durationWeeks;
    if (duration != null && duration != manifest.weeks.length) {
      issues.add(
        PlanPackageValidationIssue(
          path: 'programme.duration_weeks',
          code: 'duration_mismatch',
          message:
              'duration_weeks ($duration) must equal authored week count '
              '(${manifest.weeks.length}).',
        ),
      );
    }
  }

  void _validateDaysAndSlots(
    PlanPackageManifest manifest,
    List<PlanPackageValidationIssue> issues,
  ) {
    for (var wi = 0; wi < manifest.weeks.length; wi++) {
      final week = manifest.weeks[wi];
      final weekPath = 'weeks[$wi]';

      if (week.days.isEmpty) {
        issues.add(
          PlanPackageValidationIssue(
            path: '$weekPath.days',
            code: 'incomplete_structure',
            message:
                'Week ${week.weekNumber} has no days; schedule will not be '
                'invented.',
          ),
        );
        continue;
      }

      final dayKeys = <String>{};
      final dayOrders = <int>{};
      for (var di = 0; di < week.days.length; di++) {
        final day = week.days[di];
        final dayPath = '$weekPath.days[$di]';

        if (!dayKeys.add(day.dayKey)) {
          issues.add(
            PlanPackageValidationIssue(
              path: '$dayPath.day_key',
              code: 'duplicate_id',
              message: 'Duplicate day_key "${day.dayKey}" in week.',
            ),
          );
        }
        if (!dayOrders.add(day.dayOrder)) {
          issues.add(
            PlanPackageValidationIssue(
              path: '$dayPath.day_order',
              code: 'duplicate_id',
              message: 'Duplicate day_order ${day.dayOrder} in week.',
            ),
          );
        }

        switch (day.dayType) {
          case ProgrammeDayType.rest:
            if (day.slots.isNotEmpty) {
              issues.add(
                PlanPackageValidationIssue(
                  path: '$dayPath.slots',
                  code: 'impossible_schedule',
                  message: 'Rest days must not schedule session slots.',
                ),
              );
            }
          case ProgrammeDayType.training:
            if (day.slots.isEmpty) {
              issues.add(
                PlanPackageValidationIssue(
                  path: '$dayPath.slots',
                  code: 'incomplete_structure',
                  message:
                      'Training days must reference at least one session; '
                      'missing sessions will not be generated.',
                ),
              );
            }
          case ProgrammeDayType.optional:
            break;
        }

        final slotOrders = <int>{};
        for (var si = 0; si < day.slots.length; si++) {
          final slot = day.slots[si];
          final slotPath = '$dayPath.slots[$si]';
          if (!slotOrders.add(slot.sessionOrder)) {
            issues.add(
              PlanPackageValidationIssue(
                path: '$slotPath.session_order',
                code: 'duplicate_id',
                message: 'Duplicate session_order ${slot.sessionOrder}.',
              ),
            );
          }
        }

        if (day.slots.isNotEmpty) {
          final sortedOrders = day.slots.map((s) => s.sessionOrder).toList()
            ..sort();
          for (var i = 0; i < sortedOrders.length; i++) {
            if (sortedOrders[i] != i + 1) {
              issues.add(
                PlanPackageValidationIssue(
                  path: '$dayPath.slots',
                  code: 'slot_order_gap',
                  message:
                      'session_order values must be contiguous starting at 1.',
                ),
              );
              break;
            }
          }
        }
      }

      final sortedDayOrders = week.days.map((d) => d.dayOrder).toList()..sort();
      for (var i = 0; i < sortedDayOrders.length; i++) {
        if (sortedDayOrders[i] != i + 1) {
          issues.add(
            PlanPackageValidationIssue(
              path: '$weekPath.days',
              code: 'day_order_gap',
              message: 'day_order values must be contiguous starting at 1.',
            ),
          );
          break;
        }
      }
    }
  }

  void _validateSessionReferences(
    PlanPackageManifest manifest,
    List<PlanPackageValidationIssue> issues,
  ) {
    if (manifest.sessions.isEmpty) {
      issues.add(
        const PlanPackageValidationIssue(
          path: 'sessions',
          code: 'incomplete_structure',
          message:
              'Package must declare at least one session revision reference.',
        ),
      );
    }

    final byKey = {for (final s in manifest.sessions) s.sessionKey: s};

    for (var wi = 0; wi < manifest.weeks.length; wi++) {
      final week = manifest.weeks[wi];
      for (var di = 0; di < week.days.length; di++) {
        final day = week.days[di];
        for (var si = 0; si < day.slots.length; si++) {
          final slot = day.slots[si];
          final path = 'weeks[$wi].days[$di].slots[$si].session_key';
          final session = byKey[slot.sessionKey];
          if (session == null) {
            issues.add(
              PlanPackageValidationIssue(
                path: path,
                code: 'broken_reference',
                message:
                    'Slot references unknown session_key "${slot.sessionKey}".',
              ),
            );
            continue;
          }
          // Explicit versioned identity must be present on the resolved session.
          if (session.protocolId.isEmpty ||
              session.sessionLineageId.isEmpty ||
              session.revisionNumber < 1) {
            issues.add(
              PlanPackageValidationIssue(
                path: path,
                code: 'missing_session_version',
                message:
                    'Resolved session "${slot.sessionKey}" lacks explicit '
                    'immutable Session Revision identity.',
              ),
            );
          }
        }
      }
    }
  }

  void _validateAssessmentsAndComparisons(
    PlanPackageManifest manifest,
    List<PlanPackageValidationIssue> issues,
  ) {
    final slotKeys = <String>{
      for (final week in manifest.weeks)
        for (final day in week.days)
          for (final slot in day.slots) slot.slotKey,
    };
    final comparisonIds = {for (final c in manifest.comparisonIdentities) c.id};
    final sessionLineages = {
      for (final s in manifest.sessions) s.sessionLineageId,
    };

    for (var i = 0; i < manifest.comparisonIdentities.length; i++) {
      final c = manifest.comparisonIdentities[i];
      if (!sessionLineages.contains(c.sessionLineageId)) {
        issues.add(
          PlanPackageValidationIssue(
            path: 'comparison_identities[$i].session_lineage_id',
            code: 'broken_reference',
            message:
                'Comparison identity references unknown session_lineage_id '
                '"${c.sessionLineageId}".',
          ),
        );
      }
    }

    for (var i = 0; i < manifest.assessments.length; i++) {
      final a = manifest.assessments[i];
      final path = 'assessments[$i]';
      if (!slotKeys.contains(a.slotRef)) {
        issues.add(
          PlanPackageValidationIssue(
            path: '$path.slot_ref',
            code: 'broken_reference',
            message: 'Assessment references unknown slot_ref "${a.slotRef}".',
          ),
        );
      }
      if (!comparisonIds.contains(a.comparisonIdentityId)) {
        issues.add(
          PlanPackageValidationIssue(
            path: '$path.comparison_identity_id',
            code: 'broken_reference',
            message:
                'Assessment references unknown comparison_identity_id '
                '"${a.comparisonIdentityId}".',
          ),
        );
      }
    }

    for (var i = 0; i < manifest.performanceEvidenceRequirements.length; i++) {
      final e = manifest.performanceEvidenceRequirements[i];
      if (!comparisonIds.contains(e.comparisonIdentityId)) {
        issues.add(
          PlanPackageValidationIssue(
            path:
                'performance_evidence_requirements[$i].comparison_identity_id',
            code: 'broken_reference',
            message:
                'Evidence requirement references unknown comparison_identity_id '
                '"${e.comparisonIdentityId}".',
          ),
        );
      }
    }

    // Like-for-like comparison expected for assessments.
    for (var i = 0; i < manifest.assessments.length; i++) {
      final a = manifest.assessments[i];
      if (a.comparisonIdentityId.isEmpty) {
        issues.add(
          PlanPackageValidationIssue(
            path: 'assessments[$i].comparison_identity_id',
            code: 'missing_comparison_identity',
            message:
                'Assessment requires a comparison identity for like-for-like '
                'progress comparison.',
          ),
        );
      }
    }
  }

  void _validateAdaptationsAndInvariants(
    PlanPackageManifest manifest,
    List<PlanPackageValidationIssue> issues,
  ) {
    // An empty adaptation_permissions list is an explicit authored boundary
    // ("no adaptations permitted"). The field itself is required by parsing.

    for (var i = 0; i < manifest.adaptationPermissions.length; i++) {
      final permission = manifest.adaptationPermissions[i];
      if (!permission.athleteAgreementRequired) {
        issues.add(
          PlanPackageValidationIssue(
            path: 'adaptation_permissions[$i].athlete_agreement_required',
            code: 'agreement_required',
            message:
                'Athlete agreement is required for all authored adaptations.',
          ),
        );
      }
      if (!AdaptationPolicyGate.allowed.contains(permission.changeKind)) {
        issues.add(
          PlanPackageValidationIssue(
            path: 'adaptation_permissions[$i].change_kind',
            code: 'prohibited_adaptation',
            message:
                'Adaptation kind ${permission.changeKind.name} is not '
                'permitted by AdaptationPolicyGate.',
          ),
        );
      }
    }

    final protectedTargets = {
      for (final inv in manifest.protectedInvariants) inv.targetRef,
    };
    final adaptableTargets = {
      for (final a in manifest.adaptationPermissions) a.targetRef,
    };

    for (final target in protectedTargets.intersection(adaptableTargets)) {
      issues.add(
        PlanPackageValidationIssue(
          path: 'protected_invariants',
          code: 'protected_adaptable_conflict',
          message:
              'Target "$target" is both protected and declared adaptable. '
              'Protected content cannot simultaneously be freely adaptable.',
        ),
      );
    }

    // Also: protected assessment targets cannot have adaptation on same ref.
    for (var i = 0; i < manifest.protectedInvariants.length; i++) {
      final inv = manifest.protectedInvariants[i];
      if (inv.kind == PlanPackageInvariantKind.assessmentImmutable) {
        final assessmentIds = manifest.assessments.map((a) => a.id).toSet();
        if (!assessmentIds.contains(inv.targetRef) &&
            !_slotExists(manifest, inv.targetRef)) {
          issues.add(
            PlanPackageValidationIssue(
              path: 'protected_invariants[$i].target_ref',
              code: 'broken_reference',
              message:
                  'Protected invariant target_ref "${inv.targetRef}" does not '
                  'resolve to an assessment or slot.',
            ),
          );
        }
      } else if (!_slotExists(manifest, inv.targetRef) &&
          inv.targetRef != 'programme') {
        // Allow assessment ids for assessmentImmutable already handled;
        // for slot invariants, require slot.
        final assessmentIds = manifest.assessments.map((a) => a.id).toSet();
        if (!assessmentIds.contains(inv.targetRef)) {
          issues.add(
            PlanPackageValidationIssue(
              path: 'protected_invariants[$i].target_ref',
              code: 'broken_reference',
              message:
                  'Protected invariant target_ref "${inv.targetRef}" does not '
                  'resolve.',
            ),
          );
        }
      }
    }

    for (var i = 0; i < manifest.adaptationPermissions.length; i++) {
      final a = manifest.adaptationPermissions[i];
      if (a.targetRef == 'programme') continue;
      if (!_slotExists(manifest, a.targetRef)) {
        issues.add(
          PlanPackageValidationIssue(
            path: 'adaptation_permissions[$i].target_ref',
            code: 'broken_reference',
            message:
                'Adaptation permission target_ref "${a.targetRef}" does not '
                'resolve to a slot.',
          ),
        );
      }
    }
  }

  void _validateAuthoredProgressionCompleteness(
    PlanPackageManifest manifest,
    List<PlanPackageValidationIssue> issues,
  ) {
    for (var wi = 0; wi < manifest.weeks.length; wi++) {
      final week = manifest.weeks[wi];
      for (var di = 0; di < week.days.length; di++) {
        final day = week.days[di];
        for (var si = 0; si < day.slots.length; si++) {
          final slot = day.slots[si];
          final summary = slot.progression.prescriptionSummary.trim();
          if (summary.isEmpty) {
            issues.add(
              PlanPackageValidationIssue(
                path:
                    'weeks[$wi].days[$di].slots[$si].progression.prescription_summary',
                code: 'incomplete_progression',
                message:
                    'Authored progression is incomplete; compilation will not '
                    'invent training prescriptions.',
              ),
            );
          }
        }
      }
    }

    if (manifest.programme.coachingIntent.trim().isEmpty) {
      issues.add(
        const PlanPackageValidationIssue(
          path: 'programme.coaching_intent',
          code: 'incomplete_progression',
          message: 'Authored coaching intent is required.',
        ),
      );
    }
  }

  void _validateNoMutableBuilderSemantics(
    PlanPackageManifest manifest,
    List<PlanPackageValidationIssue> issues,
  ) {
    // Version identity must be explicit positive integer — already enforced.
    // Reject representing published source as draft-only mutable builder state:
    // package requires version_number and lineage_code (stable + versioned).
    if (manifest.programme.versionNumber < 1) {
      issues.add(
        const PlanPackageValidationIssue(
          path: 'programme.version_number',
          code: 'missing_version_identity',
          message: 'Programme version identity must be explicit and >= 1.',
        ),
      );
    }
    if (manifest.programme.lineageCode.trim().isEmpty) {
      issues.add(
        const PlanPackageValidationIssue(
          path: 'programme.lineage_code',
          code: 'missing_stable_identity',
          message: 'Stable programme identity (lineage_code) is required.',
        ),
      );
    }
  }

  bool _slotExists(PlanPackageManifest manifest, String slotKey) {
    for (final week in manifest.weeks) {
      for (final day in week.days) {
        for (final slot in day.slots) {
          if (slot.slotKey == slotKey) return true;
        }
      }
    }
    return false;
  }

  void _assertUnique(
    Iterable<Object> values,
    String collection,
    String field,
    List<PlanPackageValidationIssue> issues,
  ) {
    final seen = <Object>{};
    for (final value in values) {
      if (!seen.add(value)) {
        issues.add(
          PlanPackageValidationIssue(
            path: collection,
            code: 'duplicate_id',
            message: 'Duplicate $field "$value".',
          ),
        );
      }
    }
  }
}
