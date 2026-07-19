import 'package:flutter/material.dart';

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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<TrainingSessionRecord>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Text('Loading history…'));
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text('Could not load history', style: CohortTextStyles.h1),
                    Text('${snapshot.error}', style: CohortTextStyles.body),
                  ],
                );
              }

              final records = snapshot.data ?? const [];
              if (records.isEmpty) {
                return ListView(
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
                padding: const EdgeInsets.all(24),
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('← Back'),
                  ),
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
