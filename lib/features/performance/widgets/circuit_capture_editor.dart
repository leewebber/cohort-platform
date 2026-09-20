import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../models/circuit_station_actual.dart';
import '../models/performance_result_data.dart';
import 'performance_numeric_field.dart';

class CircuitCaptureEditor extends StatelessWidget {
  const CircuitCaptureEditor({
    super.key,
    required this.result,
    required this.onChanged,
  });

  final CircuitResultData result;
  final ValueChanged<PerformanceResultData> onChanged;

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<CircuitStationActual>>{};
    for (final row in result.stations) {
      grouped.putIfAbsent(row.round, () => []).add(row);
    }
    final rounds = grouped.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.format == 'emom' ? 'EMOM PERFORMANCE' : 'CIRCUIT PERFORMANCE',
          style: CohortTextStyles.sectionLabel,
        ),
        const SizedBox(height: 4),
        Text(
          '${result.recordedCount} of ${result.prescribedCount} stations recorded',
          style: CohortTextStyles.small,
        ),
        if (result.endedEarly) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(
            result.earlyEndReason == null || result.earlyEndReason!.isEmpty
                ? 'Circuit ended early'
                : 'Circuit ended early · ${result.earlyEndReason}',
            style: CohortTextStyles.body,
          ),
        ],
        const SizedBox(height: CohortSpacing.sm),
        for (final round in rounds) ...[
          Text(
            result.format == 'emom' ? 'Minute $round' : 'Round $round',
            style: CohortTextStyles.cardTitle,
          ),
          const SizedBox(height: CohortSpacing.xs),
          for (final row in grouped[round]!)
            _CircuitStationRow(
              row: row,
              onChanged: (next) => onChanged(result.replaceStation(next)),
            ),
          const SizedBox(height: CohortSpacing.sm),
        ],
      ],
    );
  }
}

class _CircuitStationRow extends StatelessWidget {
  const _CircuitStationRow({required this.row, required this.onChanged});

  final CircuitStationActual row;
  final ValueChanged<CircuitStationActual> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.displayName, style: CohortTextStyles.body),
          if (row.primaryMetric == CircuitStationMetric.calories)
            PerformanceNumericField(
              key: ValueKey('circuit-${row.ordinal}-cal'),
              label: 'Calories${row.prescribedCalories == null ? '' : ' / ${row.prescribedCalories} cal'}',
              value: row.calories?.toString() ?? '',
              allowDecimal: true,
              onChanged: (value) {
                final parsed = double.tryParse(value);
                onChanged(
                  row.copyWith(
                    calories: parsed,
                    clearCalories: parsed == null,
                    state: parsed == null
                        ? CircuitOccurrenceState.pending
                        : CircuitOccurrenceState.recorded,
                  ),
                );
              },
            ),
          if (row.primaryMetric == CircuitStationMetric.reps)
            PerformanceNumericField(
              key: ValueKey('circuit-${row.ordinal}-reps'),
              label: 'Reps${row.prescribedReps == null ? '' : ' / ${row.prescribedReps}'}',
              value: row.reps?.toString() ?? '',
              onChanged: (value) {
                final parsed = int.tryParse(value);
                onChanged(
                  row.copyWith(
                    reps: parsed,
                    clearReps: parsed == null,
                    state: parsed == null
                        ? CircuitOccurrenceState.pending
                        : CircuitOccurrenceState.recorded,
                  ),
                );
              },
            ),
          if (row.primaryMetric == CircuitStationMetric.distance) ...[
            PerformanceNumericField(
              key: ValueKey('circuit-${row.ordinal}-distance'),
              label:
                  'Distance (${row.distanceUnit})${row.prescribedDistanceMeters == null && (row.prescribedDistanceText == null || row.prescribedDistanceText!.trim().isEmpty) ? '' : ' / ${row.prescribedDistanceMeters ?? row.prescribedDistanceText} ${row.distanceUnit}'}',
              value: row.distance?.toString() ?? '',
              allowDecimal: true,
              onChanged: (value) {
                final parsed = double.tryParse(value);
                onChanged(
                  row.copyWith(
                    distance: parsed,
                    clearDistance: parsed == null,
                    state: parsed == null && row.load == null
                        ? CircuitOccurrenceState.pending
                        : CircuitOccurrenceState.recorded,
                  ),
                );
              },
            ),
            PerformanceNumericField(
              key: ValueKey('circuit-${row.ordinal}-load'),
              label: 'Load (${row.loadUnit ?? 'kg'})',
              value: row.load?.toString() ?? '',
              allowDecimal: true,
              onChanged: (value) {
                final parsed = double.tryParse(value);
                onChanged(
                  row.copyWith(
                    load: parsed,
                    clearLoad: parsed == null,
                    state: parsed == null && row.distance == null
                        ? CircuitOccurrenceState.pending
                        : CircuitOccurrenceState.recorded,
                  ),
                );
              },
            ),
            PerformanceNumericField(
              key: ValueKey('circuit-${row.ordinal}-time'),
              label: 'Time (sec)',
              value: row.durationSeconds?.toString() ?? '',
              onChanged: (value) {
                final parsed = int.tryParse(value);
                onChanged(
                  row.copyWith(
                    durationSeconds: parsed,
                    clearDuration: parsed == null,
                  ),
                );
              },
            ),
            PerformanceNumericField(
              key: ValueKey('circuit-${row.ordinal}-cal'),
              label: 'Calories',
              value: row.calories?.toString() ?? '',
              allowDecimal: true,
              onChanged: (value) {
                final parsed = double.tryParse(value);
                onChanged(
                  row.copyWith(
                    calories: parsed,
                    clearCalories: parsed == null,
                  ),
                );
              },
            ),
          ],
          if (row.primaryMetric == CircuitStationMetric.completion)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Completed'),
              value: row.state == CircuitOccurrenceState.recorded,
              onChanged: (value) => onChanged(
                row.copyWith(
                  state: value == true
                      ? CircuitOccurrenceState.recorded
                      : CircuitOccurrenceState.pending,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
