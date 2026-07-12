import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import '../../models/protocol_draft_summary.dart';
import 'protocol_builder_screen.dart';
import 'services/protocol_builder_service.dart';

/// Lists published protocols for Coach Studio editing.
class PublishedProtocolsScreen extends StatefulWidget {
  const PublishedProtocolsScreen({super.key});

  @override
  State<PublishedProtocolsScreen> createState() =>
      _PublishedProtocolsScreenState();
}

class _PublishedProtocolsScreenState extends State<PublishedProtocolsScreen> {
  final _builderService = ProtocolBuilderService();

  late Future<List<ProtocolDraftSummary>> _protocolsFuture;

  @override
  void initState() {
    super.initState();
    _reloadProtocols();
  }

  void _reloadProtocols() {
    setState(() {
      _protocolsFuture = _builderService.getPublishedProtocols();
    });
  }

  void _openProtocol(ProtocolDraftSummary protocol) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ProtocolBuilderScreen(
              protocolId: protocol.protocolId,
            ),
          ),
        )
        .then((_) => _reloadProtocols());
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
                'Published Protocols',
                style: CohortTextStyles.h1,
              ),
              const SizedBox(height: CohortSpacing.sm),
              const Text(
                'Browse and edit live protocols available to athletes.',
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.xl),
              Expanded(
                child: FutureBuilder<List<ProtocolDraftSummary>>(
                  future: _protocolsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Text(
                          'Loading published protocols...',
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
                              : 'We could not load published protocols right now.',
                          style: CohortTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final protocols = snapshot.data ?? [];

                    if (protocols.isEmpty) {
                      return const Center(
                        child: Text(
                          'No published protocols yet.',
                          style: CohortTextStyles.body,
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: protocols.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: CohortSpacing.md),
                      itemBuilder: (context, index) {
                        final protocol = protocols[index];
                        final subtitleParts = <String>[
                          protocol.protocolId,
                          if (protocol.sessionType != null &&
                              protocol.sessionType!.trim().isNotEmpty)
                            protocol.sessionType!,
                          if (protocol.durationMin != null)
                            '${protocol.durationMin} min',
                        ];

                        return CohortCard(
                          onTap: () => _openProtocol(protocol),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      protocol.name,
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
                                'PUBLISHED',
                                style: CohortTextStyles.eyebrow.copyWith(
                                  color: CohortColors.success,
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
