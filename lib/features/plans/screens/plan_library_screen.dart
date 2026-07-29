import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../athlete_profile/models/athlete_profile.dart';
import '../data/plan_catalog.dart';
import '../models/plan.dart';
import '../services/plan_assignment_service.dart';
import '../widgets/plan_widgets.dart';
import 'plan_detail_screen.dart';

class PlanLibraryScreen extends StatefulWidget {
  const PlanLibraryScreen({super.key, this.athleteId});

  final String? athleteId;

  @override
  State<PlanLibraryScreen> createState() => _PlanLibraryScreenState();
}

class _PlanLibraryScreenState extends State<PlanLibraryScreen> {
  PlanLibraryFilters _filters = const PlanLibraryFilters();

  List<Plan> get _plans => _filters.apply(PlanCatalog.published);

  Future<void> _openPlan(Plan plan) async {
    final started = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlanDetailScreen(
          plan: plan,
          athleteId: widget.athleteId,
        ),
      ),
    );
    if (started == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CohortColors.background,
      appBar: AppBar(
        backgroundColor: CohortColors.background,
        elevation: 0,
        title: const Text('PLANS', style: CohortTextStyles.eyebrow),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CohortSpacing.xl,
                CohortSpacing.md,
                CohortSpacing.xl,
                CohortSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose your plan', style: CohortTextStyles.h1),
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    'Pick a coaching product. Cohort personalises every session.',
                    style: CohortTextStyles.body,
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: CohortSpacing.xl,
              ),
              child: Row(
                children: [
                  PlanFilterChip(
                    label: 'All',
                    selected: _filters.isEmpty,
                    onSelected: (_) => setState(() {
                      _filters = const PlanLibraryFilters();
                    }),
                  ),
                  PlanFilterChip(
                    key: const Key('plan_filter_beginner'),
                    label: 'Beginner',
                    selected: _filters.difficulty == PlanDifficulty.beginner,
                    onSelected: (selected) => setState(() {
                      _filters = selected
                          ? _filters.copyWith(
                              difficulty: PlanDifficulty.beginner,
                            )
                          : _filters.copyWith(clearDifficulty: true);
                    }),
                  ),
                  for (final goal in AthleteGoalCatalog.options)
                    PlanFilterChip(
                      label: goal.label,
                      selected: _filters.goalId == goal.id,
                      onSelected: (selected) => setState(() {
                        _filters = selected
                            ? _filters.copyWith(goalId: goal.id)
                            : _filters.copyWith(clearGoal: true);
                      }),
                    ),
                  PlanFilterChip(
                    label: '3 days',
                    selected: _filters.daysPerWeek == 3,
                    onSelected: (selected) => setState(() {
                      _filters = selected
                          ? _filters.copyWith(daysPerWeek: 3)
                          : _filters.copyWith(clearDays: true);
                    }),
                  ),
                  PlanFilterChip(
                    label: '4 days',
                    selected: _filters.daysPerWeek == 4,
                    onSelected: (selected) => setState(() {
                      _filters = selected
                          ? _filters.copyWith(daysPerWeek: 4)
                          : _filters.copyWith(clearDays: true);
                    }),
                  ),
                  PlanFilterChip(
                    label: '≤45 min',
                    selected: _filters.maxDurationMinutes == 45,
                    onSelected: (selected) => setState(() {
                      _filters = selected
                          ? _filters.copyWith(maxDurationMinutes: 45)
                          : _filters.copyWith(clearDuration: true);
                    }),
                  ),
                  PlanFilterChip(
                    label: 'Home',
                    selected: _filters.equipmentPresetId == 'home_gym',
                    onSelected: (selected) => setState(() {
                      _filters = selected
                          ? _filters.copyWith(equipmentPresetId: 'home_gym')
                          : _filters.copyWith(clearEquipment: true);
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CohortSpacing.md),
            Expanded(
              child: _plans.isEmpty
                  ? Center(
                      child: Text(
                        'No plans match these filters.',
                        style: CohortTextStyles.body,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        CohortSpacing.xl,
                        0,
                        CohortSpacing.xl,
                        CohortSpacing.xl,
                      ),
                      itemCount: _plans.length,
                      itemBuilder: (context, index) {
                        final plan = _plans[index];
                        return PlanCard(
                          plan: plan,
                          onTap: () => _openPlan(plan),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
