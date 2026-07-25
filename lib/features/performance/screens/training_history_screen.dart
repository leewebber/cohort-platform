import 'package:flutter/material.dart';

import '../../../core/presentation/athlete_safe_error_presenter.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
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
  late Future<List<TrainingSessionRecord>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<TrainingSessionRecord>> _loadHistory() {
    return _coordinator.listHistory(athleteId: widget.athleteId);
  }

  Future<void> _refresh() async {
    setState(() {
      _historyFuture = _loadHistory();
    });
    await _historyFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training History'),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<TrainingSessionRecord>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: const [
                    Center(child: Text('Loading history…')),
                  ],
                );
              }
              if (snapshot.hasError) {
                final message = AthleteSafeErrorPresenter.message(
                  snapshot.error!,
                  logTag: 'training_history',
                );
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text('Could not load history', style: CohortTextStyles.h1),
                    const SizedBox(height: CohortSpacing.md),
                    Text(message, style: CohortTextStyles.body),
                  ],
                );
              }

              final records = snapshot.data ?? const [];
              if (records.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SectionTitle('Training History'),
                    SizedBox(height: CohortSpacing.md),
                    CohortCard(
                      child: Text(
                        'Completed sessions will appear here.',
                        style: CohortTextStyles.body,
                      ),
                    ),
                  ],
                );
              }

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SectionTitle('Training History'),
                  const SizedBox(height: CohortSpacing.md),
                  for (final record in records) ...[
                    TrainingHistoryCard(
                      record: record,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TrainingHistoryDetailScreen(
                            recordId: record.recordId,
                            athleteId: widget.athleteId,
                            saveCoordinator: _coordinator,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: CohortSpacing.md),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
