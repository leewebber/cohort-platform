import '../../performance/mappers/performance_record_mapper.dart';
import '../../performance/models/session_result_entry_mode.dart';
import '../../performance/models/training_session_record.dart';
import '../../performance/models/training_session_record_status.dart';
import '../../performance/repositories/in_memory_performance_record_store.dart';
import '../models/backfill_programme_session.dart';
import '../models/fixed_programme_occurrence_projection.dart';
import 'backfill_programme_session_store.dart';
import 'fixed_programme_occurrence_projection_store.dart';

class InMemoryBackfillProgrammeSessionStore
    implements BackfillProgrammeSessionStore {
  InMemoryBackfillProgrammeSessionStore({
    required this.performance,
    required this.projectionStore,
    this.readProjection,
    this.writeProjection,
  });

  final InMemoryPerformanceRecordStore performance;
  final FixedProgrammeOccurrenceProjectionStore projectionStore;
  final FixedProgrammeCalendarProjection? Function()? readProjection;
  final void Function(FixedProgrammeCalendarProjection calendar)?
  writeProjection;

  final Set<String> _idempotencyKeys = <String>{};
  int _nextTrainingSessionId = 900;

  @override
  bool get isSupported => true;

  @override
  Future<BackfillProgrammeSessionResult> save(
    BackfillProgrammeSessionCommand command,
  ) async {
    if (_idempotencyKeys.contains(command.idempotencyKey)) {
      final existing = _existingCompleted(command);
      return BackfillProgrammeSessionResult(
        status: BackfillProgrammeSessionStatus.saved,
        code: 'idempotent_replay',
        record: existing,
      );
    }
    final existing = _existingCompleted(command);
    if (existing != null) {
      return const BackfillProgrammeSessionResult(
        status: BackfillProgrammeSessionStatus.conflict,
        code: 'already_completed',
        message: 'Results for this session have already been saved.',
      );
    }
    final calendar = readProjection?.call() ?? await projectionStore.resolveActive();
    if (calendar == null || calendar.assignmentId != command.assignmentId) {
      return const BackfillProgrammeSessionResult(
        status: BackfillProgrammeSessionStatus.failed,
        code: 'assignment_missing',
      );
    }
    FixedProgrammeOccurrenceProjection? occurrence;
    for (final item in calendar.occurrences) {
      if (item.occurrenceId == command.occurrenceId) {
        occurrence = item;
        break;
      }
    }
    if (occurrence == null) {
      return const BackfillProgrammeSessionResult(
        status: BackfillProgrammeSessionStatus.rejected,
        code: 'occurrence_missing',
      );
    }
    if (occurrence.isResumable ||
        occurrence.state == FixedProgrammeOccurrenceState.completed ||
        occurrence.state == FixedProgrammeOccurrenceState.skipped) {
      return const BackfillProgrammeSessionResult(
        status: BackfillProgrammeSessionStatus.conflict,
        code: 'occurrence_ineligible',
      );
    }
    final dateDecision = BackfillPerformedDatePolicy.validate(
      scheduledDate: command.scheduledDate,
      performedOn: command.performedOn,
      today: calendar.today,
      assignmentStart: calendar.startDate,
      assignmentEnd: calendar.calendarEndDate,
    );
    if (!dateDecision.accepted) {
      return BackfillProgrammeSessionResult(
        status: BackfillProgrammeSessionStatus.rejected,
        code: dateDecision.code,
        message: dateDecision.message,
      );
    }

    final recordedAt = DateTime.now().toUtc();
    final performedOn = DateTime.parse(command.performedOn);
    final trainingSessionId = _nextTrainingSessionId++;
    final mapped = const PerformanceRecordMapper().fromDraft(
      command.draft.copyWith(
        status: TrainingSessionRecordStatus.completed,
        completedAt: recordedAt,
      ),
    );
    final record = TrainingSessionRecord(
      recordId: mapped.recordId,
      athleteId: command.athleteId,
      trainingSessionId: trainingSessionId,
      sourceProtocolId: mapped.sourceProtocolId,
      programmeId: mapped.programmeId,
      assignmentId: command.assignmentId,
      programmeSessionId: occurrence.sessionSlotId,
      status: TrainingSessionRecordStatus.completed,
      sessionSnapshot: mapped.sessionSnapshot,
      startedAt: recordedAt,
      completedAt: recordedAt,
      durationSeconds: mapped.durationSeconds,
      overallRpe: mapped.overallRpe,
      athleteNote: mapped.athleteNote,
      blockResults: mapped.blockResults,
      createdAt: recordedAt,
      updatedAt: recordedAt,
      entryMode: SessionResultEntryMode.backfill,
      performedOn: DateTime.utc(
        performedOn.year,
        performedOn.month,
        performedOn.day,
      ),
      performedPrecision: SessionPerformedPrecision.date,
      recordedAt: recordedAt,
    );
    performance.put(record);
    _idempotencyKeys.add(command.idempotencyKey);
    final next = calendar.copyWith(
      occurrences: [
        for (final item in calendar.occurrences)
          if (item.occurrenceId == occurrence.occurrenceId)
            item.copyWith(
              state: FixedProgrammeOccurrenceState.completed,
              trainingSessionId: trainingSessionId,
            )
          else
            item,
      ],
    );
    writeProjection?.call(next);
    return BackfillProgrammeSessionResult(
      status: BackfillProgrammeSessionStatus.saved,
      record: record,
    );
  }

  TrainingSessionRecord? _existingCompleted(
    BackfillProgrammeSessionCommand command,
  ) {
    for (final record in performance.records) {
      if (record.athleteId == command.athleteId &&
          record.assignmentId == command.assignmentId &&
          record.programmeSessionId == command.draft.programmeSessionId &&
          record.status == TrainingSessionRecordStatus.completed &&
          record.entryMode == SessionResultEntryMode.backfill) {
        return record;
      }
    }
    return null;
  }
}
