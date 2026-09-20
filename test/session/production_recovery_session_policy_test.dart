import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/production_recovery_session_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = ProductionRecoverySessionPolicy();

  test('empty recovery/rest plan is guidance only', () {
    const plan = SessionExecutionPlan(
      sessionId: 'rest',
      sessionTitle: 'Rest',
      blocks: [],
    );
    expect(
      policy.decide(plan: plan, authoredAsRecoveryOrRest: true),
      ProductionRecoveryTreatment.guidanceOnly,
    );
  });

  test('plan without executable blocks is unavailable when not rest', () {
    const plan = SessionExecutionPlan(
      sessionId: 'unknown',
      sessionTitle: 'Unknown',
      blocks: [],
    );
    expect(
      policy.decide(plan: plan, authoredAsRecoveryOrRest: false),
      ProductionRecoveryTreatment.unavailable,
    );
  });
}
