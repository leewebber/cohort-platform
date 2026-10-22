import '../../domain/hyrox_base/base_personalisation.dart';

typedef BasePreviewBuilder =
    Future<BaseSessionPreview> Function(
      String athleteId,
      int week,
      Map<BaseMetric, BaseBenchmark> selected,
      int? incrementGrams,
    );

class BaseSelectionProposal {
  const BaseSelectionProposal._(this.benchmark, this.generation);
  final BaseBenchmark benchmark;
  final int generation;
}

class BaseLocalWorkout {
  const BaseLocalWorkout._(
    this.id,
    this.prescription,
    this.completed,
    this.actualSquatGrams,
  );
  final String id;
  final BaseSessionPreview prescription;
  final bool completed;
  final int? actualSquatGrams;
}

/// In-memory synthetic review, unreachable from production composition.
/// Entries and selections are separate. No result or completion changes a target.
class BaseReviewController {
  BaseReviewController(this.athleteId, {BasePreviewBuilder? builder})
    : _builder = builder ?? _calculate {
    if (!{'synthetic-a', 'synthetic-b'}.contains(athleteId)) {
      throw const FormatException(
        'Only the two local synthetic athletes are supported.',
      );
    }
  }
  final String athleteId;
  final BasePreviewBuilder _builder;
  final Map<String, BaseBenchmark> _entries = {};
  final Map<BaseMetric, BaseBenchmark> _selected = {};
  final Map<String, BaseLocalWorkout> _workouts = {};
  Map<String, BaseBenchmark> get entries => Map.unmodifiable(_entries);
  Map<BaseMetric, BaseBenchmark> get selected => Map.unmodifiable(_selected);
  Map<String, BaseLocalWorkout> get workouts => Map.unmodifiable(_workouts);
  BaseSessionPreview? get preview => _preview;
  BaseSessionPreview? _preview;
  BaseSelectionProposal? _proposal;
  BaseSelectionProposal? get proposal => _proposal;
  int _generation = 0, _request = 0;
  int _week = 1;
  int get week => _week;
  int? _incrementGrams;
  int? get incrementGrams => _incrementGrams;
  bool _disposed = false;
  String? error;
  bool busy = false;
  bool _reviewFailed = false;

  static Future<BaseSessionPreview> _calculate(
    String athlete,
    int week,
    Map<BaseMetric, BaseBenchmark> selected,
    int? increment,
  ) async => const BasePersonalisationCalculator().preview(
    athleteId: athlete,
    week: week,
    selected: selected,
    incrementGrams: increment,
  );

  void _invalidate() {
    _reviewFailed = false;
    _generation++;
    _request++;
    _preview = null;
    _proposal = null;
    busy = false;
  }

  void configure({required int week, int? incrementGrams}) {
    if (_disposed) return;
    if (week < 1 ||
        week > 8 ||
        (incrementGrams != null &&
            (incrementGrams <= 0 || incrementGrams > 1000000000))) {
      _invalidate();
      error = 'Invalid week or total-barbell increment.';
      return;
    }
    _invalidate();
    error = null;
    _week = week;
    _incrementGrams = incrementGrams;
  }

  bool enter(BaseBenchmark benchmark) {
    if (_disposed) return false;
    _invalidate();
    if (benchmark.athleteId != athleteId ||
        (_entries.containsKey(benchmark.id) &&
            _entries[benchmark.id]!.digest != benchmark.digest)) {
      error = 'Foreign owner or conflicting immutable benchmark ID.';
      return false;
    }
    _entries[benchmark.id] = benchmark;
    error = null;
    return true;
  }

  void rejectInput(String reason) {
    if (_disposed) return;
    _invalidate();
    error = reason;
  }

  BaseSelectionProposal? proposeSelection(String entryId) {
    if (_disposed || !_entries.containsKey(entryId)) return null;
    _invalidate();
    error = null;
    return _proposal = BaseSelectionProposal._(_entries[entryId]!, _generation);
  }

  bool acceptSelection(BaseSelectionProposal proposal) {
    if (_disposed ||
        !identical(proposal, _proposal) ||
        proposal.generation != _generation) {
      return false;
    }
    _selected[proposal.benchmark.metric] = proposal.benchmark;
    _invalidate();
    error = null;
    return true;
  }

  void cancelSelection() {
    if (!_disposed) {
      _invalidate();
      error = null;
    }
  }

  void deselect(BaseMetric metric) {
    if (_disposed) return;
    _selected.remove(metric);
    _invalidate();
    error = null;
  }

  Future<bool> review() async {
    if (_disposed || (error != null && !_reviewFailed) || _proposal != null) {
      return false;
    }
    error = null;
    _reviewFailed = false;
    final generation = _generation, request = ++_request;
    final captured = Map<BaseMetric, BaseBenchmark>.unmodifiable(_selected);
    _preview = null;
    busy = true;
    try {
      final result = await _builder(
        athleteId,
        _week,
        captured,
        _incrementGrams,
      );
      if (_disposed || generation != _generation || request != _request) {
        return false;
      }
      // A worker's reply must match the exact captured calculation and scope.
      final expected = const BasePersonalisationCalculator().preview(
        athleteId: athleteId,
        week: _week,
        selected: captured,
        incrementGrams: _incrementGrams,
      );
      if (expected.digest != result.digest) {
        throw const FormatException('Review scope mismatch.');
      }
      _preview = result;
      busy = false;
      return true;
    } catch (_) {
      if (!_disposed && generation == _generation && request == _request) {
        busy = false;
        error = 'Review unavailable. Retry with valid inputs.';
        _reviewFailed = true;
      }
      return false;
    }
  }

  BaseLocalWorkout? start(String id) {
    if (_disposed || id.trim().isEmpty) return null;
    // Existing started/completed occurrence always wins; no recalculation.
    if (_workouts.containsKey(id)) return _workouts[id];
    if (_preview == null || error != null || _proposal != null || busy) {
      return null;
    }
    return _workouts[id] = BaseLocalWorkout._(id, _preview!, false, null);
  }

  bool complete(String id, {int? actualSquatGrams}) {
    if (_disposed ||
        !_workouts.containsKey(id) ||
        _workouts[id]!.completed ||
        (actualSquatGrams != null &&
            (actualSquatGrams < 0 || actualSquatGrams > 1000000000))) {
      return false;
    }
    final old = _workouts[id]!;
    _workouts[id] = BaseLocalWorkout._(
      id,
      old.prescription,
      true,
      actualSquatGrams,
    );
    return true;
  }

  void dispose() {
    _invalidate();
    _disposed = true;
  }
}
