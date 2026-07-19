import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/section_title.dart';
import '../models/training_session_record_status.dart';
import '../services/performance_record_save_coordinator.dart';
import '../widgets/performance_capture_widgets.dart';

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

class _TrainingHistoryDetailScreenState extends State<TrainingHistoryDetailScreen> {
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

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('← Back'),
                  ),
                  Text(record.sessionSnapshot.sessionTitle,
                      style: CohortTextStyles.h1),
                  Text(record.status.displayLabel, style: CohortTextStyles.body),
                  if (record.sessionSnapshot.programmeContextLabel != null)
                    Text(record.sessionSnapshot.programmeContextLabel!,
                        style: CohortTextStyles.small),
                  if (record.overallRpe != null)
                    Text('RPE ${record.overallRpe}', style: CohortTextStyles.small),
                  if (record.athleteNote?.isNotEmpty == true) ...[
                    const SizedBox(height: CohortSpacing.md),
                    Text(record.athleteNote!, style: CohortTextStyles.body),
                  ],
                  const SizedBox(height: CohortSpacing.xl),
                  const SectionTitle('Blocks'),
                  const SizedBox(height: CohortSpacing.md),
                  for (final block in record.blockResults) ...[
                    HistoricalBlockResultCard(block: block),
                    const SizedBox(height: CohortSpacing.md),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
