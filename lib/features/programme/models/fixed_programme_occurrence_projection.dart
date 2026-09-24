enum FixedProgrammeOccurrenceState {
  planned('PLANNED', 'Planned'),
  today('TODAY', 'Today'),
  inProgress('IN_PROGRESS', 'In Progress'),
  overdue('OVERDUE', 'Incomplete'),
  inProgressOverdue('IN_PROGRESS_OVERDUE', 'Incomplete'),
  completed('COMPLETED', 'Completed'),
  skipped('SKIPPED', 'Skipped'),
  missed('MISSED', 'Missed'),
  rest('REST', 'Rest');

  const FixedProgrammeOccurrenceState(this.wireValue, this.displayLabel);

  final String wireValue;
  final String displayLabel;

  static FixedProgrammeOccurrenceState parse(Object? value) {
    final wireValue = value?.toString();
    for (final state in values) {
      if (state.wireValue == wireValue) return state;
    }
    throw FormatException('Unknown fixed occurrence state: $wireValue');
  }
}

class FixedProgrammeOccurrenceProjection {
  const FixedProgrammeOccurrenceProjection({
    required this.assignmentId,
    required this.occurrenceId,
    required this.sessionSlotId,
    required this.programmeVersionId,
    required this.protocolId,
    required this.programmedSessionKey,
    required this.weekNumber,
    required this.dayKey,
    required this.sessionOrder,
    required this.scheduledDate,
    required this.originalScheduledDate,
    required this.state,
    required this.sessionTitle,
    this.sessionType,
    this.sessionLineageId,
    this.sessionRevisionNumber,
    this.trainingSessionId,
  });

  final String assignmentId;
  final String occurrenceId;
  final String sessionSlotId;
  final String programmeVersionId;
  final String protocolId;
  final String programmedSessionKey;
  final int weekNumber;
  final String dayKey;
  final int sessionOrder;
  final String scheduledDate;
  final String originalScheduledDate;
  final FixedProgrammeOccurrenceState state;
  final String sessionTitle;
  final String? sessionType;
  final String? sessionLineageId;
  final int? sessionRevisionNumber;
  final int? trainingSessionId;

  bool get isToday => state == FixedProgrammeOccurrenceState.today;

  bool get isOverdue =>
      state == FixedProgrammeOccurrenceState.overdue ||
      state == FixedProgrammeOccurrenceState.inProgressOverdue;

  /// Date-derived unfinished work. Legacy `MISSED` is not an explicit skip.
  bool get isDateDerivedUnfinished =>
      state == FixedProgrammeOccurrenceState.overdue ||
      state == FixedProgrammeOccurrenceState.missed;

  bool get isLateStartable => isDateDerivedUnfinished;

  bool get canOfferHistoricalBackfill => isDateDerivedUnfinished;

  bool get isExecutable => isToday || isResumable || isLateStartable;

  bool get wasRescheduled => scheduledDate != originalScheduledDate;

  bool get isResumable =>
      state == FixedProgrammeOccurrenceState.inProgress ||
      state == FixedProgrammeOccurrenceState.inProgressOverdue;

  factory FixedProgrammeOccurrenceProjection.fromMap(
    Map<String, dynamic> map, {
    required String assignmentId,
  }) {
    return FixedProgrammeOccurrenceProjection(
      assignmentId: assignmentId,
      occurrenceId: _requiredString(map, 'id'),
      sessionSlotId: _requiredString(map, 'session_slot_id'),
      programmeVersionId: _requiredString(map, 'programme_version_id'),
      protocolId: _requiredString(map, 'protocol_id'),
      programmedSessionKey: _requiredString(map, 'programmed_session_key'),
      weekNumber: _requiredPositiveInt(map, 'week_number'),
      dayKey: _requiredString(map, 'day_key'),
      sessionOrder: _requiredPositiveInt(map, 'session_order'),
      scheduledDate: _requiredDate(map, 'scheduled_date'),
      originalScheduledDate: _requiredDate(map, 'original_scheduled_date'),
      state: FixedProgrammeOccurrenceState.parse(map['state']),
      sessionTitle: _requiredString(map, 'session_title'),
      sessionType: _optionalString(map['session_type']),
      sessionLineageId: _optionalString(map['session_lineage_id']),
      sessionRevisionNumber: _optionalPositiveInt(
        map['session_revision_number'],
      ),
      trainingSessionId: _optionalPositiveInt(map['training_session_id']),
    );
  }

  FixedProgrammeOccurrenceProjection copyWith({
    FixedProgrammeOccurrenceState? state,
    int? trainingSessionId,
    String? scheduledDate,
  }) {
    return FixedProgrammeOccurrenceProjection(
      assignmentId: assignmentId,
      occurrenceId: occurrenceId,
      sessionSlotId: sessionSlotId,
      programmeVersionId: programmeVersionId,
      protocolId: protocolId,
      programmedSessionKey: programmedSessionKey,
      weekNumber: weekNumber,
      dayKey: dayKey,
      sessionOrder: sessionOrder,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      originalScheduledDate: originalScheduledDate,
      state: state ?? this.state,
      sessionTitle: sessionTitle,
      sessionType: sessionType,
      sessionLineageId: sessionLineageId,
      sessionRevisionNumber: sessionRevisionNumber,
      trainingSessionId: trainingSessionId ?? this.trainingSessionId,
    );
  }
}

class FixedProgrammeCalendarDayProjection {
  const FixedProgrammeCalendarDayProjection({
    required this.date,
    required this.state,
    this.occurrence,
  });

  final String date;
  final FixedProgrammeOccurrenceState state;
  final FixedProgrammeOccurrenceProjection? occurrence;

  bool get isRest => state == FixedProgrammeOccurrenceState.rest;

  factory FixedProgrammeCalendarDayProjection.fromMap(
    Map<String, dynamic> map, {
    required String assignmentId,
  }) {
    final state = FixedProgrammeOccurrenceState.parse(map['state']);
    final rawOccurrence = map['occurrence'];
    final occurrence = rawOccurrence is Map
        ? FixedProgrammeOccurrenceProjection.fromMap(
            Map<String, dynamic>.from(rawOccurrence),
            assignmentId: assignmentId,
          )
        : null;
    if (state == FixedProgrammeOccurrenceState.rest && occurrence != null) {
      throw const FormatException('Rest day cannot contain an occurrence');
    }
    if (state != FixedProgrammeOccurrenceState.rest && occurrence == null) {
      throw const FormatException('Executable calendar day missing occurrence');
    }
    return FixedProgrammeCalendarDayProjection(
      date: _requiredDate(map, 'date'),
      state: state,
      occurrence: occurrence,
    );
  }
}

class FixedProgrammeCalendarProjection {
  const FixedProgrammeCalendarProjection({
    required this.assignmentId,
    required this.programmeName,
    required this.timezone,
    required this.scheduleMode,
    required this.startDate,
    required this.today,
    required this.weekStart,
    required this.weekEnd,
    required this.occurrences,
    required this.currentWeek,
    this.assignmentStatus = 'active',
  });

  final String assignmentId;
  /// Persisted assignment status: `active` or `completed`.
  final String assignmentStatus;
  final String programmeName;
  final String timezone;
  final String scheduleMode;
  final String startDate;
  final String today;
  final String weekStart;
  final String weekEnd;
  final List<FixedProgrammeOccurrenceProjection> occurrences;
  final List<FixedProgrammeCalendarDayProjection> currentWeek;

  FixedProgrammeOccurrenceProjection? get todayOccurrence {
    final matches = occurrencesOnDate(today);
    return matches.isEmpty ? null : matches.first;
  }

  /// True when today is an authored rest day, not an executable session.
  bool get isRestToday {
    for (final day in currentWeek) {
      if (day.date == today) return day.isRest;
    }
    final todaySessions = occurrencesOnDate(today);
    return todaySessions.isEmpty ||
        todaySessions.every(
          (occurrence) => occurrence.state == FixedProgrammeOccurrenceState.rest,
        );
  }

  List<FixedProgrammeOccurrenceProjection> get todaySessions {
    return occurrencesOnDate(today)
        .where(
          (occurrence) => occurrence.state != FixedProgrammeOccurrenceState.rest,
        )
        .toList(growable: false);
  }

  /// Home consumes only today plus an optional rest-day next-session hint.
  FixedProgrammeCalendarProjection forHomeToday() {
    if (startsInFuture) {
      return copyWith(occurrences: const [], currentWeek: const []);
    }
    final todaySessions = occurrencesOnDate(today);
    final todayWeek = currentWeek
        .where((day) => day.date == today)
        .toList(growable: false);
    final restToday =
        todayWeek.any((day) => day.isRest) ||
        todaySessions.isEmpty ||
        todaySessions.every(
          (occurrence) => occurrence.state == FixedProgrammeOccurrenceState.rest,
        );
    final kept = <FixedProgrammeOccurrenceProjection>[...todaySessions];
    if (restToday) {
      final next = nextPlannedOccurrence;
      if (next != null &&
          !kept.any((occurrence) => occurrence.occurrenceId == next.occurrenceId)) {
        kept.add(next);
      }
    }
    return copyWith(
      occurrences: List.unmodifiable(kept),
      currentWeek: List.unmodifiable(todayWeek),
    );
  }

  FixedProgrammeCalendarProjection copyWith({
    List<FixedProgrammeOccurrenceProjection>? occurrences,
    List<FixedProgrammeCalendarDayProjection>? currentWeek,
  }) {
    return FixedProgrammeCalendarProjection(
      assignmentId: assignmentId,
      programmeName: programmeName,
      timezone: timezone,
      scheduleMode: scheduleMode,
      startDate: startDate,
      today: today,
      weekStart: weekStart,
      weekEnd: weekEnd,
      occurrences: occurrences ?? this.occurrences,
      currentWeek: currentWeek ?? this.currentWeek,
      assignmentStatus: assignmentStatus,
    );
  }

  List<FixedProgrammeOccurrenceProjection> get overdue => occurrences
      .where((occurrence) => occurrence.isOverdue)
      .toList(growable: false);

  String get calendarEndDate {
    var end = startDate;
    for (final occurrence in occurrences) {
      if (occurrence.scheduledDate.compareTo(end) > 0) {
        end = occurrence.scheduledDate;
      }
      if (occurrence.originalScheduledDate.compareTo(end) > 0) {
        end = occurrence.originalScheduledDate;
      }
    }
    return end;
  }

  FixedProgrammeOccurrenceProjection? occurrenceOnDate(String isoDate) {
    final matches = occurrencesOnDate(isoDate);
    return matches.isEmpty ? null : matches.first;
  }

  List<FixedProgrammeOccurrenceProjection> occurrencesOnDate(String isoDate) {
    final matches = occurrences
        .where((occurrence) => occurrence.scheduledDate == isoDate)
        .toList();
    matches.sort((a, b) => a.sessionOrder.compareTo(b.sessionOrder));
    return List.unmodifiable(matches);
  }

  bool isWithinOverdueRescheduleHorizon(String isoDate) {
    final selectedDate = _dateOnly(isoDate);
    final todayDate = _dateOnly(today);
    if (selectedDate == null || todayDate == null) return false;
    final days = selectedDate.difference(todayDate).inDays;
    return days >= 0 && days <= futureTrainTodayHorizonDays;
  }

  bool isWithinAssignmentCalendar(String isoDate) {
    return isoDate.compareTo(startDate) >= 0 &&
        isoDate.compareTo(calendarEndDate) <= 0;
  }

  FixedProgrammeOccurrenceProjection? get nextPlannedOccurrence {
    FixedProgrammeOccurrenceProjection? next;
    for (final occurrence in occurrences) {
      if (occurrence.scheduledDate.compareTo(today) <= 0 ||
          occurrence.state != FixedProgrammeOccurrenceState.planned) {
        continue;
      }
      if (next == null ||
          occurrence.scheduledDate.compareTo(next.scheduledDate) < 0) {
        next = occurrence;
      }
    }
    return next;
  }

  bool get startsInFuture => startDate.compareTo(today) > 0;

  bool get isInspectionOnly => assignmentStatus == 'completed';

  static const int futureTrainTodayHorizonDays = 7;

  /// Calendar days from athlete-local today to [selected], ignoring clock time.
  int? calendarDaysUntil(FixedProgrammeOccurrenceProjection selected) {
    final selectedDate = _dateOnly(selected.scheduledDate);
    final todayDate = _dateOnly(today);
    if (selectedDate == null || todayDate == null) return null;
    return selectedDate.difference(todayDate).inDays;
  }

  bool isWithinFutureTrainTodayHorizon(
    FixedProgrammeOccurrenceProjection selected,
  ) {
    final days = calendarDaysUntil(selected);
    return days != null && days >= 1 && days <= futureTrainTodayHorizonDays;
  }

  /// A clean one-for-one Train-today swap is locally plausible.
  ///
  /// The authenticated RPC remains the authority and still rejects when the
  /// server state is not a clean exchange.
  bool canOfferFutureTrainTodaySwap(
    FixedProgrammeOccurrenceProjection selected,
  ) {
    if (isInspectionOnly) return false;
    if (selected.assignmentId != assignmentId) return false;
    if (selected.state != FixedProgrammeOccurrenceState.planned) return false;
    if (!isWithinFutureTrainTodayHorizon(selected)) return false;
    final todaySession = todayOccurrence;
    if (todaySession == null) return false;
    if (todaySession.occurrenceId == selected.occurrenceId) return false;
    if (todaySession.trainingSessionId != null || todaySession.isResumable) {
      return false;
    }
    if (todaySession.state != FixedProgrammeOccurrenceState.today &&
        todaySession.state != FixedProgrammeOccurrenceState.planned) {
      return false;
    }
    for (final occurrence in occurrences) {
      if (occurrence.isResumable) return false;
    }
    return true;
  }

  factory FixedProgrammeCalendarProjection.fromMap(Map<String, dynamic> map) {
    final assignmentId = _requiredString(map, 'assignment_id');
    final rawOccurrences = map['occurrences'];
    final rawWeek = map['current_week'];
    if (rawOccurrences is! List || rawWeek is! List || rawWeek.length != 7) {
      throw const FormatException(
        'Fixed schedule projection must contain occurrences and seven week days',
      );
    }
    final scheduleMode = _requiredString(map, 'scheduling_mode');
    if (scheduleMode != 'fixed_schedule') {
      throw FormatException('Unsupported scheduling mode: $scheduleMode');
    }
    final occurrences = rawOccurrences
        .whereType<Map>()
        .map(
          (entry) => FixedProgrammeOccurrenceProjection.fromMap(
            Map<String, dynamic>.from(entry),
            assignmentId: assignmentId,
          ),
        )
        .toList(growable: false);
    if (occurrences.length != rawOccurrences.length) {
      throw const FormatException('Malformed fixed schedule occurrence list');
    }
    final currentWeek = rawWeek
        .whereType<Map>()
        .map(
          (entry) => FixedProgrammeCalendarDayProjection.fromMap(
            Map<String, dynamic>.from(entry),
            assignmentId: assignmentId,
          ),
        )
        .toList(growable: false);
    if (currentWeek.length != 7) {
      throw const FormatException('Malformed fixed schedule current week');
    }
    final assignmentStatus = _optionalString(map['assignment_status']) ?? 'active';
    if (assignmentStatus != 'active' && assignmentStatus != 'completed') {
      throw FormatException(
        'Unsupported assignment status: $assignmentStatus',
      );
    }
    return FixedProgrammeCalendarProjection(
      assignmentId: assignmentId,
      programmeName: _requiredString(map, 'programme_name'),
      timezone: _requiredString(map, 'programme_timezone'),
      scheduleMode: scheduleMode,
      startDate: _requiredDate(map, 'start_date'),
      today: _requiredDate(map, 'today'),
      weekStart: _requiredDate(map, 'week_start'),
      weekEnd: _requiredDate(map, 'week_end'),
      occurrences: List.unmodifiable(occurrences),
      currentWeek: List.unmodifiable(currentWeek),
      assignmentStatus: assignmentStatus,
    );
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = _optionalString(map[key]);
  if (value == null) throw FormatException('Missing fixed projection $key');
  return value;
}

String _requiredDate(Map<String, dynamic> map, String key) {
  final value = _requiredString(map, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || value.length != 10) {
    throw FormatException('Invalid fixed projection $key');
  }
  return value;
}

DateTime? _dateOnly(String raw) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (match == null) return null;
  return DateTime.utc(
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
  );
}

int _requiredPositiveInt(Map<String, dynamic> map, String key) {
  final value = _optionalPositiveInt(map[key]);
  if (value == null) throw FormatException('Invalid fixed projection $key');
  return value;
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _optionalPositiveInt(Object? value) {
  if (value == null) return null;
  final parsed = value is int ? value : int.tryParse(value.toString());
  return parsed == null || parsed <= 0 ? null : parsed;
}
