import '../models/programme_builder_constants.dart';
import '../models/programme_builder_document.dart';
import '../models/programme_builder_preview.dart';
import '../models/programme_session_display_labels.dart';
import 'programme_builder_preview_service.dart';

/// Builds structural and athlete-facing previews from editor documents.
class ProgrammeBuilderPreviewServiceImpl implements ProgrammeBuilderPreviewService {
  const ProgrammeBuilderPreviewServiceImpl();

  @override
  Future<ProgrammeBuilderPreview> buildPreview(
    ProgrammeBuilderDocument document, {
    Map<String, String> protocolNamesById = const {},
  }) async {
    final weeks = document.template.allWeeks.map((week) {
      final days = week.days.map((day) {
        final slots = day.slots.map((slot) {
          final protocolId = ProgrammeBuilderConstants.isUnassignedProtocolId(
            slot.protocolId,
          )
              ? ''
              : slot.protocolId;
          final protocolName = protocolId.isEmpty
              ? null
              : protocolNamesById[protocolId];

          ProgrammeBuilderAthleteSessionPreview? athletePreview;
          if (protocolName != null && protocolName.isNotEmpty) {
            athletePreview = ProgrammeBuilderAthleteSessionPreview(
              title: ProgrammeSessionDisplayLabels.canonicalSessionTitle(
                protocolName: protocolName,
              ),
              subtitle: ProgrammeSessionDisplayLabels.executableSubtitle(
                isOptional: slot.isOptional,
                protocolName: protocolName,
                slotDisplayTitle: slot.displayTitle,
              ),
              weekLabel: ProgrammeSessionDisplayLabels.weekLabel(
                programmeName: document.metadata.name,
                weekNumber: week.weekNumber,
                dayKey: day.dayKey,
                dayTitle: day.title,
              ),
              status: ProgrammeSessionDisplayLabels.athletePreviewStatus,
              protocolId: protocolId,
              weekNumber: week.weekNumber,
              dayKey: day.dayKey,
              sessionOrder: slot.sessionOrder,
            );
          }

          return ProgrammeBuilderPreviewSlot(
            slotLocalId: slot.localId,
            sessionOrder: slot.sessionOrder,
            protocolId: protocolId,
            protocolName: protocolName,
            displayTitle: slot.displayTitle,
            isOptional: slot.isOptional,
            completionExpectation: slot.completionExpectation,
            athletePreview: athletePreview,
          );
        }).toList();

        return ProgrammeBuilderPreviewDay(
          dayLocalId: day.localId,
          dayKey: day.dayKey,
          dayOrder: day.dayOrder,
          title: day.title,
          dayType: day.dayType,
          slots: slots,
          isRestDay: day.isRestDay,
        );
      }).toList();

      return ProgrammeBuilderPreviewWeek(
        weekLocalId: week.localId,
        weekNumber: week.weekNumber,
        title: week.title,
        days: days,
      );
    }).toList();

    ProgrammeBuilderAthleteSessionPreview? initialPreview;
    for (final week in weeks) {
      for (final day in week.days) {
        for (final slot in day.slots) {
          if (slot.athletePreview != null) {
            initialPreview = slot.athletePreview;
            break;
          }
        }
        if (initialPreview != null) break;
      }
      if (initialPreview != null) break;
    }

    return ProgrammeBuilderPreview(
      programmeName: document.metadata.name,
      lineageCode: document.metadata.lineageCode,
      versionNumber: document.metadata.versionNumber,
      weeks: weeks,
      initialAthletePreview: initialPreview,
    );
  }
}
