import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/today_session_card.dart';
import '../../data/repositories/athlete_state_repository.dart';
import '../../data/repositories/programme_repository.dart';
import '../../data/repositories/protocol_repository.dart';
import '../../models/athlete_state.dart';
import '../../models/programme.dart';
import '../../models/protocol.dart';
import '../exercises/exercise_library/exercise_library_screen.dart';
import '../protocols/protocol_library_screen.dart';
import '../session/session_player_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openProtocolLibrary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProtocolLibraryScreen(),
      ),
    );
  }

  void _openExerciseLibrary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExerciseLibraryScreen(),
      ),
    );
  }

  void _openSessionPlayer(
    BuildContext context, {
    required String protocolId,
    String? displayTitle,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionPlayerScreen(
          protocolId: protocolId,
          displayTitle: displayTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Cohort'),
              const SizedBox(height: CohortSpacing.md),
              const Text(
                'Today',
                style: CohortTextStyles.h1,
              ),
              const SizedBox(height: CohortSpacing.md),
              const Text(
                'Know the plan. Execute with confidence.',
                style: CohortTextStyles.body,
              ),

              const SizedBox(height: CohortSpacing.xl),

              _TodaySessionSection(
                onBeginSession: (protocolId, displayTitle) =>
                    _openSessionPlayer(
                  context,
                  protocolId: protocolId,
                  displayTitle: displayTitle,
                ),
              ),

              const SizedBox(height: CohortSpacing.xl),

              const SectionTitle('Need to Adapt?'),
              const SizedBox(height: CohortSpacing.md),

              const CohortCard(
                child: _AdaptationRow(
                  title: 'Travelling',
                  subtitle: 'Preserve the training intent with limited equipment.',
                  icon: Icons.flight_takeoff,
                ),
              ),
              const SizedBox(height: CohortSpacing.md),
              const CohortCard(
                child: _AdaptationRow(
                  title: 'Limited Equipment',
                  subtitle: 'Find the closest available version of today’s session.',
                  icon: Icons.fitness_center,
                ),
              ),
              const SizedBox(height: CohortSpacing.md),
              const CohortCard(
                child: _AdaptationRow(
                  title: 'Poor Recovery',
                  subtitle: 'Reduce load or volume while protecting progress.',
                  icon: Icons.bedtime,
                ),
              ),

              const SizedBox(height: CohortSpacing.xl),

              const SectionTitle('Knowledge'),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: () => _openProtocolLibrary(context),
                child: const _HomeActionRow(
                  title: 'Protocol Library',
                  subtitle: 'Browse structured training sessions.',
                  status: 'OPEN',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: () => _openExerciseLibrary(context),
                child: const _HomeActionRow(
                  title: 'Exercise Library',
                  subtitle: 'Browse movements, cues and coaching knowledge.',
                  status: 'OPEN',
                ),
              ),

              const SizedBox(height: CohortSpacing.xxl),

              const Center(
                child: Text(
                  'Build physical capability.',
                  style: CohortTextStyles.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodaySessionData {
  const _TodaySessionData({
    required this.athleteState,
    this.programme,
    this.protocol,
  });

  final AthleteState athleteState;
  final Programme? programme;
  final Protocol? protocol;
}

class _TodaySessionSection extends StatefulWidget {
  const _TodaySessionSection({
    required this.onBeginSession,
  });

  final void Function(String protocolId, String? displayTitle) onBeginSession;

  @override
  State<_TodaySessionSection> createState() => _TodaySessionSectionState();
}

class _TodaySessionSectionState extends State<_TodaySessionSection> {
  static const _athleteId = 'lee';

  final _athleteStateRepository = const AthleteStateRepository();
  final _programmeRepository = ProgrammeRepository();
  final _protocolRepository = ProtocolRepository();

  late final Future<_TodaySessionData?> _todaySessionFuture;

  @override
  void initState() {
    super.initState();
    _todaySessionFuture = _loadTodaySession();
  }

  Future<_TodaySessionData?> _loadTodaySession() async {
    final athleteState =
        await _athleteStateRepository.getAthleteState(_athleteId);

    if (athleteState == null) return null;

    final programme = athleteState.programmeId != null
        ? await _programmeRepository.getProgrammeById(
            athleteState.programmeId!,
          )
        : null;

    final protocol = athleteState.currentProtocolId != null
        ? await _protocolRepository.getProtocolById(
            athleteState.currentProtocolId!,
          )
        : null;

    return _TodaySessionData(
      athleteState: athleteState,
      programme: programme,
      protocol: protocol,
    );
  }

  String _buildSubtitle(_TodaySessionData data) {
    final parts = <String>[];

    final goal = data.athleteState.currentGoal?.trim();
    if (goal != null && goal.isNotEmpty) {
      parts.add(goal);
    }

    final capability = data.protocol?.capability?.trim();
    if (capability != null && capability.isNotEmpty) {
      parts.add(capability);
    }

    return parts.join(' • ');
  }

  String _buildWeekLabel(_TodaySessionData data) {
    final parts = <String>[];

    final programmeName = data.programme?.name.trim();
    if (programmeName != null && programmeName.isNotEmpty) {
      parts.add(programmeName);
    }

    final week = data.athleteState.currentWeek;
    if (week != null) {
      parts.add('Week $week');
    }

    return parts.join(' • ');
  }

  String _buildDuration(Protocol? protocol) {
    final durationMin = protocol?.durationMin;
    if (durationMin == null) return '';

    return '$durationMin minutes';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TodaySessionData?>(
      future: _todaySessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text(
            'Loading session...',
            style: CohortTextStyles.body,
          );
        }

        final data = snapshot.data;
        if (data == null || data.protocol == null) {
          return const Text(
            'No session scheduled.',
            style: CohortTextStyles.body,
          );
        }

        final protocol = data.protocol!;

        return TodaySessionCard(
          title: protocol.name,
          subtitle: _buildSubtitle(data),
          weekLabel: _buildWeekLabel(data),
          duration: _buildDuration(protocol),
          status: 'Planned Session',
          onPressed: data.athleteState.currentProtocolId == null
              ? null
              : () => widget.onBeginSession(
                    data.athleteState.currentProtocolId!,
                    protocol.name,
                  ),
        );
      },
    );
  }
}

class _AdaptationRow extends StatelessWidget {
  const _AdaptationRow({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: CohortSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: CohortTextStyles.cardTitle),
              const SizedBox(height: CohortSpacing.sm),
              Text(subtitle, style: CohortTextStyles.small),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeActionRow extends StatelessWidget {
  const _HomeActionRow({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: CohortTextStyles.cardTitle),
              const SizedBox(height: CohortSpacing.sm),
              Text(subtitle, style: CohortTextStyles.small),
            ],
          ),
        ),
        const SizedBox(width: CohortSpacing.lg),
        Text(status, style: CohortTextStyles.eyebrow),
      ],
    );
  }
}
