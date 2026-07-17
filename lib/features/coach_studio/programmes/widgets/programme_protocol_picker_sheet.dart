import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../programme_builder/services/programme_builder_protocol_picker_service.dart';
import 'cohort_protocol_programme_options_sheet.dart';

typedef ProgrammeProtocolListLoader = Future<List<ProgrammeBuilderProtocolOption>>
    Function({String? searchTerm});

class ProgrammeProtocolPickerSheet extends StatefulWidget {
  const ProgrammeProtocolPickerSheet({
    super.key,
    required this.listProtocols,
  });

  final ProgrammeProtocolListLoader listProtocols;

  @override
  State<ProgrammeProtocolPickerSheet> createState() =>
      _ProgrammeProtocolPickerSheetState();
}

class _ProgrammeProtocolPickerSheetState
    extends State<ProgrammeProtocolPickerSheet> {
  final _searchController = TextEditingController();
  List<ProgrammeBuilderProtocolOption> _options = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final options = await widget.listProtocols(
        searchTerm: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _options = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: CohortSpacing.lg,
        right: CohortSpacing.lg,
        top: CohortSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + CohortSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Cohort Protocols', style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.md),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search by name or protocol ID',
            ),
          ),
          const SizedBox(height: CohortSpacing.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(CohortSpacing.lg),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(CohortSpacing.lg),
              child: Column(
                children: [
                  Text(
                    'We could not load protocols right now.',
                    style: CohortTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: CohortSpacing.md),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          else if (_options.isEmpty &&
              _searchController.text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.all(CohortSpacing.lg),
              child: Text(
                'No protocols are available in the library yet.',
                style: CohortTextStyles.body,
                textAlign: TextAlign.center,
              ),
            )
          else if (_options.isEmpty)
            Padding(
              padding: const EdgeInsets.all(CohortSpacing.lg),
              child: Text(
                'No protocols match your search.',
                style: CohortTextStyles.body,
                textAlign: TextAlign.center,
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  final option = _options[index];
                  return ListTile(
                    title: Text(
                      option.name,
                      style: CohortTextStyles.cardTitle,
                    ),
                    subtitle: Text(
                      [
                        option.protocolId,
                        if (option.sessionType != null) option.sessionType!,
                        if (option.durationMin != null)
                          '${option.durationMin} min',
                        if (option.equipmentSummary != null)
                          option.equipmentSummary!,
                      ].join(' • '),
                      style: CohortTextStyles.small,
                    ),
                    onTap: () async {
                      final selection =
                          await showModalBottomSheet<
                              CohortProtocolProgrammeSelection>(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) =>
                            CohortProtocolProgrammeOptionsSheet(
                          protocol: option,
                        ),
                      );
                      if (selection != null && context.mounted) {
                        Navigator.pop(context, selection);
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
