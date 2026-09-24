import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../domain/enrolment_iana_timezone.dart';
import '../presentation/athlete_programme_continuity_copy.dart';

Future<String?> showEnrolmentTimezonePicker({
  required BuildContext context,
  String? selectedIana,
  String? suggestedIana,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: CohortColors.surface,
    builder: (context) {
      return EnrolmentTimezonePickerSheet(
        selectedIana: selectedIana,
        suggestedIana: suggestedIana,
      );
    },
  );
}

class EnrolmentTimezonePickerSheet extends StatefulWidget {
  const EnrolmentTimezonePickerSheet({
    super.key,
    this.selectedIana,
    this.suggestedIana,
  });

  final String? selectedIana;
  final String? suggestedIana;

  @override
  State<EnrolmentTimezonePickerSheet> createState() =>
      _EnrolmentTimezonePickerSheetState();
}

class _EnrolmentTimezonePickerSheetState
    extends State<EnrolmentTimezonePickerSheet> {
  final _search = TextEditingController();
  late String? _selected = widget.selectedIana;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String? get _suggested {
    return EnrolmentIanaCatalog.suggestedValidIana(widget.suggestedIana);
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final hits = EnrolmentIanaCatalog.search(query);
    final suggested = _suggested;
    final showSuggested =
        suggested != null &&
        hits.any((hit) => hit.$2 == suggested);
    final remaining = hits
        .where((hit) => hit.$2 != suggested)
        .toList(growable: false);
    final sectionLabel = query.isEmpty
        ? AthleteProgrammeContinuityCopy.allTimezones
        : AthleteProgrammeContinuityCopy.searchResults;
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.only(
            left: CohortSpacing.lg,
            right: CohortSpacing.lg,
            top: CohortSpacing.lg,
            bottom: MediaQuery.viewInsetsOf(context).bottom + CohortSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AthleteProgrammeContinuityCopy.selectTimezone,
                style: CohortTextStyles.h2,
              ),
              const SizedBox(height: CohortSpacing.md),
              TextField(
                controller: _search,
                autofocus: true,
                style: CohortTextStyles.body,
                decoration: InputDecoration(
                  hintText: AthleteProgrammeContinuityCopy.searchTimezones,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: CohortColors.surfaceRaised,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: CohortSpacing.md),
              Expanded(
                child: ListView(
                  children: [
                    if (showSuggested) ...[
                      Text(
                        AthleteProgrammeContinuityCopy.suggestedTimezones,
                        style: CohortTextStyles.sectionLabel,
                      ),
                      const SizedBox(height: CohortSpacing.sm),
                      _TimezoneChoiceRow(
                        iana: suggested,
                        selected: suggested == _selected,
                        onTap: () => setState(() => _selected = suggested),
                      ),
                      const SizedBox(height: CohortSpacing.md),
                    ],
                    Text(sectionLabel, style: CohortTextStyles.sectionLabel),
                    const SizedBox(height: CohortSpacing.sm),
                    for (final hit in remaining)
                      _TimezoneChoiceRow(
                        iana: hit.$2,
                        selected: hit.$2 == _selected,
                        onTap: () => setState(() => _selected = hit.$2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: CohortSpacing.md),
              CohortButton(
                label: AthleteProgrammeContinuityCopy.useSelectedTimezone,
                onPressed: _selected == null
                    ? null
                    : () => Navigator.of(context).pop(_selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimezoneChoiceRow extends StatelessWidget {
  const _TimezoneChoiceRow({
    required this.iana,
    required this.selected,
    required this.onTap,
  });

  final String iana;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final friendly = EnrolmentIanaLabels.labelFor(iana);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: selected ? '$friendly, $iana, selected' : '$friendly, $iana',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected
                      ? CohortColors.oliveSoft
                      : CohortColors.surfaceRaised,
                  border: Border.all(
                    color: selected
                        ? CohortColors.phosphor
                        : CohortColors.border,
                    width: selected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ExcludeSemantics(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(friendly, style: CohortTextStyles.body),
                              Text(iana, style: CohortTextStyles.muted),
                            ],
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check,
                          color: CohortColors.phosphor,
                          semanticLabel: 'Selected',
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
