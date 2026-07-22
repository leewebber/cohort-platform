import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../programme/models/programme_catalog_entry.dart';
import '../controllers/personal_training_setup_controller.dart';
import '../services/personal_training_setup_services.dart';

class PersonalTrainingSetupScreen extends StatefulWidget {
  const PersonalTrainingSetupScreen({
    super.key,
    PersonalTrainingSetupController? controller,
  }) : _controller = controller;

  final PersonalTrainingSetupController? _controller;

  @override
  State<PersonalTrainingSetupScreen> createState() =>
      _PersonalTrainingSetupScreenState();
}

class _PersonalTrainingSetupScreenState extends State<PersonalTrainingSetupScreen> {
  late final PersonalTrainingSetupController _controller =
      widget._controller ??
      PersonalTrainingSetupController(
        service: PersonalTrainingSetupServices.createService(),
      );

  DateTime _startDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _confirmAssignment() async {
    if (_isSubmitting || _controller.selectedProgramme == null) return;

    var replaceExisting = _controller.hasActiveAssignment;
    if (replaceExisting) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace active programme?'),
          content: const Text(
            'Starting a new programme will replace your current active assignment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace programme'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isSubmitting = true);
    final success = await _controller.assignSelected(
      startDate: _startDate,
      timezone: DateTime.now().timeZoneName,
      replaceExisting: replaceExisting,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← Back'),
              ),
              Text('Choose programme', style: CohortTextStyles.h1),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'Select a published programme and start date for your training.',
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.textSecondary,
                ),
              ),
              const SizedBox(height: CohortSpacing.lg),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_controller.status) {
      case PersonalTrainingSetupStatus.loading:
      case PersonalTrainingSetupStatus.assigning:
        return const Center(
          child: Text('Loading programmes...', style: CohortTextStyles.body),
        );
      case PersonalTrainingSetupStatus.error:
        return _buildMessageCard(
          title: 'Could not load programmes',
          message: _controller.errorMessage ??
              'Check your connection and try again.',
        );
      case PersonalTrainingSetupStatus.empty:
        return _buildMessageCard(
          title: 'No published programmes yet',
          message:
              'Publish a programme from Coach Studio before setting up training.',
        );
      case PersonalTrainingSetupStatus.ready:
        return _buildReadyContent();
    }
  }

  Widget _buildMessageCard({
    required String title,
    required String message,
  }) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: CohortTextStyles.cardTitle),
          const SizedBox(height: CohortSpacing.sm),
          Text(message, style: CohortTextStyles.body),
        ],
      ),
    );
  }

  Widget _buildReadyContent() {
    final selected = _controller.selectedProgramme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_controller.hasActiveAssignment) ...[
            CohortCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current programme', style: CohortTextStyles.cardTitle),
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    _controller.currentAssignment?.lineageCode ??
                        'Active programme',
                    style: CohortTextStyles.body,
                  ),
                ],
              ),
            ),
            const SizedBox(height: CohortSpacing.md),
          ],
          Text('Published programmes', style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.md),
          for (final entry in _controller.programmes) ...[
            _ProgrammeChoiceCard(
              entry: entry,
              selected: entry.versionId == selected?.versionId,
              onTap: () => _controller.selectProgramme(entry),
            ),
            const SizedBox(height: CohortSpacing.sm),
          ],
          if (selected != null) ...[
            const SizedBox(height: CohortSpacing.lg),
            CohortCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Review assignment', style: CohortTextStyles.cardTitle),
                  const SizedBox(height: CohortSpacing.md),
                  Text(selected.name, style: CohortTextStyles.h2),
                  const SizedBox(height: CohortSpacing.xs),
                  Text(
                    'Version ${selected.versionNumber}',
                    style: CohortTextStyles.body,
                  ),
                  if (selected.durationWeeks != null) ...[
                    const SizedBox(height: CohortSpacing.xs),
                    Text(
                      '${selected.durationWeeks} weeks',
                      style: CohortTextStyles.small,
                    ),
                  ],
                  if (selected.primaryGoal?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: CohortSpacing.sm),
                    Text(
                      selected.primaryGoal!.trim(),
                      style: CohortTextStyles.body,
                    ),
                  ],
                  if (selected.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: CohortSpacing.sm),
                    Text(
                      selected.description!.trim(),
                      style: CohortTextStyles.small,
                    ),
                  ],
                  const SizedBox(height: CohortSpacing.md),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start date'),
                    subtitle: Text(
                      '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _pickStartDate,
                  ),
                  if (_controller.hasActiveAssignment) ...[
                    const SizedBox(height: CohortSpacing.sm),
                    Text(
                      'Confirming will replace your current active programme.',
                      style: CohortTextStyles.small.copyWith(
                        color: CohortColors.warning,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_controller.errorMessage != null) ...[
              const SizedBox(height: CohortSpacing.sm),
              Text(
                _controller.errorMessage!,
                style: CohortTextStyles.body.copyWith(color: CohortColors.warning),
              ),
            ],
            const SizedBox(height: CohortSpacing.lg),
            CohortButton(
              label: _isSubmitting ? 'Assigning…' : 'Confirm assignment',
              onPressed: _isSubmitting ? () {} : _confirmAssignment,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgrammeChoiceCard extends StatelessWidget {
  const _ProgrammeChoiceCard({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final ProgrammeCatalogEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: CohortTextStyles.cardTitle),
                const SizedBox(height: CohortSpacing.xs),
                Text(
                  'Version ${entry.versionNumber}',
                  style: CohortTextStyles.small,
                ),
                if (entry.durationWeeks != null)
                  Text(
                    '${entry.durationWeeks} weeks',
                    style: CohortTextStyles.small,
                  ),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: CohortColors.success),
        ],
      ),
    );
  }
}
