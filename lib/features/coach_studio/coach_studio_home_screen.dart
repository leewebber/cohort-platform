import 'package:flutter/material.dart';

import '../admin/protocol_builder_screen.dart';
import '../admin/protocol_drafts_screen.dart';
import '../admin/published_protocols_screen.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import 'models/coach_studio_navigation_state.dart';
import 'models/coach_studio_section.dart';
import 'programmes/programme_catalogue_screen.dart';
import 'programmes/controllers/programme_catalogue_controller.dart';
import 'programmes/services/programme_catalogue_services.dart';

class CoachStudioHomeScreen extends StatefulWidget {
  const CoachStudioHomeScreen({
    super.key,
    this.catalogueController,
    this.openProgrammesDirectly = false,
  });

  final ProgrammeCatalogueController? catalogueController;
  final bool openProgrammesDirectly;

  @override
  State<CoachStudioHomeScreen> createState() => _CoachStudioHomeScreenState();
}

class _CoachStudioHomeScreenState extends State<CoachStudioHomeScreen> {
  late final ProgrammeCatalogueController _catalogueController =
      widget.catalogueController ??
          ProgrammeCatalogueServices.createController();

  @override
  void initState() {
    super.initState();

    if (widget.openProgrammesDirectly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openSection(CoachStudioSection.programmes, replace: true);
      });
    }
  }

  Future<void> _openSection(
    CoachStudioSection section, {
    bool replace = false,
  }) async {
    CoachStudioNavigationState.instance.rememberSection(section);

    if (!section.isAvailableInV01) return;

    final route = switch (section) {
      CoachStudioSection.programmes => MaterialPageRoute(
          builder: (_) => ProgrammeCatalogueScreen(
            controller: _catalogueController,
          ),
        ),
      CoachStudioSection.protocols => MaterialPageRoute(
          builder: (_) => const _ProtocolsHubScreen(),
        ),
      _ => null,
    };

    if (route == null) return;

    if (!mounted) return;

    if (replace) {
      await Navigator.of(context).pushReplacement(route);
    } else {
      await Navigator.of(context).push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastSection = CoachStudioNavigationState.instance.lastSection;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← Back'),
              ),
              const SizedBox(height: CohortSpacing.md),
              const SectionTitle('Coach Studio'),
              const SizedBox(height: CohortSpacing.md),
              const Text('Authoring tools', style: CohortTextStyles.h1),
              const SizedBox(height: CohortSpacing.sm),
              const Text(
                'Build programmes, protocols, and coach content.',
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.xl),
              Expanded(
                child: ListView.separated(
                  itemCount: CoachStudioSection.values.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: CohortSpacing.md),
                  itemBuilder: (context, index) {
                    final section = CoachStudioSection.values[index];
                    final isLastOpened = lastSection == section;
                    final available = section.isAvailableInV01;

                    return CohortCard(
                      onTap: available ? () => _openSection(section) : null,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  section.title,
                                  style: CohortTextStyles.cardTitle.copyWith(
                                    color: available
                                        ? null
                                        : CohortTextStyles.body.color,
                                  ),
                                ),
                                const SizedBox(height: CohortSpacing.xs),
                                Text(
                                  section.subtitle,
                                  style: CohortTextStyles.body,
                                ),
                                if (isLastOpened && available) ...[
                                  const SizedBox(height: CohortSpacing.xs),
                                  Text(
                                    'Last opened',
                                    style: CohortTextStyles.body.copyWith(
                                      color: CohortTextStyles.body.color,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            available ? 'OPEN' : 'SOON',
                            style: CohortTextStyles.body,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtocolsHubScreen extends StatelessWidget {
  const _ProtocolsHubScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← Coach Studio'),
              ),
              const SizedBox(height: CohortSpacing.md),
              const Text('Protocols', style: CohortTextStyles.h1),
              const SizedBox(height: CohortSpacing.xl),
              CohortCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProtocolBuilderScreen(),
                  ),
                ),
                child: const Text('Protocol Builder', style: CohortTextStyles.body),
              ),
              const SizedBox(height: CohortSpacing.md),
              CohortCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProtocolDraftsScreen(),
                  ),
                ),
                child: const Text('Draft Protocols', style: CohortTextStyles.body),
              ),
              const SizedBox(height: CohortSpacing.md),
              CohortCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PublishedProtocolsScreen(),
                  ),
                ),
                child: const Text(
                  'Published Protocols',
                  style: CohortTextStyles.body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
