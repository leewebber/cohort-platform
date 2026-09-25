import 'package:flutter/foundation.dart';

import '../domain/programme_review_models.dart';

enum ProgrammeStudioView {
  overview,
  structure,
  session,
  validation,
  athlete,
  readiness,
}

class ProgrammeStudioSelection {
  const ProgrammeStudioSelection({
    required this.catalogId,
    this.weekNumber,
    this.dayKey,
    this.sessionKey,
    this.view = ProgrammeStudioView.overview,
  });

  final String catalogId;
  final int? weekNumber;
  final String? dayKey;
  final String? sessionKey;
  final ProgrammeStudioView view;

  ProgrammeStudioSelection copyWith({
    String? catalogId,
    int? weekNumber,
    String? dayKey,
    String? sessionKey,
    ProgrammeStudioView? view,
    bool clearSession = false,
  }) {
    return ProgrammeStudioSelection(
      catalogId: catalogId ?? this.catalogId,
      weekNumber: weekNumber ?? this.weekNumber,
      dayKey: dayKey ?? this.dayKey,
      sessionKey: clearSession ? null : (sessionKey ?? this.sessionKey),
      view: view ?? this.view,
    );
  }
}

class ProgrammeStudioController extends ChangeNotifier {
  ProgrammeStudioController({
    required ProgrammeReviewCatalog catalog,
    bool showDeveloperFixtures = false,
    ProgrammeStudioSelection? initialSelection,
  }) : _catalog = catalog,
       _showDeveloperFixtures = showDeveloperFixtures,
       _selection = initialSelection ??
           ProgrammeStudioSelection(
             catalogId: catalog
                 .realInventory(includeFixtures: showDeveloperFixtures)
                 .firstOrNull
                 ?.catalogId ??
               '',
           );

  ProgrammeReviewCatalog _catalog;
  bool _showDeveloperFixtures;
  ProgrammeStudioSelection _selection;

  ProgrammeReviewCatalog get catalog => _catalog;
  bool get showDeveloperFixtures => _showDeveloperFixtures;
  ProgrammeStudioSelection get selection => _selection;

  List<ProgrammeReviewProgramme> get inventory =>
      _catalog.realInventory(includeFixtures: _showDeveloperFixtures);

  ProgrammeReviewProgramme? get selectedProgramme {
    for (final item in inventory) {
      if (item.catalogId == _selection.catalogId) {
        return item;
      }
    }
    return inventory.firstOrNull;
  }

  ProgrammeReviewWeek? get selectedWeek {
    final programme = selectedProgramme;
    if (programme == null || programme.weeks.isEmpty) {
      return null;
    }
    final match = programme.weeks.where(
      (week) => week.weekNumber == _selection.weekNumber,
    );
    return match.isEmpty ? programme.weeks.first : match.first;
  }

  ProgrammeReviewDay? get selectedDay {
    final week = selectedWeek;
    if (week == null || week.days.isEmpty) {
      return null;
    }
    final match = week.days.where((day) => day.dayKey == _selection.dayKey);
    return match.isEmpty ? week.days.first : match.first;
  }

  ProgrammeReviewSession? get selectedSession {
    final day = selectedDay;
    if (day == null || day.sessions.isEmpty) {
      return null;
    }
    final match = day.sessions.where(
      (session) => session.sessionKey == _selection.sessionKey,
    );
    return match.isEmpty ? day.sessions.first : match.first;
  }

  void replaceCatalog(ProgrammeReviewCatalog catalog) {
    _catalog = catalog;
    notifyListeners();
  }

  void setShowDeveloperFixtures(bool value) {
    _showDeveloperFixtures = value;
    if (selectedProgramme == null && inventory.isNotEmpty) {
      _selection = ProgrammeStudioSelection(catalogId: inventory.first.catalogId);
    }
    notifyListeners();
  }

  void selectProgramme(String catalogId) {
    _selection = ProgrammeStudioSelection(
      catalogId: catalogId,
      view: _selection.view,
    );
    notifyListeners();
  }

  void selectWeek(int weekNumber) {
    _selection = _selection.copyWith(
      weekNumber: weekNumber,
      clearSession: true,
    );
    notifyListeners();
  }

  void selectDay(String dayKey) {
    _selection = _selection.copyWith(dayKey: dayKey, clearSession: true);
    notifyListeners();
  }

  void selectSession(String sessionKey) {
    _selection = _selection.copyWith(
      sessionKey: sessionKey,
      view: ProgrammeStudioView.session,
    );
    notifyListeners();
  }

  void selectView(ProgrammeStudioView view) {
    _selection = _selection.copyWith(view: view);
    notifyListeners();
  }

  void moveWeek(int delta) {
    final programme = selectedProgramme;
    if (programme == null || programme.weeks.isEmpty) {
      return;
    }
    final current = selectedWeek ?? programme.weeks.first;
    final index = programme.weeks.indexWhere(
      (week) => week.weekNumber == current.weekNumber,
    );
    final next = (index + delta).clamp(0, programme.weeks.length - 1);
    selectWeek(programme.weeks[next].weekNumber);
  }

  void moveDay(int delta) {
    final week = selectedWeek;
    if (week == null || week.days.isEmpty) {
      return;
    }
    final current = selectedDay ?? week.days.first;
    final index = week.days.indexWhere((day) => day.dayKey == current.dayKey);
    final next = (index + delta).clamp(0, week.days.length - 1);
    selectDay(week.days[next].dayKey);
  }

  void moveSession(int delta) {
    final day = selectedDay;
    if (day == null || day.sessions.isEmpty) {
      return;
    }
    final current = selectedSession ?? day.sessions.first;
    final index = day.sessions.indexWhere(
      (session) => session.sessionKey == current.sessionKey,
    );
    final next = (index + delta).clamp(0, day.sessions.length - 1);
    selectSession(day.sessions[next].sessionKey);
  }
}
