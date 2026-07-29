import 'package:flutter/material.dart';

import '../../../application/adaptation/athlete_workout_adaptation_application_service.dart';
import '../../../core/presentation/athlete_safe_error_presenter.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/adaptation_bottom_sheet.dart';
import '../../../core/widgets/adaptation_decision_bottom_sheet.dart';
import '../../../models/adaptation_request.dart';
import '../../admin/services/protocol_builder_service.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../../application/athlete_workout/home_workout_launch_service.dart';
import '../models/home_today_session_state.dart';
import '../services/home_today_session_loader.dart';
import '../services/home_today_session_services.dart';

/// Mounted Adapt entry that does not depend on an unmounted Home section key.
class HomeAdaptFlow {
  HomeAdaptFlow({
    HomeTodaySessionLoader? loader,
    AthleteWorkoutAdaptationApplicationService? adaptationService,
    HomeWorkoutLaunchService? launchService,
  }) : _loader = loader ?? HomeTodaySessionServices.createLoader(),
       _adaptationService =
           adaptationService ??
           AthleteWorkoutAdaptationApplicationService(
             loadProtocolDraft: (protocolId) =>
                 ProtocolBuilderService().loadProtocol(protocolId),
           ),
       _launchService =
           launchService ??
           HomeWorkoutLaunchService(
             loadProtocolDraft: (protocolId) =>
                 ProtocolBuilderService().loadProtocol(protocolId),
           );

  final HomeTodaySessionLoader _loader;
  final AthleteWorkoutAdaptationApplicationService _adaptationService;
  final HomeWorkoutLaunchService _launchService;

  /// Opens category sheet → evaluate → decision → commit when possible.
  Future<void> open(BuildContext context, {required String athleteId}) async {
    if (!AthleteProfileSession.hasActivePlan) {
      await _showSafeMessage(
        context,
        'Choose a Plan before adapting training. '
        'Adapt adjusts today’s session once a plan is active.',
      );
      return;
    }

    final request = await showAdaptationBottomSheet(context);
    if (request == null || !context.mounted) return;

    HomeTodaySessionState state;
    try {
      state = await _loader.load(athleteId);
    } catch (error) {
      if (!context.mounted) return;
      await _showSafeMessage(
        context,
        AthleteSafeErrorPresenter.message(
          error,
          fallback: "We couldn't prepare today's training.",
          logTag: 'HomeAdaptFlow.load',
        ),
      );
      return;
    }

    if (!context.mounted) return;

    if (state is! HomeTodaySessionProgrammeExecutable) {
      await _showSafeMessage(
        context,
        state is HomeTodaySessionRestDay
            ? 'Today is a recovery day — there is no session to adapt.'
            : state is HomeTodaySessionDayComplete
            ? "Today's training is already complete."
            : 'There is no active session to adapt right now.',
      );
      return;
    }

    final protocol = state.protocol;
    final execution = state.workoutExecution;

    try {
      final decision = await _adaptationService.evaluateSessionAdaptation(
        athleteId: athleteId,
        currentProtocol: protocol,
        request: request,
      );

      if (!context.mounted) return;

      final accepted = await showAdaptationDecisionBottomSheet(
        context,
        decision,
      );
      if (accepted != true || !context.mounted) return;

      if (execution == null) {
        await _showSafeMessage(
          context,
          "We couldn't apply that adaptation to today's training. Try again.",
        );
        return;
      }

      await _launchService.commitDayOfAdaptation(
        executionContext: execution,
        athleteId: athleteId,
        protocol: protocol,
        request: request,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Today's training has been adapted."),
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      await _showSafeMessage(
        context,
        AthleteSafeErrorPresenter.message(
          error,
          fallback: "We couldn't prepare today's training.",
          logTag: 'HomeAdaptFlow.apply',
        ),
      );
    }
  }

  Future<void> _showSafeMessage(BuildContext context, String message) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adapt', style: CohortTextStyles.h2),
              const SizedBox(height: 12),
              Text(message, style: CohortTextStyles.body),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Re-export for callers that need the request type.
typedef HomeAdaptRequest = AdaptationRequest;
