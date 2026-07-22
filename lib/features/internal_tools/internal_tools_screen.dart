import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import '../admin/admin_protocol_editor_screen.dart';
import '../auth/services/current_user_session.dart';
import 'internal_tools_debug_actions.dart';

/// Engineering-only actions moved off the production Home screen.
class InternalToolsScreen extends StatefulWidget {
  const InternalToolsScreen({super.key});

  @override
  State<InternalToolsScreen> createState() => _InternalToolsScreenState();
}

class _InternalToolsScreenState extends State<InternalToolsScreen> {
  String get _athleteId => CurrentUserSession.requireInstance.athleteId;

  Future<void> _run(String label, Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label completed')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← Back'),
              ),
              const SectionTitle('Internal tools'),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'Engineering-only utilities. Requires explicit opt-in via '
                'ENABLE_INTERNAL_TOOLS.',
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.lg),
              _toolCard(
                title: 'Admin Protocol Editor',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminProtocolEditorScreen(),
                    ),
                  );
                },
              ),
              _toolCard(
                title: 'Analyze Current Protocol',
                onTap: () => _run(
                  'Analyze current protocol',
                  () => InternalToolsDebugActions.analyzeCurrentProtocol(
                    athleteId: _athleteId,
                  ),
                ),
              ),
              _toolCard(
                title: 'Compare BW-001 Similarity',
                onTap: () => _run(
                  'Compare BW-001 similarity',
                  InternalToolsDebugActions.compareBw001Similarity,
                ),
              ),
              _toolCard(
                title: 'Compile RN-006 Interval Plan',
                onTap: () => _run(
                  'Compile RN-006 interval plan',
                  InternalToolsDebugActions.compileRn006IntervalPlan,
                ),
              ),
              _toolCard(
                title: 'Compile Circuit Debug Plans',
                onTap: () => _run(
                  'Compile circuit debug plans',
                  InternalToolsDebugActions.compileCircuitDebugPlans,
                ),
              ),
              _toolCard(
                title: 'Compare BW-001 Suitable Alternatives',
                onTap: () => _run(
                  'Compare suitable alternatives',
                  () => InternalToolsDebugActions.compareBw001SuitableAlternatives(
                    athleteId: _athleteId,
                  ),
                ),
              ),
              _toolCard(
                title: 'Assign Test Programme',
                onTap: () => _run(
                  'Assign test programme',
                  () => InternalToolsDebugActions.assignTestProgramme(
                    athleteId: _athleteId,
                  ),
                ),
              ),
              _toolCard(
                title: 'Resolve Test Programme',
                onTap: () => _run(
                  'Resolve test programme',
                  () => InternalToolsDebugActions.resolveTestProgramme(
                    athleteId: _athleteId,
                  ),
                ),
              ),
              _toolCard(
                title: 'Sync Resolved Session',
                onTap: () => _run(
                  'Sync resolved session',
                  () => InternalToolsDebugActions.syncResolvedSession(
                    athleteId: _athleteId,
                  ),
                ),
              ),
              _toolCard(
                title: 'Complete Current Programme Slot',
                onTap: () => _run(
                  'Complete current programme slot',
                  () => InternalToolsDebugActions.completeCurrentProgrammeSlot(
                    athleteId: _athleteId,
                    partial: false,
                  ),
                ),
              ),
              _toolCard(
                title: 'Complete Current Slot Partial',
                onTap: () => _run(
                  'Complete current slot partial',
                  () => InternalToolsDebugActions.completeCurrentProgrammeSlot(
                    athleteId: _athleteId,
                    partial: true,
                  ),
                ),
              ),
              _toolCard(
                title: 'Reset Test Programme Assignment',
                onTap: () => _run(
                  'Reset test programme assignment',
                  () => InternalToolsDebugActions.resetTestProgrammeAssignment(
                    athleteId: _athleteId,
                  ),
                ),
              ),
              _toolCard(
                title: 'Install Founder Acceptance Programme',
                onTap: () => _run(
                  'Install founder acceptance programme',
                  InternalToolsDebugActions.installFounderAcceptanceProgramme,
                ),
              ),
              _toolCard(
                title: 'Assign Founder Acceptance Programme',
                onTap: () => _run(
                  'Assign founder acceptance programme',
                  () => InternalToolsDebugActions.assignFounderAcceptanceProgramme(
                    athleteId: _athleteId,
                  ),
                ),
              ),
              _toolCard(
                title: 'Resolve Founder Acceptance Programme',
                onTap: () => _run(
                  'Resolve founder acceptance programme',
                  () => InternalToolsDebugActions.resolveFounderAcceptanceProgramme(
                    athleteId: _athleteId,
                  ),
                ),
              ),
              _toolCard(
                title: 'Reset Founder Acceptance Programme',
                onTap: () => _run(
                  'Reset founder acceptance programme',
                  () => InternalToolsDebugActions
                      .resetFounderAcceptanceProgrammeAssignment(
                    athleteId: _athleteId,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolCard({
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: CohortCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: CohortTextStyles.cardTitle),
            ),
            Text('RUN', style: CohortTextStyles.eyebrow),
          ],
        ),
      ),
    );
  }
}
