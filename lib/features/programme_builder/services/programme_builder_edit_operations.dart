import '../../../models/programme_day_draft.dart';
import '../../../models/programme_session_slot_draft.dart';
import '../../../models/programme_vocabulary.dart';
import '../../../models/programme_week_draft.dart';
import '../models/programme_builder_document.dart';
import '../models/programme_template_draft.dart';
import '../models/programme_version_draft_metadata.dart';
import 'programme_builder_compiler.dart';

/// Pure in-memory tree transforms for Programme Editor.
///
/// No Supabase access. Used by [ProgrammeBuilderServiceImpl].
class ProgrammeBuilderEditOperations {
  const ProgrammeBuilderEditOperations({
    ProgrammeBuilderCompiler compiler = const ProgrammeBuilderCompiler(),
  }) : _compiler = compiler;

  final ProgrammeBuilderCompiler _compiler;

  ProgrammeBuilderDocument addWeek(ProgrammeBuilderDocument document) {
    _assertEditable(document);
    final weeks = List<ProgrammeWeekDraft>.from(document.template.weeks);
    final nextNumber = weeks.isEmpty
        ? 1
        : weeks.map((w) => w.weekNumber).reduce((a, b) => a > b ? a : b) + 1;

    weeks.add(
      ProgrammeWeekDraft(
        localId: _newLocalId('week'),
        weekNumber: nextNumber,
        days: [
          ProgrammeDayDraft(
            localId: _newLocalId('day'),
            dayKey: 'day_1',
            dayOrder: 1,
            slots: [
              ProgrammeSessionSlotDraft(
                localId: _newLocalId('slot'),
                sessionOrder: 1,
                protocolId: '',
              ),
            ],
          ),
        ],
      ),
    );

    return _withTemplate(document, weeks);
  }

  ProgrammeBuilderDocument duplicateWeek(
    ProgrammeBuilderDocument document, {
    required String weekLocalId,
  }) {
    _assertEditable(document);
    final weeks = List<ProgrammeWeekDraft>.from(document.template.weeks);
    final sourceIndex = weeks.indexWhere((w) => w.localId == weekLocalId);
    if (sourceIndex < 0) {
      throw ArgumentError('Week not found: $weekLocalId');
    }

    final source = weeks[sourceIndex];
    final nextNumber =
        weeks.map((w) => w.weekNumber).reduce((a, b) => a > b ? a : b) + 1;
    final copy = _deepCopyWeek(source, nextNumber);
    weeks.add(copy);
    weeks.sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

    return _withTemplate(document, _renumberWeeks(weeks));
  }

  ProgrammeBuilderDocument removeWeek(
    ProgrammeBuilderDocument document, {
    required String weekLocalId,
  }) {
    _assertEditable(document);
    var weeks = document.template.weeks
        .where((w) => w.localId != weekLocalId)
        .toList();

    if (weeks.isEmpty) {
      weeks = [
        ProgrammeWeekDraft(
          localId: _newLocalId('week'),
          weekNumber: 1,
          days: [
            ProgrammeDayDraft(
              localId: _newLocalId('day'),
              dayKey: 'day_1',
              dayOrder: 1,
              slots: [
                ProgrammeSessionSlotDraft(
                  localId: _newLocalId('slot'),
                  sessionOrder: 1,
                  protocolId: '',
                ),
              ],
            ),
          ],
        ),
      ];
    }

    return _withTemplate(document, _renumberWeeks(weeks));
  }

  ProgrammeBuilderDocument addDay(
    ProgrammeBuilderDocument document, {
    required String weekLocalId,
  }) {
    _assertEditable(document);
    final weeks = document.template.weeks.map((week) {
      if (week.localId != weekLocalId) return week;

      final days = List<ProgrammeDayDraft>.from(week.days);
      final nextOrder = days.isEmpty
          ? 1
          : days.map((d) => d.dayOrder).reduce((a, b) => a > b ? a : b) + 1;

      days.add(
        ProgrammeDayDraft(
          localId: _newLocalId('day'),
          dayKey: 'day_$nextOrder',
          dayOrder: nextOrder,
          slots: [
            ProgrammeSessionSlotDraft(
              localId: _newLocalId('slot'),
              sessionOrder: 1,
              protocolId: '',
            ),
          ],
        ),
      );

      return week.copyWith(days: _renumberDays(days));
    }).toList();

    return _withTemplate(document, weeks);
  }

  ProgrammeBuilderDocument removeDay(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
  }) {
    _assertEditable(document);
    final weeks = document.template.weeks.map((week) {
      var days =
          week.days.where((day) => day.localId != dayLocalId).toList();

      if (days.isEmpty) {
        days = [
          ProgrammeDayDraft(
            localId: _newLocalId('day'),
            dayKey: 'day_1',
            dayOrder: 1,
            dayType: ProgrammeDayType.rest,
            slots: const [],
          ),
        ];
      }

      return week.copyWith(days: _renumberDays(days));
    }).toList();

    return _withTemplate(document, weeks);
  }

  ProgrammeBuilderDocument updateDayMetadata(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
    String? title,
    ProgrammeIntent? intent,
    bool clearTitle = false,
    bool clearIntent = false,
  }) {
    _assertEditable(document);
    final weeks = document.template.weeks.map((week) {
      final days = week.days.map((day) {
        if (day.localId != dayLocalId) return day;
        return day.copyWith(
          title: title,
          intent: intent,
          clearTitle: clearTitle,
          clearIntent: clearIntent,
        );
      }).toList();
      return week.copyWith(days: days);
    }).toList();

    return _withTemplate(document, weeks);
  }

  ProgrammeBuilderDocument setDayType(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
    required ProgrammeDayType dayType,
    bool clearSlotsOnRest = true,
  }) {
    _assertEditable(document);
    final weeks = document.template.weeks.map((week) {
      final days = week.days.map((day) {
        if (day.localId != dayLocalId) return day;

        if (dayType == ProgrammeDayType.rest && clearSlotsOnRest) {
          return day.copyWith(
            dayType: ProgrammeDayType.rest,
            slots: const [],
          );
        }

        var slots = day.slots;
        if (dayType == ProgrammeDayType.training && slots.isEmpty) {
          slots = [
            ProgrammeSessionSlotDraft(
              localId: _newLocalId('slot'),
              sessionOrder: 1,
              protocolId: '',
            ),
          ];
        }

        return day.copyWith(dayType: dayType, slots: slots);
      }).toList();
      return week.copyWith(days: days);
    }).toList();

    return _withTemplate(document, weeks);
  }

  ProgrammeBuilderDocument addSlot(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
  }) {
    _assertEditable(document);
    final weeks = document.template.weeks.map((week) {
      final days = week.days.map((day) {
        if (day.localId != dayLocalId) return day;
        if (day.dayType == ProgrammeDayType.rest) {
          throw StateError('Cannot add slot to rest day');
        }

        final slots = List<ProgrammeSessionSlotDraft>.from(day.slots);
        final nextOrder = slots.isEmpty
            ? 1
            : slots.map((s) => s.sessionOrder).reduce((a, b) => a > b ? a : b) +
                1;

        slots.add(
          ProgrammeSessionSlotDraft(
            localId: _newLocalId('slot'),
            sessionOrder: nextOrder,
            protocolId: '',
          ),
        );

        return day.copyWith(
          dayType: ProgrammeDayType.training,
          slots: _renumberSlots(slots),
        );
      }).toList();
      return week.copyWith(days: days);
    }).toList();

    return _withTemplate(document, weeks);
  }

  ProgrammeBuilderDocument removeSlot(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
  }) {
    _assertEditable(document);
    final weeks = document.template.weeks.map((week) {
      final days = week.days.map((day) {
        final slots =
            day.slots.where((slot) => slot.localId != slotLocalId).toList();
        if (slots.length == day.slots.length) return day;
        return day.copyWith(slots: _renumberSlots(slots));
      }).toList();
      return week.copyWith(days: days);
    }).toList();

    return _withTemplate(document, weeks);
  }

  ProgrammeBuilderDocument assignProtocol(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
    required String protocolId,
    String? displayTitle,
  }) {
    _assertEditable(document);
    final weeks = document.template.weeks.map((week) {
      final days = week.days.map((day) {
        final slots = day.slots.map((slot) {
          if (slot.localId != slotLocalId) return slot;
          return slot.copyWith(
            protocolId: protocolId.trim(),
            displayTitle: displayTitle,
          );
        }).toList();
        return day.copyWith(slots: slots);
      }).toList();
      return week.copyWith(days: days);
    }).toList();

    return _withTemplate(document, weeks);
  }

  ProgrammeBuilderDocument clearProtocol(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
  }) {
    return assignProtocol(
      document,
      slotLocalId: slotLocalId,
      protocolId: '',
      displayTitle: null,
    );
  }

  ProgrammeBuilderDocument updateSlotMetadata(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
    String? displayTitle,
    ProgrammeSessionTimeOfDay? timeOfDay,
    bool? isOptional,
    ProgrammeSessionCompletionExpectation? completionExpectation,
    String? coachNote,
    String? athleteNote,
    bool clearDisplayTitle = false,
    bool clearCoachNote = false,
    bool clearAthleteNote = false,
  }) {
    _assertEditable(document);
    final weeks = document.template.weeks.map((week) {
      final days = week.days.map((day) {
        final slots = day.slots.map((slot) {
          if (slot.localId != slotLocalId) return slot;

          final optional = isOptional ?? slot.isOptional;
          final expectation = completionExpectation ??
              (optional
                  ? ProgrammeSessionCompletionExpectation.optional
                  : slot.completionExpectation);

          return slot.copyWith(
            displayTitle: displayTitle,
            timeOfDay: timeOfDay,
            isOptional: optional,
            completionExpectation: expectation,
            coachNote: coachNote,
            athleteNote: athleteNote,
            clearDisplayTitle: clearDisplayTitle,
            clearCoachNote: clearCoachNote,
            clearAthleteNote: clearAthleteNote,
          );
        }).toList();
        return day.copyWith(slots: slots);
      }).toList();
      return week.copyWith(days: days);
    }).toList();

    return _withTemplate(document, weeks);
  }

  ProgrammeBuilderDocument updateMetadata(
    ProgrammeBuilderDocument document,
    ProgrammeVersionDraftMetadata metadata,
  ) {
    _assertEditable(document);
    return document.copyWith(
      metadata: metadata,
      isDirty: true,
      hasUnsavedChanges: true,
    );
  }

  ProgrammeWeekDraft? findWeek(
    ProgrammeBuilderDocument document,
    String weekLocalId,
  ) {
    for (final week in document.template.allWeeks) {
      if (week.localId == weekLocalId) return week;
    }
    return null;
  }

  ProgrammeDayDraft? findDay(
    ProgrammeBuilderDocument document,
    String dayLocalId,
  ) {
    for (final week in document.template.allWeeks) {
      for (final day in week.days) {
        if (day.localId == dayLocalId) return day;
      }
    }
    return null;
  }

  ProgrammeSessionSlotDraft? findSlot(
    ProgrammeBuilderDocument document,
    String slotLocalId,
  ) {
    for (final week in document.template.allWeeks) {
      for (final day in week.days) {
        for (final slot in day.slots) {
          if (slot.localId == slotLocalId) return slot;
        }
      }
    }
    return null;
  }

  ProgrammeBuilderDocument _withTemplate(
    ProgrammeBuilderDocument document,
    List<ProgrammeWeekDraft> weeks,
  ) {
    final normalized = _compiler.assignLocalIds(
      ProgrammeTemplateDraft(weeks: _renumberWeeks(weeks)),
    );
    return document.copyWith(
      template: normalized,
      isDirty: true,
      hasUnsavedChanges: true,
    );
  }

  List<ProgrammeWeekDraft> _renumberWeeks(List<ProgrammeWeekDraft> weeks) {
    final sorted = List<ProgrammeWeekDraft>.from(weeks)
      ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

    return [
      for (var i = 0; i < sorted.length; i++)
        sorted[i].copyWith(weekNumber: i + 1),
    ];
  }

  List<ProgrammeDayDraft> _renumberDays(List<ProgrammeDayDraft> days) {
    final sorted = List<ProgrammeDayDraft>.from(days)
      ..sort((a, b) => a.dayOrder.compareTo(b.dayOrder));

    return [
      for (var i = 0; i < sorted.length; i++)
        sorted[i].copyWith(
          dayOrder: i + 1,
          dayKey: 'day_${i + 1}',
        ),
    ];
  }

  List<ProgrammeSessionSlotDraft> _renumberSlots(
    List<ProgrammeSessionSlotDraft> slots,
  ) {
    final sorted = List<ProgrammeSessionSlotDraft>.from(slots)
      ..sort((a, b) => a.sessionOrder.compareTo(b.sessionOrder));

    return [
      for (var i = 0; i < sorted.length; i++)
        sorted[i].copyWith(sessionOrder: i + 1),
    ];
  }

  ProgrammeWeekDraft _deepCopyWeek(ProgrammeWeekDraft source, int weekNumber) {
    return ProgrammeWeekDraft(
      localId: _newLocalId('week'),
      weekNumber: weekNumber,
      title: source.title,
      intent: source.intent,
      coachNote: source.coachNote,
      athleteNote: source.athleteNote,
      days: source.days.map((day) {
        return ProgrammeDayDraft(
          localId: _newLocalId('day'),
          dayKey: day.dayKey,
          dayOrder: day.dayOrder,
          title: day.title,
          dayType: day.dayType,
          intent: day.intent,
          coachNote: day.coachNote,
          athleteNote: day.athleteNote,
          slots: day.slots
              .map(
                (slot) => ProgrammeSessionSlotDraft(
                  localId: _newLocalId('slot'),
                  sessionOrder: slot.sessionOrder,
                  protocolId: slot.protocolId,
                  displayTitle: slot.displayTitle,
                  timeOfDay: slot.timeOfDay,
                  isOptional: slot.isOptional,
                  completionExpectation: slot.completionExpectation,
                  coachNote: slot.coachNote,
                  athleteNote: slot.athleteNote,
                ),
              )
              .toList(),
        );
      }).toList(),
    );
  }

  void _assertEditable(ProgrammeBuilderDocument document) {
    if (!document.isEditable) {
      throw StateError('Document is not editable');
    }
  }

  String _newLocalId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }
}
