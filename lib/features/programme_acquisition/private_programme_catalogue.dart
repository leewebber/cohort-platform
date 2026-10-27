import 'package:flutter/material.dart';

import '../../core/widgets/cohort_button.dart';
import '../programme/screens/athlete_programme_schedule_screen.dart';
import 'acquisition_controller.dart';
import 'acquisition_store.dart';

/// Private offers in the normal catalogue, using server-owned visibility.
class PrivateProgrammeCatalogue extends StatefulWidget {
  const PrivateProgrammeCatalogue({
    super.key,
    required this.athleteId,
    this.store,
    this.onAcquired,
  });
  final String athleteId;
  final AcquisitionStore? store;
  final VoidCallback? onAcquired;
  @override
  State<PrivateProgrammeCatalogue> createState() =>
      _PrivateProgrammeCatalogueState();
}

class _PrivateProgrammeCatalogueState extends State<PrivateProgrammeCatalogue> {
  late AcquisitionController c;
  void _create() {
    c = AcquisitionController(
      athleteId: widget.athleteId,
      store:
          widget.store ?? SupabaseAcquisitionStore(athleteId: widget.athleteId),
    );
    c.addListener(_changed);
    c.loadCatalogue();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void didUpdateWidget(covariant PrivateProgrammeCatalogue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteId != widget.athleteId ||
        oldWidget.store != widget.store) {
      c.removeListener(_changed);
      c.dispose();
      _create();
    }
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    c.dispose();
    super.dispose();
  }

  Future<void> _open(PrivateProgrammeOffer offer) async {
    final acquired = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrivateProgrammeDetail(
          athleteId: widget.athleteId,
          versionId: offer.versionId,
          store: c.store,
        ),
      ),
    );
    if (mounted && c.isCurrent && acquired == true) {
      widget.onAcquired?.call();
      await c.loadCatalogue();
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Available to you', style: Theme.of(context).textTheme.titleLarge),
        const Text('Private programmes · free access'),
        if (c.busy) const LinearProgressIndicator(),
        if (c.error != null) ...[
          Text(c.error!.message),
          TextButton(
            onPressed: c.busy ? null : c.loadCatalogue,
            child: const Text('Retry private programmes'),
          ),
        ] else if (!c.busy && c.offers.isEmpty)
          const Text(
            'No private programmes are available to your account yet.',
          ),
        if (c.isCurrent)
          for (final offer in c.offers)
            Card(
              child: ListTile(
                title: Text(offer.title),
                subtitle: Text(_facts(offer)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(offer),
              ),
            ),
      ],
    ),
  );
}

String _facts(PrivateProgrammeOffer offer) => [
  if (offer.durationWeeks != null) '${offer.durationWeeks} weeks',
  if (offer.sessionsPerWeek != null)
    '${offer.sessionsPerWeek} sessions per week',
  if (offer.equipment?.trim().isNotEmpty == true)
    'Equipment: ${offer.equipment}',
  if (offer.level?.trim().isNotEmpty == true) offer.level!,
  offer.ready ? 'Ready to start' : 'Not ready to start',
].join(' · ');

class PrivateProgrammeDetail extends StatefulWidget {
  const PrivateProgrammeDetail({
    super.key,
    required this.athleteId,
    required this.versionId,
    required this.store,
    this.openSchedule,
  });
  final String athleteId;
  final String versionId;
  final AcquisitionStore store;
  final Future<void> Function(String assignmentId)? openSchedule;
  @override
  State<PrivateProgrammeDetail> createState() => _PrivateProgrammeDetailState();
}

class _PrivateProgrammeDetailState extends State<PrivateProgrammeDetail> {
  late final c = AcquisitionController(
    athleteId: widget.athleteId,
    store: widget.store,
  );
  PrivateProgrammeOffer? _offer;
  DateTime? _date;
  bool _acquired = false;
  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    _load();
  }

  Future<void> _load() async {
    setState(() => _offer = null);
    final offer = await c.detail(widget.versionId);
    if (mounted && c.isCurrent) setState(() => _offer = offer);
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    c.dispose();
    super.dispose();
  }

  Future<void> _schedule(String id) async {
    if (!c.isCurrent) return;
    _acquired = true;
    if (widget.openSchedule != null) {
      await widget.openSchedule!(id);
    } else if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AthleteProgrammeScheduleScreen(
            athleteId: widget.athleteId,
            assignmentId: id,
          ),
        ),
      );
    }
    if (mounted && c.isCurrent) Navigator.of(context).pop(true);
  }

  Future<void> _get() async {
    final offer = _offer;
    if (offer == null || c.busy || _acquired) return;
    if (offer.assignmentId != null) {
      await _schedule(offer.assignmentId!);
      return;
    }
    if (_date == null) return;
    final id = await c.acquire(widget.versionId, _date!);
    if (id != null && mounted && c.isCurrent) await _schedule(id);
  }

  @override
  Widget build(BuildContext context) {
    final offer = c.isCurrent ? _offer : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Programme details')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (c.busy) const LinearProgressIndicator(),
          if (c.error != null) ...[
            Text(c.error!.message, key: const Key('acquisition-error')),
            TextButton(
              onPressed: c.busy ? null : _load,
              child: const Text('Reload programme'),
            ),
          ],
          if (offer != null) ...[
            Text(offer.title, style: Theme.of(context).textTheme.headlineSmall),
            const Text('Private · Free'),
            if (offer.summary?.trim().isNotEmpty == true) Text(offer.summary!),
            Text(_facts(offer)),
            const SizedBox(height: 16),
            const Text(
              'No payment or billing consent is required. Getting this programme will make it your current training. An existing active programme will be kept; it will not be replaced.',
            ),
            if (offer.assignmentId == null) ...[
              const Text(
                'Choose your start date in your saved training timezone.',
              ),
              TextButton(
                onPressed: c.busy
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              _date ?? DateTime(now.year, now.month, now.day),
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 2),
                        );
                        if (mounted && c.isCurrent && date != null) {
                          setState(() => _date = date);
                        }
                      },
                child: Text(
                  _date == null
                      ? 'Choose start date'
                      : 'Starts ${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}',
                ),
              ),
            ],
            CohortButton(
              label: offer.assignmentId != null
                  ? 'Open schedule'
                  : 'Get programme — free',
              onPressed:
                  c.busy ||
                      _acquired ||
                      !offer.ready ||
                      (offer.assignmentId == null && _date == null)
                  ? null
                  : _get,
            ),
          ],
        ],
      ),
    );
  }
}
