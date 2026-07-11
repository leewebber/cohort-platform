import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import '../../models/protocol_draft_summary.dart';
import 'protocol_builder_screen.dart';
import 'services/protocol_builder_service.dart';

/// Lists unpublished protocol drafts for Coach Studio.
class ProtocolDraftsScreen extends StatefulWidget {
  const ProtocolDraftsScreen({super.key});

  @override
  State<ProtocolDraftsScreen> createState() => _ProtocolDraftsScreenState();
}

class _ProtocolDraftsScreenState extends State<ProtocolDraftsScreen> {
  final _builderService = ProtocolBuilderService();

  late Future<List<ProtocolDraftSummary>> _draftsFuture;

  @override
  void initState() {
    super.initState();
    _reloadDrafts();
  }

  void _reloadDrafts() {
    setState(() {
      _draftsFuture = _builderService.getDraftProtocols();
    });
  }

  void _openDraft(ProtocolDraftSummary draft) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ProtocolBuilderScreen(
              protocolId: draft.protocolId,
            ),
          ),
        )
        .then((_) => _reloadDrafts());
  }

  void _openNewDraft() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const ProtocolBuilderScreen(),
          ),
        )
        .then((_) => _reloadDrafts());
  }

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
                child: const Text('← Back'),
              ),
              const SizedBox(height: CohortSpacing.md),
              const SectionTitle('Coach Studio'),
              const SizedBox(height: CohortSpacing.md),
              const Text(
                'Draft Protocols',
                style: CohortTextStyles.h1,
              ),
              const SizedBox(height: CohortSpacing.sm),
              const Text(
                'Unpublished protocols saved from Protocol Builder.',
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.xl),
              Expanded(
                child: FutureBuilder<List<ProtocolDraftSummary>>(
                  future: _draftsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Text(
                          'Loading drafts...',
                          style: CohortTextStyles.body,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          snapshot.error is ProtocolBuilderException
                              ? (snapshot.error! as ProtocolBuilderException)
                                  .message
                              : 'We could not load drafts right now.',
                          style: CohortTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final drafts = snapshot.data ?? [];

                    if (drafts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'No draft protocols yet.',
                              style: CohortTextStyles.body,
                            ),
                            const SizedBox(height: CohortSpacing.md),
                            TextButton(
                              onPressed: _openNewDraft,
                              child: Text(
                                'Create a protocol',
                                style: CohortTextStyles.body.copyWith(
                                  color: CohortColors.olive,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: drafts.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: CohortSpacing.md),
                      itemBuilder: (context, index) {
                        final draft = drafts[index];
                        final subtitleParts = <String>[
                          draft.protocolId,
                          if (draft.sessionType != null &&
                              draft.sessionType!.trim().isNotEmpty)
                            draft.sessionType!,
                          if (draft.durationMin != null)
                            '${draft.durationMin} min',
                        ];

                        return CohortCard(
                          onTap: () => _openDraft(draft),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      draft.name,
                                      style: CohortTextStyles.cardTitle,
                                    ),
                                    const SizedBox(height: CohortSpacing.sm),
                                    Text(
                                      subtitleParts.join(' · '),
                                      style: CohortTextStyles.small,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: CohortSpacing.lg),
                              Text(
                                'DRAFT',
                                style: CohortTextStyles.eyebrow.copyWith(
                                  color: CohortColors.warning,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
