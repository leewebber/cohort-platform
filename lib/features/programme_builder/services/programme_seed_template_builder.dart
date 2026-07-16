import '../../../models/programme_day_draft.dart';
import '../../../models/programme_session_slot_draft.dart';
import '../../../models/programme_vocabulary.dart';
import '../../../models/programme_week_draft.dart';
import '../models/programme_seed_template.dart';
import '../models/programme_template_draft.dart';

/// Builds deterministic structural scaffolds for new programme drafts.
///
/// No protocol assignment. Slots use empty [ProgrammeSessionSlotDraft.protocolId].
class ProgrammeSeedTemplateBuilder {
  const ProgrammeSeedTemplateBuilder();

  ProgrammeTemplateDraft build(ProgrammeSeedTemplate template) {
    return switch (template) {
      ProgrammeSeedTemplate.empty => _empty(),
      ProgrammeSeedTemplate.strength => _strength(),
      ProgrammeSeedTemplate.running => _running(),
      ProgrammeSeedTemplate.circuit => _circuit(),
      ProgrammeSeedTemplate.recovery => _recovery(),
      ProgrammeSeedTemplate.assessment => _assessment(),
      ProgrammeSeedTemplate.hybrid => _hybrid(),
    };
  }

  ProgrammeTemplateDraft _empty() {
    return ProgrammeTemplateDraft(
      weeks: [
        _week1(
          days: [
            _trainingDay(
              dayKey: 'day_1',
              dayOrder: 1,
              slots: [_requiredSlot(sessionOrder: 1, localId: 'slot-1')],
            ),
          ],
        ),
      ],
    );
  }

  ProgrammeTemplateDraft _strength() {
    return ProgrammeTemplateDraft(
      weeks: [
        _week1(
          days: [
            _trainingDay(
              dayKey: 'day_1',
              dayOrder: 1,
              title: 'Strength',
              slots: [
                _requiredSlot(
                  sessionOrder: 1,
                  localId: 'slot-1',
                  displayTitle: 'Strength session',
                ),
              ],
            ),
            _restDay(dayKey: 'day_2', dayOrder: 2),
          ],
        ),
      ],
    );
  }

  ProgrammeTemplateDraft _running() {
    return ProgrammeTemplateDraft(
      weeks: [
        _week1(
          days: [
            _trainingDay(
              dayKey: 'day_1',
              dayOrder: 1,
              title: 'Running',
              slots: [
                _requiredSlot(
                  sessionOrder: 1,
                  localId: 'slot-1',
                  displayTitle: 'Running session',
                ),
              ],
            ),
            _restDay(dayKey: 'day_2', dayOrder: 2),
          ],
        ),
      ],
    );
  }

  ProgrammeTemplateDraft _circuit() {
    return ProgrammeTemplateDraft(
      weeks: [
        _week1(
          days: [
            _trainingDay(
              dayKey: 'day_1',
              dayOrder: 1,
              title: 'Circuit',
              slots: [
                _requiredSlot(
                  sessionOrder: 1,
                  localId: 'slot-1',
                  displayTitle: 'Circuit session',
                ),
              ],
            ),
            _restDay(dayKey: 'day_2', dayOrder: 2),
          ],
        ),
      ],
    );
  }

  ProgrammeTemplateDraft _recovery() {
    return ProgrammeTemplateDraft(
      weeks: [
        _week1(
          days: [
            ProgrammeDayDraft(
              localId: 'day-1',
              dayKey: 'day_1',
              dayOrder: 1,
              dayType: ProgrammeDayType.training,
              intent: ProgrammeIntent.recover,
              title: 'Recovery',
              slots: [
                ProgrammeSessionSlotDraft(
                  localId: 'slot-1',
                  sessionOrder: 1,
                  protocolId: '',
                  displayTitle: 'Recovery session',
                  isOptional: true,
                  completionExpectation:
                      ProgrammeSessionCompletionExpectation.optional,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  ProgrammeTemplateDraft _assessment() {
    return ProgrammeTemplateDraft(
      weeks: [
        _week1(
          days: [
            ProgrammeDayDraft(
              localId: 'day-1',
              dayKey: 'day_1',
              dayOrder: 1,
              dayType: ProgrammeDayType.training,
              intent: ProgrammeIntent.test,
              title: 'Assessment',
              slots: [
                _requiredSlot(
                  sessionOrder: 1,
                  localId: 'slot-1',
                  displayTitle: 'Assessment session',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  ProgrammeTemplateDraft _hybrid() {
    return ProgrammeTemplateDraft(
      weeks: [
        _week1(
          days: [
            _trainingDay(
              dayKey: 'day_1',
              dayOrder: 1,
              slots: [_requiredSlot(sessionOrder: 1, localId: 'slot-1')],
            ),
            _trainingDay(
              dayKey: 'day_2',
              dayOrder: 2,
              slots: [_requiredSlot(sessionOrder: 1, localId: 'slot-2')],
            ),
            _restDay(dayKey: 'day_3', dayOrder: 3),
            _trainingDay(
              dayKey: 'day_4',
              dayOrder: 4,
              slots: [_requiredSlot(sessionOrder: 1, localId: 'slot-3')],
            ),
          ],
        ),
      ],
    );
  }

  ProgrammeWeekDraft _week1({required List<ProgrammeDayDraft> days}) {
    return ProgrammeWeekDraft(
      localId: 'week-1',
      weekNumber: 1,
      days: days,
    );
  }

  ProgrammeDayDraft _trainingDay({
    required String dayKey,
    required int dayOrder,
    String? title,
    required List<ProgrammeSessionSlotDraft> slots,
  }) {
    return ProgrammeDayDraft(
      localId: 'day-$dayOrder',
      dayKey: dayKey,
      dayOrder: dayOrder,
      dayType: ProgrammeDayType.training,
      title: title,
      slots: slots,
    );
  }

  ProgrammeDayDraft _restDay({
    required String dayKey,
    required int dayOrder,
  }) {
    return ProgrammeDayDraft(
      localId: 'day-$dayOrder',
      dayKey: dayKey,
      dayOrder: dayOrder,
      dayType: ProgrammeDayType.rest,
      slots: const [],
    );
  }

  ProgrammeSessionSlotDraft _requiredSlot({
    required int sessionOrder,
    required String localId,
    String? displayTitle,
  }) {
    return ProgrammeSessionSlotDraft(
      localId: localId,
      sessionOrder: sessionOrder,
      protocolId: '',
      displayTitle: displayTitle,
    );
  }
}
