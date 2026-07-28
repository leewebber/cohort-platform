import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/cohort_lighting.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'cohort_button.dart';
import 'cohort_card.dart';

class TodaySessionCard extends StatelessWidget {
  const TodaySessionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.weekLabel,
    required this.duration,
    this.programmeName,
    this.sessionGoal,
    this.progressLabel,
    this.adaptationNotice,
    this.status = 'Planned Session',
    this.statusDetail,
    this.buttonLabel = 'START SESSION',
    this.badgeLabel,
    this.onPressed,
  });

  final String title;
  final String subtitle;
  final String weekLabel;
  final String duration;
  final String? programmeName;
  final String? sessionGoal;
  final String? progressLabel;
  final String? adaptationNotice;
  final String status;
  final String? statusDetail;
  final String buttonLabel;
  final String? badgeLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final phaseLabel = _phaseFromSessionGoal(sessionGoal);

    return CohortCard(
      variant: CohortCardVariant.premium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  "TODAY'S TRAINING",
                  style: CohortTextStyles.sectionLabel,
                ),
              ),
              if (badgeLabel != null && badgeLabel!.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: CohortColors.oliveSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: CohortColors.borderAccent),
                  ),
                  child: Text(
                    badgeLabel!.toUpperCase(),
                    style: CohortTextStyles.sectionLabel.copyWith(fontSize: 9),
                  ),
                ),
            ],
          ),
          const SizedBox(height: CohortSpacing.lg),
          Text(title.toUpperCase(), style: CohortTextStyles.h2),
          if (programmeName != null && programmeName!.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              programmeName!.toUpperCase(),
              style: CohortTextStyles.small.copyWith(
                color: CohortColors.textMuted,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: CohortSpacing.xs),
          Text(subtitle, style: CohortTextStyles.body),
          const SizedBox(height: CohortSpacing.lg),
          _MetadataGrid(
            weekLabel: weekLabel,
            duration: duration,
            progressLabel: progressLabel,
            phaseLabel: phaseLabel,
          ),
          if (adaptationNotice != null &&
              adaptationNotice!.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.md),
            Text(adaptationNotice!, style: CohortTextStyles.small),
          ],
          const SizedBox(height: CohortSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: CohortLighting.statusEmissiveDot(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.toUpperCase(),
                      style: CohortTextStyles.statusActive,
                    ),
                    if (statusDetail != null &&
                        statusDetail!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(statusDetail!, style: CohortTextStyles.small),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CohortSpacing.xl),
          CohortButton(
            label: buttonLabel,
            showTrailingArrow: true,
            onPressed: onPressed ?? () {},
          ),
        ],
      ),
    );
  }

  static String? _phaseFromSessionGoal(String? sessionGoal) {
    if (sessionGoal == null || sessionGoal.trim().isEmpty) return null;
    final trimmed = sessionGoal.trim();
    if (trimmed.toLowerCase().startsWith('session goal:')) {
      return trimmed.substring('session goal:'.length).trim();
    }
    return trimmed;
  }
}

class _MetadataGrid extends StatelessWidget {
  const _MetadataGrid({
    required this.weekLabel,
    required this.duration,
    required this.progressLabel,
    required this.phaseLabel,
  });

  final String weekLabel;
  final String duration;
  final String? progressLabel;
  final String? phaseLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: CohortSpacing.md),
      decoration: CohortLighting.insetPanel(),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Tile(
                icon: Icons.calendar_today_outlined,
                label: 'Week / day',
                value: weekLabel.isEmpty ? '—' : weekLabel,
              ),
            ),
            const _Divider(),
            Expanded(
              child: _Tile(
                icon: Icons.schedule_outlined,
                label: 'Duration',
                value: duration.trim().isEmpty ? '—' : duration,
              ),
            ),
            const _Divider(),
            Expanded(
              child: _Tile(
                icon: Icons.show_chart_outlined,
                label: 'Progress',
                value: (progressLabel == null || progressLabel!.trim().isEmpty)
                    ? '—'
                    : progressLabel!,
              ),
            ),
            const _Divider(),
            Expanded(
              child: _Tile(
                icon: Icons.flag_outlined,
                label: 'Phase',
                value: (phaseLabel == null || phaseLabel!.trim().isEmpty)
                    ? '—'
                    : phaseLabel!,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      color: CohortColors.border.withValues(alpha: 0.8),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Icon(
            icon,
            size: 16,
            color: CohortColors.phosphor,
            shadows: [
              Shadow(
                color: CohortColors.phosphor.withValues(alpha: 0.35),
                blurRadius: 4,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: CohortTextStyles.tileLabel,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: CohortTextStyles.tileValue,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
