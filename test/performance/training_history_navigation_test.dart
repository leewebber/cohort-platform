import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/screens/training_history_screen.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Training History exposes AppBar back affordance in all states', (
    tester,
  ) async {
    final coordinator = PerformanceRecordSaveCoordinator(
      store: InMemoryPerformanceRecordStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrainingHistoryScreen(
                          athleteId: 'athlete-1',
                          saveCoordinator: coordinator,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open history'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open history'));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Training History'), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Open history'), findsOneWidget);
  });
}
