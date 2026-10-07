import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/performance_tracking/coherent_history_rpc_reader.dart';
import '../../application/performance_tracking/distance_observations_profile.dart';
import '../../application/performance_tracking/history_tracking_adapter.dart';
import '../../application/performance_tracking/profile_tracking_evaluator.dart';

/// Metadata only. It proposes navigation candidates, never observation authority.
abstract interface class DistanceRecordListPort {
  String? get authenticatedAthleteId;
  Future<List<DistanceRecordSummary>> listOwned(String athleteId, int offset);
}

final class DistanceRecordSummary {
  const DistanceRecordSummary(this.id, this.athleteId, this.date, this.status);
  final String id;
  final String athleteId;
  final String date;
  final String status;
}

final class DistanceBlockCandidate {
  const DistanceBlockCandidate(this.field, this.label);
  final HistoryFieldSelection field;
  final String label;
}

final class DistanceRecordView {
  DistanceRecordView(this.summary, this.candidates);
  final DistanceRecordSummary summary;
  final List<DistanceBlockCandidate> candidates;
  DistanceBlockCandidate? _selected;
  TrackingEvaluationInput? _input;
  DistanceBlockCandidate? get selected => _selected;
  TrackingEvaluationInput? get input => _input;
}

/// Request/visit-scoped ownership and exact-source controller. No saved choices.
final class DistanceHistoryController extends ChangeNotifier {
  DistanceHistoryController({
    required this.rpc,
    required this.records,
    required this.activeAthlete,
    required Stream<void> identityChanges,
  }) {
    _identitySubscription = identityChanges.listen((_) => reset());
  }
  final HistoryTrackingRpcClient rpc;
  final DistanceRecordListPort records;
  final String? Function() activeAthlete;
  late final StreamSubscription<void> _identitySubscription;
  final _frames = <String, HistoryReadFrame>{};
  final _views = <String, DistanceRecordView>{};
  List<DistanceRecordSummary> page = const [];
  List<DistanceRecordView> get views => List.unmodifiable(_views.values);
  ProfileTrackingEvaluation? evaluation;
  bool busy = false;
  bool hasNext = false;
  int offset = 0;
  String? error;
  String? _actor;
  int _generation = 0;
  bool _disposed = false;

  String? get authorizedActor {
    final id = activeAthlete();
    return id != null &&
            id == rpc.authenticatedAthleteId &&
            id == records.authenticatedAthleteId
        ? id
        : null;
  }

  bool get identityValid => _actor != null && _actor == authorizedActor;

  void reset() {
    _generation++;
    _frames.clear();
    _views.clear();
    page = const [];
    evaluation = null;
    _actor = null;
    busy = false;
    hasNext = false;
    offset = 0;
    error = 'identity_changed';
    if (!_disposed) notifyListeners();
  }

  bool _current(int generation, String actor) =>
      !_disposed && generation == _generation && actor == authorizedActor;

  Future<void> loadPage({int? pageOffset}) async {
    final actor = authorizedActor;
    if (actor == null) {
      reset();
      return;
    }
    if (_actor != actor) {
      reset();
    }
    _actor = actor;
    final generation = ++_generation;
    busy = true;
    error = null;
    page = const [];
    notifyListeners();
    final requested = pageOffset ?? offset;
    try {
      final rows = await records.listOwned(actor, requested);
      if (!_current(generation, actor)) {
        if (!_disposed && generation == _generation) {
          reset();
        }
        return;
      }
      if (rows.length > 25 ||
          rows.any((r) => r.athleteId != actor || !_uuid(r.id)) ||
          rows.map((r) => r.id).toSet().length != rows.length) {
        throw const HistoryTrackingReadException('invalid_record_metadata');
      }
      page = List.unmodifiable(rows);
      offset = requested;
      hasNext = rows.length == 25;
    } catch (_) {
      if (_current(generation, actor)) error = 'history_list_unavailable';
    }
    if (!_disposed && generation == _generation) {
      if (actor != authorizedActor) {
        reset();
        return;
      }
      busy = false;
      notifyListeners();
    }
  }

  Future<void> toggleRecord(DistanceRecordSummary summary) async {
    if (!identityValid) {
      reset();
      return;
    }
    if (busy) {
      return;
    }
    final actor = _actor!;
    if (_views.containsKey(summary.id)) {
      _views.remove(summary.id);
      _frames.remove(summary.id);
      _evaluate(compare: false);
      notifyListeners();
      return;
    }
    if (_views.length >= 2 ||
        !page.contains(summary) ||
        summary.athleteId != actor) {
      return;
    }
    final generation = ++_generation;
    busy = true;
    error = null;
    evaluation = null;
    notifyListeners();
    try {
      final frame = await CoherentHistoryRpcReader(
        rpc,
      ).readCurrentRecord(summary.id);
      if (!_current(generation, actor)) {
        if (!_disposed && generation == _generation) {
          reset();
        }
        return;
      }
      if (frame.record == null) {
        throw const HistoryTrackingReadException('record_not_available');
      }
      final candidates = <DistanceBlockCandidate>[];
      for (final block in frame.blocks) {
        // Enumerate supported scopes even when their value/unit is absent or incompatible.
        if (!['distance', 'endurance'].contains(block['result_type'])) {
          continue;
        }
        final snapshot = block['block_snapshot'];
        final sourceId = block['source_block_id'];
        if (sourceId is! String ||
            sourceId.isEmpty ||
            snapshot is! Map ||
            snapshot['sourceBlockId'] != sourceId) {
          throw const HistoryTrackingReadException('source_block_mismatch');
        }
        candidates.add(
          DistanceBlockCandidate(
            HistoryFieldSelection(
              recordId: summary.id,
              blockResultId: block['block_result_id'] as String,
              sourceBlockId: sourceId,
              fieldPath: const ['result_data', 'distance'],
            ),
            snapshot['title'] is String &&
                    (snapshot['title'] as String).trim().isNotEmpty
                ? snapshot['title'] as String
                : 'Distance block',
          ),
        );
      }
      _frames[summary.id] = frame;
      _views[summary.id] = DistanceRecordView(
        summary,
        List.unmodifiable(candidates),
      );
    } on HistoryTrackingReadException catch (failure) {
      if (_current(generation, actor)) error = failure.code;
    } catch (_) {
      if (_current(generation, actor)) error = 'history_read_failed';
    }
    if (!_disposed && generation == _generation) {
      if (actor != authorizedActor) {
        reset();
        return;
      }
      _evaluate(compare: false);
      busy = false;
      notifyListeners();
    }
  }

  Future<void> selectBlock(
    String recordId,
    DistanceBlockCandidate candidate,
  ) async {
    if (!identityValid) {
      reset();
      return;
    }
    if (busy) {
      return;
    }
    final view = _views[recordId];
    final frame = _frames[recordId];
    if (view == null || frame == null || !view.candidates.contains(candidate)) {
      return;
    }
    final actor = _actor!;
    final generation = ++_generation;
    view._selected = candidate;
    view._input = null;
    evaluation = null;
    error = null;
    busy = true;
    notifyListeners();
    final query = HistoryTrackingQuery(
      athleteId: actor,
      metric: DistanceObservationsProfile.metric.reference,
      field: candidate.field,
    );
    // Only this controller's strict bridge output enters the private scoped port.
    final result = await HistoryTrackingAdapter(
      reader: _VisitFramePort(frame, recordId, () => authorizedActor),
      definitions: DistanceObservationsProfile.definitions,
    ).read(query);
    if (!_current(generation, actor)) {
      if (!_disposed && generation == _generation) {
        reset();
      }
      return;
    }
    view._input = TrackingEvaluationInput(
      id: recordId,
      query: query,
      result: result,
    );
    _evaluate(compare: false);
    busy = false;
    notifyListeners();
  }

  void compare() {
    if (!identityValid) {
      reset();
      return;
    }
    if (busy ||
        _views.length != 2 ||
        _views.values.any((v) => v.input == null)) {
      return;
    }
    _evaluate(compare: true);
    notifyListeners();
  }

  void _evaluate({required bool compare}) {
    final inputs = [
      for (final view in _views.values)
        if (view.input != null) view.input!,
    ];
    if (inputs.isEmpty) {
      evaluation = null;
      return;
    }
    evaluation =
        ProfileTrackingEvaluator(
          definitions: DistanceObservationsProfile.definitions,
        ).evaluate(
          athleteId: _actor!,
          profiles: [
            TrackingProfileRequest(
              profile: DistanceObservationsProfile.profile.reference,
            ),
          ],
          inputs: inputs,
          comparisons: compare && inputs.length == 2
              ? [
                  TrackingComparisonRequest(
                    id: 'explicit-pair',
                    metric: DistanceObservationsProfile.metric.reference,
                    policy: TrackingComparabilityPolicy.reference,
                    leftInputId: inputs[0].id,
                    rightInputId: inputs[1].id,
                  ),
                ]
              : const [],
        );
  }

  Future<void> refresh() async {
    _generation++;
    _frames.clear();
    _views.clear();
    evaluation = null;
    await loadPage();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _identitySubscription.cancel();
    _frames.clear();
    _views.clear();
    page = const [];
    evaluation = null;
    super.dispose();
  }
}

/// No public arbitrary-frame constructor/composition or programme mode.
final class _VisitFramePort implements HistoryTrackingReadPort {
  const _VisitFramePort(this.frame, this.recordId, this.actor);
  final HistoryReadFrame frame;
  final String recordId;
  final String? Function() actor;
  @override
  String? get authenticatedAthleteId => actor();
  @override
  Future<HistoryReadFrame> readCurrentRecord(
    String id, {
    HistoryProgrammeClaim? programmeClaim,
  }) async {
    if (id != recordId ||
        programmeClaim != null ||
        actor() != frame.athleteId) {
      throw const HistoryTrackingReadException('ownership_denied');
    }
    return frame;
  }
}

bool _uuid(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
).hasMatch(value);
