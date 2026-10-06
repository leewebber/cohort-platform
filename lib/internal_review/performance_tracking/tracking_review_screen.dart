import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../domain/performance_tracking/performance_tracking.dart';
import 'tracking_review_scenarios.dart';

class TrackingReviewApp extends StatelessWidget {
  const TrackingReviewApp({
    super.key,
    this.initialScenario = TrackingReviewScenario.complete,
  });
  final TrackingReviewScenario initialScenario;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'C4 synthetic tracking review',
    debugShowCheckedModeBanner: false,
    theme: cohortTheme,
    home: TrackingReviewScreen(initialScenario: initialScenario),
  );
}

class TrackingReviewScreen extends StatefulWidget {
  const TrackingReviewScreen({
    super.key,
    this.initialScenario = TrackingReviewScenario.complete,
  });
  final TrackingReviewScenario initialScenario;
  @override
  State<TrackingReviewScreen> createState() => _TrackingReviewScreenState();
}

class _TrackingReviewScreenState extends State<TrackingReviewScreen> {
  late TrackingReviewScenario _scenario = widget.initialScenario;
  late Future<List<TrackingReviewCase>> _cases = buildTrackingReviewScenario(
    _scenario,
  );

  void _open(TrackingReviewScenario scenario) {
    if (_scenario == scenario) return;
    setState(() {
      _scenario = scenario;
      _cases = buildTrackingReviewScenario(scenario);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(CohortSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.4) {
                  return const Text(
                    'Synthetic data — internal visual review only.',
                    style: CohortTextStyles.small,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'INTERNAL REVIEW / C4',
                      style: CohortTextStyles.eyebrow,
                    ),
                    const SizedBox(height: CohortSpacing.sm),
                    const Text(
                      'Performance tracking',
                      style: CohortTextStyles.h2,
                    ),
                    const SizedBox(height: CohortSpacing.sm),
                    const Text(
                      'Synthetic data — internal visual review only. These fixtures are not approved real profiles.',
                      style: CohortTextStyles.body,
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow =
                    constraints.maxWidth < 900 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.4;
                final workspace = KeyedSubtree(
                  key: ValueKey(_scenario),
                  child: FutureBuilder<List<TrackingReviewCase>>(
                    future: _cases,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Review fixtures could not be evaluated. No observations admitted.',
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return SingleChildScrollView(
                        key: const ValueKey('review-workspace'),
                        padding: const EdgeInsets.all(CohortSpacing.lg),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1080),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Performance tracking · fixtures are not approved real profiles.',
                                  style: CohortTextStyles.small,
                                ),
                                const SizedBox(height: CohortSpacing.md),
                                Text(
                                  _scenario.title,
                                  style: CohortTextStyles.h1,
                                ),
                                const SizedBox(height: CohortSpacing.sm),
                                Text(
                                  _scenario.subtitle,
                                  style: CohortTextStyles.body,
                                ),
                                const SizedBox(height: CohortSpacing.xl),
                                for (final review in snapshot.data!)
                                  _CaseView(review: review),
                                const _Panel(
                                  children: [
                                    Text(
                                      'Review limits',
                                      style: CohortTextStyles.cardTitle,
                                    ),
                                    Text(
                                      'Tracking does not create prescription eligibility. Valid observations, comparable pairs and proven synthetic scope do not authorise training targets or prove test completion.',
                                      style: CohortTextStyles.body,
                                    ),
                                    Text(
                                      'Earlier inputs cannot be reconstructed from these audits. Multiple record frames do not establish one cross-record database snapshot. Cohort 5 km ingestion remains blocked.',
                                      style: CohortTextStyles.body,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
                if (narrow) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CohortSpacing.lg,
                          vertical: CohortSpacing.sm,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PopupMenuButton<TrackingReviewScenario>(
                            key: const ValueKey('scenario-menu'),
                            tooltip: 'Review scenarios',
                            onSelected: _open,
                            itemBuilder: (context) => [
                              for (final scenario
                                  in TrackingReviewScenario.values)
                                PopupMenuItem(
                                  value: scenario,
                                  child: Text(scenario.title),
                                ),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.all(CohortSpacing.sm),
                              child: Row(
                                children: [
                                  const Icon(Icons.unfold_more, size: 20),
                                  const SizedBox(width: CohortSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      'Review scenario: ${_scenario.title}',
                                      style: CohortTextStyles.small,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: workspace),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 260,
                      child: ListView(
                        padding: const EdgeInsets.all(CohortSpacing.md),
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(CohortSpacing.md),
                            child: Text(
                              'REVIEW SCENARIOS',
                              style: CohortTextStyles.sectionLabel,
                            ),
                          ),
                          for (final scenario in TrackingReviewScenario.values)
                            ListTile(
                              key: ValueKey('scenario-${scenario.name}'),
                              selected: _scenario == scenario,
                              selectedTileColor: CohortColors.oliveSoft,
                              title: Text(scenario.title),
                              subtitle: Text(scenario.subtitle),
                              onTap: () => _open(scenario),
                            ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: workspace),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _CaseView extends StatelessWidget {
  const _CaseView({required this.review});
  final TrackingReviewCase review;

  @override
  Widget build(BuildContext context) {
    final data = review.evaluation.content;
    final observations = _maps(data['observations']);
    final requests = _maps(data['inputs']);
    final comparisons = _maps(data['comparisons']);
    return _Panel(
      children: [
        Text(review.title, style: CohortTextStyles.h2),
        Text(review.note, style: CohortTextStyles.body),
        const Divider(),
        Text(
          '${review.profile.name} · version ${review.profile.version}',
          style: CohortTextStyles.cardTitle,
        ),
        const Text(
          'Synthetic curated composition · exact supplied definitions',
          style: CohortTextStyles.small,
        ),
        for (final metric in review.metrics) ...[
          Text(
            '${metric.label} · definition version ${metric.version}',
            style: CohortTextStyles.cardTitle,
          ),
          Text(
            '${_fieldLabel(metric.captureField)} · ${trackingUnitLabel(metric.unit.name)} · ${_methodLabel(review, metric)} version ${metric.method.version}',
            style: CohortTextStyles.body,
          ),
          Text(
            '${metric.allowPartial ? 'Partial values may be shown, but are not comparison eligible.' : 'Incomplete selected fields withhold the value.'} Required comparison context: retained comparison family. No freshness rule or assessment requirement.',
            style: CohortTextStyles.small,
          ),
        ],
        _Evidence(
          title: 'Definition evidence',
          data: {
            'profile_reference': review.profile.reference.toJson(),
            'definitions': [
              for (final a in review.definitions)
                {'reference': a.reference.toJson(), 'content': a.toJson()},
            ],
            'comparison_policy': data['policy'],
          },
        ),
        if (review.evaluation.isFailure) ...[
          const Text('Evaluation refused', style: CohortTextStyles.cardTitle),
          Text(
            trackingReasonLabel(review.evaluation.failureCode!),
            style: CohortTextStyles.body,
          ),
          const Text(
            'No observations admitted by this evaluation.',
            style: CohortTextStyles.body,
          ),
        ] else ...[
          const Text(
            'Recorded observations',
            style: CohortTextStyles.cardTitle,
          ),
          if (observations.isEmpty)
            const Text(
              'No observations admitted.',
              style: CohortTextStyles.body,
            ),
          for (final observation in observations)
            _Observation(review: review, observation: observation),
          for (final request in requests)
            if (request['outcome'] is Map)
              _FailedRequest(review: review, request: request),
          const Text(
            'Requested observation pairs',
            style: CohortTextStyles.cardTitle,
          ),
          if (comparisons.isEmpty)
            const Text(
              'No pair requested in this case.',
              style: CohortTextStyles.body,
            ),
          for (final pair in comparisons)
            _Pair(review: review, pair: pair, observations: observations),
        ],
        const Text('Authority boundary', style: CohortTextStyles.cardTitle),
        const Text(
          'Prescription eligibility: not granted. Programme attribution and tracking eligibility are separate facts.',
          style: CohortTextStyles.body,
        ),
        _Evidence(
          title: 'Source and correction evidence',
          data: {
            'observations': observations,
            'requested_fields': [
              for (final i in review.inputs)
                {
                  'alias': i.id,
                  'source_identity': jsonDecode(i.query.field.sourceIdentity),
                  'requested_correction': i.query.field.expectedCorrectionId,
                },
            ],
            'audit_membership': [
              for (final f in review.frames)
                if (f.corrections.isNotEmpty) f.corrections,
            ],
          },
        ),
        _Evidence(
          title: 'Authority evidence',
          data: {
            'evaluation': data,
            'evaluation_digest': review.evaluation.digest,
            'claims': [
              for (final i in review.inputs)
                if (i.query.programmeClaim != null)
                  {
                    'alias': i.id,
                    'assignment': i.query.programmeClaim!.assignmentId,
                    'occurrence': i.query.programmeClaim!.occurrenceId,
                    'session': i.query.programmeClaim!.trainingSessionId,
                    'scope': i.query.programmeClaim!.scope.toJson(),
                  },
            ],
            'synthetic_witnesses': [
              for (final f in review.frames)
                if (f.programmeWitness != null)
                  {
                    'athlete': f.programmeWitness!.athleteId,
                    'record': f.programmeWitness!.recordId,
                    'assignment': f.programmeWitness!.assignmentId,
                    'occurrence': f.programmeWitness!.occurrenceId,
                    'session': f.programmeWitness!.trainingSessionId,
                    'scope': f.programmeWitness!.scope.toJson(),
                  },
            ],
            'synthetic_only': true,
            'cross_record_snapshot_proven': false,
          },
        ),
      ],
    );
  }
}

class _Observation extends StatelessWidget {
  const _Observation({required this.review, required this.observation});
  final TrackingReviewCase review;
  final Map observation;
  @override
  Widget build(BuildContext context) {
    final views = _maps(observation['views']);
    final names = views
        .expand((v) => v['aliases'] as List)
        .map((a) => review.labels[a])
        .toSet()
        .join(' / ');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: CohortSpacing.sm),
      padding: const EdgeInsets.all(CohortSpacing.md),
      decoration: BoxDecoration(
        color: CohortColors.surfaceRaised,
        border: Border.all(color: CohortColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(names, style: CohortTextStyles.cardTitle),
          if (views.expand((v) => v['aliases'] as List).length > 1)
            const Text(
              'One physical observation · multiple references',
              style: CohortTextStyles.small,
            ),
          for (final view in views) ...[
            if (views.length > 1)
              Text(
                _metricFor(review, view).label,
                style: CohortTextStyles.small,
              ),
            Text(_valueLabel(view), style: CohortTextStyles.h2),
            Text(_dateLabel(view), style: CohortTextStyles.small),
            Text(
              '${_stateLabel(view['state'] as String)} · Recorded session ${_fieldLabel(_metricFor(review, view).captureField).toLowerCase()}',
              style: CohortTextStyles.body,
            ),
            if ((view['evidence'] as Map?)?['reason'] != null)
              Text(
                trackingReasonLabel(
                  (view['evidence'] as Map)['reason'] as String,
                ),
                style: CohortTextStyles.body,
              ),
            Text(_coverageLabel(view), style: CohortTextStyles.small),
            Text(
              'Independent tracking eligibility: ${view['tracking_eligible'] == true ? 'eligible' : 'not eligible'}',
              style: CohortTextStyles.body,
            ),
            Text(
              _attributionLabel(view['programme_attribution'] as String),
              style: CohortTextStyles.body,
            ),
            if ((view['correction_ids'] as List? ?? []).isNotEmpty) ...[
              const Text(
                'Correction audit present; earlier inputs unavailable.',
                style: CohortTextStyles.body,
              ),
              Text(
                'Recorded audit times (unordered): ${review.frames.expand((f) => f.corrections).map((a) => a['corrected_at']).toSet().join(', ')}. Membership does not prove this field changed or identify a latest revision.',
                style: CohortTextStyles.small,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FailedRequest extends StatelessWidget {
  const _FailedRequest({required this.review, required this.request});
  final TrackingReviewCase review;
  final Map request;
  @override
  Widget build(BuildContext context) {
    final outcome = request['outcome'] as Map;
    final reason =
        outcome['reason'] ?? (outcome['evidence'] as Map?)?['reason'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CohortSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            review.labels[request['id']]!,
            style: CohortTextStyles.cardTitle,
          ),
          Text(
            _stateLabel(outcome['state'] as String),
            style: CohortTextStyles.body,
          ),
          if (reason != null)
            Text(
              trackingReasonLabel(reason as String),
              style: CohortTextStyles.body,
            ),
          const Text(
            'No measured value admitted from this request. Independent tracking eligibility: not eligible.',
            style: CohortTextStyles.body,
          ),
          Text(
            _attributionLabel(outcome['programme_attribution'] as String),
            style: CohortTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({
    required this.review,
    required this.pair,
    required this.observations,
  });
  final TrackingReviewCase review;
  final Map pair;
  final List<Map> observations;
  @override
  Widget build(BuildContext context) {
    Widget operand(String role) {
      final id = (pair[role] as Map)['id'] as String;
      final views = observations
          .expand((o) => _maps(o['views']))
          .where((v) => (v['aliases'] as List).contains(id));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(review.labels[id]!, style: CohortTextStyles.cardTitle),
          if (views.isNotEmpty) ...[
            Text(_valueLabel(views.single), style: CohortTextStyles.body),
            Text(_dateLabel(views.single), style: CohortTextStyles.small),
          ] else
            const Text('No admitted observation', style: CohortTextStyles.body),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CohortSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(switch (pair['state']) {
            'comparable' => 'Comparable',
            'incomparable' => 'Not comparable',
            _ => 'Comparison unavailable',
          }, style: CohortTextStyles.cardTitle),
          const SizedBox(height: CohortSpacing.sm),
          LayoutBuilder(
            builder: (context, c) =>
                c.maxWidth < 600 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.4
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      operand('left'),
                      const SizedBox(height: CohortSpacing.md),
                      operand('right'),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: operand('left')),
                      const SizedBox(width: CohortSpacing.lg),
                      Expanded(child: operand('right')),
                    ],
                  ),
          ),
          const SizedBox(height: CohortSpacing.sm),
          if ((pair['reasons'] as List).isEmpty)
            const Text(
              'Same exact definition and method, matching unit, field scope and retained context; two distinct eligible observations.',
              style: CohortTextStyles.body,
            ),
          for (final reason in pair['reasons'] as List)
            Text(
              trackingReasonLabel(reason as String),
              style: CohortTextStyles.body,
            ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: CohortSpacing.lg),
    padding: const EdgeInsets.all(CohortSpacing.lg),
    decoration: BoxDecoration(
      color: CohortColors.surface,
      border: Border.all(color: CohortColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children)
          Padding(
            padding: const EdgeInsets.only(bottom: CohortSpacing.md),
            child: child,
          ),
      ],
    ),
  );
}

class _Evidence extends StatelessWidget {
  const _Evidence({required this.title, required this.data});
  final String title;
  final Object data;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ExpansionTile(
      title: Text(title, style: CohortTextStyles.small),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: CohortSpacing.md),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          const JsonEncoder.withIndent('  ').convert(data),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

List<Map> _maps(Object? value) => value is List ? value.cast<Map>() : [];
TrackingMetricDefinition _metricFor(TrackingReviewCase review, Map view) =>
    review.metrics.singleWhere(
      (m) => m.digest == (view['metric'] as Map)['digest'],
    );
String _methodLabel(TrackingReviewCase review, TrackingMetricDefinition m) =>
    review.definitions
            .whereType<TrackingMethodDefinition>()
            .singleWhere((a) => a.digest == m.method.digest)
            .kind ==
        TrackingMethodKind.fieldExtraction
    ? 'Field extraction'
    : 'Unsupported difference signature';
String _fieldLabel(String field) => switch (field) {
  'duration_seconds' => 'Set duration',
  'distance' => 'Block distance',
  _ => 'Block duration',
};
String trackingUnitLabel(String? unit) => switch (unit) {
  'seconds' => 'seconds',
  'metres' => 'metres',
  'kilometres' => 'kilometres',
  'kilograms' => 'kilograms',
  'count' => 'count',
  'secondsPerKilometre' => 'seconds per kilometre',
  _ => 'unit not retained',
};
String _valueLabel(Map view) => view['value'] == null
    ? '${_stateLabel(view['state'] as String)} — no value'
    : '${view['value']} ${trackingUnitLabel(view['unit'] as String?)}';
String _dateLabel(Map view) {
  final chronology = view['chronology'] as Map?;
  if (chronology == null) return 'Performed date unavailable';
  if (chronology['precision'] == 'civil_date') {
    return '${chronology['performed_on']} · date only · timezone unknown';
  }
  return '${chronology['performed_at']} · timestamp (UTC) · civil timezone unknown';
}

String _coverageLabel(Map view) {
  final e = view['evidence'] as Map?;
  if (e?['recorded_count'] == null) {
    return 'Selected-field coverage unavailable';
  }
  return 'Selected-field coverage: ${e!['recorded_count']} of ${e['required_count']} required complete fields';
}

String _stateLabel(String state) => switch (state) {
  'available' => 'Recorded',
  'partial' => 'Partial evidence',
  'missing' => 'Missing evidence',
  'skipped' => 'Skipped',
  'unavailable' => 'Value unavailable',
  'incomparable' => 'Incompatible evidence',
  'ineligible' => 'Evidence not eligible',
  'failure' => 'Request refused',
  _ => 'Unrecognised evidence state (see evidence)',
};
String _attributionLabel(String state) => switch (state) {
  'not_requested' => 'Programme attribution not requested',
  'proven' => 'Programme attribution: proven in this synthetic fixture',
  'unproven' => 'Programme scope unproven',
  _ => 'Programme attribution failed',
};

/// Formatting only: returned codes remain intact in expandable evidence.
String trackingReasonLabel(String reason) {
  if (reason.startsWith('context_incompatible:')) {
    return 'Retained comparison context differs (${reason.split(':').last.replaceAll('_', ' ')}).';
  }
  if (reason.startsWith('context_unavailable:')) {
    return 'Required comparison context is missing (${reason.split(':').last.replaceAll('_', ' ')}).';
  }
  return switch (reason) {
    'same_observation' =>
      'Both references identify the same physical observation.',
    'metric_version_incompatible' =>
      'The exact metric definitions or versions differ.',
    'method_incompatible' => 'The exact extraction methods differ.',
    'unit_incompatible' || 'canonical_unit_incompatible' =>
      'Recorded units do not match the required unit; no conversion is performed.',
    'field_scope_incompatible' => 'The selected field scopes differ.',
    'evidence_not_available' =>
      'At least one operand lacks an available, tracking-eligible value.',
    'selected_scope_incomplete' =>
      'The selected measurement scope is incomplete.',
    'actual_not_captured' =>
      'Work was completed, but this actual value was not captured.',
    'block_not_started' => 'The selected scope has not been started.',
    'block_skipped' => 'The selected scope was skipped.',
    'programme_scope_unproven' =>
      'Retained programme scope proof is unavailable; no programme attribution is admitted.',
    'programme_scope_mismatch' || 'programme_scope_conflict' =>
      'The programme claim contradicts the supplied source proof.',
    'conflicting_source_aliases' =>
      'Aliases of one physical source contain conflicting evidence.',
    'unsupported_method' =>
      'This method is not supported for observation extraction; no calculated result is produced.',
    _ =>
      'Evidence cannot be admitted for an unrecognised reason. See expandable evidence for the exact diagnostic.',
  };
}
