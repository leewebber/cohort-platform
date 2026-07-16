import 'package:cohort_platform/features/programme_builder/models/programme_seed_template.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_validation_service_impl.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_seed_template_builder.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_document.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_template_draft.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_version_draft_metadata.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_validation_result.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = ProgrammeSeedTemplateBuilder();
  final validationService = ProgrammeBuilderValidationServiceImpl(
    scheduleResolver: const ProgrammeScheduleResolverImpl(),
  );

  ProgrammeBuilderDocument documentFor(ProgrammeSeedTemplate template) {
    return ProgrammeBuilderDocument.clean(
      metadata: const ProgrammeVersionDraftMetadata(
        lineageCode: 'COHORT-SEED-TEST',
        versionNumber: 1,
        name: 'Seed Test',
      ),
      template: builder.build(template),
    );
  }

  void expectNoProtocols(ProgrammeTemplateDraft template) {
    for (final week in template.allWeeks) {
      for (final day in week.days) {
        for (final slot in day.slots) {
          expect(slot.protocolId, isEmpty);
        }
      }
    }
  }

  void expectContiguousOrdering(ProgrammeTemplateDraft template) {
    final weeks = template.allWeeks;
    expect(weeks.first.weekNumber, 1);

    for (final week in weeks) {
      final dayOrders = week.days.map((day) => day.dayOrder).toList()..sort();
      for (var index = 0; index < dayOrders.length; index++) {
        expect(dayOrders[index], index + 1);
      }

      for (final day in week.days) {
        final slotOrders = day.slots.map((slot) => slot.sessionOrder).toList()
          ..sort();
        for (var index = 0; index < slotOrders.length; index++) {
          expect(slotOrders[index], index + 1);
        }
      }
    }
  }

  group('ProgrammeSeedTemplateBuilder', () {
    for (final template in ProgrammeSeedTemplate.values) {
      test('${template.label} template has contiguous ordering', () {
        expectContiguousOrdering(builder.build(template));
      });

      test('${template.label} template assigns no protocol IDs', () {
        expectNoProtocols(builder.build(template));
      });
    }

    test('empty template structure', () {
      final template = builder.build(ProgrammeSeedTemplate.empty);
      expect(template.allWeeks, hasLength(1));
      expect(template.allWeeks.first.days, hasLength(1));
      expect(template.allWeeks.first.days.first.slots, hasLength(1));
    });

    test('strength template includes rest day', () {
      final template = builder.build(ProgrammeSeedTemplate.strength);
      expect(template.allWeeks.first.days, hasLength(2));
      expect(
        template.allWeeks.first.days.last.dayType,
        ProgrammeDayType.rest,
      );
    });

    test('hybrid template includes three training days and rest', () {
      final template = builder.build(ProgrammeSeedTemplate.hybrid);
      expect(template.allWeeks.first.days, hasLength(4));
      expect(
        template.allWeeks.first.days
            .where((day) => day.dayType != ProgrammeDayType.rest)
            .length,
        3,
      );
    });

    test('missing protocol validation expected for seeded drafts', () {
      for (final template in ProgrammeSeedTemplate.values) {
        final validation = validationService.validate(documentFor(template));
        expect(
          validation.issues.any(
            (issue) => issue.code == ProgrammeValidationCode.slotProtocolRequired,
          ),
          isTrue,
          reason: '${template.label} should surface missing protocol errors',
        );
      }
    });
  });
}
