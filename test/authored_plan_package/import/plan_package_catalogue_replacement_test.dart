import 'package:flutter_test/flutter_test.dart';

import 'package:cohort_platform/features/authored_plan_package/import/plan_package_catalogue_approval_service.dart';
import 'package:cohort_platform/features/authored_plan_package/import/plan_package_catalogue_replacement_result.dart';
import 'package:cohort_platform/features/authored_plan_package/import/plan_package_import_store.dart';

void main() {
  group('PlanPackageCatalogueReplacementResult', () {
    test('maps replaced and idempotent success outcomes', () {
      final replaced = PlanPackageCatalogueReplacementResult.fromRpcMap({
        'status': 'replaced',
        'code': 'catalogue_version_replaced',
        'retiring_version_id': 'old',
        'replacement_version_id': 'new',
        'eligible_version_count': 1,
      });
      final retried = PlanPackageCatalogueReplacementResult.fromRpcMap({
        'status': 'already_replaced',
        'code': 'idempotent_success',
        'eligible_version_count': '1',
      });

      expect(replaced.status, PlanPackageCatalogueReplacementStatus.replaced);
      expect(replaced.isSuccess, isTrue);
      expect(replaced.retiringVersionId, 'old');
      expect(replaced.replacementVersionId, 'new');
      expect(replaced.eligibleVersionCount, 1);
      expect(
        retried.status,
        PlanPackageCatalogueReplacementStatus.alreadyReplaced,
      );
      expect(retried.isSuccess, isTrue);
      expect(retried.eligibleVersionCount, 1);
    });

    test('maps every fail-closed typed outcome', () {
      expect(
        _result('validation_failure', 'wrong_lineage').status,
        PlanPackageCatalogueReplacementStatus.wrongLineage,
      );
      expect(
        _result('validation_failure', 'invalid_replacement').status,
        PlanPackageCatalogueReplacementStatus.invalidReplacement,
      );
      expect(
        _result('conflict', 'conflicting_eligible_version').status,
        PlanPackageCatalogueReplacementStatus.conflictingEligibleVersion,
      );
      expect(
        _result('authorization_failure', 'service_role_required').status,
        PlanPackageCatalogueReplacementStatus.unauthorized,
      );
      expect(
        _result(
          'lifecycle_invariant_failure',
          'atomic_replacement_rolled_back',
        ).status,
        PlanPackageCatalogueReplacementStatus.lifecycleInvariantFailure,
      );
      expect(
        _result('validation_failure', 'invalid_args').status,
        PlanPackageCatalogueReplacementStatus.invalidRequest,
      );
    });
  });

  test(
    'approval service delegates exact atomic replacement identities',
    () async {
      final store = _RecordingLifecycleStore();
      final service = PlanPackageCatalogueApprovalService(store);

      final result = await service.replaceApprovedVersion(
        retiringVersionId: 'retiring',
        replacementVersionId: 'replacement',
        actor: 'founder',
      );

      expect(result.isSuccess, isTrue);
      expect(store.retiringVersionId, 'retiring');
      expect(store.replacementVersionId, 'replacement');
      expect(store.actor, 'founder');
    },
  );
}

PlanPackageCatalogueReplacementResult _result(String status, String code) {
  return PlanPackageCatalogueReplacementResult.fromRpcMap({
    'status': status,
    'code': code,
  });
}

class _RecordingLifecycleStore implements PlanPackageLifecycleStore {
  String? retiringVersionId;
  String? replacementVersionId;
  String? actor;

  @override
  Future<Map<String, dynamic>> approveCohortGlobalVersion({
    required String versionId,
    required String actor,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> publishCohortGlobalVersion({
    required String versionId,
    required String actor,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PlanPackageCatalogueReplacementResult>
  replaceApprovedCohortGlobalVersion({
    required String retiringVersionId,
    required String replacementVersionId,
    required String actor,
  }) async {
    this.retiringVersionId = retiringVersionId;
    this.replacementVersionId = replacementVersionId;
    this.actor = actor;
    return const PlanPackageCatalogueReplacementResult(
      status: PlanPackageCatalogueReplacementStatus.replaced,
      code: 'catalogue_version_replaced',
    );
  }
}
