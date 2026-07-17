import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../diagnostics/training_library_diagnostics.dart';
import '../models/training_library_tab.dart';
import '../widgets/cohort_protocols_tab.dart';
import '../widgets/session_library_tab.dart';

/// Coach Studio Training Library shell (M4).
class TrainingLibraryScreen extends StatefulWidget {
  const TrainingLibraryScreen({
    super.key,
    this.initialTab = TrainingLibraryTab.cohortProtocols,
    this.cohortTab,
    this.sessionTab,
  });

  final TrainingLibraryTab initialTab;
  final Widget? cohortTab;
  final Widget? sessionTab;

  @override
  State<TrainingLibraryScreen> createState() => _TrainingLibraryScreenState();
}

class _TrainingLibraryScreenState extends State<TrainingLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: TrainingLibraryTab.values.length,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
    _tabController.addListener(_onTabChanged);
    TrainingLibraryDiagnostics.log(
      'opened tab=${widget.initialTab.name}',
    );
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      TrainingLibraryDiagnostics.log(
        'opened tab=${TrainingLibraryTab.values[_tabController.index].name}',
      );
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('← Coach Studio'),
                  ),
                  const SizedBox(height: CohortSpacing.md),
                  const Text('Training Library', style: CohortTextStyles.h1),
                  const SizedBox(height: CohortSpacing.sm),
                  const Text(
                    'Browse official Cohort Protocols and manage reusable Sessions.',
                    style: CohortTextStyles.body,
                  ),
                  const SizedBox(height: CohortSpacing.lg),
                  TabBar(
                    controller: _tabController,
                    tabs: TrainingLibraryTab.values
                        .map((tab) => Tab(text: tab.title))
                        .toList(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  widget.cohortTab ?? const CohortProtocolsTab(),
                  widget.sessionTab ?? const SessionLibraryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
