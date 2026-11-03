import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/database_uuid.dart';

import '../../session_revision/models/session_revision_usage_models.dart';
import '../authoring/plan_package_v2_yaml_writer.dart';
import '../authoring/programme_authoring_controller.dart';
import '../authoring/programme_authoring_fixtures.dart';
import '../authoring/programme_authoring_source.dart';
import '../domain/programme_review_models.dart';
import '../projection/programme_review_source.dart';
import '../local_revision_lifecycle.dart';
import '../workspace_json.dart';
import 'native_session_source.dart';
import 'catalogue_operation_receipt.dart';
import 'selected_source_profiles.dart';
export 'selected_source_profiles.dart'
    show hybridSourceDirectory, archivedHybridSourceDirectory;

const genuineWorkspaceProfile = 'hybrid10k_native_v2_legacy_rows_v1';

class NativeRevision {
  NativeRevision({
    required this.identity,
    required this.title,
    required this.source,
    required Map<String, dynamic> origin,
  }) : _origin = encodeWorkspaceJson(origin) {
    final keys = switch (origin['kind']) {
      'retained_source_snapshot_history_unknown' => {
        'kind',
        'path',
        'sha256',
        'source_week',
        'source_day',
      },
      'local_revision' => {'kind', 'parent', 'parent_sha256'},
      'explicit_source_copy_history_unknown' => {'kind', 'source_sha256'},
      'imported_native_snapshot_history_unknown' => {
        'kind',
        'source_index_sha256',
        'path',
        'sha256',
      },
      'new_local_draft_root_no_validation' => {'kind'},
      _ => throw const FormatException('Unknown local source origin.'),
    };
    workspaceObject(origin, keys, 'revision origin');
    if (origin.containsKey('source_week')) {
      workspaceInt(origin['source_week'], 'source week', min: 1, max: 10);
      workspaceInt(origin['source_day'], 'source day', min: 1, max: 7);
    }
  }
  final SessionRevisionIdentity identity;
  final String title, source;
  final String _origin;
  Map<String, dynamic> get origin => readWorkspaceJson(_origin);
  String get key =>
      'session-${identity.sessionLineageId}-r${identity.revisionNumber}';
  Map<String, dynamic> get reference => {
    'session_key': key,
    'protocol_id': identity.protocolId,
    'session_lineage_id': identity.sessionLineageId,
    'revision_number': identity.revisionNumber,
    'title': title,
  };
}

class NativeSessionOwner {
  NativeSessionOwner(this.lineage, NativeRevision root)
    : _revisions = [root],
      numbers = LocalRevisionNumbers(highWater: root.identity.revisionNumber);
  final String lineage;
  final List<NativeRevision> _revisions;
  List<NativeRevision> get revisions => List.unmodifiable(_revisions);
  final LocalRevisionNumbers numbers;
  Map<String, dynamic>? draft;
  int? parent, reserved;
  String? draftTitle;
  NativeRevision get latest => revisions.last;
  NativeRevision revision(int number) =>
      revisions.singleWhere((r) => r.identity.revisionNumber == number);
  void begin(int number) {
    if (draft != null) {
      throw StateError('Save or cancel this session draft first.');
    }
    final base = revision(number);
    parent = number;
    reserved = numbers.reserve(number);
    draft = readWorkspaceJson(base.source)
      ..['protocol_id'] = 'protocol-${DatabaseUuid.newV4()}'
      ..['revision_number'] = reserved;
    draftTitle = base.title;
  }

  void cancel() {
    numbers.reservations.remove(reserved);
    draft = null;
    parent = null;
    reserved = null;
    draftTitle = null;
  }
}

/// Shared programme authoring policy over native session owners. The source
/// catalogue is exact identities; titles are never lookup authority.
class GenuineProgrammeSource implements NativeProgrammeAuthoringSource {
  GenuineProgrammeSource(this.initialTree, this.owners)
    : available = {
        for (final r in initialTree['sessions'] as List)
          r['session_key'] as String,
      };
  final Map<String, dynamic> initialTree;
  final SessionOwnerCollection<NativeSessionOwner> owners;
  final Set<String> available;
  @override
  bool get supportsScheduleEditing => true;
  @override
  String get id => genuineWorkspaceProfile;
  @override
  String get label => 'Genuine Hybrid 10K draft — D8 pending';
  @override
  Map<String, dynamic> get trustedTree => nativeCopy(initialTree);
  @override
  String get originalSource => writeDraft(initialTree);
  @override
  List<Map<String, dynamic>> get sessionReferences => [
    for (final o in owners.values)
      for (final r in o.revisions)
        if (available.contains(r.key)) r.reference,
  ];
  @override
  String writeDraft(Map<String, dynamic> tree) =>
      const PlanPackageV2YamlWriter().writeDraft(tree);
  @override
  void checkScheduleShape(Map<String, dynamic> tree) {
    final weeks = workspaceList(tree['weeks'], 'programme weeks', max: 10);
    if (weeks.isEmpty || tree['programme']['duration_weeks'] != weeks.length) {
      throw const FormatException('Choose one to ten complete weeks.');
    }
    final slots = <String>{};
    for (var w = 0; w < weeks.length; w++) {
      final week = weeks[w] as Map;
      if (week['week_number'] != w + 1 || (week['days'] as List).length != 7) {
        throw const FormatException('Each week needs seven ordered days.');
      }
      for (var d = 0; d < 7; d++) {
        final day = week['days'][d];
        if (day['day_order'] != d + 1 ||
            day['day_key'] != 'day_${d + 1}' ||
            !{'rest', 'training'}.contains(day['day_type']) ||
            day['day_type'] == 'rest' && (day['slots'] as List).isNotEmpty) {
          throw const FormatException(
            'Rest days cannot contain workouts. Preserve day ordering.',
          );
        }
        for (final s in day['slots']) {
          if (!slots.add(s['slot_key'] as String)) {
            throw const FormatException(
              'Workout occurrence keys must be unique.',
            );
          }
          if (s['is_optional'] == true ||
              s['completion_expectation'] != null &&
                  s['completion_expectation'] != 'required') {
            throw const FormatException(
              'This bounded source supports required training slots only.',
            );
          }
        }
      }
    }
  }

  @override
  List<PlanPackageValidationIssue> catalogueIssues(
    PlanPackageManifest manifest,
  ) {
    final refs = {for (final r in sessionReferences) r['session_key']: r};
    return [
      for (final s in manifest.sessions)
        if (refs[s.sessionKey]?['protocol_id'] != s.protocolId ||
            refs[s.sessionKey]?['revision_number'] != s.revisionNumber ||
            refs[s.sessionKey]?['session_lineage_id'] != s.sessionLineageId)
          PlanPackageValidationIssue(
            path: 'sessions.${s.sessionKey}',
            code: 'exact_revision_required',
            message: 'Choose an exact owned session revision.',
          ),
    ];
  }

  String get graphs => jsonEncode([
    for (final o in owners.values)
      for (final r in o.revisions)
        if (available.contains(r.key)) jsonDecode(r.source),
  ]);
  @override
  ProgrammeReviewSourceBundle bundle(String exactYaml) =>
      ProgrammeReviewSourceBundle(
        spec: const ProgrammeReviewSourceSpec(
          catalogId: genuineWorkspaceProfile,
          classification: ProgrammeReviewClassification.internalPrivate,
          planPackagePath: 'programme.plan-package.yaml',
          reviewedProtocolGraphPath: 'protocol-graphs.json',
        ),
        planPackageYaml: exactYaml,
        reviewedProtocolGraphJson: graphs,
        localNativeGraphSha256: nativeDigest(graphs),
      );
}

class PreparedGenuineOpen {
  PreparedGenuineOpen._(this.owner, this.generation, this.candidate);
  final GenuineWorkspace owner;
  final int generation;
  final GenuineWorkspace candidate;
}

/// Existing Studio source-first programme editor, native revision owners and
/// editable JSON envelope. No database, athlete-input or publication ports.
class GenuineWorkspace extends ChangeNotifier {
  GenuineWorkspace._(
    this.owners,
    this.catalogue,
    this.origins,
    Map<String, dynamic> tree,
  ) {
    policy = GenuineProgrammeSource(tree, owners);
    programme = ProgrammeAuthoringController(
      fixture: programmeAuthoringFixtures.first,
      source: policy,
    );
    if (programme.tree == null) {
      throw FormatException(
        programme.issues.map((i) => '${i.path}: ${i.message}').join('\n'),
      );
    }
    _programmeRevision = programme.revision;
    programme.addListener(_programmeChanged);
  }
  final SessionOwnerCollection<NativeSessionOwner> owners;
  LegacyCatalogueEvidence catalogue;
  final Map<String, dynamic> origins;
  late final GenuineProgrammeSource policy;
  late final ProgrammeAuthoringController programme;
  int generation = 0;
  int _programmeRevision = 0;
  bool _disposed = false;
  String? _savedText;
  List<Map<String, String>> _trustedBootstrapSources = const [];
  bool get isArchivedRunningSource =>
      origins.keys.any((k) => k.startsWith('$archivedHybridSourceDirectory/'));

  List<NativeSessionReceipt>? _review;
  String? _reviewFingerprint;
  bool get hasDrafts => owners.values.any((o) => o.draft != null);
  List<String> errors = [];
  List<NativeSessionReceipt> get review => List.unmodifiable(_review ?? []);
  bool get reviewCurrent =>
      _review != null && _reviewFingerprint == fingerprint;
  String get fingerprint {
    try {
      return nativeDigest(save());
    } on FormatException {
      return 'invalid:$generation:${programme.revision}';
    }
  }

  bool get unsaved {
    try {
      return _savedText != save();
    } on FormatException {
      return true;
    }
  }

  String? get saveError {
    try {
      save();
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  String get status => saveError != null
      ? 'Invalid draft — ${saveError!}'
      : hasDrafts
      ? 'Editable draft — session edits pending'
      : reviewCurrent && errors.isEmpty
      ? 'Locally validated revision — prepared export available'
      : 'Editable draft — refresh exact prescription review';
  void _changed() {
    generation++;
    _review = null;
    _reviewFingerprint = null;
    errors = [];
    if (!_disposed) notifyListeners();
  }

  void _programmeChanged() {
    if (programme.revision != _programmeRevision) {
      _programmeRevision = programme.revision;
      _changed();
    } else if (!_disposed) {
      notifyListeners();
    }
  }

  static Future<GenuineWorkspace> load({AssetBundle? assets}) async {
    final bundle = assets ?? rootBundle;
    final sources = <Map<String, String>>[];
    for (final directory in [
      hybridSourceDirectory,
      archivedHybridSourceDirectory,
    ]) {
      final values = await Future.wait(
        selectedSourceFiles.map((n) => bundle.loadString('$directory/$n')),
      );
      sources.add(Map.fromIterables(selectedSourceFiles, values));
    }
    return fromSelectedSources(
      sources.first,
      historicalSources: sources.skip(1).toList(),
    );
  }

  static GenuineWorkspace fromSelectedSources(
    Map<String, String> sources, {
    List<Map<String, String>> historicalSources = const [],
  }) {
    final directory = verifiedSourceDirectory(sources);
    for (final historical in historicalSources) {
      verifiedSourceDirectory(historical);
    }
    final schedule = nativeCopy(
      jsonDecode(sources['SCHEDULE_CANDIDATE.json']!) as Map,
    )..['package_schema_version'] = 2;
    final owners = SessionOwnerCollection<NativeSessionOwner>();
    final strength =
        jsonDecode(sources['STRENGTH_REVIEW_GRAPHS.json']!) as List;
    final selectedSource = jsonDecode(sources['SOURCE.json']!) as Map;
    final runs = jsonDecode(sources['RUNNING_BODIES.json']!) as List;
    final refs = <Map<String, dynamic>>[];
    for (final old in schedule['sessions'] as List) {
      final id = old['session_key'];
      final isStrength = strength.any((g) => g['source_session_id'] == id);
      Map<String, dynamic> graph;
      if (isStrength) {
        graph = nativeCopy(
          strength.singleWhere((g) => g['source_session_id'] == id) as Map,
        );
        final sourceSession = (selectedSource['sessions'] as List).singleWhere(
          (s) => s['session_id'] == id,
        );
        final instructions = (sourceSession['instructions'] as List)
            .cast<String>()
            .join('\n');
        if (instructions.isNotEmpty) {
          graph['blocks'][0]['coach_notes'] = instructions;
        }
      } else {
        final run = runs.singleWhere((g) => g['source_session_id'] == id);
        graph = {
          'protocol_id': old['protocol_id'],
          'revision_number': old['revision_number'],
          'blocks': [
            {
              'position': 1,
              'block_type': 'conditioning',
              'title': run['workout']['title'],
              'content':
                  'Genuine selected draft. D8 full-programme content review pending.',
              'coach_notes': run['workout']['notes'],
              'workout_format': 'steady_state',
              'performance_capture_mode': 'endurance',
              'timer_config': {
                'durationSeconds': run['fixed_seconds'],
                'running_workout': run['workout'],
              },
              'exercises': [],
            },
          ],
        };
      }
      final revision = NativeRevision(
        identity: SessionRevisionIdentity(
          protocolId: old['protocol_id'] as String,
          sessionLineageId: old['session_lineage_id'] as String,
          revisionNumber: old['revision_number'] as int,
        ),
        title: old['title'] as String,
        source: jsonEncode(graph),
        origin: {
          'kind': 'retained_source_snapshot_history_unknown',
          'source_week': (selectedSource['sessions'] as List).singleWhere(
            (s) => s['session_id'] == id,
          )['week'],
          'source_day': (selectedSource['sessions'] as List).singleWhere(
            (s) => s['session_id'] == id,
          )['day'],
          'path':
              '$directory/${isStrength ? 'STRENGTH_REVIEW_GRAPHS.json' : 'RUNNING_BODIES.json'}',
          'sha256': nativeDigest(
            sources[isStrength
                ? 'STRENGTH_REVIEW_GRAPHS.json'
                : 'RUNNING_BODIES.json']!,
          ),
        },
      );
      owners.add(
        revision.identity.sessionLineageId,
        NativeSessionOwner(revision.identity.sessionLineageId, revision),
      );
      refs.add(revision.reference);
      for (final w in schedule['weeks']) {
        for (final d in w['days']) {
          for (final s in d['slots']) {
            if (s['session_key'] == id) s['session_key'] = revision.key;
          }
        }
      }
    }
    schedule['sessions'] = refs;
    final workspace = GenuineWorkspace._(
      owners,
      LegacyCatalogueEvidence(
        jsonDecode(sources['IDENTITY_INTAKE.json']!) as Map<String, dynamic>,
      ),
      {
        for (final e in sources.entries)
          '$directory/${e.key}': nativeDigest(e.value),
      },
      schedule,
    );
    workspace._trustedBootstrapSources = [
      for (final profile in [sources, ...historicalSources])
        Map.unmodifiable(profile),
    ];
    return workspace;
  }

  NativeRevision selected(String slotKey) {
    final slot = occurrences.singleWhere((s) => s['slot_key'] == slotKey);
    return owners.values
        .expand((o) => o.revisions)
        .singleWhere((r) => r.key == slot['session_key']);
  }

  List<Map<String, dynamic>> get occurrences => [
    for (final w in programme.tree!['weeks'])
      for (final d in w['days'])
        for (final s in d['slots'])
          {
            ...Map<String, dynamic>.from(s as Map),
            'week': w['week_number'],
            'day': d['day_order'],
          },
  ];
  NativeSessionOwner ownerOf(NativeRevision revision) =>
      owners[revision.identity.sessionLineageId];
  String sessionLabel(NativeRevision revision) {
    final root = ownerOf(revision).revisions.first.origin;
    final week = root['source_week'], day = root['source_day'];
    final prefix = week == null
        ? ''
        : 'Source week $week ${['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][(day as int) - 1]} · ';
    final graph = readWorkspaceJson(revision.source);
    final work = (graph['blocks'] as List).where(
      (b) => b['timer_config'] != null,
    );
    final workoutTitle = work.isEmpty
        ? null
        : work.first['timer_config']['running_workout']['title'];
    return '$prefix${revision.title}${workoutTitle != null && workoutTitle != revision.title ? ' · $workoutTitle' : ''} · version ${revision.identity.revisionNumber}';
  }

  void begin(NativeRevision revision) {
    ownerOf(revision).begin(revision.identity.revisionNumber);
    _changed();
  }

  void cancel(NativeSessionOwner owner) {
    owner.cancel();
    _changed();
  }

  void edit(
    NativeSessionOwner owner,
    void Function(Map<String, dynamic>) change,
  ) {
    if (owner.draft == null) throw StateError('Open a session draft first.');
    final before = nativeCopy(owner.draft!);
    change(owner.draft!);
    final previous = {
      for (final b in before['blocks'])
        for (final e in b['exercises'])
          e['source_occurrence_id']: e['prescription'],
    };
    for (final b in owner.draft!['blocks']) {
      for (final e in b['exercises']) {
        final p = e['prescription'] as Map;
        if (nativeEqual(previous[e['source_occurrence_id']], p)) continue;
        final details =
            p.putIfAbsent('authored_details', () => <String, dynamic>{}) as Map;
        final reps = p['reps'] as Map;
        details['source_repetitions_or_duration'] = switch (reps['type']) {
          'exact' =>
            '${reps['exact_reps']}${p['per_side'] == true ? '/side' : ''}',
          'range' =>
            '${reps['min_reps']}–${reps['max_reps']}${p['per_side'] == true ? '/side' : ''}',
          _ => reps['text']?.toString() ?? '',
        };
        details['source_tempo_reference'] = p['tempo'] ?? '';
        details['source_dose_status'] = 'LOCAL_PROPOSED_EDIT_D8_PENDING';
      }
    }
    _changed();
  }

  /// The caller supplies a separately pinned/audited operation receipt. Existing
  /// revision bytes are never rebound silently; the founder explicitly selects
  /// the retained setup in a later draft and chooses affected occurrences.
  void installRetainedCatalogueOperation(RetainedCatalogueOperation operation) {
    catalogue = operation.bind(catalogue);
    _changed();
  }

  NativeSessionReceipt inspect(NativeSessionOwner owner) {
    final graph = owner.draft;
    return const NativeSessionCompiler().compile(
      source: graph == null ? owner.latest.source : jsonEncode(graph),
      identity: graph == null
          ? owner.latest.identity
          : SessionRevisionIdentity(
              protocolId: graph['protocol_id'] as String,
              sessionLineageId: owner.lineage,
              revisionNumber: owner.reserved!,
            ),
      catalogue: catalogue,
      title: owner.draftTitle ?? owner.latest.title,
    );
  }

  NativeSessionReceipt inspectRevision(NativeRevision revision) =>
      const NativeSessionCompiler().compile(
        source: revision.source,
        identity: revision.identity,
        catalogue: catalogue,
        title: revision.title,
      );

  bool freeze(NativeSessionOwner owner) {
    if (owner.revisions.length >= 128 || policy.available.length >= 128) {
      errors = [
        'The local revision/inventory limit is reached. Keep the editable file; exclude unused programme sources before adding another revision.',
      ];
      notifyListeners();
      return false;
    }
    final receipt = inspect(owner);
    if (!receipt.admitted) {
      errors = receipt.issues;
      notifyListeners();
      return false;
    }
    if (owner.draft == null) return false;
    final parent = owner.revision(owner.parent!);
    final before = readWorkspaceJson(parent.source)
      ..remove('protocol_id')
      ..remove('revision_number');
    final after = nativeCopy(owner.draft!)
      ..remove('protocol_id')
      ..remove('revision_number');
    if (nativeEqual(before, after) && parent.title == owner.draftTitle) {
      errors = [
        'No prescription change. Cancel to keep the original revision.',
      ];
      notifyListeners();
      return false;
    }
    final frozen = NativeRevision(
      identity: receipt.identity,
      title: owner.draftTitle!,
      source: receipt.source,
      origin: {
        'kind': 'local_revision',
        'parent': owner.parent!,
        'parent_sha256': nativeDigest(parent.source),
      },
    );
    owner._revisions.add(frozen);
    if (parent.origin['kind'] == 'new_local_draft_root_no_validation' &&
        !occurrences.any((s) => s['session_key'] == parent.key)) {
      policy.available.remove(parent.key);
    }
    policy.available.add(frozen.key);
    owner.numbers.parents[owner.reserved!] = owner.parent!;
    owner.cancel();
    programme.refreshSourceCatalogue();
    return true;
  }

  void useRevision(
    NativeRevision revision,
    List<String> slotKeys,
    int expectedGeneration,
  ) {
    if (generation != expectedGeneration) {
      throw StateError(
        'Sources changed. Review the affected occurrence list again.',
      );
    }
    if (!policy.available.contains(revision.key)) {
      throw const FormatException(
        'Add this saved source to the programme inventory first.',
      );
    }
    if (slotKeys.isEmpty || slotKeys.toSet().length != slotKeys.length) {
      throw const FormatException('Select exact workout occurrences.');
    }
    programme.editNativeArrangement((tree) {
      final found = <String>{};
      for (final w in tree['weeks']) {
        for (final d in w['days']) {
          for (final s in d['slots']) {
            if (slotKeys.contains(s['slot_key'])) {
              s['session_key'] = revision.key;
              found.add(s['slot_key'] as String);
            }
          }
        }
      }
      if (found.length != slotKeys.length) {
        throw const FormatException('An affected workout no longer exists.');
      }
    });
    _excludeUnusedEmptyRoots();
  }

  void place(int week, int day, NativeRevision revision) =>
      programme.editNativeArrangement((tree) {
        if (!policy.available.contains(revision.key)) {
          throw const FormatException(
            'Add this saved source to the programme inventory first.',
          );
        }
        final d = tree['weeks'][week]['days'][day];
        d['day_type'] = 'training';
        (d['slots'] as List).add({
          'slot_key': 'slot-${DatabaseUuid.newV4()}',
          'session_key': revision.key,
          'session_order': (d['slots'] as List).length + 1,
          'time_of_day': 'any',
          'is_optional': false,
          'completion_expectation': 'required',
          'progression': {
            'prescription_summary':
                'Authored local placement. No automatic progression.',
          },
        });
      });
  void _excludeUnusedEmptyRoots() {
    final used = occurrences.map((s) => s['session_key']).toSet();
    final empty = {
      for (final owner in owners.values)
        if (owner.draft == null &&
            owner.revisions.first.origin['kind'] ==
                'new_local_draft_root_no_validation' &&
            !used.contains(owner.revisions.first.key))
          owner.revisions.first.key,
    };
    final count = policy.available.length;
    policy.available.removeAll(empty);
    if (count != policy.available.length) programme.refreshSourceCatalogue();
  }

  void removeOccurrence(String slotKey) {
    if (!occurrences.any((s) => s['slot_key'] == slotKey)) {
      throw const FormatException('Choose a session again.');
    }
    programme.editNativeArrangement((tree) {
      for (final week in tree['weeks']) {
        for (final day in week['days']) {
          final slots = day['slots'] as List;
          slots.removeWhere((s) => s['slot_key'] == slotKey);
          for (var i = 0; i < slots.length; i++) {
            slots[i]['session_order'] = i + 1;
          }
          if (slots.isEmpty) day['day_type'] = 'rest';
        }
      }
    });
    _excludeUnusedEmptyRoots();
  }

  void rest(int week, int day) => programme.editNativeArrangement((tree) {
    final d = tree['weeks'][week]['days'][day];
    d['slots'] = [];
    d['day_type'] = 'rest';
  });
  void setWeeks(int count) => programme.editNativeArrangement((tree) {
    if (count < 1 || count > 10) {
      throw const FormatException('Choose one to ten weeks.');
    }
    final weeks = tree['weeks'] as List;
    if (count < weeks.length) weeks.removeRange(count, weeks.length);
    while (weeks.length < count) {
      weeks.add({
        'week_number': weeks.length + 1,
        'title': 'New authored week',
        'days': [
          for (var d = 1; d <= 7; d++)
            {
              'day_key': 'day_$d',
              'day_order': d,
              'day_type': 'rest',
              'slots': [],
            },
        ],
      });
    }
    tree['programme']['duration_weeks'] = count;
  });
  void duplicateWeek(int index, int target) =>
      programme.editNativeArrangement((tree) {
        final weeks = tree['weeks'] as List;
        if (target == index || target < 0 || target >= weeks.length) {
          throw const FormatException('Choose a different existing week.');
        }
        final copy = nativeCopy(weeks[index] as Map)
          ..['week_number'] = target + 1;
        for (final d in copy['days']) {
          for (final s in d['slots']) {
            s['slot_key'] = 'slot-${DatabaseUuid.newV4()}';
          }
        }
        weeks[target] = copy;
      });

  /// Coach copies are independent owners. Pending intent remains a draft and
  /// never gains catalogue/publication authority by being copied.
  NativeRevision copyForCoach(NativeRevision original) {
    final sourceOwner = ownerOf(original);
    final copy = duplicateSession(original);
    if (sourceOwner.draft != null &&
        sourceOwner.parent == original.identity.revisionNumber) {
      begin(copy);
      final owner = ownerOf(copy);
      final intent = nativeCopy(sourceOwner.draft!);
      intent['protocol_id'] = owner.draft!['protocol_id'];
      intent['revision_number'] = owner.reserved;
      for (final block in intent['blocks']) {
        block['block_id'] = DatabaseUuid.newV4();
        final workout = block['timer_config']?['running_workout'];
        if (workout != null) {
          workout['workout_id'] = DatabaseUuid.newV4();
          for (final step in workout['steps']) {
            step['step_id'] = DatabaseUuid.newV4();
          }
        }
        for (final exercise in block['exercises']) {
          exercise['source_occurrence_id'] = DatabaseUuid.newV4();
        }
      }
      owner.draftTitle = '${sourceOwner.draftTitle} copy';
      owner.draft = intent;
      _changed();
    }
    return copy;
  }

  NativeRevision copyToDay(NativeRevision original, int week, int day) {
    _checkDay(week, day);
    final copy = copyForCoach(original);
    place(week, day, copy);
    return copy;
  }

  void moveOccurrence(String slotKey, int week, int day) {
    _checkDay(week, day);
    if (!occurrences.any((s) => s['slot_key'] == slotKey)) {
      throw const FormatException('Choose a session again.');
    }
    programme.editNativeArrangement((tree) {
      Map<String, dynamic>? moved;
      for (final w in tree['weeks']) {
        for (final d in w['days']) {
          final slots = d['slots'] as List;
          for (var i = 0; i < slots.length; i++) {
            if (slots[i]['slot_key'] == slotKey) {
              moved = Map<String, dynamic>.from(slots.removeAt(i) as Map);
              for (var j = 0; j < slots.length; j++) {
                slots[j]['session_order'] = j + 1;
              }
              if (slots.isEmpty) d['day_type'] = 'rest';
              break;
            }
          }
        }
      }
      if (moved == null) {
        throw const FormatException('Choose a session again.');
      }
      final target = tree['weeks'][week]['days'][day];
      target['day_type'] = 'training';
      moved['session_order'] = (target['slots'] as List).length + 1;
      (target['slots'] as List).add(moved);
    });
  }

  void _checkDay(int week, int day) {
    if (week < 0 ||
        week >= (programme.tree!['weeks'] as List).length ||
        day < 0 ||
        day > 6) {
      throw const FormatException('Choose a day in this programme.');
    }
  }

  void copyWeekForCoach(int index, int target) {
    final weeks = programme.tree!['weeks'] as List;
    if (index == target ||
        index < 0 ||
        target < 0 ||
        index >= weeks.length ||
        target >= weeks.length) {
      throw const FormatException('Choose a different existing week.');
    }
    final sources = <String, NativeRevision>{
      for (final day in weeks[index]['days'])
        for (final slot in day['slots'])
          slot['slot_key'] as String: selected(slot['slot_key'] as String),
    };
    if (owners.values.length + sources.length > 128 ||
        policy.available.length + sources.length > 128) {
      throw const FormatException(
        'This workspace is full. Download a backup before making more copies.',
      );
    }
    final copies = {
      for (final entry in sources.entries) entry.key: copyForCoach(entry.value),
    };
    programme.editNativeArrangement((tree) {
      final copy = nativeCopy(tree['weeks'][index] as Map)
        ..['week_number'] = target + 1;
      for (final day in copy['days']) {
        for (final slot in day['slots']) {
          slot['session_key'] = copies[slot['slot_key']]!.key;
          slot['slot_key'] = 'slot-${DatabaseUuid.newV4()}';
        }
      }
      tree['weeks'][target] = copy;
    });
  }

  NativeRevision duplicateSession(NativeRevision original) {
    if (owners.values.length >= 128 || policy.available.length >= 128) {
      throw const FormatException(
        'This workspace is full. Download a backup before making more copies.',
      );
    }
    final lineage = 'session-${DatabaseUuid.newV4()}';
    final graph = readWorkspaceJson(original.source)
      ..['protocol_id'] = 'protocol-${DatabaseUuid.newV4()}'
      ..['revision_number'] = 1;
    for (final b in graph['blocks']) {
      b['block_id'] = DatabaseUuid.newV4();
      final workout = b['timer_config']?['running_workout'];
      if (workout != null) {
        workout['workout_id'] = DatabaseUuid.newV4();
        for (final s in workout['steps']) {
          s['step_id'] = DatabaseUuid.newV4();
        }
      }
      for (final e in b['exercises']) {
        e['source_occurrence_id'] = DatabaseUuid.newV4();
      }
    }
    final revision = NativeRevision(
      identity: SessionRevisionIdentity(
        protocolId: graph['protocol_id'] as String,
        sessionLineageId: lineage,
        revisionNumber: 1,
      ),
      title: '${original.title} copy',
      source: jsonEncode(graph),
      origin: {
        'kind': 'explicit_source_copy_history_unknown',
        'source_sha256': nativeDigest(original.source),
      },
    );
    owners.add(lineage, NativeSessionOwner(lineage, revision));
    policy.available.add(revision.key);
    programme.refreshSourceCatalogue();
    return revision;
  }

  void excludeUnusedSources() {
    final used = occurrences.map((s) => s['session_key']).toSet();
    policy.available.removeWhere((key) => !used.contains(key));
    programme.refreshSourceCatalogue();
  }

  void addSource(NativeRevision revision) {
    if (!policy.available.contains(revision.key) &&
        policy.available.length >= 128) {
      throw const FormatException(
        'Exclude unused programme sources before adding another.',
      );
    }
    policy.available.add(revision.key);
    programme.refreshSourceCatalogue();
  }

  NativeRevision createSession({required bool running}) {
    if (owners.values.length >= 128) {
      throw const FormatException(
        'This workspace already has 128 session owners. Keep its complete editable history in a separate file.',
      );
    }
    final lineage = 'session-${DatabaseUuid.newV4()}',
        protocol = 'protocol-${DatabaseUuid.newV4()}';
    final title = running ? 'New structured run' : 'New strength session';
    final graph = {
      'protocol_id': protocol,
      'revision_number': 1,
      'blocks': [
        if (!running)
          {
            'position': 1,
            'block_id': DatabaseUuid.newV4(),
            'block_type': 'warm_up',
            'title': 'Preparation',
            'content': '',
            'workout_format': 'none',
            'exercises': [],
          },
        {
          'position': running ? 1 : 2,
          'block_id': DatabaseUuid.newV4(),
          'block_type': running ? 'conditioning' : 'strength',
          'title': title,
          'content': '',
          'workout_format': running ? 'steady_state' : 'none',
          'exercises': [],
          if (running)
            'timer_config': {
              'durationSeconds': 0,
              'running_workout': {
                'schema_version': 1,
                'workout_id': DatabaseUuid.newV4(),
                'title': title,
                'notes': '',
                'steps': [],
              },
            },
        },
        if (!running)
          {
            'position': 3,
            'block_id': DatabaseUuid.newV4(),
            'block_type': 'cool_down',
            'title': 'Finish',
            'content': '',
            'workout_format': 'none',
            'exercises': [],
          },
      ],
    };
    final revision = NativeRevision(
      identity: SessionRevisionIdentity(
        protocolId: protocol,
        sessionLineageId: lineage,
        revisionNumber: 1,
      ),
      title: title,
      source: jsonEncode(graph),
      origin: {'kind': 'new_local_draft_root_no_validation'},
    );
    owners.add(lineage, NativeSessionOwner(lineage, revision));
    policy.available.add(revision.key);
    programme.refreshSourceCatalogue();
    return revision;
  }

  static GenuineWorkspace fromNativeSources(
    Map<String, String> files,
    LegacyCatalogueEvidence catalogue,
  ) {
    final index = readWorkspaceJson(files['source-index.json']!);
    final owners = SessionOwnerCollection<NativeSessionOwner>();
    final byLineage = <String, List<NativeRevision>>{};
    for (final row in index['sessions'] as List) {
      final tuple = row['identity'];
      final lineage = tuple['session_lineage_id'] as String;
      byLineage
          .putIfAbsent(lineage, () => [])
          .add(
            NativeRevision(
              identity: SessionRevisionIdentity(
                protocolId: tuple['protocol_id'] as String,
                sessionLineageId: lineage,
                revisionNumber: tuple['revision_number'] as int,
              ),
              title: row['title'] as String,
              source: files[row['path']]!,
              origin: {
                'kind': 'imported_native_snapshot_history_unknown',
                'source_index_sha256': nativeDigest(
                  files['source-index.json']!,
                ),
                'path': row['path'],
                'sha256': row['source_sha256'],
              },
            ),
          );
    }
    for (final group in byLineage.entries) {
      group.value.sort(
        (a, b) =>
            a.identity.revisionNumber.compareTo(b.identity.revisionNumber),
      );
      final owner = NativeSessionOwner(group.key, group.value.first)
        .._revisions.addAll(group.value.skip(1));
      owner.numbers.highWater = group.value.last.identity.revisionNumber;
      owners.add(group.key, owner);
    }
    final compiled = const PlanPackageCompiler().compile(
      files['programme.plan-package.yaml']!,
    );
    final workspace = GenuineWorkspace._(owners, catalogue, {
      'imported_native_source_index': nativeDigest(files['source-index.json']!),
    }, nativeCopy(jsonDecode(compiled.canonicalJson!) as Map));
    workspace.programme.restoreWorkspaceSource(
      files['programme.plan-package.yaml']!,
      retainSourceFormatting: true,
    );
    return workspace;
  }

  Future<bool> refreshReview({Future<void> Function()? beforeCommit}) async {
    final boundaryError = saveError;
    if (boundaryError != null) {
      errors = [boundaryError];
      _review = null;
      _reviewFingerprint = null;
      notifyListeners();
      return false;
    }
    final token = generation, snapshot = fingerprint;
    final results = [
      for (final o in owners.values)
        for (final r in o.revisions)
          if (policy.available.contains(r.key))
            const NativeSessionCompiler().compile(
              source: r.source,
              identity: r.identity,
              catalogue: catalogue,
              title: r.title,
            ),
    ];
    final issues = [
      if (hasDrafts)
        'Save or cancel pending session edits before preparing export.',
      for (final r in results) ...r.issues,
    ];
    if (beforeCommit != null) await beforeCommit();
    if (_disposed || token != generation || snapshot != fingerprint) {
      return false;
    }
    if (issues.isEmpty) {
      if (!programme.validateAndReview()) {
        issues.addAll(programme.issues.map((i) => i.message));
      }
      if (_disposed || token != generation || snapshot != fingerprint) {
        return false;
      }
      if (issues.isEmpty) {
        final compile = const PlanPackageCompiler().compile(
          programme.draftSource,
        );
        const NativeSessionCompiler().inspect(compile, policy.graphs);
      }
    }
    _review = results;
    errors = issues;
    _reviewFingerprint = fingerprint;
    notifyListeners();
    return issues.isEmpty;
  }

  String save() {
    workspaceString(programme.draftSource, 'programme source');
    workspaceList(owners.values, 'session owners', max: 128);
    workspaceList(policy.available.toList(), 'programme inventory', max: 128);
    for (final owner in owners.values) {
      workspaceList(owner.revisions, 'saved local revisions', max: 128);
      for (final revision in owner.revisions) {
        workspaceString(revision.source, 'native revision source');
      }
      if (owner.draft != null) {
        workspaceString(jsonEncode(owner.draft), 'native draft source');
      }
    }
    final text = encodeWorkspaceJson({
      'kind': 'cohort_editable_workspace',
      'version': 4,
      'profile': genuineWorkspaceProfile,
      'programme_source': programme.draftSource,
      'available': policy.available.toList()..sort(),
      'catalogue_evidence': jsonEncode(catalogue.source),
      'origin_inventory': origins,
      'owners': [
        for (final o in owners.values)
          {
            'lineage': o.lineage,
            'high_water': o.numbers.highWater,
            'parents': {
              for (final e in o.numbers.parents.entries) '${e.key}': e.value,
            },
            'reservations': {
              for (final e in o.numbers.reservations.entries)
                '${e.key}': e.value,
            },
            'revisions': [
              for (final r in o.revisions)
                {
                  'number': r.identity.revisionNumber,
                  'protocol_id': r.identity.protocolId,
                  'title': r.title,
                  'source': r.source,
                  'sha256': nativeDigest(r.source),
                  'origin': r.origin,
                },
            ],
            'draft': o.draft == null
                ? null
                : {
                    'number': o.reserved,
                    'parent': o.parent,
                    'title': o.draftTitle,
                    'source': jsonEncode(o.draft),
                  },
          },
      ],
    });
    if (utf8.encode(text).length > workspaceMaxBytes) {
      workspaceInvalid(
        'File exceeds 2 MiB; keep the source/history intact and reduce the selected inventory explicitly.',
      );
    }
    return text;
  }

  void markSaved(String exactText) {
    if (save() == exactText) {
      _savedText = exactText;
      notifyListeners();
    }
  }

  PreparedGenuineOpen prepareOpen(String text) {
    // A saved archived workspace keeps its own pinned root/evidence; opening it
    // never upgrades prescriptions or borrows the current source's authority.
    final requestedOrigins = readWorkspaceJson(text)['origin_inventory'];
    GenuineWorkspace? historical;
    var reference = this;
    if (!nativeEqual(requestedOrigins, origins)) {
      for (final profile in _trustedBootstrapSources) {
        final directory = verifiedSourceDirectory(profile);
        final inventory = {
          for (final e in profile.entries)
            '$directory/${e.key}': nativeDigest(e.value),
        };
        if (nativeEqual(inventory, requestedOrigins)) {
          historical = fromSelectedSources(profile);
          reference = historical;
          break;
        }
      }
    }
    GenuineWorkspace candidate;
    try {
      candidate = _open(
        text,
        catalogue,
        reference.origins,
        reference.policy.trustedTree,
      );
    } catch (_) {
      historical?.dispose();
      rethrow;
    }
    try {
      for (final owner in candidate.owners.values) {
        for (final revision in owner.revisions) {
          if (revision.origin['kind'] ==
              'retained_source_snapshot_history_unknown') {
            final known = reference.owners.values
                .expand((o) => o.revisions)
                .where(
                  (r) => r.identity.protocolId == revision.identity.protocolId,
                );
            if (known.length != 1 ||
                known.single.source != revision.source ||
                !nativeEqual(known.single.origin, revision.origin)) {
              workspaceInvalid(
                'A retained source snapshot was rewritten. Create a later draft instead.',
              );
            }
          }
        }
      }
    } catch (_) {
      candidate.dispose();
      rethrow;
    } finally {
      historical?.dispose();
    }
    candidate._trustedBootstrapSources = _trustedBootstrapSources;
    return PreparedGenuineOpen._(this, generation, candidate);
  }

  static GenuineWorkspace _open(
    String text,
    LegacyCatalogueEvidence trusted,
    Map<String, dynamic> origins,
    Map<String, dynamic> baseline,
  ) {
    final envelope = workspaceObject(readWorkspaceJson(text), {
      'kind',
      'version',
      'profile',
      'programme_source',
      'available',
      'owners',
      'catalogue_evidence',
      'origin_inventory',
    }, 'workspace');
    if (envelope['kind'] != 'cohort_editable_workspace' ||
        envelope['version'] != 4 ||
        envelope['profile'] != genuineWorkspaceProfile) {
      workspaceInvalid('Use the matching supported Studio workspace version.');
    }
    if (!nativeEqual(
          jsonDecode(
            workspaceString(
              envelope['catalogue_evidence'],
              'catalogue evidence',
            ),
          ),
          trusted.source,
        ) ||
        !nativeEqual(envelope['origin_inventory'], origins)) {
      workspaceInvalid(
        'Catalogue/origin evidence differs from retained verified sources.',
      );
    }
    final owners = SessionOwnerCollection<NativeSessionOwner>();
    final allProtocols = <String>{};
    for (final raw in workspaceList(envelope['owners'], 'owners', max: 128)) {
      final o = workspaceObject(raw, {
        'lineage',
        'high_water',
        'parents',
        'reservations',
        'revisions',
        'draft',
      }, 'session owner');
      final lineage = workspaceString(o['lineage'], 'lineage');
      final revisions = <NativeRevision>[];
      final numbers = <int>{};
      for (final rawRevision in workspaceList(
        o['revisions'],
        'revisions',
        max: 128,
      )) {
        final r = workspaceObject(rawRevision, {
          'number',
          'protocol_id',
          'title',
          'source',
          'sha256',
          'origin',
        }, 'revision');
        final number = workspaceInt(r['number'], 'revision', min: 1);
        final protocol = workspaceString(r['protocol_id'], 'protocol');
        final source = workspaceString(r['source'], 'native source');
        guardNativeDraftShape(source);
        if (!numbers.add(number) ||
            !allProtocols.add(protocol) ||
            nativeDigest(source) != r['sha256']) {
          workspaceInvalid('Duplicate identity or changed graph digest.');
        }
        final identity = SessionRevisionIdentity(
          protocolId: protocol,
          sessionLineageId: lineage,
          revisionNumber: number,
        );
        const NativeSessionCompiler().compile(
          source: source,
          identity: identity,
          catalogue: trusted,
          title: workspaceString(r['title'], 'title'),
        );
        revisions.add(
          NativeRevision(
            identity: identity,
            title: r['title'] as String,
            source: source,
            origin: nativeCopy(r['origin'] as Map),
          ),
        );
      }
      if (revisions.isEmpty) {
        workspaceInvalid('An owner requires its retained root snapshot.');
      }
      final owner = NativeSessionOwner(lineage, revisions.first)
        .._revisions.addAll(revisions.skip(1));
      owner.numbers.highWater = workspaceInt(
        o['high_water'],
        'reservation high water',
        min: numbers.reduce((a, b) => a > b ? a : b),
      );
      for (final pair in [
        (o['parents'], owner.numbers.parents),
        (o['reservations'], owner.numbers.reservations),
      ]) {
        if (pair.$1 is! Map) {
          workspaceInvalid('Invalid parent/reservation map.');
        }
        for (final e in (pair.$1 as Map).entries) {
          final n = int.tryParse(e.key as String),
              parent = workspaceInt(e.value, 'parent', min: 1);
          if (n == null ||
              n <= parent ||
              n > owner.numbers.highWater ||
              !numbers.contains(parent)) {
            workspaceInvalid('Invalid revision ancestry/reservation.');
          }
          pair.$2[n] = parent;
        }
      }
      if (o['draft'] != null) {
        final d = workspaceObject(o['draft'], {
          'number',
          'parent',
          'title',
          'source',
        }, 'draft');
        owner.reserved = workspaceInt(d['number'], 'draft revision', min: 1);
        owner.parent = workspaceInt(d['parent'], 'draft parent', min: 1);
        if (numbers.contains(owner.reserved) ||
            owner.numbers.reservations[owner.reserved] != owner.parent) {
          workspaceInvalid('Draft has no exact active reservation.');
        }
        owner.draftTitle = workspaceString(d['title'], 'draft title');
        owner.draft = readWorkspaceJson(
          workspaceString(d['source'], 'draft source'),
        );
        guardNativeDraftShape(d['source'] as String);
        if (owner.draft!['revision_number'] != owner.reserved ||
            owner.draft!['protocol_id'] is! String) {
          workspaceInvalid('Draft identity changed.');
        }
      }
      if (owner.numbers.reservations.length != (owner.draft == null ? 0 : 1)) {
        workspaceInvalid('Unexpected active reservation.');
      }
      owners.add(lineage, owner);
    }
    final source = workspaceString(
      envelope['programme_source'],
      'programme source',
    );
    guardWorkspaceYaml(source);
    final candidate = GenuineWorkspace._(
      owners,
      trusted,
      nativeCopy(origins),
      baseline,
    );
    try {
      final available = workspaceList(
        envelope['available'],
        'available sources',
        max: 128,
      ).cast<String>();
      final owned = owners.values
          .expand((o) => o.revisions)
          .map((r) => r.key)
          .toSet();
      if (available.isEmpty ||
          available.toSet().length != available.length ||
          !available.every(owned.contains)) {
        workspaceInvalid('Invalid programme source inventory.');
      }
      candidate.policy.available
        ..clear()
        ..addAll(available);
      candidate.programme.restoreWorkspaceSource(
        source,
        retainSourceFormatting: true,
      );
    } catch (_) {
      candidate.dispose();
      rethrow;
    }
    candidate._savedText = candidate.save();
    return candidate;
  }

  bool isCurrentOpen(PreparedGenuineOpen open) =>
      identical(open.owner, this) &&
      open.generation == generation &&
      !_disposed;
  @override
  void dispose() {
    _disposed = true;
    programme.removeListener(_programmeChanged);
    programme.dispose();
    super.dispose();
  }
}
