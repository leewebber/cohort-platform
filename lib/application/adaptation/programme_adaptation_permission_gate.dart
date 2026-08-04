import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/authored_plan_package/plan_package_manifest.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';

/// Result of checking authored package adaptation permissions.
enum ProgrammeAdaptationPermissionDenial {
  /// Empty list is an explicit authored "no adaptations permitted" boundary.
  emptyPermissions,

  /// No permission row covers the requested change kind / target.
  noMatchingPermission,

  /// Permission exists but athlete agreement is not required (illegal).
  athleteAgreementNotRequired,

  /// Change kind is outside AdaptationPolicyGate.allowed.
  changeKindNotAllowed,
}

class ProgrammeAdaptationPermissionCheck {
  const ProgrammeAdaptationPermissionCheck._({
    required this.allowed,
    this.denial,
    this.matchedPermission,
  });

  factory ProgrammeAdaptationPermissionCheck.permit(
    PlanPackageAdaptationPermission permission,
  ) {
    return ProgrammeAdaptationPermissionCheck._(
      allowed: true,
      matchedPermission: permission,
    );
  }

  factory ProgrammeAdaptationPermissionCheck.deny(
    ProgrammeAdaptationPermissionDenial denial,
  ) {
    return ProgrammeAdaptationPermissionCheck._(allowed: false, denial: denial);
  }

  final bool allowed;
  final ProgrammeAdaptationPermissionDenial? denial;
  final PlanPackageAdaptationPermission? matchedPermission;
}

/// Enforces authored plan-package adaptation permissions at propose/accept.
///
/// Permission authorizes a change *kind*; it does not invent a replacement.
class ProgrammeAdaptationPermissionGate {
  const ProgrammeAdaptationPermissionGate();

  ProgrammeAdaptationPermissionCheck allowEquipmentSubstitution({
    required List<PlanPackageAdaptationPermission> permissions,
    String? slotKey,
  }) {
    return _allow(
      permissions: permissions,
      reason: AdaptationReason.equipment,
      slotKey: slotKey,
    );
  }

  ProgrammeAdaptationPermissionCheck _allow({
    required List<PlanPackageAdaptationPermission> permissions,
    required AdaptationReason reason,
    String? slotKey,
  }) {
    if (permissions.isEmpty) {
      return ProgrammeAdaptationPermissionCheck.deny(
        ProgrammeAdaptationPermissionDenial.emptyPermissions,
      );
    }

    final wanted = AdaptationPolicyGate.kindsForDayOf(reason).toSet();
    PlanPackageAdaptationPermission? matched;

    for (final permission in permissions) {
      if (!wanted.contains(permission.changeKind)) continue;
      if (!_targetMatches(permission.targetRef, slotKey)) continue;
      if (!AdaptationPolicyGate.allowed.contains(permission.changeKind)) {
        return ProgrammeAdaptationPermissionCheck.deny(
          ProgrammeAdaptationPermissionDenial.changeKindNotAllowed,
        );
      }
      if (!permission.athleteAgreementRequired) {
        return ProgrammeAdaptationPermissionCheck.deny(
          ProgrammeAdaptationPermissionDenial.athleteAgreementNotRequired,
        );
      }
      matched = permission;
      break;
    }

    if (matched == null) {
      return ProgrammeAdaptationPermissionCheck.deny(
        ProgrammeAdaptationPermissionDenial.noMatchingPermission,
      );
    }
    return ProgrammeAdaptationPermissionCheck.permit(matched);
  }

  static bool _targetMatches(String targetRef, String? slotKey) {
    final ref = targetRef.trim();
    if (ref == 'programme') return true;
    if (slotKey == null || slotKey.trim().isEmpty) {
      // Without a slot key, only programme-wide permissions apply.
      return false;
    }
    return ref == slotKey.trim();
  }
}
