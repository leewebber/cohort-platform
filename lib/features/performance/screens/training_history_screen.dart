import 'package:flutter/material.dart';

import '../../../core/presentation/athlete_safe_error_presenter.dart';
import '../../../core/services/authenticated_identity.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../auth/services/athlete_surface_identity.dart';
import '../models/training_session_record.dart';
import '../services/performance_record_save_coordinator.dart';
import '../widgets/performance_capture_widgets.dart';
import 'training_history_detail_screen.dart';

class TrainingHistoryScreen extends StatefulWidget {
  const TrainingHistoryScreen({
    super.key,
    required this.athleteId,
    this.saveCoordinator,
  });

  final String athleteId;
  final PerformanceRecordSaveCoordinator? saveCoordinator;

  @override
  State<TrainingHistoryScreen> createState() => _TrainingHistoryScreenState();
}

class _TrainingHistoryScreenState extends State<TrainingHistoryScreen> {
  late final PerformanceRecordSaveCoordinator _coordinator =
      widget.saveCoordinator ?? PerformanceRecordSaveCoordinator();
  List<TrainingSessionRecord>? _lastGood;
  Object? _error;
  bool _loading = true;
  String? _scopedAthleteId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant TrainingHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteId != widget.athleteId) {
      _lastGood = null;
      _error = null;
      _reload();
    }
  }

  String? _authorizedAthleteId() {
    try {
      return AthleteSurfaceIdentity.require(override: widget.athleteId);
    } on AuthenticatedIdentityException {
      return null;
    }
  }

  Future<void> _reload() async {
    final athleteId = _authorizedAthleteId();
    if (athleteId == null) {
      setState(() {
        _scopedAthleteId = null;
        _lastGood = null;
        _loading = false;
        _error = const AuthenticatedIdentityException(
          'Athlete access is required to open History.',
        );
      });
      return;
    }
    if (_scopedAthleteId != athleteId) {
      _lastGood = null;
      _scopedAthleteId = athleteId;
    }
    setState(() {
      _loading = _lastGood == null;
      _error = null;
    });
    try {
      final records = await _coordinator.listHistory(athleteId: athleteId);
      if (!mounted) return;
      setState(() {
        _lastGood = records;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Training History')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: _body(),
          ),
        ),
      ),
    );
  }

  List<Widget> _body() {
    if (_loading) {
      return const [Center(child: Text('Loading history…'))];
    }
    if (_error != null && _lastGood == null) {
      final message = AthleteSafeErrorPresenter.message(
        _error!,
        logTag: 'training_history',
      );
      return [
        Text('Could not load history', style: CohortTextStyles.h1),
        const SizedBox(height: CohortSpacing.md),
        Text(message, style: CohortTextStyles.body),
        const SizedBox(height: CohortSpacing.md),
        CohortButton(label: 'Retry', onPressed: _reload),
      ];
    }
    if (_error != null && _lastGood != null) {
      return [
        Text('Refresh failed', style: CohortTextStyles.h2),
        const SizedBox(height: CohortSpacing.sm),
        const Text(
          'Showing last loaded history. This list may not be current.',
          style: CohortTextStyles.body,
        ),
        const SizedBox(height: CohortSpacing.md),
        CohortButton(label: 'Retry', onPressed: _reload),
        const SizedBox(height: CohortSpacing.lg),
        ..._records(_lastGood!),
      ];
    }
    final records = _lastGood ?? const <TrainingSessionRecord>[];
    if (records.isEmpty) {
      return const [
        SectionTitle('Training History'),
        SizedBox(height: CohortSpacing.md),
        CohortCard(
          child: Text(
            'Completed sessions will appear here.',
            style: CohortTextStyles.body,
          ),
        ),
      ];
    }
    return [
      const SectionTitle('Training History'),
      const SizedBox(height: CohortSpacing.md),
      ..._records(records),
    ];
  }

  List<Widget> _records(List<TrainingSessionRecord> records) {
    return [
      for (final record in records) ...[
        TrainingHistoryCard(
          record: record,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TrainingHistoryDetailScreen(
                recordId: record.recordId,
                athleteId: _scopedAthleteId ?? widget.athleteId,
                saveCoordinator: _coordinator,
              ),
            ),
          ),
        ),
        const SizedBox(height: CohortSpacing.md),
      ],
    ];
  }
}
