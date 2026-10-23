import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../application/hyrox_base/benchmark_repository.dart';
import '../../../application/hyrox_base/programme_prescription_repository.dart';
import '../../../core/utils/database_uuid.dart';
import '../../../domain/hyrox_base/base_personalisation.dart';
import '../../../domain/hyrox_base/programme_prescription.dart';
import '../../session/models/bound_programme_execution.dart';
import '../../session/models/session_execution_plan.dart';
import '../../session/services/session_execution_loader.dart';
import '../models/programme_execution_context.dart';

/// Authenticated programme-scoped review. No synthetic fallback or client math.
class ProgrammePrescriptionReviewScreen extends StatefulWidget {
  const ProgrammePrescriptionReviewScreen({
    super.key,
    required this.executionContext,
    required this.athleteId,
    this.plan,
    this.repository,
    this.benchmarks,
    this.forLaunch = false,
  });
  final ProgrammeExecutionContext executionContext;
  final String athleteId;
  final SessionExecutionPlan? plan;
  final ProgrammePrescriptionRepository? repository;
  final BaseBenchmarkRepository? benchmarks;
  final bool forLaunch;
  @override
  State<ProgrammePrescriptionReviewScreen> createState() => _ReviewState();
}

class _ReviewState extends State<ProgrammePrescriptionReviewScreen> {
  late final _repository =
      widget.repository ?? ProgrammePrescriptionRepository();
  late final _benchmarks = widget.benchmarks ?? BaseBenchmarkRepository();
  final _increment = TextEditingController();
  List<Map<String, dynamic>> _entries = [];
  final Map<String, String?> _selection = {};
  Map<String, dynamic>? _head;
  Map<String, Object?>? _review;
  ProgrammePrescription? _projection;
  StreamSubscription<Object?>? _authSubscription;
  bool _accountChanged = false;
  bool _busy = false;
  String? _error;
  bool _loaded = false;
  ProgrammeExecutionContext get scope => widget.executionContext;
  static const metrics = {
    'run10km': '10 km run',
    'row2km': '2 km row',
    'backSquat5rm': 'Back squat 5RM',
  };
  @override
  void initState() {
    super.initState();
    if (widget.repository == null) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((
        event,
      ) {
        if (event.session?.user.id == widget.athleteId || !mounted) return;
        setState(() {
          _accountChanged = true;
          _invalidate();
          _entries = [];
          _selection.clear();
          _head = null;
          _loaded = false;
          _error =
              'Your account changed. Close this review and reopen your programme.';
        });
      });
    }
    _load();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _increment.dispose();
    super.dispose();
  }

  void _invalidate() {
    _review = null;
    _projection = null;
    _error = null;
  }

  Future<void> _load() async {
    if (_accountChanged) return;
    setState(() {
      _busy = true;
      _loaded = false;
      _invalidate();
    });
    try {
      final state = await _repository.readState(
        assignmentId: scope.assignmentId,
        programmeVersionId: scope.programmeVersionId,
      );
      if (!mounted || _accountChanged) return;
      final head = state['consent'];
      final doc = state['accepted_document'];
      final entries = state['benchmarks'];
      if (entries is! List || (head != null && head is! Map)) {
        throw const FormatException();
      }
      _entries = entries
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _head = head == null ? null : Map<String, dynamic>.from(head as Map);
      _selection.clear();
      if (_head?['disposition'] == 'accepted' && doc is Map) {
        final saved = doc['selection'];
        if (saved is! Map) throw const FormatException();
        for (final metric in metrics.keys) {
          final id = saved[metric];
          // A corrected result cannot remain selected. Require deliberate choice.
          if (id != null && !_entries.any((e) => e['revision_id'] == id)) {
            _error =
                'A previously selected result was corrected. Choose a current result and review again, or explicitly accept numerical unavailability.';
          }
          _selection[metric] = _entries.any((e) => e['revision_id'] == id)
              ? id as String?
              : null;
        }
        _increment.text = doc['increment_grams'] == null
            ? ''
            : '${(doc['increment_grams'] as num) / 1000}';
      } else {
        _increment.clear();
      }
      _loaded = true;
    } catch (_) {
      if (mounted) {
        _error =
            'Programme targets are unavailable. Check your connection and try again. The server may need the programme target update.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int? _incrementGrams() {
    if (_increment.text.trim().isEmpty) return null;
    final value = double.tryParse(_increment.text.trim());
    if (value == null ||
        !value.isFinite ||
        value <= 0 ||
        value > 1000000 ||
        (value * 1000 - (value * 1000).round()).abs() > 0.000001) {
      throw const FormatException(
        'Enter a positive total barbell increment in kg, with at most three decimal places.',
      );
    }
    return (value * 1000).round();
  }

  Future<void> _calculateReview() async {
    if (_accountChanged) return;
    setState(() {
      _busy = true;
      _invalidate();
    });
    try {
      final r = await _repository.review(
        assignmentId: scope.assignmentId,
        programmeVersionId: scope.programmeVersionId,
        selectedRevisions: Map.of(_selection),
        incrementGrams: _incrementGrams(),
      );
      if (!mounted || _accountChanged) return;
      if (r['status'] != 'review' ||
          r['review_id'] is! String ||
          r['document'] is! Map) {
        throw const FormatException(
          'The programme sources or selected benchmarks are no longer available. Reload and review again.',
        );
      }
      final projection = ProgrammePrescription(
        Map<String, dynamic>.from(r['document'] as Map),
      );
      if (projection.json['athlete_id'] != widget.athleteId ||
          projection.json['assignment_id'] != scope.assignmentId ||
          projection.json['programme_version_id'] != scope.programmeVersionId ||
          projection.json['package_hash'] != scope.packageContentHash) {
        throw const FormatException(
          'This review no longer matches your programme.',
        );
      }
      final currentPlan = widget.plan;
      if (currentPlan != null) {
        final slotKey = scope.packageSlotKey;
        if (slotKey == null) {
          throw const FormatException('The session source cannot be resolved.');
        }
        bindProgrammePrescription(
          plan: currentPlan,
          prescription: projection,
          protocolId: scope.effectiveProtocolId,
          slotKey: slotKey,
        );
      } else {
        // Programme management also works on rest days. Check each exact bound
        // source with the existing production loader before enabling acceptance.
        final loader = SessionExecutionLoader();
        final checked = <String>{};
        for (final target in projection.targets) {
          final protocol = target.binding['protocol_id'] as String;
          final slot = target.binding['slot_key'] as String;
          if (!checked.add(slot)) continue;
          final loaded = await loader.load(protocolId: protocol);
          if (!mounted || _accountChanged) return;
          bindProgrammePrescription(
            plan: loaded.plan,
            prescription: projection,
            protocolId: protocol,
            slotKey: slot,
          );
        }
      }
      _head = r['expected_consent_id'] == null
          ? null
          : {'consent_id': r['expected_consent_id']};
      _review = r;
      _projection = projection;
    } on FormatException catch (e) {
      if (mounted) {
        _error = e.message.isEmpty
            ? 'These programme targets are not supported.'
            : e.message;
      }
    } catch (_) {
      if (mounted) {
        _error =
            'Review unavailable. Reload to check the current programme, benchmarks and server capabilities.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _consent(bool withdraw) async {
    if (_accountChanged) return;
    final reviewed = _review;
    if (!withdraw && reviewed == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await _repository.consent(
        commandId: DatabaseUuid.newV4(),
        assignmentId: scope.assignmentId,
        programmeVersionId: scope.programmeVersionId,
        reviewId: withdraw ? null : (reviewed!['review_id'] as String),
        expectedConsentId: withdraw
            ? (_head?['consent_id'] as String?)
            : (reviewed!['expected_consent_id'] as String?),
        withdraw: withdraw,
      );
      if (!mounted || _accountChanged) return;
      if (!{'accepted', 'replayed'}.contains(r['status']) ||
          r['consent_id'] is! String ||
          r['disposition'] != (withdraw ? 'withdrawn' : 'accepted')) {
        throw const FormatException(
          'This review or consent has changed. Reload and review again before starting.',
        );
      }
      if (!withdraw && widget.forLaunch) {
        Navigator.pop(context, r['consent_id'] as String);
        return;
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              withdraw
                  ? 'Consent withdrawn for future starts. Started sessions keep their original targets.'
                  : 'Programme targets accepted for future unstarted sessions.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        _invalidate();
        _error =
            'Consent could not be confirmed, or the review has changed. Reload to check its current state before retrying.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _record(String metric) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _BenchmarkEntry(metric: metric, repository: _benchmarks),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Review programme targets')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            scope.programmeName ?? 'Your programme',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            'Version ${scope.programmeVersionNumber ?? 'unavailable'} · Week ${scope.weekNumber}',
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose which declared results to use for this programme. Recording a result does not select it. Missing results remain unavailable; only authored effort guidance can be used.',
          ),
          const Text(
            'Accepting replaces your previous programme consent for future unstarted sessions. Withdrawal prevents new starts. Started and completed sessions always retain their original targets and actuals.',
          ),
          if (_head != null)
            Text(
              _head!['disposition'] == 'withdrawn'
                  ? 'Consent withdrawn'
                  : 'Programme consent recorded; review again to change future targets.',
            ),
          if (_busy) const LinearProgressIndicator(),
          if (_loaded) ...[
            for (final metric in metrics.keys) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('$metric-${_selection[metric]}'),
                initialValue: _selection[metric] ?? '',
                isExpanded: true,
                decoration: InputDecoration(labelText: metrics[metric]),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('No benchmark selected'),
                  ),
                  for (final b in _entries.where((b) => b['metric'] == metric))
                    DropdownMenuItem(
                      value: b['revision_id'] as String,
                      child: Text(
                        '${b['raw_value']} ${benchmarkUnit(b['input_unit'])} · ${b['test_date']} · ${benchmarkSource(b['source_type'])} · ${b['source_reference']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _selection[metric] = value == '' ? null : value;
                        _invalidate();
                      }),
              ),
              TextButton(
                onPressed: _busy ? null : () => _record(metric),
                child: Text('Add ${metrics[metric]} result'),
              ),
            ],
            TextField(
              controller: _increment,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Available total barbell increment (kg)',
                helperText:
                    'Leave blank if unknown. Includes both sides of the bar.',
              ),
              onChanged: (_) => setState(_invalidate),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _calculateReview,
              child: const Text('Review calculated targets'),
            ),
          ],
          if (_projection case final projection?) ...[
            for (final t in projection.targets)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${t.label} · Week ${t.binding['week_number']}'),
                      Text(t.benchmarkLabel),
                      Text(t.dose),
                      Text(t.targetLabel),
                    ],
                  ),
                ),
              ),
            const Text(
              'I accept these benchmark choices, calculated targets and any numerical unavailability shown for this programme version. This applies to future unstarted sessions only.',
            ),
            FilledButton(
              onPressed: _busy ? null : () => _consent(false),
              child: Text(
                widget.forLaunch
                    ? 'Accept and begin session'
                    : 'Accept programme targets',
              ),
            ),
          ],
          if (_head?['consent_id'] != null)
            TextButton(
              onPressed: _busy ? null : () => _consent(true),
              child: const Text('Withdraw consent for future starts'),
            ),
          if (_error != null)
            Text(_error!, key: const ValueKey('programme-target-error')),
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Reload programme target state'),
          ),
        ],
      ),
    ),
  );
}

class _BenchmarkEntry extends StatefulWidget {
  const _BenchmarkEntry({required this.metric, required this.repository});
  final String metric;
  final BaseBenchmarkRepository repository;
  @override
  State<_BenchmarkEntry> createState() => _EntryState();
}

class _EntryState extends State<_BenchmarkEntry> {
  final _value = TextEditingController();
  final _date = TextEditingController();
  final _source = TextEditingController();
  bool _busy = false;
  String? _error;
  BaseSourceType _sourceType = BaseSourceType.knownResult;
  late BaseInputUnit _unit = widget.metric == 'backSquat5rm'
      ? BaseInputUnit.kilograms
      : BaseInputUnit.seconds;
  @override
  void dispose() {
    _value.dispose();
    _date.dispose();
    _source.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.repository.record(
        commandId: DatabaseUuid.newV4(),
        metric: BaseMetric.values.byName(widget.metric),
        value: _value.text.trim(),
        unit: _unit,
        testDate: _date.text.trim(),
        sourceType: _sourceType,
        sourceReference: _source.text.trim(),
      );
      if (!mounted) return;
      if (!{'recorded', 'replayed'}.contains(r['status'])) {
        throw const FormatException('Check your result, date and source.');
      }
      Navigator.pop(context, true);
    } on FormatException catch (e) {
      if (mounted) _error = e.message;
    } catch (_) {
      if (mounted) {
        _error =
            'Result could not be confirmed. Reload programme state before retrying.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('Add ${_ReviewState.metrics[widget.metric]} result'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your declared result and test date. This does not attest a verified assessment or select it for use.',
            ),
            TextField(
              controller: _value,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Result'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            DropdownButton<BaseInputUnit>(
              value: _unit,
              items: [
                for (final u
                    in widget.metric == 'backSquat5rm'
                        ? [BaseInputUnit.kilograms, BaseInputUnit.pounds]
                        : [BaseInputUnit.seconds, BaseInputUnit.minutes])
                  DropdownMenuItem(
                    value: u,
                    child: Text(benchmarkUnit(u.name)),
                  ),
              ],
              onChanged: _busy ? null : (u) => setState(() => _unit = u!),
            ),
            TextField(
              controller: _date,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Test date (YYYY-MM-DD)',
              ),
            ),
            DropdownButton<BaseSourceType>(
              value: _sourceType,
              items: [
                for (final s in [
                  BaseSourceType.knownResult,
                  BaseSourceType.recordedResult,
                ])
                  DropdownMenuItem(
                    value: s,
                    child: Text(benchmarkSource(s.name)),
                  ),
              ],
              onChanged: _busy ? null : (s) => setState(() => _sourceType = s!),
            ),
            TextField(
              controller: _source,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Source or result reference',
              ),
            ),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save result'),
        ),
      ],
    ),
  );
}
