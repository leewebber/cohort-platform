import 'package:flutter/material.dart';
import '../models/session_execution_plan.dart';
import '../models/running_target_admission.dart';
import '../../programme/models/programme_execution_context.dart';
import '../services/running_target_admission_store.dart';
import 'quality_target_review_screen.dart';

class RunningTargetReviewScreen extends StatefulWidget {
  const RunningTargetReviewScreen({
    super.key,
    required this.athleteId,
    required this.plan,
    required this.programmeContext,
    required this.store,
    this.onQualitySourceAccepted,
  });
  final String athleteId;
  final ValueChanged<String>? onQualitySourceAccepted;
  final SessionExecutionPlan plan;
  final ProgrammeExecutionContext programmeContext;
  final RunningTargetAdmissionStore store;
  @override
  State<RunningTargetReviewScreen> createState() =>
      _RunningTargetReviewScreenState();
}

class _RunningTargetReviewScreenState extends State<RunningTargetReviewScreen> {
  final lower = TextEditingController(), upper = TextEditingController();
  Map<String, dynamic>? review;
  String? message;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    if (!requiresQualityAdmission(widget.plan)) _load();
  }

  @override
  void dispose() {
    lower.dispose();
    upper.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        busy = true;
        review = null;
      });
    }
    try {
      final r = await widget.store.review(
        widget.programmeContext.occurrenceId!,
      );
      if (!mounted) return;
      final raw = r['document'];
      if (r['status'] == 'review_required' && raw is Map) {
        final doc = Map<String, dynamic>.from(raw);
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
          throw const FormatException('Invalid review receipt.');
        }
        lower.text = doc['zone2']['lower_bpm'].toString();
        upper.text = doc['zone2']['upper_bpm'].toString();
        setState(() {
          review = r;
          message = null;
          busy = false;
        });
      } else if (r['status'] == 'input_required') {
        setState(() {
          review = null;
          message = r['reason'] == 'withdrawn'
              ? 'Your Zone 2 input was withdrawn. Confirm a range to continue.'
              : 'Confirm your Zone 2 range to continue.';
          busy = false;
        });
      } else {
        throw const FormatException(
          'Reopen this workout to load its current start state.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          review = null;
          busy = false;
          message =
              'Targets could not be reviewed. Retry or return to the workout.';
        });
      }
    }
  }

  Future<void> _save({bool withdraw = false}) async {
    try {
      final lo = int.tryParse(lower.text.trim()),
          hi = int.tryParse(upper.text.trim());
      if (!withdraw) validateConfirmedZone2(lo, hi);
      setState(() {
        busy = true;
        review = null;
      });
      await widget.store.confirmZone(
        withdraw ? null : lo,
        withdraw ? null : hi,
        withdraw: withdraw,
      );
      await _load();
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
          message = 'Could not confirm your range. Retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (requiresQualityAdmission(widget.plan)) {
      final store = widget.store;
      if (store is! QualityRunningTargetAdmissionStore) {
        return const Scaffold(
          body: Text(
            'Quality input review is unavailable. Return to the workout.',
          ),
        );
      }
      return QualityTargetReviewScreen(
        athleteId: widget.athleteId,
        plan: widget.plan,
        programmeContext: widget.programmeContext,
        store: store as QualityRunningTargetAdmissionStore,
        onAccepted: (source, hash) {
          widget.onQualitySourceAccepted?.call(source);
          Navigator.pop(context, hash);
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Review running targets')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Enter your confirmed Zone 2 heart-rate limits. Cohort does not calculate a zone from your age or a universal formula.',
          ),
          TextField(
            key: const ValueKey('zone2-lower'),
            controller: lower,
            enabled: !busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Lower heart rate (bpm)',
            ),
            onChanged: (_) => setState(() => review = null),
          ),
          TextField(
            key: const ValueKey('zone2-upper'),
            controller: upper,
            enabled: !busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Upper heart rate (bpm)',
            ),
            onChanged: (_) => setState(() => review = null),
          ),
          FilledButton(
            onPressed: busy ? null : () => _save(),
            child: const Text('Confirm these Zone 2 limits'),
          ),
          TextButton(
            onPressed: busy ? null : () => _save(withdraw: true),
            child: const Text('Withdraw Zone 2 input'),
          ),
          if (message != null) Text(message!),
          if (review?['document'] case final Map doc) ...[
            const Text('Review before accepting this workout'),
            for (final block in widget.plan.blocks)
              if (block.timerConfiguration?.runningWorkout case final workout?)
                for (final step in runningAtomicSteps(workout))
                  Text(
                    '${step.label ?? step.role.name}: ${step.target.heartRateZoneRef == confirmedZone2Reference ? '${doc['zone2']['lower_bpm']}–${doc['zone2']['upper_bpm']} bpm (confirmed Zone 2)' : 'Unchanged authored target / guidance'}',
                  ),
            const Text(
              'Accepting starts this workout with these targets frozen. Later input changes affect future starts only. Recorded performance remains separate.',
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => Navigator.pop(
                      context,
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
}
