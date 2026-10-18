import 'package:yaml/yaml.dart';
import '../workspace_json.dart';
import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:flutter/foundation.dart';

import '../domain/programme_review_models.dart';
import '../projection/programme_review_projector.dart';
import '../projection/programme_review_source.dart';
import '../projection/sql_values_parser.dart';
import 'plan_package_v1_yaml_writer.dart';
import 'programme_authoring_fixtures.dart';
import 'programme_authoring_source.dart';

/// Opaque, detached candidate. Only its original editor may commit it.
class PreparedProgrammeSelection {
  PreparedProgrammeSelection._(
    this._owner,
    this._revision,
    this._source,
    this._tree,
  );
  final ProgrammeAuthoringController _owner;
  final int _revision;
  final String _source;
  final Map<String, dynamic> _tree;
  String get source => const PlanPackageV1YamlWriter().writeDraft(_tree);
}

/// Transient editing of an allowlisted synthetic canonical source. Every edit
/// removes the previous successful result; validation always compiles the
/// exact YAML that is later reviewed/copied. The editable canonical source is
/// also retained by the separate portable workspace envelope.
class ProgrammeAuthoringController extends ChangeNotifier {
  ProgrammeAuthoringController({
    required this.fixture,
    this.source,
    this.projector = const ProgrammeReviewProjector(),
  }) {
    _trusted = _clone(
      _compiler
          .compile(jsonEncode(source?.trustedTree ?? fixture.sourceTree))
          .canonicalJson!,
    );
    loadSource(source?.originalSource ?? fixture.source);
  }

  final ProgrammeAuthoringFixture fixture;
  final ProgrammeAuthoringSource? source;
  bool get supportsScheduleEditing => source?.supportsScheduleEditing ?? false;
  String get sourceId => source?.id ?? fixture.id;
  String get sourceLabel => source?.label ?? fixture.label;
  final ProgrammeReviewProjector projector;
  static const _compiler = PlanPackageCompiler();
  static const _writer = PlanPackageV1YamlWriter();
  static const programmeFields = {
    'name',
    'description',
    'coaching_intent',
    'primary_goal',
    'sessions_per_week',
  };
  static const textFields = {'title', 'coach_note'};
  static const slotFields = {
    'session_key',
    'time_of_day',
    'display_title',
    'coach_note',
  };
  late final Map<String, dynamic> _trusted;
  Map<String, dynamic>? _tree;
  String _originalSource = '';
  String? _originalCanonical;
  List<PlanPackageValidationIssue> _issues = [];
  PlanPackageCompileResult? _validated;
  ProgrammeReviewCatalog? _review;
  String? _export;
  int revision = 0;
  int? _reviewRevision;

  Map<String, dynamic>? get tree =>
      _tree == null ? null : _clone(jsonEncode(_tree));
  List<PlanPackageValidationIssue> get issues => List.unmodifiable(_issues);
  String get originalSource => _originalSource;
  String get draftSource => _tree == null ? '' : _writer.writeDraft(_tree!);
  String? get currentHash => isCurrent ? _validated!.contentHashSha256 : null;
  ProgrammeReviewCatalog? get currentReview => isCurrent ? _review : null;
  String? get exportYaml => isCurrent ? _export : null;
  bool get isCurrent =>
      _reviewRevision == revision && _validated != null && _review != null;
  bool get meaningChanged =>
      isCurrent && _validated!.canonicalJson != _originalCanonical;
  String get status => isCurrent
      ? 'Validated and reviewed — current source'
      : _issues.isNotEmpty
      ? 'Invalid draft — export and review unavailable'
      : 'Source changed — validate and refresh review';

  // The textual baseline is the original imported bytes (including comments).
  // Semantic comparison separately uses the original compiled canonical bytes.
  List<String> get sourceDiff {
    final before = _originalSource.split('\n');
    final after = draftSource.split('\n');
    // Line alignment separates normalization (for example a removed comment)
    // from authored edits. The baseline remains the exact imported bytes.
    final lengths = List.generate(
      before.length + 1,
      (_) => List<int>.filled(after.length + 1, 0),
    );
    for (var i = before.length - 1; i >= 0; i--) {
      for (var j = after.length - 1; j >= 0; j--) {
        lengths[i][j] = before[i] == after[j]
            ? lengths[i + 1][j + 1] + 1
            : (lengths[i + 1][j] >= lengths[i][j + 1]
                  ? lengths[i + 1][j]
                  : lengths[i][j + 1]);
      }
    }
    final diff = <String>[];
    var i = 0;
    var j = 0;
    while (i < before.length || j < after.length) {
      if (i < before.length && j < after.length && before[i] == after[j]) {
        i++;
        j++;
      } else if (i < before.length &&
          (j == after.length || lengths[i + 1][j] >= lengths[i][j + 1])) {
        diff.add('- ${i + 1}: ${before[i++]}');
      } else {
        diff.add('+ ${j + 1}: ${after[j++]}');
      }
    }
    return diff;
  }

  bool loadSource(String source) {
    _invalidate();
    final compiled = _compiler.compile(source);
    if (!compiled.isValid) {
      _tree = null;
      _issues = compiled.issues;
      notifyListeners();
      return false;
    }
    if (compiled.manifest!.packageSchemaVersion != 1) {
      _tree = null;
      _issues = [
        _issue(
          'package_schema_version',
          'unsupported_d1_schema',
          'D1 edits v1 only. Use existing read-only Studio for v2.',
        ),
      ];
      notifyListeners();
      return false;
    }
    final candidate = _clone(compiled.canonicalJson!);
    final scope = _scopeIssues(candidate);
    if (scope.isNotEmpty) {
      _tree = null;
      _issues = scope;
      notifyListeners();
      return false;
    }
    _originalSource = source;
    _originalCanonical = compiled.canonicalJson;
    _tree = candidate;
    notifyListeners();
    return true;
  }

  /// Restores an unvalidated form draft, keeping the fixed source baseline.
  /// No compiler/review receipt is restored; only existing editable fields vary.
  void restoreWorkspaceSource(String text, {bool legacySchedule = false}) {
    guardWorkspaceYaml(text);
    final decoded = jsonDecode(jsonEncode(loadYaml(text)));
    if (decoded is! Map<String, dynamic> ||
        _writer.writeDraft(decoded) != text ||
        _scopeIssues(decoded).isNotEmpty ||
        (legacySchedule &&
            !_equal(_legacySkeleton(decoded), _legacySkeleton(_trusted)))) {
      workspaceInvalid('Unsupported programme source/template.');
    }
    if (source == null ||
        encodeWorkspaceJson(decoded['sessions']) !=
            encodeWorkspaceJson(source!.sessionReferences)) {
      workspaceInvalid(
        'Programme availability differs from exact owned revisions.',
      );
    }
    void strings(Map map, Iterable<String> keys) {
      for (final k in keys) {
        if (map.containsKey(k) && map[k] != null) workspaceString(map[k], k);
      }
    }

    final p = decoded['programme'] as Map;
    strings(p, programmeFields.where((k) => k != 'sessions_per_week'));
    if (p['sessions_per_week'] is! int && p['sessions_per_week'] is! String) {
      workspaceInvalid('Invalid sessions-per-week input.');
    }
    final slotKeys = <String>{};
    final sessionKeys = source!.sessionReferences
        .map((r) => r['session_key'])
        .toSet();
    for (final w in decoded['weeks'] as List) {
      strings(w as Map, textFields);
      for (final d in w['days'] as List) {
        strings(d as Map, textFields);
        if (!{'training', 'rest', 'optional'}.contains(d['day_type'])) {
          workspaceInvalid('Unsupported day type.');
        }
        final slots = workspaceList(d['slots'], 'slots', max: 64);
        for (var i = 0; i < slots.length; i++) {
          final slot = slots[i] as Map;
          final key = workspaceString(slot['slot_key'], 'slot_key');
          if (key.trim().isEmpty ||
              !slotKeys.add(key) ||
              slot['session_order'] != i + 1 ||
              !sessionKeys.contains(slot['session_key'])) {
            workspaceInvalid('Conflicting slot identity/selection/order.');
          }
          strings(slot, slotFields);
        }
      }
    }
    _tree = _clone(jsonEncode(decoded));
    _invalidate();
    notifyListeners();
  }

  void reset() =>
      loadSource(_originalSource.isEmpty ? fixture.source : _originalSource);

  void editProgramme(String field, String value) => _edit(() {
    _allow(programmeFields, field);
    final programme = _tree!['programme'] as Map<String, dynamic>;
    if (field == 'sessions_per_week') {
      programme[field] = int.tryParse(value) ?? value;
    } else {
      _text(
        programme,
        field,
        value,
        required: field == 'name' || field == 'coaching_intent',
      );
    }
  });

  void editWeek(int week, String field, String value) => _edit(() {
    _allow(textFields, field);
    _text(_week(week), field, value);
  });

  void editDay(int week, int day, String field, String value) => _edit(() {
    _allow(textFields, field);
    _text(_day(week, day), field, value);
  });

  void setDayType(int week, int day, String type) => _edit(() {
    final target = _day(week, day);
    if (target['day_type'] == 'optional' ||
        !{'training', 'rest'}.contains(type)) {
      throw const FormatException(
        'Only existing training/rest day placement is editable.',
      );
    }
    target['day_type'] = type;
  });

  void editSlot(int week, int day, int slot, String field, String value) =>
      _edit(() {
        _allow(slotFields, field);
        final target = _slots(week, day)[slot] as Map<String, dynamic>;
        if (!_requiredSlot(target)) {
          throw const FormatException('Optional slots are read-only.');
        }
        _text(
          target,
          field,
          value,
          required: field == 'session_key' || field == 'time_of_day',
        );
      });

  void addSlot(int week, int day, String key, String sessionKey) => _edit(() {
    final target = _day(week, day);
    if (target['day_type'] != 'training') {
      throw const FormatException(
        'Choose a training day before adding a slot.',
      );
    }
    if (supportsScheduleEditing &&
        (key.trim().isEmpty ||
            (_tree!['weeks'] as List).any(
              (w) => (w['days'] as List).any(
                (d) => (d['slots'] as List).any((s) => s['slot_key'] == key),
              ),
            ))) {
      throw const FormatException('Choose a unique workout identifier.');
    }
    final template = _trustedSlots.values.first;
    final item = _clone(jsonEncode(template));
    item['slot_key'] = key;
    item['session_key'] = sessionKey;
    item['session_order'] = _slots(week, day).length + 1;
    _slots(week, day).add(item);
  });

  void removeSlot(int week, int day, int slot) => _edit(() {
    final slots = _slots(week, day);
    if (!_requiredSlot(slots[slot] as Map<String, dynamic>)) {
      throw const FormatException('Optional slots are read-only.');
    }
    slots.removeAt(slot);
    _renumber(slots);
  });

  void moveSlot(
    int fromWeek,
    int fromDay,
    int slot,
    int toWeek,
    int toDay,
    int position,
  ) => _edit(() {
    final targetDay = _day(toWeek, toDay);
    final source = _slots(fromWeek, fromDay);
    final item = source[slot] as Map<String, dynamic>;
    if (!_requiredSlot(item) || targetDay['day_type'] != 'training') {
      throw const FormatException(
        'Required slots can move only to a training day.',
      );
    }
    final target = _slots(toWeek, toDay);
    final maxPosition = target.length - (identical(source, target) ? 1 : 0);
    if (position < 0 || position > maxPosition) {
      throw const FormatException('Choose an existing valid slot position.');
    }
    source.removeAt(slot);
    target.insert(position, item);
    _renumber(source);
    _renumber(target);
  });

  bool validateAndReview() {
    _validated = null;
    _review = null;
    _reviewRevision = null;
    _export = null;
    if (_tree == null) {
      notifyListeners();
      return false;
    }
    final yaml = draftSource;
    final compiled = _compiler.compile(yaml);
    _issues = List.of(compiled.issues);
    if (compiled.isValid) {
      _issues.addAll(_scopeIssues(_clone(compiled.canonicalJson!)));
      _issues.addAll(_protocolIssues(compiled.manifest!));
      if (_issues.isEmpty) {
        try {
          final projected = projector.project(
            ProgrammeReviewProjectionRequest(
              bundles: [source?.bundle(yaml) ?? fixture.bundle(yaml)],
            ),
          );
          final programme = projected.developerFixtures.single;
          for (final session
              in programme.weeks
                  .expand((w) => w.days)
                  .expand((d) => d.sessions)) {
            if (!session.bodiesResolved ||
                session.blocks.isEmpty ||
                session.blocks.any(
                  (b) =>
                      b.unsupportedReason != null ||
                      b.movements.any((m) => m.unsupportedReason != null),
                )) {
              _issues.add(
                _issue(
                  'sessions.${session.sessionKey}',
                  'fixture_body_unresolved',
                  'The exact fixture prescription cannot be reviewed. Restore its immutable source.',
                ),
              );
            }
          }
          if (programme.findings.any(
            (f) => f.severity == ProgrammeReviewFindingSeverity.error,
          )) {
            _issues.add(
              _issue(
                'review',
                'fixture_review_failed',
                'The existing Studio projector rejected the fixture source.',
              ),
            );
          }
          if (_issues.isEmpty) {
            _validated = compiled;
            _review = projected;
            _export = yaml;
            _reviewRevision = revision;
          }
        } on FormatException catch (error) {
          _issues.add(_issue('review', 'fixture_review_failed', error.message));
        }
      }
    }
    notifyListeners();
    return isCurrent;
  }

  /// The copy boundary independently recompiles the reviewed exact text.
  String? verifiedExport() {
    if (!isCurrent) return null;
    final check = _compiler.compile(_export!);
    if (!check.isValid ||
        check.canonicalJson != _validated!.canonicalJson ||
        check.contentHashSha256 != _validated!.contentHashSha256 ||
        _export != draftSource) {
      _invalidate();
      _issues = [
        _issue(
          'export',
          'export_mismatch',
          'Source changed. Validate and review again before export.',
        ),
      ];
      notifyListeners();
      return null;
    }
    return _export;
  }

  List<PlanPackageValidationIssue> _scopeIssues(
    Map<String, dynamic> candidate,
  ) {
    final result = <PlanPackageValidationIssue>[];
    if ((source == null && !{'contracts', 'empty'}.contains(fixture.id)) ||
        !_equal(_scopeSkeleton(candidate), _scopeSkeleton(_trusted))) {
      result.add(
        _issue(
          'source',
          'locked_source_changed',
          'Use this synthetic fixture identity and preserve all locked source contracts, phases, weeks and days.',
        ),
      );
    }
    if (supportsScheduleEditing) {
      try {
        _checkScheduleShape(candidate);
        _checkLockedReferences(candidate);
      } on FormatException catch (error) {
        result.add(_issue('schedule', 'unsupported_schedule', error.message));
      }
    }
    final trustedSlots = _trustedSlots;
    for (final week in candidate['weeks'] as List) {
      for (final day in week['days'] as List) {
        for (final raw in day['slots'] as List) {
          final slot = raw as Map<String, dynamic>;
          final old = trustedSlots[slot['slot_key']];
          final expected = old ?? trustedSlots.values.first;
          if (!_equal(_lockedSlot(slot), _lockedSlot(expected))) {
            result.add(
              _issue(
                'slots.${slot['slot_key']}',
                'locked_slot_changed',
                'Preserve authored progression and required completion rules. New slots must reuse the exact fixture template.',
              ),
            );
          }
          if (!_requiredSlot(expected) && !_equal(slot, expected)) {
            result.add(
              _issue(
                'slots.${slot['slot_key']}',
                'optional_slot_locked',
                'Optional source constructs are read-only.',
              ),
            );
          }
        }
      }
    }
    return result;
  }

  // A detached candidate becomes the source only through the existing atomic
  // catalogue/selection commit. There is no separate schedule persistence model.
  PreparedProgrammeSelection prepareFourWeekSchedule(
    List<Map<String, dynamic>> references,
    String sessionA,
    String sessionB,
    int dayA,
    int dayB,
  ) {
    if (!supportsScheduleEditing || _tree == null) {
      throw const FormatException(
        'This source has no supported schedule editor.',
      );
    }
    final candidate = tree!;
    final weeks = candidate['weeks'] as List;
    final existing = [
      for (final w in weeks)
        for (final d in w['days'])
          for (final s in d['slots']) s,
    ];
    if (weeks.length != 1 ||
        existing.length != 1 ||
        existing.single['slot_key'] != 'W1D1S1' ||
        existing.single['session_key'] != sessionA) {
      throw const FormatException(
        'Setup preserves the original workout and its selected A version. '
        'This schedule already has other edits; use the individual workout controls.',
      );
    }
    if (dayA < 1 || dayA > 7 || dayB < 1 || dayB > 7 || dayA == dayB) {
      throw const FormatException('Choose two different days between 1 and 7.');
    }
    final byKey = {for (final r in references) r['session_key']: r};
    if (byKey[sessionA] == null ||
        byKey[sessionB] == null ||
        byKey[sessionA]!['session_lineage_id'] ==
            byKey[sessionB]!['session_lineage_id']) {
      throw const FormatException(
        'Choose exact versions from both independent sessions.',
      );
    }
    final firstWeek = weeks.single as Map<String, dynamic>;
    final originalDays = firstWeek['days'] as List;
    final anchor = existing.single;
    Map<String, dynamic> newSlot(int w, int d, String session) {
      final slot = _clone(jsonEncode(_trustedSlots.values.first));
      slot.removeWhere((k, _) => slotFields.contains(k));
      slot.addAll({
        'slot_key':
            'W$w'
            'D$d'
            'S${w == 1 && d == 1 ? 2 : 1}',
        'session_order': 1,
        'session_key': session,
        'time_of_day': 'any',
      });
      return slot;
    }

    candidate['weeks'] = [
      for (var w = 1; w <= 4; w++)
        {
          ..._clone(jsonEncode(firstWeek)),
          'week_number': w,
          if (w > 1) 'title': 'Synthetic week $w',
          if (w > 1) 'coach_note': '',
          'days': [
            for (var d = 1; d <= 7; d++)
              {
                ..._clone(
                  jsonEncode(
                    d <= originalDays.length
                        ? originalDays[d - 1]
                        : (_trusted['weeks'] as List).first['days'][1],
                  ),
                ),
                'day_key': 'day_$d',
                'day_order': d,
                if (w > 1 || d > originalDays.length)
                  'title': 'Synthetic day $d',
                if (w > 1 || d > originalDays.length) 'coach_note': '',
                'day_type': d == dayA || d == dayB ? 'training' : 'rest',
                'slots': [
                  if (d == dayA) w == 1 ? anchor : newSlot(w, d, sessionA),
                  if (d == dayB) newSlot(w, d, sessionB),
                ],
              },
          ],
        },
    ];
    // Preserve the old occurrence key even when it moves to another day.
    // No new key may collide with it.
    (candidate['programme'] as Map)['duration_weeks'] = 4;
    (candidate['programme'] as Map)['sessions_per_week'] = 2;
    candidate['sessions'] = references;
    final check = _compiler.compile(_writer.writeDraft(candidate));
    final scope = _scopeIssues(candidate);
    if (!check.isValid || scope.isNotEmpty) {
      throw FormatException(
        [...check.issues, ...scope].map((i) => i.message).join('\n'),
      );
    }
    return PreparedProgrammeSelection._(this, revision, draftSource, candidate);
  }

  void _checkScheduleShape(Map<String, dynamic> candidate) {
    final weeks = candidate['weeks'];
    if (weeks is! List ||
        !{1, 4}.contains(weeks.length) ||
        candidate['programme']['duration_weeks'] != weeks.length) {
      throw const FormatException(
        'Supported schedules are the original week or four weeks.',
      );
    }
    final base = (_trusted['weeks'] as List).first as Map;
    Map strip(Map row, Set<String> keys) =>
        Map.of(row)..removeWhere((k, _) => keys.contains(k));
    for (var w = 0; w < weeks.length; w++) {
      final week = weeks[w] as Map;
      if (week['week_number'] != w + 1 ||
          !_equal(
            strip(week, {'week_number', 'days', ...textFields}),
            strip(base, {'week_number', 'days', ...textFields}),
          )) {
        throw const FormatException(
          'Preserve the existing week phase and intent.',
        );
      }
      final days = week['days'] as List;
      if (days.length != (weeks.length == 1 ? 2 : 7)) {
        throw const FormatException(
          'Unsupported imported day structure; it cannot be edited.',
        );
      }
      for (var d = 0; d < days.length; d++) {
        final day = days[d] as Map;
        final template = base['days'][d == 0 ? 0 : 1] as Map;
        const editable = {
          'day_key',
          'day_order',
          'day_type',
          'slots',
          ...textFields,
        };
        if (day['day_key'] != 'day_${d + 1}' ||
            day['day_order'] != d + 1 ||
            !{'training', 'rest'}.contains(day['day_type']) ||
            !_equal(strip(day, editable), strip(template, editable))) {
          throw const FormatException(
            'Unsupported imported day fields; preserve source intent.',
          );
        }
      }
    }
  }

  Map<String, dynamic> _legacySkeleton(Map<String, dynamic> tree) {
    final value = _clone(jsonEncode(tree));
    value.remove('sessions');
    (value['programme'] as Map).removeWhere(
      (k, _) => programmeFields.contains(k),
    );
    for (final w in value['weeks'] as List) {
      (w as Map).removeWhere((k, _) => textFields.contains(k));
      for (final d in w['days'] as List) {
        (d as Map).removeWhere(
          (k, _) => textFields.contains(k) || k == 'slots' || k == 'day_type',
        );
      }
    }
    return value;
  }

  void _checkLockedReferences(Map<String, dynamic> candidate) {
    final slots = {
      for (final w in candidate['weeks'] as List)
        for (final d in w['days'])
          for (final s in d['slots']) s['slot_key']: s,
    };
    final days = {
      for (final w in candidate['weeks'] as List)
        for (final d in w['days']) d['day_key'],
    };
    final refs = {
      for (final s in candidate['sessions'] as List) s['session_key']: s,
    };
    final comparisons = {
      for (final c in candidate['comparison_identities'] as List) c['id']: c,
    };
    for (final a in candidate['assessments'] as List) {
      final slot = slots[a['slot_ref']];
      if (slot == null) {
        throw FormatException(
          'Workout ${a['slot_ref']} is required by locked assessment ${a['id']}. It cannot be removed.',
        );
      }
      final comparison = comparisons[a['comparison_identity_id']];
      if (refs[slot['session_key']]?['session_lineage_id'] !=
          comparison?['session_lineage_id']) {
        throw FormatException(
          'Workout ${a['slot_ref']} is bound to locked comparison ${a['comparison_identity_id']}. Choose a version from the same session lineage.',
        );
      }
    }
    for (final key in ['adaptation_permissions', 'protected_invariants']) {
      for (final declaration in candidate[key] as List) {
        final target = declaration['target_ref'];
        if (target is String &&
            !slots.containsKey(target) &&
            !days.contains(target) &&
            !(candidate['assessments'] as List).any((a) => a['id'] == target) &&
            !(candidate['phases'] as List).any(
              (p) => p['phase_key'] == target,
            )) {
          throw FormatException(
            'Locked $key declaration ${declaration['id']} requires $target; this schedule action is refused.',
          );
        }
      }
    }
  }

  Map<String, Map<String, dynamic>> get _trustedSlots => {
    for (final w in _trusted['weeks'] as List)
      for (final d in w['days'] as List)
        for (final s in d['slots'] as List)
          s['slot_key'] as String: s as Map<String, dynamic>,
  };

  Map<String, dynamic> _scopeSkeleton(Map<String, dynamic> tree) {
    final value = _clone(jsonEncode(tree));
    if (source != null) value.remove('sessions');
    if (supportsScheduleEditing) {
      value.remove('weeks');
      (value['programme'] as Map).remove('duration_weeks');
    }
    (value['programme'] as Map).removeWhere(
      (k, _) => programmeFields.contains(k),
    );
    for (final week in value['weeks'] as List? ?? []) {
      (week as Map).removeWhere((k, _) => textFields.contains(k));
      for (final day in week['days'] as List) {
        (day as Map).removeWhere(
          (k, _) => textFields.contains(k) || k == 'slots',
        );
        if (day['day_type'] != 'optional') day.remove('day_type');
      }
    }
    return value;
  }

  Map<String, dynamic> _lockedSlot(Map<String, dynamic> slot) {
    final value = _clone(jsonEncode(slot));
    value.removeWhere(
      (k, _) =>
          slotFields.contains(k) || k == 'slot_key' || k == 'session_order',
    );
    return value;
  }

  List<PlanPackageValidationIssue> _protocolIssues(
    PlanPackageManifest manifest,
  ) {
    if (source != null) return source!.catalogueIssues(manifest);
    final issues = <PlanPackageValidationIssue>[];
    try {
      // The fixture SQL schema/order is fixed, and package catalogue equality
      // was checked above. Titles never resolve a revision.
      final marker = RegExp(
        r'INSERT INTO public\.performance_protocols\(([^)]+)\) VALUES',
      );
      final matches = marker.allMatches(fixture.protocolSql).toList();
      if (matches.length != 1) {
        throw const FormatException(
          'Missing/duplicate fixture protocol declaration.',
        );
      }
      final columns = matches.single.group(1)!.split(',');
      final clause = const SqlInsertExtractor().valuesClause(
        sql: fixture.protocolSql,
        table: 'performance_protocols',
      );
      final tuples = const SqlValuesParser().parseTupleList(clause!);
      if (tuples.any((tuple) => tuple.length != columns.length)) {
        throw const FormatException(
          'Every fixture revision row must match the declared source columns.',
        );
      }
      final records = [
        for (final tuple in tuples) Map.fromIterables(columns, tuple),
      ];
      for (final ref in manifest.sessions) {
        final found = records
            .where((row) => row['protocol_id'] == ref.protocolId)
            .toList();
        if (found.length != 1 ||
            found.single['session_lineage_id'] != ref.sessionLineageId ||
            found.single['revision_number'] != ref.revisionNumber ||
            found.single['lifecycle_status'] != 'draft' ||
            found.single['published'] != 'false') {
          issues.add(
            _issue(
              'sessions.${ref.sessionKey}',
              'fixture_revision_mismatch',
              'Choose an exact unpublished fixture protocol, lineage and revision.',
            ),
          );
        }
      }
      if (records.length != manifest.sessions.length) {
        issues.add(
          _issue(
            'sessions',
            'fixture_catalogue_mismatch',
            'Fixture source catalogue must contain exactly the declared revisions.',
          ),
        );
      }
    } on FormatException catch (error) {
      issues.add(
        _issue('sessions', 'fixture_source_unsupported', error.message),
      );
    }
    return issues;
  }

  PreparedProgrammeSelection prepareCatalogueSelection(
    List<Map<String, dynamic>> references,
    String slotKey,
    String sessionKey,
  ) {
    if (source == null || _tree == null) {
      throw const FormatException('Programme source unavailable.');
    }
    final candidate = tree!;
    final targets = [
      for (final w in candidate['weeks'] as List)
        for (final d in w['days'] as List)
          for (final s in d['slots'] as List)
            if (s['slot_key'] == slotKey) s as Map<String, dynamic>,
    ];
    if (targets.length != 1 ||
        !_requiredSlot(targets.single) ||
        references.where((r) => r['session_key'] == sessionKey).length != 1) {
      throw const FormatException(
        'Choose an existing required workout and exact version.',
      );
    }
    targets.single['session_key'] = sessionKey;
    candidate['sessions'] = _clone(jsonEncode({'rows': references}))['rows'];
    final check = _compiler.compile(_writer.writeDraft(candidate));
    final scope = _scopeIssues(candidate);
    if (!check.isValid || scope.isNotEmpty) {
      throw FormatException(
        [...check.issues, ...scope].map((i) => i.message).join('\n'),
      );
    }
    return PreparedProgrammeSelection._(this, revision, draftSource, candidate);
  }

  bool isCurrentSelection(PreparedProgrammeSelection selection) =>
      identical(selection._owner, this) &&
      selection._revision == revision &&
      selection._source == draftSource;

  /// Both source lanes change before the one editor notification. No await or
  /// observer runs between the checked catalogue commit and detached tree install.
  bool commitCatalogueSelection(
    PreparedProgrammeSelection selection,
    VoidCallback commitCatalogue,
  ) {
    if (!isCurrentSelection(selection)) return false;
    commitCatalogue();
    _tree = selection._tree;
    _invalidate();
    notifyListeners();
    return true;
  }

  /// Only an injected source policy can supply an exact, detached catalogue.
  /// The existing draft and original comparison bytes are retained.
  void refreshSourceCatalogue() => _edit(() {
    if (source == null) {
      throw const FormatException('Fixed D1 catalogue is read-only.');
    }
    _tree!['sessions'] = jsonDecode(jsonEncode(source!.sessionReferences));
  });

  void _edit(VoidCallback mutation) {
    final before = tree;
    if (!supportsScheduleEditing) _invalidate();
    if (_tree == null) {
      _invalidate();
      _issues = [
        _issue(
          'source',
          'source_unavailable',
          'Reset or reopen a supported synthetic source before editing.',
        ),
      ];
    } else {
      try {
        mutation();
        if (supportsScheduleEditing) _checkLockedReferences(_tree!);
        if (supportsScheduleEditing) _invalidate();
      } on FormatException catch (error) {
        if (supportsScheduleEditing) _tree = before;
        _issues = [_issue('edit', 'unsupported_edit', error.message)];
      }
    }
    notifyListeners();
  }

  void _invalidate() {
    revision++;
    _issues = [];
    _validated = null;
    _review = null;
    _reviewRevision = null;
    _export = null;
  }

  Map<String, dynamic> _week(int index) =>
      (_tree!['weeks'] as List)[index] as Map<String, dynamic>;
  Map<String, dynamic> _day(int week, int day) =>
      (_week(week)['days'] as List)[day] as Map<String, dynamic>;
  List<dynamic> _slots(int week, int day) =>
      _day(week, day)['slots'] as List<dynamic>;
  static bool _requiredSlot(Map<String, dynamic> slot) =>
      slot['is_optional'] == false &&
      slot['completion_expectation'] == 'required';
  static void _renumber(List<dynamic> slots) {
    for (var i = 0; i < slots.length; i++) {
      slots[i]['session_order'] = i + 1;
    }
  }

  static void _allow(Set<String> fields, String field) {
    if (!fields.contains(field)) {
      throw FormatException(
        'The field "$field" is locked or unsupported in D1.',
      );
    }
  }

  static void _text(
    Map<String, dynamic> target,
    String key,
    String value, {
    bool required = false,
  }) {
    if (!required && value.isEmpty) {
      target.remove(key);
    } else {
      target[key] = value;
    }
  }

  static Map<String, dynamic> _clone(String json) =>
      jsonDecode(json) as Map<String, dynamic>;
  static bool _equal(Object? a, Object? b) {
    Object? sorted(Object? x) => x is Map
        ? {
            for (final k in (x.keys.cast<String>().toList()..sort()))
              k: sorted(x[k]),
          }
        : x is List
        ? x.map(sorted).toList()
        : x;
    return jsonEncode(sorted(a)) == jsonEncode(sorted(b));
  }

  static PlanPackageValidationIssue _issue(
    String path,
    String code,
    String message,
  ) => PlanPackageValidationIssue(path: path, code: code, message: message);
}
