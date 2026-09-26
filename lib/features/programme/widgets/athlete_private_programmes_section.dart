import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../models/private_programme_summary.dart';
import '../screens/athlete_private_programme_activation_screen.dart';
import '../services/private_programme_discovery_store.dart';
import '../services/private_programme_enrolment_store.dart';

class AthletePrivateProgrammesSection extends StatefulWidget {
  const AthletePrivateProgrammesSection({
    super.key,
    required this.discoveryStore,
    required this.enrolmentStore,
    this.currentProgrammeTitle,
    this.refreshController,
    this.onActivated,
  });

  final PrivateProgrammeDiscoveryStore discoveryStore;
  final PrivateProgrammeEnrolmentStore enrolmentStore;
  final String? currentProgrammeTitle;
  final HomeTodaySessionRefreshController? refreshController;
  final VoidCallback? onActivated;

  @override
  State<AthletePrivateProgrammesSection> createState() =>
      _AthletePrivateProgrammesSectionState();
}

class _AthletePrivateProgrammesSectionState
    extends State<AthletePrivateProgrammesSection> {
  List<PrivateProgrammeSummary> _programmes = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    List<PrivateProgrammeSummary> items = const [];
    try {
      items = await widget.discoveryStore.listMine();
    } catch (_) {
      items = const [];
    }
    if (!mounted) return;
    setState(() {
      _programmes = items;
      _loaded = true;
    });
  }

  Future<void> _open(PrivateProgrammeSummary programme) async {
    final activated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AthletePrivateProgrammeActivationScreen(
          programme: programme,
          currentProgrammeTitle: widget.currentProgrammeTitle,
          enrolmentStore: widget.enrolmentStore,
          refreshController: widget.refreshController,
        ),
      ),
    );
    if (activated == true) {
      widget.onActivated?.call();
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _programmes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('My private programmes'),
        const SizedBox(height: CohortSpacing.sm),
        for (final programme in _programmes) ...[
          CohortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(programme.title, style: CohortTextStyles.h2),
                const SizedBox(height: CohortSpacing.xs),
                const Text('Private', style: CohortTextStyles.small),
                if (programme.summary != null) ...[
                  const SizedBox(height: CohortSpacing.xs),
                  Text(programme.summary!, style: CohortTextStyles.body),
                ],
                if (programme.authorisedLocalStartDate != null) ...[
                  const SizedBox(height: CohortSpacing.xs),
                  Text(
                    'Start ${_iso(programme.authorisedLocalStartDate!)}'
                    '${programme.authorisedTimezone == null ? '' : ' · ${programme.authorisedTimezone}'}',
                    style: CohortTextStyles.small,
                  ),
                ],
                const SizedBox(height: CohortSpacing.sm),
                TextButton(
                  onPressed: () => _open(programme),
                  child: const Text('Review activation'),
                ),
              ],
            ),
          ),
          const SizedBox(height: CohortSpacing.sm),
        ],
      ],
    );
  }

  static String _iso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
