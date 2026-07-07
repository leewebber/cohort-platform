import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/filter_selection_sheet.dart';
import '../../core/widgets/filter_selector.dart';
import '../../core/widgets/protocol_card.dart';
import '../../core/widgets/search_bar.dart';
import '../../core/widgets/section_title.dart';
import '../../data/repositories/protocol_repository.dart';
import '../../models/protocol.dart';
import '../../models/protocol_filtering.dart';
import '../../models/protocol_filters.dart';
import 'protocol_detail/protocol_detail_screen.dart';

class ProtocolLibraryScreen extends StatefulWidget {
  const ProtocolLibraryScreen({super.key});

  @override
  State<ProtocolLibraryScreen> createState() =>
      _ProtocolLibraryScreenState();
}

class _ProtocolLibraryScreenState
    extends State<ProtocolLibraryScreen> {
  final ProtocolRepository _repository = ProtocolRepository();

  late Future<List<Protocol>> _protocolsFuture;
  late Future<List<String>> _goalsFuture;

  String _search = '';
  ProtocolFilters _filters = ProtocolFilters.empty;

  @override
  void initState() {
    super.initState();
    _protocolsFuture = _repository.getProtocols();
    _goalsFuture = _repository.getGoals();
  }

  void _openGoalFilter(List<String> goals) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CohortColors.surfaceRaised,
      isScrollControlled: true,
      builder: (_) => FilterSelectionSheet(
        title: 'Goal',
        items: goals,
        selectedValue: _filters.goal,
        onSelected: (value) {
          setState(() {
            _filters = ProtocolFilters(
              goal: value,
              equipment: _filters.equipment,
              capability: _filters.capability,
              demand: _filters.demand,
              recovery: _filters.recovery,
            );
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Protocol>>(
          future: _protocolsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(snapshot.error.toString()),
              );
            }

            final protocols = filterProtocols(
              protocols: snapshot.data ?? [],
              search: _search,
              filters: _filters,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context),
                    child: const Text('← Back'),
                  ),

                  const SizedBox(
                    height: CohortSpacing.md,
                  ),

                  const SectionTitle('FIELD MANUAL'),

                  const SizedBox(
                    height: CohortSpacing.sm,
                  ),

                  const Text(
                    'Protocol Library',
                    style: CohortTextStyles.h1,
                  ),

                  const SizedBox(
                    height: CohortSpacing.md,
                  ),

                  const Text(
                    'Search and discover training protocols.',
                    style: CohortTextStyles.body,
                  ),

                  const SizedBox(
                    height: CohortSpacing.xl,
                  ),

                  CohortSearchBar(
                    onChanged: (value) {
                      setState(() {
                        _search = value;
                      });
                    },
                  ),

                  const SizedBox(
                    height: CohortSpacing.lg,
                  ),

                  FutureBuilder<List<String>>(
                    future: _goalsFuture,
                    builder: (context, goalSnapshot) {
                      return FilterSelector(
                        title: 'Goal',
                        value: _filters.goal ?? 'Any',
                        onTap: () {
                          _openGoalFilter(
                            goalSnapshot.data ?? [],
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(
                    height: CohortSpacing.lg,
                  ),

                  Text(
                    '${protocols.length} Protocols Available',
                    style: CohortTextStyles.muted,
                  ),

                  const SizedBox(
                    height: CohortSpacing.lg,
                  ),

                  ...protocols.map(
                    (protocol) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child: ProtocolCard(
                        protocol: protocol,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProtocolDetailScreen(
                                protocol: protocol,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}