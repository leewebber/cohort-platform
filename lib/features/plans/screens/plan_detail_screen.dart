import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../models/plan.dart';
import '../services/plan_start_service.dart';

class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({
    super.key,
    required this.plan,
    this.startService,
    this.athleteId,
  });

  final Plan plan;
  final PlanStartService? startService;
  final String? athleteId;

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  bool _starting = false;
  String? _error;

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      final athleteId =
          widget.athleteId ??
          AthleteProfileSession.profile?.athleteId ??
          'athlete.local.${DateTime.now().toUtc().millisecondsSinceEpoch}';

      final service = widget.startService ?? PlanStartService();
      await service.startPlan(
        planId: widget.plan.planId,
        athleteId: athleteId,
        existingProfile: AthleteProfileSession.profile,
        displayName: AthleteProfileSession.profile?.displayName,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;

    return Scaffold(
      backgroundColor: CohortColors.background,
      appBar: AppBar(
        backgroundColor: CohortColors.background,
        elevation: 0,
        title: Text('PLAN', style: CohortTextStyles.eyebrow),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  CohortSpacing.xl,
                  CohortSpacing.md,
                  CohortSpacing.xl,
                  CohortSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            plan.colourTheme.withValues(alpha: 0.55),
                            CohortColors.surfaceRaised,
                          ],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.terrain_rounded,
                        size: 56,
                        color: CohortColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: CohortSpacing.xl),
                    Text(plan.name, style: CohortTextStyles.h1),
                    const SizedBox(height: CohortSpacing.sm),
                    Text(plan.subtitle, style: CohortTextStyles.body),
                    const SizedBox(height: CohortSpacing.xl),
                    _Section(title: 'Overview', body: plan.description),
                    _Section(title: 'Who it\'s for', body: plan.whoItsFor),
                    _Section(
                      title: 'What you\'ll improve',
                      body: plan.whatYouImprove.map((e) => '· $e').join('\n'),
                    ),
                    _Section(
                      title: 'Requirements',
                      body:
                          '${plan.difficultyLabel} · ${plan.daysLabel} · '
                          '${plan.durationLabel}\n${plan.equipmentSummary}',
                    ),
                    _Section(
                      title: 'Typical week',
                      body: plan.typicalWeekSummary,
                    ),
                    if (plan.faqs.isNotEmpty) ...[
                      Text('FAQs', style: CohortTextStyles.sectionLabel),
                      const SizedBox(height: CohortSpacing.md),
                      for (final faq in plan.faqs) ...[
                        Text(
                          faq.question,
                          style: CohortTextStyles.cardTitle,
                        ),
                        const SizedBox(height: CohortSpacing.xs),
                        Text(faq.answer, style: CohortTextStyles.body),
                        const SizedBox(height: CohortSpacing.lg),
                      ],
                    ],
                    if (_error != null)
                      Text(
                        _error!,
                        style: CohortTextStyles.small.copyWith(
                          color: CohortColors.danger,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CohortSpacing.xl,
                CohortSpacing.md,
                CohortSpacing.xl,
                CohortSpacing.xl,
              ),
              child: CohortButton(
                label: _starting ? 'STARTING…' : 'START THIS PLAN',
                showTrailingArrow: true,
                onPressed: _starting ? () {} : _start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: CohortTextStyles.sectionLabel),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            body,
            style: CohortTextStyles.body.copyWith(
              color: CohortColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
