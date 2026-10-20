import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/presentation/programme_studio_app.dart';
import 'package:cohort_platform/features/programme_studio/domain/programme_review_models.dart';
import 'programme_first_screen_test.dart' show tap;
import 'source_prescription_review_test.dart' show syntheticReview;

Future<ProgrammeReviewCatalog> mountReview(
  WidgetTester t, {
  String? extraFields,
  bool narrow = false,
}) async {
  await t.binding.setSurfaceSize(
    narrow ? const Size(390, 844) : const Size(1440, 1100),
  );
  addTearDown(() => t.binding.setSurfaceSize(null));
  final catalog = await syntheticReview(extraFields: extraFields);
  await t.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(narrow ? 2 : 1)),
        child: child!,
      ),
      home: ProgrammeStudioScreen(
        catalog: catalog,
        showDeveloperFixtures: true,
      ),
    ),
  );
  await t.pumpAndSettle();
  return catalog;
}

void main() {
  testWidgets(
    'retained effort/resistance/eccentric fields are readable and source is optional read-only evidence',
    (t) async {
      final catalog = await mountReview(
        t,
        extraFields:
            '"rir":0,"rpe":"7-8","resistance":"manual/towel","eccentric_seconds":3,"per_side":true',
      );
      expect(find.text('RIR (authored): 0'), findsOneWidget);
      expect(find.text('RPE (authored): 7-8'), findsOneWidget);
      expect(find.text('Resistance: “manual/towel”'), findsOneWidget);
      expect(find.text('Eccentric: 3 seconds (authored)'), findsOneWidget);
      expect(find.text('Per side: true'), findsOneWidget);
      expect(find.text('12.5 kg'), findsOneWidget);
      expect(find.text('Prescription review is incomplete.'), findsNothing);
      expect(find.byType(SelectableText), findsNothing);
      await tap(t, find.text('Retained prescription source (read-only)').first);
      final raw = catalog
          .developerFixtures
          .single
          .weeks
          .single
          .days
          .first
          .sessions
          .single
          .blocks
          .single
          .movements
          .first
          .rawPrescription!;
      expect(
        t.widget<SelectableText>(find.byType(SelectableText).first).data,
        raw,
      );
      expect(find.text('Publish'), findsNothing);
      expect(find.text('Save new version'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'uninterpreted fields are visible and quality gate cannot pass full prescription review',
    (t) async {
      final catalog = await mountReview(
        t,
        extraFields: '"future_policy":{"target":"uninterpreted"}',
      );
      expect(find.text('Prescription review is incomplete.'), findsOneWidget);
      expect(
        find.textContaining('not interpreted: future_policy'),
        findsOneWidget,
      );
      expect(
        catalog.developerFixtures.single.readiness
            .singleWhere((r) => r.id == 'prescription_renderable')
            .status,
        ProgrammeReviewCheckStatus.failed,
      );
      await tap(t, find.text('Retained prescription source (read-only)').first);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SelectableText &&
              (w.data?.contains('"future_policy":{"target":"uninterpreted"}') ??
                  false),
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'narrow 2x text review can expose exact source and limitations without overflow',
    (t) async {
      await mountReview(
        t,
        extraFields: '"rir":"2-3","rest_policy":{"minimum":60,"maximum":90}',
        narrow: true,
      );
      expect(find.text('RIR (authored): 2-3'), findsOneWidget);
      expect(
        find.textContaining('not interpreted: rest_policy'),
        findsOneWidget,
      );
      final source = find
          .text('Retained prescription source (read-only)')
          .first;
      await Scrollable.ensureVisible(t.element(source), alignment: .4);
      await t.pumpAndSettle();
      await t.tap(source);
      await t.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
