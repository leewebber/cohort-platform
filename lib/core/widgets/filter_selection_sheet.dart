import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class FilterSelectionSheet extends StatelessWidget {
  const FilterSelectionSheet({
    super.key,
    required this.title,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
  });

  final String title;
  final List<String> items;
  final String? selectedValue;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <String?>[null, ...items];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose $title', style: CohortTextStyles.h2),
              const SizedBox(height: CohortSpacing.lg),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: CohortColors.border,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final label = option ?? 'Any';
                    final isSelected = option == selectedValue;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        label,
                        style: isSelected
                            ? CohortTextStyles.cardTitle
                            : CohortTextStyles.body,
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: CohortColors.olive,
                            )
                          : null,
                      onTap: () {
                        onSelected(option);
                        Navigator.of(context).pop();
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