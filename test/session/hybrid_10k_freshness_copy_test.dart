import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme/content/hybrid_10k_release_copy.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/session/screens/quality_target_review_screen.dart';
import 'package:cohort_platform/features/session/services/running_target_admission_store.dart';
import 'quality_target_admission_test.dart' as fixture;

class ExpiredInput implements QualityRunningTargetAdmissionStore {
  int confirms = 0;
  @override
  Future<Map<String, dynamic>> reviewQuality(
    String occurrence,
    String source,
  ) async => {
    'status': 'input_required',
    'reason': 'stale_5k',
    'evaluation_timezone': 'UTC',
    'authored_rpe_available': false,
  };
  @override
  Future<void> confirmQuality({
    required String kind,
    int? seconds,
    String? date,
    bool? sustained,
    bool withdraw = false,
    String? manualOrigin,
  }) async {
    confirms++;
  }
}

void main() {
  test('release renewal copy is exactly the founder-approved wording', () {
    final approved = jsonDecode(
      File(
        'docs/programmes/hybrid_10k/d8_approved_integration_2026_11_04/ATHLETE_WORDING.json',
      ).readAsStringSync(),
    );
    expect(hybrid10kFreshnessRenewalMessage, approved['freshness_message']);
  });
  for (final hybrid in [true, false]) {
    testWidgets(
      'expired input remains unavailable with scoped Hybrid copy: $hybrid',
      (tester) async {
        final store = ExpiredInput();
        var accepted = false;
        final c = ProgrammeExecutionContext(
          assignmentId: 'assignment',
          programmeVersionId: 'version',
          sessionSlotId: 'slot',
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 1,
          plannedProtocolId: 'quality-fixture',
          effectiveProtocolId: 'quality-fixture',
          occurrenceId: 'occurrence',
          lineageCode: hybrid ? hybrid10kLineageCode : 'UNRELATED',
          packageContentHash: 'a' * 64,
          packageSchemaVersion: 1,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: QualityTargetReviewScreen(
              athleteId: fixture.owner,
              plan: fixture.fixturePlan(),
              programmeContext: c,
              store: store,
              onAccepted: (_, _) => accepted = true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(hybrid10kFreshnessRenewalMessage),
          hybrid ? findsOneWidget : findsNothing,
        );
        expect(find.text('Accept targets and start'), findsNothing);
        expect(accepted, isFalse);
        expect(store.confirms, 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
