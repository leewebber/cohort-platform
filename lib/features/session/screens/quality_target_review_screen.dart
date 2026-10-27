import 'package:flutter/material.dart';
import '../models/session_execution_plan.dart';
import '../models/running_target_admission.dart';
import '../../programme/models/programme_execution_context.dart';
import '../services/running_target_admission_store.dart';
import '../../../domain/running_workout/running_workout.dart';

int parseQualityTime(String text) {
  final pieces = text.trim().split(':');
  final raw = int.tryParse(text.trim());
  int? seconds = raw;
  if (pieces.length == 2) {
    final m = int.tryParse(pieces[0]), s = int.tryParse(pieces[1]);
    if (m == null || s == null || m < 0 || s < 0 || s > 59) {
      throw const FormatException('Use minutes:seconds or whole seconds.');
    }
    seconds = m * 60 + s;
  }
  if (seconds == null || seconds < 1 || seconds > 86400) {
    throw const FormatException('Enter a positive time of at most 24 hours.');
  }
  return seconds;
}

class QualityTargetReviewScreen extends StatefulWidget {
  const QualityTargetReviewScreen({
    super.key,
    required this.athleteId,
    required this.plan,
    required this.programmeContext,
    required this.store,
    required this.onAccepted,
  });
  final String athleteId;
  final SessionExecutionPlan plan;
  final ProgrammeExecutionContext programmeContext;
  final QualityRunningTargetAdmissionStore store;
  final void Function(String source, String hash) onAccepted;
  @override
  State<QualityTargetReviewScreen> createState() =>
      _QualityTargetReviewScreenState();
}

class _QualityTargetReviewScreenState extends State<QualityTargetReviewScreen> {
  final time = TextEditingController(), date = TextEditingController();
  String source = 'five_k', origin = 'manual_entry';
  bool sustained = false, busy = true;
  String? message, timezone;
  Map<String, dynamic>? review;
  bool get hasRpe => widget.plan.blocks
      .expand(
        (b) => b.timerConfiguration?.runningWorkout == null
            ? <RunningAtomicStep>[]
            : runningAtomicSteps(b.timerConfiguration!.runningWorkout!),
      )
      .where((s) => s.target.kind == RunningTargetKind.qualityPaceRef)
      .every((s) => s.target.fallbackRpe != null);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    time.dispose();
    date.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      review = null;
    });
    try {
      final r = await widget.store.reviewQuality(
        widget.programmeContext.occurrenceId!,
        source,
      );
      if (!mounted) return;
      Map? input = r['input'] as Map?;
      final raw = r['document'];
      if (r['status'] == 'review_required' && raw is Map) {
        final doc = Map<String, dynamic>.from(raw);
        if (doc['quality'] is! Map ||
            doc['quality']['selected_source'] != source) {
          throw const FormatException(
            'Target source changed. Review your selection again.',
          );
        }
        final c = widget.programmeContext;
        validateRunningTargetDocument(
          widget.plan,
          doc,
          athleteId: widget.athleteId,
          occurrenceId: c.occurrenceId!,
          assignmentId: c.assignmentId,
          versionId: c.programmeVersionId,
          packageHash: c.packageContentHash!,
        );
        if (r['review_hash'] is! String ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(r['review_hash'] as String)) {
          throw const FormatException('Invalid review hash.');
        }
        input = doc['quality']['input'] as Map?;
        timezone = doc['quality']['evaluation_timezone'] as String?;
        review = r;
        message = null;
      } else if (r['status'] == 'input_required') {
        message = _unavailableMessage(r['reason']);
        timezone = r['evaluation_timezone'] as String?;
      } else {
        throw const FormatException(
          'Reopen the workout to load the started state.',
        );
      }
      if (source == 'five_k' && input != null) {
        time.text = input['five_k_seconds']?.toString() ?? '';
        date.text = input['five_k_date']?.toString() ?? '';
        sustained =
            input['sustained'] == true && input['five_k_withdrawn'] == false;
      } else if (source == 'manual_threshold' && input != null) {
        time.text = input['manual_seconds_per_km']?.toString() ?? '';
        origin = input['manual_origin']?.toString() ?? 'manual_entry';
      }
      setState(() => busy = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          busy = false;
          review = null;
          message = error is FormatException
              ? error.message
              : 'Could not review these targets. Retry, change the input, or return to the workout.';
        });
      }
    }
  }

  Future<void> _save({bool withdraw = false}) async {
    try {
      final seconds = withdraw ? null : parseQualityTime(time.text);
      final resultDate = source == 'five_k' && !withdraw
          ? date.text.trim()
          : null;
      if (source == 'five_k' &&
          !withdraw &&
          (!sustained ||
              !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(resultDate!))) {
        throw const FormatException(
          'Enter the result date and confirm a representative sustained 5K effort.',
        );
      }
      setState(() {
        busy = true;
        review = null;
      });
      await widget.store.confirmQuality(
        kind: source,
        seconds: seconds,
        date: resultDate,
        sustained: source == 'five_k' && !withdraw ? true : null,
        withdraw: withdraw,
        manualOrigin: source == 'manual_threshold' && !withdraw ? origin : null,
      );
      if (mounted) await _load();
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          message = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          message = 'Input was not confirmed. Check its value/date and retry.';
        });
      }
    }
  }

  String _stepLabel(Map row) {
    for (final block in widget.plan.blocks) {
      final workout = block.timerConfiguration?.runningWorkout;
      if (block.blockId == row['block_id'] && workout != null) {
        for (final step in runningAtomicSteps(workout)) {
          if (step.stepId == row['step_id']) {
            return step.label ?? 'Authored work';
          }
        }
      }
    }
    throw const FormatException('Reviewed step is unavailable.');
  }

  static String _sourceLabel(String source) => switch (source) {
    'five_k' => 'Representative sustained 5K estimate',
    'manual_threshold' => 'Your manually entered threshold pace',
    'authored_rpe' => 'Authored RPE without a pace target',
    _ => 'Unavailable target source',
  };
  static String _approx(Object? value) =>
      num.tryParse(value?.toString() ?? '')?.toStringAsFixed(2) ??
      'not available';
  static String _unavailableMessage(Object? reason) => switch (reason) {
    'missing_5k' =>
      'Confirm a representative sustained 5K result, or explicitly choose an available authored alternative.',
    'stale_5k' =>
      'Your 5K result is older than 56 local calendar days. Enter a recent result or explicitly choose an available authored alternative.',
    'withdrawn_5k' =>
      'Your 5K input was withdrawn. Confirm a result or explicitly choose an available authored alternative.',
    'future_5k' =>
      'The 5K date is in the future. Correct and confirm the input.',
    'benchmark_timezone_mismatch' =>
      'The benchmark date was confirmed in a different training timezone. Reconfirm it in this programme timezone.',
    'missing_or_withdrawn_manual_threshold' =>
      'Confirm a manual threshold pace before reviewing its targets.',
    'manual_threshold_only_for_threshold' =>
      'Manual threshold pace is available only for threshold-labelled work. Choose another source.',
    'missing' || 'withdrawn' =>
      'This workout also requires confirmed Zone 2 limits. Confirm those before starting.',
    _ =>
      'Targets are unavailable for this source. Check the input or choose an available authored alternative.',
  };
  void _edited(String _) => setState(() {
    review = null;
    if (source == 'five_k') sustained = false;
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review quality-run targets')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Choose the target source. These are estimated alpha coaching targets, not measured physiological thresholds or guaranteed race predictions.',
        ),
        DropdownButtonFormField<String>(
          key: const ValueKey('quality-source'),
          initialValue: source,
          items: [
            const DropdownMenuItem(
              value: 'five_k',
              child: Text('Representative sustained 5K estimate'),
            ),
            const DropdownMenuItem(
              value: 'manual_threshold',
              child: Text('Manually entered threshold pace'),
            ),
            if (hasRpe)
              const DropdownMenuItem(
                value: 'authored_rpe',
                child: Text('Authored RPE instead of pace'),
              ),
          ],
          onChanged: busy
              ? null
              : (value) {
                  setState(() {
                    source = value!;
                    time.clear();
                    date.clear();
                    sustained = false;
                    review = null;
                  });
                  _load();
                },
        ),
        if (source != 'authored_rpe') ...[
          TextField(
            key: const ValueKey('quality-time'),
            controller: time,
            enabled: !busy,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              labelText: source == 'five_k'
                  ? '5K time (m:ss or seconds)'
                  : 'Threshold pace (m:ss per km or seconds/km)',
            ),
            onChanged: _edited,
          ),
          if (source == 'five_k') ...[
            TextField(
              key: const ValueKey('quality-date'),
              controller: date,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Result date (YYYY-MM-DD)',
              ),
              onChanged: _edited,
            ),
            CheckboxListTile(
              title: const Text(
                'I confirm this was a representative sustained 5K effort',
              ),
              value: sustained,
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      sustained = value!;
                      review = null;
                    }),
            ),
            Text(
              'Previous 56 local calendar days, including the cutoff day and today. Training timezone: ${timezone ?? 'confirmed at review'}. Future dates do not qualify.',
            ),
          ] else ...[
            DropdownButtonFormField<String>(
              key: const ValueKey('manual-origin'),
              initialValue: origin,
              items: const [
                DropdownMenuItem(
                  value: 'manual_entry',
                  child: Text('Manual entry'),
                ),
                DropdownMenuItem(
                  value: 'garmin_read_manually',
                  child: Text('Read from Garmin and entered manually'),
                ),
              ],
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      origin = value!;
                      review = null;
                    }),
            ),
            const Text(
              'Manual threshold window: 0.98×–1.02×, only for threshold-labelled work. This is manual entry, not a Garmin connection.',
            ),
          ],
          FilledButton(
            onPressed: busy ? null : () => _save(),
            child: const Text('Confirm this input'),
          ),
          TextButton(
            onPressed: busy ? null : () => _save(withdraw: true),
            child: const Text('Withdraw this input'),
          ),
        ],
        if (message != null) Text(message!),
        if (review?['document'] case final Map doc) ...[
          Text(
            '${widget.plan.sessionTitle} · ${_sourceLabel(source)} (alpha v1)',
          ),
          if (doc['quality']['input'] != null)
            Text(
              source == 'five_k'
                  ? '5K: ${doc['quality']['input']['five_k_seconds']} seconds · ${doc['quality']['input']['five_k_date']} · ${doc['quality']['input']['five_k_timezone']}'
                  : 'Manual threshold: ${doc['quality']['input']['manual_seconds_per_km']} s/km · ${doc['quality']['input']['manual_origin']}',
            ),
          if (source == 'five_k')
            Text(
              'P5 ≈ ${_approx(doc['quality']['p5_seconds_per_km'])} s/km; estimated 10K ≈ ${_approx(doc['quality']['estimated_10k_seconds'])} seconds; P10 ≈ ${_approx(doc['quality']['p10_seconds_per_km'])} s/km.',
            ),
          for (final row in doc['quality_targets'] as List)
            Text(
              '${_stepLabel(row as Map)}: ${row['target']['unit'] == 'rpe_cr10' ? 'Authored RPE ${row['target']['value']}/10' : '${row['target']['lower']}–${row['target']['upper']} seconds/km'}',
            ),
          const Text(
            'Nearest whole second; exact half-seconds round upward. Accepting starts this workout with this source, input revision, rule and targets frozen. Actual performance is recorded separately.',
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () => widget.onAccepted(
                    source,
                    review!['review_hash'] as String,
                  ),
            child: const Text('Accept targets and start'),
          ),
        ],
        TextButton(
          onPressed: busy ? null : _load,
          child: const Text('Retry target review'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}
