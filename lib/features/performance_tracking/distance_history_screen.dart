import 'dart:convert';

import 'package:flutter/material.dart';

import '../../application/performance_tracking/distance_observations_profile.dart';
import 'distance_history_controller.dart';

/// Athlete view. Its controller owns all ephemeral choices and authority reads.
class DistanceHistoryScreen extends StatefulWidget {
  const DistanceHistoryScreen({super.key, required this.controller});
  final DistanceHistoryController controller;
  @override
  State<DistanceHistoryScreen> createState() => _DistanceHistoryScreenState();
}

class _DistanceHistoryScreenState extends State<DistanceHistoryScreen> {
  DistanceHistoryController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    c.loadPage();
  }

  @override
  void didUpdateWidget(covariant DistanceHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != c) {
      oldWidget.controller.removeListener(_changed);
      oldWidget.controller.dispose();
      c.addListener(_changed);
      c.loadPage();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = c.identityValid ? c.evaluation?.content : null;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(56),
        title: const Text('History tracking'),
      ),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('distance-history-scroll'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Distance observations · v1',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text('Recorded block distance · v1 · kilometres'),
            const SizedBox(height: 8),
            const Text(DistanceObservationsProfile.description),
            const Text(
              'Independent History observations. No programme attribution is requested. '
              'Tracking does not grant training targets or prescription eligibility.',
            ),
            const Text(
              'Choose at most two records, then explicitly choose one block in each. '
              'Choices reset when you leave, refresh or your account changes.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton(
                  onPressed: c.busy ? null : c.refresh,
                  child: const Text('Refresh and clear choices'),
                ),
                if (!c.identityValid)
                  OutlinedButton(
                    onPressed: c.busy ? null : c.loadPage,
                    child: const Text('Load owned History'),
                  ),
              ],
            ),
            if (c.busy) const LinearProgressIndicator(),
            if (c.error != null)
              Text(
                distanceReason(c.error!),
                key: const ValueKey('tracking-error'),
              ),
            if (c.error != null)
              _evidence('Read Evidence', {'reason': c.error}),
            if (c.identityValid) ...[
              const SizedBox(height: 12),
              Text(
                'Owned History records · page ${c.offset ~/ 25 + 1}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'A bounded metadata page, not all History. Records are rechecked through the independent reader.',
              ),
              if (!c.busy && c.page.isEmpty)
                const Text('No records on this page.'),
              for (final summary in c.page)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Performed: ${summary.date}'),
                        Text('Session: ${sessionState(summary.status)}'),
                        TextButton(
                          key: ValueKey('record-${summary.id}'),
                          onPressed:
                              c.busy ||
                                  (c.views.length == 2 &&
                                      !c.views.any(
                                        (v) => v.summary.id == summary.id,
                                      ))
                              ? null
                              : () => c.toggleRecord(summary),
                          child: Text(
                            c.views.any((v) => v.summary.id == summary.id)
                                ? 'Remove record'
                                : 'Choose record',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Wrap(
                spacing: 12,
                children: [
                  if (c.offset > 0)
                    TextButton(
                      onPressed: c.busy
                          ? null
                          : () => c.loadPage(pageOffset: c.offset - 25),
                      child: const Text('Previous page'),
                    ),
                  if (c.hasNext)
                    TextButton(
                      onPressed: c.busy
                          ? null
                          : () => c.loadPage(pageOffset: c.offset + 25),
                      child: const Text('Next page'),
                    ),
                ],
              ),
              if (data?['state'] == 'failure')
                Text(
                  'Evaluation refused: ${distanceReason(data!['reason'] as String)}',
                ),
              for (final view in c.views) _recordView(context, view, data),
              if (c.views.length == 2 && c.views.every((v) => v.input != null))
                OutlinedButton(
                  key: const ValueKey('compare-distance'),
                  onPressed: c.busy ? null : c.compare,
                  child: const Text('Check comparability'),
                ),
              for (final pair in _maps(data?['comparisons'])) ...[
                Text(switch (pair['state']) {
                  'comparable' => 'Can compare recorded distances',
                  'incomparable' => 'Cannot compare',
                  _ => 'Not enough evidence to compare',
                }, style: Theme.of(context).textTheme.titleMedium),
                for (final reason in pair['reasons'] as List)
                  Text(distanceReason(reason as String)),
                const Text(
                  'Admission applies to recorded quantities only; it does not prove equivalent exercise, '
                  'equipment, elapsed time or route, and cannot show improvement.',
                ),
                _evidence('Comparison Evidence', pair),
              ],
              if (c.views.length > 1)
                const Text(
                  'These are separate record snapshots, not one cross-record snapshot.',
                ),
            ],
            _evidence('Profile Evidence', {
              'definitions': DistanceObservationsProfile.definitions
                  .map((d) => d.toJson())
                  .toList(),
              'references': DistanceObservationsProfile.definitions
                  .map((d) => d.reference.toJson())
                  .toList(),
              'approval':
                  'Founder approved v1 metric decision, 2026-10-07; local implementation only',
              'historical_reconstruction': false,
              'prescription_eligibility': false,
            }),
          ],
        ),
      ),
    );
  }

  Widget _recordView(
    BuildContext context,
    DistanceRecordView record,
    Map<String, Object?>? data,
  ) {
    Map? projected;
    if (data?['state'] != 'failure') {
      for (final observation in _maps(data?['observations'])) {
        for (final view in _maps(observation['views'])) {
          if ((view['aliases'] as List).contains(record.summary.id)) {
            projected = view;
          }
        }
      }
      for (final input in _maps(data?['inputs'])) {
        if (input['id'] == record.summary.id && input['outcome'] is Map) {
          projected = input['outcome'] as Map;
        }
      }
    }
    final chronology = projected?['chronology'] as Map?;
    final corrections = projected?['correction_ids'] as List? ?? const [];
    final state = projected?['state'] as String?;
    final reason =
        (projected?['evidence'] as Map?)?['reason'] ?? projected?['reason'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected record · ${record.summary.date}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (record.candidates.isEmpty)
              const Text('No supported distance block scopes in this record.'),
            if (record.candidates.isNotEmpty)
              ExpansionTile(
                key: ValueKey(
                  '${record.summary.id}-${record.selected?.field.blockResultId ?? 'unselected'}',
                ),
                initiallyExpanded: record.selected == null,
                title: Text(
                  record.selected == null
                      ? 'Block sources'
                      : 'Block sources · chosen block ${record.candidates.indexOf(record.selected!) + 1}',
                ),
                children: [
                  for (var i = 0; i < record.candidates.length; i++)
                    TextButton(
                      key: ValueKey(
                        'block-${record.candidates[i].field.blockResultId}',
                      ),
                      onPressed: c.busy
                          ? null
                          : () => c.selectBlock(
                              record.summary.id,
                              record.candidates[i],
                            ),
                      child: Text(
                        '${record.selected == record.candidates[i] ? 'Chosen: ' : 'Choose '}block ${i + 1} · ${record.candidates[i].label}',
                      ),
                    ),
                ],
              ),
            if (record.selected == null && record.candidates.isNotEmpty)
              const Text(
                'Choose a block to see its evidence. No block is selected automatically.',
              ),
            if (projected != null) ...[
              const Text('Recorded block distance'),
              Text(
                projected['value'] == null
                    ? 'No admitted value'
                    : '${projected['value']} ${distanceUnit(projected['unit'])}',
                key: ValueKey('value-${record.summary.id}'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(evidenceState(state)),
              if (reason is String) Text(distanceReason(reason)),
              Text(
                chronology == null
                    ? 'Performed date unavailable'
                    : 'Performed: ${chronology['performed_on'] ?? chronology['performed_at']} · '
                          '${chronology['precision'] == 'civil_date' ? 'date only · timezone unknown' : 'timestamp · civil timezone unknown'}',
              ),
              Text(
                'Source: owned History record · ${record.selected?.label ?? 'selected block'} · recorded block distance',
              ),
              if (corrections.isNotEmpty)
                const Text(
                  'Correction audit present; earlier inputs unavailable. '
                  'Audit membership does not prove this field changed or a latest revision.',
                ),
              _evidence('Evidence', projected),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _evidence(String title, Object data) => ExpansionTile(
  title: Text(title),
  childrenPadding: const EdgeInsets.all(12),
  children: [SelectableText(const JsonEncoder.withIndent('  ').convert(data))],
);
List<Map> _maps(Object? value) => value is List ? value.cast<Map>() : [];
String distanceUnit(Object? unit) => switch (unit) {
  'kilometres' => 'kilometres',
  'metres' => 'metres',
  _ => 'unit unavailable',
};
String sessionState(String state) => switch (state) {
  'partially_completed' => 'partially completed',
  'abandoned' => 'abandoned',
  'completed' => 'completed',
  _ => 'Unrecognised session status',
};
String evidenceState(String? state) => switch (state) {
  'available' => 'Recorded',
  'partial' => 'Partial evidence',
  'skipped' => 'Skipped',
  'missing' => 'Missing evidence',
  'unavailable' => 'Value unavailable',
  'incomparable' => 'Incompatible evidence',
  'ineligible' => 'Evidence not eligible',
  'failure' => 'Request refused',
  _ => 'Evidence unavailable',
};
String distanceReason(String code) {
  if (code.startsWith('context_unavailable:')) {
    return 'Comparison context was not recorded for both blocks.';
  }
  if (code.startsWith('context_incompatible:')) {
    return 'Recorded comparison contexts differ.';
  }
  return switch (code) {
    'canonical_unit_incompatible' ||
    'unit_incompatible' => 'Units differ. No conversion is performed.',
    'unsupported_source_unit' =>
      'This source unit is unsupported. No value is admitted.',
    'selected_scope_incomplete' =>
      'This block is incomplete; its value is withheld.',
    'block_skipped' => 'This block was skipped.',
    'block_not_started' => 'This block has not been started.',
    'actual_not_captured' => 'Work was completed; distance was not recorded.',
    'evidence_not_available' => 'A complete, usable observation is missing.',
    'same_observation' => 'The same observation cannot be compared to itself.',
    'method_incompatible' => 'Measurement methods differ.',
    'metric_version_incompatible' => 'Metric definitions differ.',
    'field_scope_incompatible' => 'Selected field scopes differ.',
    'identity_changed' || 'ownership_denied' =>
      'Account access changed. Choices and evidence were cleared. Sign in with an athlete account and reload.',
    'record_not_available' => 'This record is not available to your account.',
    'history_list_unavailable' =>
      'Owned History could not be loaded. Retry when ready.',
    'conflicting_source_aliases' => 'References to the same source disagree.',
    _ =>
      'Evidence could not be admitted. Refresh to retry; see Evidence for the exact reason.',
  };
}
