import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../models/user_role.dart';

class RoleSelectionChips extends StatelessWidget {
  const RoleSelectionChips({
    super.key,
    required this.selectedRoles,
    required this.onChanged,
  });

  final Set<UserRole> selectedRoles;
  final ValueChanged<Set<UserRole>> onChanged;

  void _toggle(UserRole role) {
    final updated = Set<UserRole>.from(selectedRoles);
    if (updated.contains(role)) {
      if (updated.length == 1) return;
      updated.remove(role);
    } else {
      updated.add(role);
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: UserRole.values.map((role) {
        final selected = selectedRoles.contains(role);
        return Padding(
          padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
          child: Material(
            color: selected ? CohortColors.olive.withValues(alpha: 0.12) : CohortColors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _toggle(role),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(CohortSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? CohortColors.olive : CohortColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? CohortColors.olive : CohortColors.textSecondary,
                    ),
                    const SizedBox(width: CohortSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(role.label, style: CohortTextStyles.cardTitle),
                          const SizedBox(height: CohortSpacing.xs),
                          Text(
                            role.description,
                            style: CohortTextStyles.small.copyWith(
                              color: CohortColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
