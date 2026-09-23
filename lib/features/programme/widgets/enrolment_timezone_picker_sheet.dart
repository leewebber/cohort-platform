import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../domain/enrolment_iana_timezone.dart';
import '../presentation/athlete_programme_continuity_copy.dart';

Future<String?> showEnrolmentTimezonePicker({
  required BuildContext context,
  String? selectedIana,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return EnrolmentTimezonePickerSheet(selectedIana: selectedIana);
    },
  );
}

class EnrolmentTimezonePickerSheet extends StatefulWidget {
  const EnrolmentTimezonePickerSheet({super.key, this.selectedIana});

  final String? selectedIana;

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

  @override
  Widget build(BuildContext context) {
    final hits = EnrolmentIanaCatalog.search(_search.text);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: CohortSpacing.lg,
          right: CohortSpacing.lg,
          top: CohortSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + CohortSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              decoration: const InputDecoration(
                labelText: AthleteProgrammeContinuityCopy.searchTimezones,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: CohortSpacing.md),
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: hits.length,
                itemBuilder: (context, index) {
                  final (:group, :iana) = (
                    group: hits[index].$1,
                    iana: hits[index].$2,
                  );
                  final selected = iana == _selected;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: EnrolmentIanaLabels.display(iana),
                    child: ListTile(
                      title: Text(
                        EnrolmentIanaLabels.labelFor(iana),
                        style: CohortTextStyles.body,
                      ),
                      subtitle: Text(
                        '$group · $iana',
                        style: CohortTextStyles.small,
                      ),
                      selected: selected,
                      onTap: () => setState(() => _selected = iana),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: CohortSpacing.md),
            CohortButton(
              label: AthleteProgrammeContinuityCopy.selectTimezone,
              onPressed: _selected == null
                  ? null
                  : () => Navigator.of(context).pop(_selected),
            ),
          ],
        ),
      ),
    );
  }
}
