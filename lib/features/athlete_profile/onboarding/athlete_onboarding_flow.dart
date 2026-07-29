import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../models/athlete_profile.dart';
import '../services/athlete_programme_generation_service.dart';
import 'athlete_onboarding_draft.dart';
import 'athlete_onboarding_widgets.dart';

/// Linear athlete introduction → Coach Brain programme generation → Home.
class AthleteOnboardingFlow extends StatefulWidget {
  const AthleteOnboardingFlow({
    super.key,
    this.athleteId,
    this.initialDisplayName,
    this.generationService,
    this.onCompleted,
  });

  final String? athleteId;
  final String? initialDisplayName;
  final AthleteProgrammeGenerationService? generationService;
  final VoidCallback? onCompleted;

  @override
  State<AthleteOnboardingFlow> createState() => _AthleteOnboardingFlowState();
}

class _AthleteOnboardingFlowState extends State<AthleteOnboardingFlow> {
  static const _stepCount = 5;

  late AthleteOnboardingDraft _draft;
  late final TextEditingController _nameController;
  late final AthleteProgrammeGenerationService _generation =
      widget.generationService ?? AthleteProgrammeGenerationService();
  String? _error;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _draft = AthleteOnboardingDraft(
      displayName: widget.initialDisplayName?.trim() ?? '',
    );
    _nameController = TextEditingController(text: _draft.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _athleteId =>
      widget.athleteId ??
      'athlete.local.${DateTime.now().toUtc().millisecondsSinceEpoch}';

  void _go(AthleteOnboardingStep step) {
    setState(() {
      _error = null;
      _draft = _draft.copyWith(step: step);
    });
  }

  Future<void> _generateAndFinish() async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _error = null;
      _draft = _draft.copyWith(step: AthleteOnboardingStep.generating);
    });

    try {
      final profile = _draft.toProfile(athleteId: _athleteId);
      await _generation.generate(profile);
      if (!mounted) return;
      widget.onCompleted?.call();
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = error.toString();
        _draft = _draft.copyWith(step: AthleteOnboardingStep.assessment);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_draft.step) {
      AthleteOnboardingStep.welcome => AthleteOnboardingScaffold(
        stepIndex: 0,
        stepCount: _stepCount,
        title: 'Welcome to Cohort',
        subtitle:
            'Introduce yourself. We\'ll build training that belongs to you.',
        primaryLabel: 'CONTINUE',
        primaryEnabled: _draft.canContinueFromWelcome,
        onPrimary: () => _go(AthleteOnboardingStep.goal),
        child: TextField(
          key: const Key('onboarding_display_name'),
          controller: _nameController,
          style: CohortTextStyles.h2.copyWith(color: CohortColors.textPrimary),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'What should we call you?',
            hintStyle: CohortTextStyles.body,
            filled: true,
            fillColor: CohortColors.surfaceRaised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CohortColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CohortColors.border),
            ),
          ),
          onChanged: (value) => setState(() {
            _draft = _draft.copyWith(displayName: value);
          }),
        ),
      ),
      AthleteOnboardingStep.goal => AthleteOnboardingScaffold(
        stepIndex: 1,
        stepCount: _stepCount,
        title: 'What are you training for?',
        subtitle: 'Choose one primary focus. You can refine this later.',
        primaryLabel: 'CONTINUE',
        primaryEnabled: _draft.canContinueFromGoal,
        onBack: () => _go(AthleteOnboardingStep.welcome),
        onPrimary: () => _go(AthleteOnboardingStep.equipment),
        child: Column(
          children: [
            for (final goal in AthleteGoalCatalog.options)
              AthleteChoiceCard(
                title: goal.label,
                description: goal.description,
                selected: _draft.primaryGoal?.id == goal.id,
                onTap: () => setState(() {
                  _draft = _draft.copyWith(primaryGoal: goal);
                }),
              ),
          ],
        ),
      ),
      AthleteOnboardingStep.equipment => AthleteOnboardingScaffold(
        stepIndex: 2,
        stepCount: _stepCount,
        title: 'Where will you train?',
        subtitle: 'Select every environment you can use this week.',
        primaryLabel: 'CONTINUE',
        primaryEnabled: _draft.canContinueFromEquipment,
        onBack: () => _go(AthleteOnboardingStep.goal),
        onPrimary: () => _go(AthleteOnboardingStep.availability),
        child: Column(
          children: [
            for (final preset in AthleteEquipmentCatalog.options)
              AthleteChoiceCard(
                title: preset.label,
                description: preset.description,
                selected: _draft.selectedEquipmentPresetIds.contains(preset.id),
                onTap: () => setState(() {
                  final next = {..._draft.selectedEquipmentPresetIds};
                  if (next.contains(preset.id)) {
                    next.remove(preset.id);
                  } else {
                    next.add(preset.id);
                  }
                  _draft = _draft.copyWith(selectedEquipmentPresetIds: next);
                }),
              ),
          ],
        ),
      ),
      AthleteOnboardingStep.availability => AthleteOnboardingScaffold(
        stepIndex: 3,
        stepCount: _stepCount,
        title: 'How often can you train?',
        subtitle: 'Only two decisions — keep it honest.',
        primaryLabel: 'CONTINUE',
        primaryEnabled: _draft.canContinueFromAvailability,
        onBack: () => _go(AthleteOnboardingStep.equipment),
        onPrimary: () => _go(AthleteOnboardingStep.assessment),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DAYS PER WEEK', style: CohortTextStyles.sectionLabel),
            const SizedBox(height: CohortSpacing.sm),
            Wrap(
              spacing: CohortSpacing.sm,
              runSpacing: CohortSpacing.sm,
              children: [
                for (final days in const [2, 3, 4, 5, 6])
                  ChoiceChip(
                    label: Text('$days'),
                    selected: _draft.trainingDaysPerWeek == days,
                    onSelected: (_) => setState(() {
                      _draft = _draft.copyWith(trainingDaysPerWeek: days);
                    }),
                    selectedColor: CohortColors.phosphorDeep,
                    labelStyle: TextStyle(
                      color: _draft.trainingDaysPerWeek == days
                          ? const Color(0xFF0C0E0B)
                          : CohortColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: CohortColors.surfaceRaised,
                  ),
              ],
            ),
            const SizedBox(height: CohortSpacing.xl),
            Text('SESSION LENGTH', style: CohortTextStyles.sectionLabel),
            const SizedBox(height: CohortSpacing.sm),
            Wrap(
              spacing: CohortSpacing.sm,
              runSpacing: CohortSpacing.sm,
              children: [
                for (final minutes in const [30, 45, 60, 75])
                  ChoiceChip(
                    label: Text('$minutes min'),
                    selected:
                        _draft.preferredSessionDurationMinutes == minutes,
                    onSelected: (_) => setState(() {
                      _draft = _draft.copyWith(
                        preferredSessionDurationMinutes: minutes,
                      );
                    }),
                    selectedColor: CohortColors.phosphorDeep,
                    labelStyle: TextStyle(
                      color: _draft.preferredSessionDurationMinutes == minutes
                          ? const Color(0xFF0C0E0B)
                          : CohortColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: CohortColors.surfaceRaised,
                  ),
              ],
            ),
          ],
        ),
      ),
      AthleteOnboardingStep.assessment => AthleteOnboardingScaffold(
        stepIndex: 4,
        stepCount: _stepCount,
        title: 'Where are you starting?',
        subtitle:
            'A light check-in — deeper assessments can happen later with your coach.',
        primaryLabel: 'GENERATE MY PROGRAMME',
        primaryEnabled: _draft.canContinueFromAssessment && !_generating,
        onBack: () => _go(AthleteOnboardingStep.availability),
        onPrimary: _generateAndFinish,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final level in AthleteExperienceLevel.values)
              AthleteChoiceCard(
                title: _experienceLabel(level),
                description: _experienceDescription(level),
                selected: _draft.experienceLevel == level,
                onTap: () => setState(() {
                  _draft = _draft.copyWith(experienceLevel: level);
                }),
              ),
            const SizedBox(height: CohortSpacing.md),
            Text('CURRENT ACTIVITY (OPTIONAL)', style: CohortTextStyles.sectionLabel),
            const SizedBox(height: CohortSpacing.sm),
            TextField(
              key: const Key('onboarding_activity'),
              style: CohortTextStyles.body.copyWith(
                color: CohortColors.textPrimary,
              ),
              maxLines: 2,
              inputFormatters: [LengthLimitingTextInputFormatter(120)],
              decoration: InputDecoration(
                hintText: 'e.g. Recreational running 2× / week',
                hintStyle: CohortTextStyles.body,
                filled: true,
                fillColor: CohortColors.surfaceRaised,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: CohortColors.border),
                ),
              ),
              onChanged: (value) => setState(() {
                _draft = _draft.copyWith(currentActivity: value);
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: CohortSpacing.lg),
              Text(
                _error!,
                style: CohortTextStyles.small.copyWith(
                  color: CohortColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
      AthleteOnboardingStep.generating => Scaffold(
        backgroundColor: CohortColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(CohortSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  'Generating Your Programme',
                  style: CohortTextStyles.h1,
                ),
                const SizedBox(height: CohortSpacing.lg),
                Text(
                  'Cohort is building today\'s training from your goals, '
                  'equipment, and starting point.',
                  style: CohortTextStyles.body,
                ),
                const SizedBox(height: CohortSpacing.xxl),
                const LinearProgressIndicator(
                  color: CohortColors.phosphor,
                  backgroundColor: CohortColors.surfaceRaised,
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    };
  }

  String _experienceLabel(AthleteExperienceLevel level) {
    return switch (level) {
      AthleteExperienceLevel.beginner => 'Beginner',
      AthleteExperienceLevel.intermediate => 'Intermediate',
      AthleteExperienceLevel.advanced => 'Advanced',
    };
  }

  String _experienceDescription(AthleteExperienceLevel level) {
    return switch (level) {
      AthleteExperienceLevel.beginner =>
        'New to structured training or returning after a long break.',
      AthleteExperienceLevel.intermediate =>
        'Consistent training with room to sharpen strengths and gaps.',
      AthleteExperienceLevel.advanced =>
        'Experienced athlete with solid base and higher training demand.',
    };
  }
}
