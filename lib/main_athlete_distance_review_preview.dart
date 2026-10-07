import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'features/performance_tracking/distance_history_screen.dart';
import 'internal_review/athlete_distance/synthetic_distance_history.dart';

/// Loopback-only synthetic preview, no Supabase initialisation or live network.
void main() => runApp(const AthleteDistanceReviewPreview());

class AthleteDistanceReviewPreview extends StatefulWidget {
  const AthleteDistanceReviewPreview({super.key});
  @override
  State<AthleteDistanceReviewPreview> createState() => _PreviewState();
}

class _PreviewState extends State<AthleteDistanceReviewPreview> {
  final source = SyntheticDistanceHistory();
  late final controller = source.controller();
  bool large = false;
  @override
  void dispose() {
    source.changes.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Synthetic athlete distance review',
    theme: cohortTheme,
    debugShowCheckedModeBanner: false,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      const Text(
                        'Synthetic evidence — internal visual review only. Approved profile; no real athlete data or release.',
                      ),
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => large = !large),
                            child: Text(
                              large ? 'Standard text' : 'Large text (200%)',
                            ),
                          ),
                          TextButton(
                            onPressed: source.signOut,
                            child: const Text('Simulate sign-out'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(child: DistanceHistoryScreen(controller: controller)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
