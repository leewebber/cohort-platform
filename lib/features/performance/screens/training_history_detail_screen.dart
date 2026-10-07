import 'package:flutter/material.dart';

import '../../../core/services/authenticated_identity.dart';
import '../../../core/services/supabase_service.dart';
import '../../performance_tracking/distance_history_screen.dart';
import '../../performance_tracking/supabase_distance_history.dart';
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
                if (AuthenticatedIdentity.maybeAthleteId() == widget.athleteId)
                  TextButton(
                    onPressed: () {
                      if (AuthenticatedIdentity.maybeAthleteId() !=
                          widget.athleteId) {
                        return;
                      }
                      final controller = createDistanceHistoryController(
                        SupabaseService.client,
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DistanceHistoryScreen(controller: controller),
                        ),
                      );
                    },
                    child: const Text('Open Distance observations'),
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
