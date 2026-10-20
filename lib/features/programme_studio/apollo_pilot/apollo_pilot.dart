import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../domain/programme_review_models.dart';
import '../projection/movement_prescription_review.dart';
import '../projection/executable_protocol_sql_reader.dart';
import '../projection/programme_review_catalog.dart';
import '../projection/programme_review_projector.dart';
import '../projection/programme_review_source.dart';
import '../projection/programme_review_workspace.dart';
import '../projection/sql_values_parser.dart';
import '../workspace_json.dart';
import 'apollo_pilot_pin.dart';

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();
Never _refuse(String message) =>
    throw FormatException('Apollo pilot: $message');

/// Local source-envelope compiler. No executable publication, canonical exercise
/// version claim, Founder YAML conversion or synthetic profile admission.
class ApolloPilotSource {
  ApolloPilotSource._(
    this._sources,
    this.session,
    this.protocol,
    this.profileRows,
  );
  static const originalProtocol = 'APOLLO-W4-SAT-R1';
  static const originalLineage = 'a1400006-0000-4000-8000-000000000006';
  static const localLineage = 'studio.local.apollo.w4.sat';
  static const target = 'Local pilot · Week 4 · Saturday (day 6) · Workout 1';
  static const strengthBlock = 'b1400015-0000-4000-8000-000000000015';
  static const sourceKind = 'cohort.apollo-local-session-source.v1';
  static const workspaceKind = 'cohort.apollo-local-workspace.v1';
  static const profileId =
      'cohort.apollo-local-row-profile.v1@${ApolloPilotPin.snapshotGitRevision}';

  final Map<String, String> _sources;
  final ProgrammeReviewSession session;
  final ExecutableProtocolRecord protocol;

  /// Complete retained SQL row JSON, not canonical ExerciseDefinitions.
  final Map<String, String> profileRows;
  Map<String, String> get sources => _sources;
  String get digest => _digest(encodeWorkspaceJson(_sources));

  String get retainedDefaultGuidance {
    final text =
        sources['tool/programmes/apollo_build_12_week_implementation_source.md']!;
    const heading = '## 10. Default rest and tempo rules';
    final start = text.indexOf(heading);
    final end = text.indexOf('\n---', start);
    if (start < 0 || end < start || text.indexOf(heading, start + 1) >= 0) {
      _refuse('Unique retained default guidance is unavailable.');
    }
    return text.substring(start, end).trimRight();
  }

  factory ApolloPilotSource.read(Map<String, String> inputs) {
    if (inputs.length != ApolloPilotPin.files.length ||
        !inputs.keys.every(ApolloPilotPin.files.containsKey)) {
      _refuse('The exact pinned source set is required.');
    }
    for (final pin in ApolloPilotPin.files.entries) {
      if (_digest(inputs[pin.key]!) != pin.value) {
        _refuse('Source changed or unavailable: ${pin.key}.');
      }
    }
    final sources = Map<String, String>.unmodifiable(inputs);
    final rows = <String, String>{};
    for (final pin in ApolloPilotPin.rows.entries) {
      final path = pin.value.$1;
      final matches = [
        for (final clause in const SqlInsertExtractor().valuesClauses(
          sql: sources[path]!,
          table: 'exercises_v2',
          publicQualified: !path.contains('wave1'),
        ))
          for (final row in const SqlValuesParser().parseTupleList(clause))
            if (row.isNotEmpty && row.first == pin.key) row,
      ];
      if (matches.length != 1 ||
          matches.single.length < 4 ||
          matches.single[3].toString().toLowerCase() != 'true' ||
          _digest(jsonEncode(matches.single)) != pin.value.$2) {
        _refuse(
          'Missing, ambiguous or changed local definition row: ${pin.key}.',
        );
      }
      rows[pin.key] = jsonEncode(matches.single);
    }
    final spec = ProgrammeReviewCatalogRegistry.realSpecs.first;
    final bundle = ProgrammeReviewWorkspace(
      readAsset: (p) => sources[p]!,
    ).loadBundle(spec);
    final programme = const ProgrammeReviewProjector()
        .project(
          ProgrammeReviewProjectionRequest(
            bundles: [bundle],
            plannedFamilies: [],
          ),
        )
        .programmes
        .single;
    final matches = programme.weeks
        .expand((w) => w.days)
        .expand((d) => d.sessions)
        .where((s) => s.protocolId == originalProtocol)
        .toList();
    if (programme.compile.state != ProgrammeReviewCompileState.valid ||
        matches.length != 1) {
      _refuse('Pinned programme/session cannot be compiled uniquely.');
    }
    final originalSession = matches.single;
    final session = ProgrammeReviewSession(
      sessionKey: originalSession.sessionKey,
      protocolId: originalSession.protocolId,
      sessionLineageId: originalSession.sessionLineageId,
      revisionNumber: originalSession.revisionNumber,
      title: originalSession.title,
      bodiesResolved: originalSession.bodiesResolved,
      displayTitle: originalSession.displayTitle,
      coachNote: originalSession.coachNote,
      prescriptionSummary: originalSession.prescriptionSummary,
      slotKey: originalSession.slotKey,
      sessionOrder: originalSession.sessionOrder,
      dayType: originalSession.dayType,
      timeOfDay: originalSession.timeOfDay,
      isOptional: originalSession.isOptional,
      completionExpectation: originalSession.completionExpectation,
      blocks: List.unmodifiable([
        for (final b in originalSession.blocks)
          ProgrammeReviewBlock(
            position: b.position,
            title: b.title,
            blockType: b.blockType,
            sourceIdentity: b.sourceIdentity,
            trainingIntent: b.trainingIntent,
            content: b.content,
            workoutFormat: b.workoutFormat,
            timerConfiguration: b.timerConfiguration,
            coachNotes: b.coachNotes,
            movements: List.unmodifiable(b.movements),
            unsupportedReason: b.unsupportedReason,
            omissionForbidden: b.omissionForbidden,
          ),
      ]),
      findings: List.unmodifiable(originalSession.findings),
    );
    final record = const ExecutableProtocolSqlReader()
        .readWithCorrections(
          insertSql: [
            for (final p in spec.executableProtocolSqlPaths) sources[p]!,
          ],
          corrections: [
            for (final p in spec.correctionSqlPaths)
              ProgrammeSqlSource(path: p, sql: sources[p]!),
          ],
        )
        .protocols[originalProtocol]!;
    final protocol = ExecutableProtocolRecord(
      protocolId: record.protocolId,
      name: record.name,
      purpose: record.purpose,
      primarySessionIntent: record.primarySessionIntent,
      coachingNotes: record.coachingNotes,
      blocks: session.blocks,
    );
    final movements = session.blocks.expand((b) => b.movements).toList();
    if (session.sessionLineageId != originalLineage ||
        session.revisionNumber != 1 ||
        !session.bodiesResolved ||
        session.blocks.length != 2 ||
        movements.length != 10 ||
        movements.map((m) => m.exerciseId).toSet().length != 10 ||
        movements.any(
          (m) =>
              !rows.containsKey(m.exerciseId) ||
              !MovementPrescriptionReview.fromMovement(m).complete,
        )) {
      _refuse('Complete exact session/profile review is unavailable.');
    }
    return ApolloPilotSource._(
      sources,
      session,
      protocol,
      Map.unmodifiable(rows),
    );
  }

  ProgrammeReviewMovement movement(String key) {
    final all = [
      for (final b in session.blocks)
        for (final m in b.movements)
          if (movementKey(b, m) == key) m,
    ];
    if (all.length != 1) _refuse('Unknown or ambiguous source movement.');
    return all.single;
  }

  static String movementKey(
    ProgrammeReviewBlock b,
    ProgrammeReviewMovement m,
  ) => '${b.sourceIdentity}/${m.position}/${m.exerciseId}';

  List<String> editableFields(String key) {
    final m = movement(key);
    if (!key.startsWith('$strengthBlock/')) return const [];
    final fields = readWorkspaceJson(m.rawPrescription!);
    return [
      'sets',
      if (fields.containsKey('reps')) 'reps',
      if (fields.containsKey('rir')) 'rir',
      if (fields.containsKey('rest_seconds')) 'rest_seconds',
    ];
  }

  Object parseEdit(String key, String field, String text) {
    if (!editableFields(key).contains(field)) {
      _refuse('This source field is read-only: $field.');
    }
    final original = readWorkspaceJson(movement(key).rawPrescription!)[field];
    int positive(String v, int max) {
      if (!RegExp(r'^[1-9][0-9]*$').hasMatch(v)) {
        _refuse('Enter a positive integer.');
      }
      final n = int.tryParse(v);
      if (n == null || n > max) _refuse('Value exceeds local editor bounds.');
      return n;
    }

    if (field == 'sets') return positive(text, 100);
    if (field == 'rir') {
      if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(text)) {
        _refuse('Enter an exact RIR integer.');
      }
      final n = int.tryParse(text);
      if (n == null || n > 100) _refuse('RIR exceeds local editor bounds.');
      return n;
    }
    if (field == 'reps' && original is int) return positive(text, 1000);
    if (field == 'reps' && original is String && original.endsWith('/leg')) {
      if (!text.endsWith('/leg')) _refuse('Keep the authored /leg form.');
      positive(text.substring(0, text.length - 4), 1000);
      return text;
    }
    if (field == 'rest_seconds' || (field == 'reps' && original is String)) {
      final match = RegExp(r'^([1-9][0-9]*)-([1-9][0-9]*)$').firstMatch(text);
      if (match == null) {
        _refuse('Keep the exact authored lower-upper range form.');
      }
      final max = field == 'rest_seconds' ? 3600 : 1000;
      final lower = positive(match.group(1)!, max),
          upper = positive(match.group(2)!, max);
      if (lower > upper) _refuse('Range lower bound exceeds upper bound.');
      return text;
    }
    _refuse('Unsupported field form remains read-only.');
  }

  Map<String, Map<String, Object>> validatePatches(Object? input) {
    if (input is! Map<String, dynamic> || input.length > 5) {
      _refuse('Invalid edit set.');
    }
    final result = <String, Map<String, Object>>{};
    for (final entry in input.entries) {
      if (entry.value is! Map<String, dynamic>) {
        _refuse('Invalid movement edits.');
      }
      final fields = entry.value as Map<String, dynamic>;
      if (fields.isEmpty || fields.length > 4) {
        _refuse('Invalid movement edits.');
      }
      final original = readWorkspaceJson(movement(entry.key).rawPrescription!);
      final accepted = <String, Object>{};
      for (final field in fields.entries) {
        final parsed = parseEdit(entry.key, field.key, '${field.value}');
        if (jsonEncode(parsed) != jsonEncode(field.value)) {
          _refuse('Edited type changed.');
        }
        if (parsed == original[field.key]) {
          _refuse('Redundant edits must be omitted.');
        }
        accepted[field.key] = parsed;
      }
      result[entry.key] = Map.unmodifiable(accepted);
    }
    return Map.unmodifiable(result);
  }

  /// Same loss-aware renderer as Coach Review, fed exact source plus field edits.
  ProgrammeReviewMovement reviewedMovement(
    String key,
    Map<String, Map<String, Object>> patches,
  ) {
    final original = movement(key), edits = patches[key];
    if (edits == null) return original;
    final fields = readWorkspaceJson(original.rawPrescription!)..addAll(edits);
    return ProgrammeReviewMovement(
      position: original.position,
      name: original.name,
      exerciseId: original.exerciseId,
      notes: original.notes,
      rawPrescription: encodeWorkspaceJson(fields),
    );
  }

  String revisionDigest(int number, Map<String, Map<String, Object>> patches) =>
      _digest(
        encodeWorkspaceJson({
          'source_digest': digest,
          'profile': profileId,
          'local_lineage': localLineage,
          'revision': number,
          'patches': patches,
        }),
      );

  ApolloPilotRevision compileRevision(int number, Object? input) {
    if (number < 1 || number > 128) _refuse('Revision is out of bounds.');
    final patches = validatePatches(input);
    if (number == 1 && patches.isNotEmpty) {
      _refuse('Original working copy is immutable.');
    }
    return ApolloPilotRevision._(
      number,
      patches,
      revisionDigest(number, patches),
    );
  }

  String exportCanonical(ApolloPilotRevision revision) {
    final verified = compileRevision(revision.number, revision.patches);
    if (verified.digest != revision.digest) _refuse('Revision changed.');
    return encodeWorkspaceJson({
      'kind': sourceKind,
      'profile': profileId,
      'sources': sources,
      'local_lineage': localLineage,
      'revision': revision.number,
      'patches': revision.patches,
      'digest': revision.digest,
    });
  }

  static (ApolloPilotSource, ApolloPilotRevision) recompileCanonical(
    String text,
  ) {
    final file = workspaceObject(readWorkspaceJson(text), {
      'kind',
      'profile',
      'sources',
      'local_lineage',
      'revision',
      'patches',
      'digest',
    }, 'pilot source');
    if (file['kind'] != sourceKind ||
        file['profile'] != profileId ||
        file['local_lineage'] != localLineage) {
      _refuse('This is not the pinned local Apollo source format.');
    }
    final source = _readSources(file['sources']);
    final revision = source.compileRevision(
      workspaceInt(file['revision'], 'revision', min: 1, max: 128),
      file['patches'],
    );
    if (revision.digest != file['digest']) {
      _refuse('Revision digest does not match.');
    }
    return (source, revision);
  }

  static ApolloPilotSource _readSources(Object? input) {
    if (input is! Map<String, dynamic> ||
        input.values.any((v) => v is! String)) {
      _refuse('Invalid source envelope.');
    }
    return ApolloPilotSource.read(input.cast<String, String>());
  }
}

class ApolloPilotRevision {
  const ApolloPilotRevision._(this.number, this.patches, this.digest);
  final int number;
  final Map<String, Map<String, Object>> patches;
  final String digest;
  String get protocolId => 'LOCAL-APOLLO-W4-SAT-R$number';
}

/// Consent is tied to the exact controller, generation and immutable sources.
class ApolloPilotSelection {
  const ApolloPilotSelection._(
    this._owner,
    this._generation,
    this.current,
    this.proposed,
    this.changes,
  );
  final ApolloPilotController _owner;
  final int _generation;
  final ApolloPilotRevision current, proposed;
  final List<ApolloPilotChange> changes;
}

class ApolloPilotChange {
  const ApolloPilotChange(this.key, this.name, this.before, this.after);
  final String key, name;
  final List<String> before, after;
}

class ApolloPilotStamp {
  const ApolloPilotStamp._(this._owner, this._generation);
  final ApolloPilotController _owner;
  final int _generation;
}

class ApolloPilotController extends ChangeNotifier {
  ApolloPilotController(this.source) {
    _revisions = [source.compileRevision(1, <String, dynamic>{})];
  }
  final ApolloPilotSource source;
  late List<ApolloPilotRevision> _revisions;
  Map<String, Map<String, Object>> _draft = const {};
  int _selected = 1, _generation = 0;
  List<ApolloPilotRevision> get revisions => List.unmodifiable(_revisions);
  Map<String, Map<String, Object>> get draft => _draft;
  ApolloPilotRevision get selected => _revisions[_selected - 1];

  ApolloPilotStamp stamp() => ApolloPilotStamp._(this, _generation);
  void requireFresh(ApolloPilotStamp stamp) {
    if (!identical(stamp._owner, this) || stamp._generation != _generation) {
      _refuse('Workspace changed. Review again.');
    }
  }

  void edit(String key, String field, String text) {
    final value = source.parseEdit(key, field, text);
    final original = readWorkspaceJson(
      source.movement(key).rawPrescription!,
    )[field];
    final next = <String, Map<String, Object>>{
      for (final e in _draft.entries) e.key: {...e.value},
    };
    final movement = next.putIfAbsent(key, () => {});
    if (value == original) {
      movement.remove(field);
    } else {
      movement[field] = value;
    }
    if (movement.isEmpty) next.remove(key);
    _draft = source.validatePatches(next);
    _changed();
  }

  void startFrom(ApolloPilotRevision revision) {
    if (!_revisions.contains(revision)) _refuse('Revision is not owned here.');
    _draft = revision.patches;
    _changed();
  }

  ApolloPilotRevision freeze() {
    if (_revisions.length >= 128) _refuse('Local revision limit reached.');
    final candidate = source.compileRevision(_revisions.length + 1, _draft);
    _revisions = [..._revisions, candidate];
    _changed();
    return candidate;
  }

  ApolloPilotSelection prepareUse(ApolloPilotRevision proposed) {
    if (!_revisions.contains(proposed)) _refuse('Revision is not owned here.');
    final current = selected;
    final changes = <ApolloPilotChange>[];
    for (final b in source.session.blocks) {
      for (final m in b.movements) {
        final key = ApolloPilotSource.movementKey(b, m);
        final before = source.reviewedMovement(key, current.patches);
        final after = source.reviewedMovement(key, proposed.patches);
        // Compare authored values, never JSON formatting or display titles.
        if (encodeWorkspaceJson(readWorkspaceJson(before.rawPrescription!)) !=
            encodeWorkspaceJson(readWorkspaceJson(after.rawPrescription!))) {
          changes.add(
            ApolloPilotChange(
              key,
              m.name,
              MovementPrescriptionReview.fromMovement(before).lines,
              MovementPrescriptionReview.fromMovement(after).lines,
            ),
          );
        }
      }
    }
    return ApolloPilotSelection._(
      this,
      _generation,
      current,
      proposed,
      List.unmodifiable(changes),
    );
  }

  void confirmUse(ApolloPilotSelection prepared) {
    if (!identical(prepared._owner, this) ||
        prepared._generation != _generation ||
        !identical(prepared.current, selected) ||
        !_revisions.contains(prepared.proposed)) {
      _refuse('Workspace changed. Review this selection again.');
    }
    _selected = prepared.proposed.number;
    _changed();
  }

  String saveWorkspace() => encodeWorkspaceJson({
    'kind': ApolloPilotSource.workspaceKind,
    'profile': ApolloPilotSource.profileId,
    'sources': source.sources,
    'revisions': [
      for (final r in _revisions)
        {'revision': r.number, 'patches': r.patches, 'digest': r.digest},
    ],
    'draft': _draft,
    'selected': _selected,
  });

  static ApolloPilotController reopen(String text) {
    final file = workspaceObject(readWorkspaceJson(text), {
      'kind',
      'profile',
      'sources',
      'revisions',
      'draft',
      'selected',
    }, 'pilot workspace');
    if (file['kind'] != ApolloPilotSource.workspaceKind ||
        file['profile'] != ApolloPilotSource.profileId) {
      _refuse('Unsupported workspace format.');
    }
    final source = ApolloPilotSource._readSources(file['sources']);
    final records = workspaceList(file['revisions'], 'revisions', max: 128);
    if (records.isEmpty) _refuse('Original working copy is missing.');
    final revisions = <ApolloPilotRevision>[];
    for (final item in records) {
      final record = workspaceObject(item, {
        'revision',
        'patches',
        'digest',
      }, 'revision');
      final n = workspaceInt(record['revision'], 'revision', min: 1, max: 128);
      if (n != revisions.length + 1) {
        _refuse('Revisions must be unique and consecutive.');
      }
      final revision = source.compileRevision(n, record['patches']);
      if (record['digest'] != revision.digest) {
        _refuse('Immutable revision digest changed.');
      }
      revisions.add(revision);
    }
    final candidate = ApolloPilotController(source);
    candidate._draft = source.validatePatches(file['draft']);
    candidate._selected = workspaceInt(
      file['selected'],
      'selection',
      min: 1,
      max: revisions.length,
    );
    candidate._revisions = revisions;
    return candidate;
  }

  void _changed() {
    _generation++;
    notifyListeners();
  }
}
