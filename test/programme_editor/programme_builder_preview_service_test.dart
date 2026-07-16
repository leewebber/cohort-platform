import 'package:cohort_platform/features/programme_builder/models/programme_builder_document.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_preview.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_template_draft.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_version_draft_metadata.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_preview_service_impl.dart';
import 'package:cohort_platform/models/programme_day_draft.dart';
import 'package:cohort_platform/models/programme_session_slot_draft.dart';
import 'package:cohort_platform/models/programme_week_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preview service builds structural and athlete preview', () async {
    const service = ProgrammeBuilderPreviewServiceImpl();
    final document = ProgrammeBuilderDocument.clean(
      metadata: const ProgrammeVersionDraftMetadata(
        lineageCode: 'COHORT-TEST',
        versionNumber: 1,
        name: 'Foundation Test',
      ),
      template: ProgrammeTemplateDraft(
        weeks: [
          ProgrammeWeekDraft(
            localId: 'week-1',
            weekNumber: 1,
            days: [
              ProgrammeDayDraft(
                localId: 'day-1',
                dayKey: 'day_1',
                dayOrder: 1,
                slots: [
                  ProgrammeSessionSlotDraft(
                    localId: 'slot-1',
                    sessionOrder: 1,
                    protocolId: 'BW-001',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final preview = await service.buildPreview(
      document,
      protocolNamesById: const {'BW-001': 'Bodyweight Grinder'},
    );

    expect(preview.programmeName, 'Foundation Test');
    expect(preview.weeks, hasLength(1));
    expect(preview.weeks.single.days.single.slots.single.protocolName,
        'Bodyweight Grinder');
    expect(preview.initialAthletePreview, isNotNull);
    expect(preview.initialAthletePreview!.title, 'Bodyweight Grinder');
  });
}
