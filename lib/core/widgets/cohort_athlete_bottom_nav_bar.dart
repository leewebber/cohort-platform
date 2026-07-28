import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/cohort_lighting.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Fixed athlete bottom navigation — presentation only; taps invoke existing routes.
class CohortAthleteBottomNavBar extends StatelessWidget {
  const CohortAthleteBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<CohortAthleteNavDestination>? destinations;

  static const defaultDestinations = [
    CohortAthleteNavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    CohortAthleteNavDestination(
      label: 'Programme',
      icon: Icons.calendar_view_week_outlined,
      selectedIcon: Icons.calendar_view_week_rounded,
    ),
    CohortAthleteNavDestination(
      label: 'Sessions',
      icon: Icons.view_list_outlined,
      selectedIcon: Icons.view_list_rounded,
    ),
    CohortAthleteNavDestination(
      label: 'Analytics',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      enabled: false,
    ),
    CohortAthleteNavDestination(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = destinations ?? defaultDestinations;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CohortColors.background.withValues(alpha: 0.94),
        boxShadow: CohortShadows.navBar,
        border: Border(
          top: BorderSide(
            color: CohortColors.edgeHighlight.withValues(alpha: 0.22),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: CohortSpacing.sm, bottom: bottom + 6),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavItem(
                  destination: items[i],
                  selected: selectedIndex == i,
                  onTap: items[i].enabled
                      ? () => onDestinationSelected(i)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CohortAthleteNavDestination {
  const CohortAthleteNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool enabled;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final CohortAthleteNavDestination destination;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = destination.enabled && onTap != null;
    final color = !enabled
        ? CohortColors.textMuted.withValues(alpha: 0.45)
        : selected
            ? CohortColors.phosphor
            : CohortColors.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: selected && enabled
                    ? CohortLighting.navActiveHalo()
                    : null,
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 22,
                  color: color,
                  shadows: selected && enabled
                      ? [
                          Shadow(
                            color: CohortColors.phosphor.withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                destination.label,
                style: CohortTextStyles.muted.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
