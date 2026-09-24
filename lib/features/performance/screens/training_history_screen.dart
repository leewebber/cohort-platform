import 'package:flutter/material.dart';

import '../../../core/services/authenticated_identity.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../auth/services/athlete_surface_identity.dart';
import '../../auth/widgets/athlete_identity_access_state.dart';
import '../../programme/presentation/athlete_completion_journey_copy.dart';
import '../../programme/widgets/athlete_programme_status_state.dart';
import '../models/training_session_record.dart';
import '../services/performance_record_save_coordinator.dart';
import '../widgets/performance_capture_widgets.dart';
import 'training_history_detail_screen.dart';

class TrainingHistoryScreen extends StatefulWidget {
  const TrainingHistoryScreen({
    super.key,
    required this.athleteId,
    this.saveCoordinator,
    this.initialRecords,
    this.initialFailure = false,
  });

  final String athleteId;
  final PerformanceRecordSaveCoordinator? saveCoordinator;

  /// Preview/test injection for last-good or blocked chrome.
  final List<TrainingSessionRecord>? initialRecords;
  final bool initialFailure;

  @override
  State<TrainingHistoryScreen> createState() => _TrainingHistoryScreenState();
}

class _TrainingHistoryScreenState extends State<TrainingHistoryScreen> {
  late final PerformanceRecordSaveCoordinator _coordinator =
      widget.saveCoordinator ?? PerformanceRecordSaveCoordinator();
  List<TrainingSessionRecord>? _lastGood;
  Object? _error;
  bool _loading = true;
  bool _identityDenied = false;
  String? _scopedAthleteId;

  @override
  void initState() {
    super.initState();
    if (widget.initialFailure || widget.initialRecords != null) {
      _lastGood = widget.initialRecords;
      _error = widget.initialFailure ? StateError('history_unavailable') : null;
      _loading = false;
      _identityDenied = false;
      return;
    }
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
        _identityDenied = true;
        _error = const AuthenticatedIdentityException(
          AthleteCompletionJourneyCopy.missingAthleteHeadline,
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
      _identityDenied = false;
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
    if (_identityDenied) {
      return const [AthleteIdentityAccessState.missingProfile()];
    }
    if (_error != null && _lastGood == null) {
      return [
        AthleteProgrammeStatusState(
          badge: AthleteCompletionJourneyCopy.unavailable,
          headline: AthleteCompletionJourneyCopy.historyBlockedHeadline,
          explanation: AthleteCompletionJourneyCopy.tryAgainWhenReady,
          icon: Icons.cloud_off_outlined,
          action: CohortButton(label: 'Retry', onPressed: _reload),
        ),
      ];
    }
    if (_error != null && _lastGood != null) {
      return [
        AthleteProgrammeStatusState(
          badge: AthleteCompletionJourneyCopy.refreshFailed,
          headline: AthleteCompletionJourneyCopy.historyRefreshHeadline,
          explanation: AthleteCompletionJourneyCopy.historyRefreshSupporting,
          icon: Icons.refresh,
          action: CohortButton(label: 'Retry', onPressed: _reload),
        ),
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
