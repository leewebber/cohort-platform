import 'package:flutter/material.dart';

import '../services/performance_record_save_coordinator.dart';
import '../widgets/completed_session_result_view.dart';

class TrainingHistoryDetailScreen extends StatefulWidget {
  const TrainingHistoryDetailScreen({
    super.key,
    required this.recordId,
    required this.athleteId,
    this.saveCoordinator,
  });

  final String recordId;
  final String athleteId;
  final PerformanceRecordSaveCoordinator? saveCoordinator;

  @override
  State<TrainingHistoryDetailScreen> createState() =>
      _TrainingHistoryDetailScreenState();
}

class _TrainingHistoryDetailScreenState
    extends State<TrainingHistoryDetailScreen> {
  late final PerformanceRecordSaveCoordinator _coordinator =
      widget.saveCoordinator ?? PerformanceRecordSaveCoordinator();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder(
          future: _coordinator.getRecordById(widget.recordId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Text('Loading session…'));
            }
            final record = snapshot.data;
            if (record == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Session record not found.'),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('← Back'),
                ),
                Expanded(
                  child: CompletedSessionResultView(
                    record: record,
                    statusMessage: 'Completed',
                    performanceRecordStore: _coordinator.store,
                    onRecordCorrected: (_) => setState(() {}),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
