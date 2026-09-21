import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../programme/models/fixed_programme_occurrence_projection.dart';
import '../../session/models/prepared_execution_package.dart';
import '../presentation/athlete_home_today_presentation.dart';

/// Today command-centre card for one authored session.
class AthleteHomeTodaySessionPanel extends StatefulWidget {
  const AthleteHomeTodaySessionPanel({
    super.key,
    required this.package,
    required this.primaryLabel,
    required this.onPrimary,
    this.dateLabel,
    this.programmeName,
    this.weekDayLabel,
    this.occurrence,
    this.status,
    this.adaptationNotice,
    this.primaryBusy = false,
    this.onViewFullSession,
    this.adaptLabel,
    this.onAdapt,
    this.adaptEnabled = false,
    this.revertLabel,
    this.onRevert,
  });

  final PreparedExecutionPackage package;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? dateLabel;
  final String? programmeName;
  final String? weekDayLabel;
  final FixedProgrammeOccurrenceProjection? occurrence;
  final String? status;
  final String? adaptationNotice;
  final bool primaryBusy;
  final VoidCallback? onViewFullSession;
  final String? adaptLabel;
  final VoidCallback? onAdapt;
  final bool adaptEnabled;
  final String? revertLabel;
  final VoidCallback? onRevert;

  @override
  State<AthleteHomeTodaySessionPanel> createState() =>
      _AthleteHomeTodaySessionPanelState();
}

class _AthleteHomeTodaySessionPanelState
    extends State<AthleteHomeTodaySessionPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final package = widget.package;
    final lines = AthleteHomeTodayFormatter.prescriptionLines(package.plan);
    final collapsedCount = AthleteHomeTodayFormatter.collapsedPrescriptionCount;
    final visible = _expanded || lines.length <= collapsedCount
        ? lines
        : lines.take(collapsedCount).toList(growable: false);
    final meta = AthleteHomeTodayFormatter.metaLine(
      sessionType: AthleteHomeTodayFormatter.sessionType(
        package: package,
        occurrence: widget.occurrence,
      ),
      location: AthleteHomeTodayFormatter.location(package),
      duration: AthleteHomeTodayFormatter.duration(package),
    );
    final focus = AthleteHomeTodayFormatter.focus(package);
    final notes = AthleteHomeTodayFormatter.notes(package);
    final status = widget.status ??
        widget.occurrence?.state.displayLabel ??
        'Not started';
    final title = (widget.occurrence?.sessionTitle.trim().isNotEmpty == true)
        ? widget.occurrence!.sessionTitle
        : package.brief.sessionName;

    return CohortCard(
        variant: CohortCardVariant.premium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TODAY', style: CohortTextStyles.sectionLabel),
            if (widget.dateLabel != null) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(
                widget.dateLabel!,
                style: CohortTextStyles.small.copyWith(
                  color: CohortColors.textSecondary,
                ),
              ),
            ],
            if (widget.programmeName != null &&
                widget.programmeName!.trim().isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.sm),
              Text(widget.programmeName!, style: CohortTextStyles.small),
            ],
            if (widget.weekDayLabel != null &&
                widget.weekDayLabel!.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(widget.weekDayLabel!, style: CohortTextStyles.small),
            ],
            const SizedBox(height: CohortSpacing.md),
            Text(title, style: CohortTextStyles.h2),
            if (meta != null) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(
                meta,
                style: CohortTextStyles.small.copyWith(
                  color: CohortColors.textSecondary,
                ),
              ),
            ],
            if (focus != null) ...[
              const SizedBox(height: CohortSpacing.sm),
              Text(focus, style: CohortTextStyles.body),
            ],
            const SizedBox(height: CohortSpacing.sm),
            Semantics(
              label: 'Status $status',
              child: ExcludeSemantics(
                child: Text(status, style: CohortTextStyles.statusActive),
              ),
            ),
            if (widget.adaptationNotice != null) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(widget.adaptationNotice!, style: CohortTextStyles.small),
            ],
            if (notes != null) ...[
              const SizedBox(height: CohortSpacing.sm),
              Text(notes, style: CohortTextStyles.small),
            ],
            if (visible.isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.md),
              for (final line in visible) _PrescriptionRow(line: line),
              if (lines.length > collapsedCount)
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Show less' : 'Show more'),
                ),
            ],
            if (widget.onViewFullSession != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: widget.onViewFullSession,
                  child: const Text('View full session'),
                ),
              ),
            const SizedBox(height: CohortSpacing.md),
            CohortButton(
              key: const ValueKey('home-today-primary-action'),
              label: widget.primaryBusy ? 'Starting…' : widget.primaryLabel,
              semanticLabel:
                  '${widget.primaryLabel}. $title. Status $status',
              showTrailingArrow: true,
              onPressed: widget.primaryBusy ? null : widget.onPrimary,
            ),
            if (widget.adaptLabel != null) ...[
              const SizedBox(height: CohortSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: widget.adaptEnabled ? widget.onAdapt : null,
                  child: Text(
                    widget.adaptLabel!,
                    style: CohortTextStyles.body.copyWith(
                      color: widget.adaptEnabled
                          ? CohortColors.textPrimary
                          : CohortColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
            if (widget.revertLabel != null && widget.onRevert != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: widget.onRevert,
                  child: Text(widget.revertLabel!),
                ),
              ),
          ],
        ),
    );
  }
}

class _PrescriptionRow extends StatelessWidget {
  const _PrescriptionRow({required this.line});

  final AthleteHomePrescriptionLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(line.name, style: CohortTextStyles.body)),
          if (line.detail != null && line.detail!.trim().isNotEmpty)
            Flexible(
              child: Text(
                line.detail!,
                style: CohortTextStyles.small.copyWith(
                  color: CohortColors.textSecondary,
                ),
                textAlign: TextAlign.right,
                softWrap: true,
              ),
            ),
        ],
      ),
    );
  }
}
