import 'package:flutter/material.dart';

import '../../core/widgets/cohort_button.dart';
import '../programme/domain/enrolment_iana_timezone.dart';
import '../programme/widgets/enrolment_timezone_picker_sheet.dart';
import 'acquisition_controller.dart';
import 'acquisition_store.dart';

/// Authenticated training setup, independent of legacy programme generation.
class TrainingSetupGate extends StatefulWidget {
  const TrainingSetupGate({
    super.key,
    required this.athleteId,
    required this.child,
    this.store,
    this.onSignOut,
  });
  final String athleteId;
  final Widget child;
  final AcquisitionStore? store;
  final VoidCallback? onSignOut;
  @override
  State<TrainingSetupGate> createState() => _TrainingSetupGateState();
}

class _TrainingSetupGateState extends State<TrainingSetupGate> {
  late AcquisitionController _controller;
  String? _timezone;
  bool _review = false;

  void _create() {
    _controller = AcquisitionController(
      athleteId: widget.athleteId,
      store:
          widget.store ?? SupabaseAcquisitionStore(athleteId: widget.athleteId),
    );
    _controller.addListener(_changed);
    _load();
  }

  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void didUpdateWidget(covariant TrainingSetupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteId != widget.athleteId ||
        oldWidget.store != widget.store) {
      _controller.removeListener(_changed);
      _controller.dispose();
      _timezone = null;
      _review = false;
      _create();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final controller = _controller;
    final setup = await controller.loadSetup();
    if (!mounted ||
        !identical(controller, _controller) ||
        !controller.isCurrent) {
      return;
    }
    setState(() {
      _timezone = setup?.timezone;
      _review = _timezone != null;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c.setup?.complete == true && c.isCurrent) return widget.child;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training setup'),
        actions: [
          if (widget.onSignOut != null)
            TextButton(
              onPressed: widget.onSignOut,
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (c.busy) const LinearProgressIndicator(),
          if (c.error != null) ...[
            Text(c.error!.message, key: const Key('setup-error')),
            TextButton(
              onPressed: c.busy ? null : _load,
              child: const Text('Retry'),
            ),
          ],
          if (c.setup != null) ...[
            Text(
              _review
                  ? 'Ready to find your programme'
                  : 'Set your training timezone',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your timezone keeps programme dates and your schedule consistent. You will choose an authored programme next. Benchmarks are only needed when your programme calls for them.',
            ),
            const SizedBox(height: 16),
            Text(
              _timezone == null
                  ? 'No timezone selected'
                  : EnrolmentIanaLabels.display(_timezone!),
            ),
            TextButton(
              onPressed: c.busy
                  ? null
                  : () async {
                      final zone = await showEnrolmentTimezonePicker(
                        context: context,
                        selectedIana: _timezone,
                      );
                      if (mounted && zone != null) {
                        setState(() {
                          _timezone = zone;
                          _review = false;
                        });
                      }
                    },
              child: const Text('Choose timezone'),
            ),
            CohortButton(
              label: _review ? 'Finish setup' : 'Save and continue',
              onPressed: c.busy || _timezone == null
                  ? null
                  : () async {
                      final wasReview = _review;
                      final saved = await c.saveSetup(
                        _timezone!,
                        complete: wasReview,
                      );
                      if (mounted && c.isCurrent && saved != null) {
                        setState(() => _review = true);
                      }
                    },
            ),
          ],
        ],
      ),
    );
  }
}
