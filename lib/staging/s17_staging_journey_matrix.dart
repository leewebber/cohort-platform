/// Phase 1.6 / Sprint 1.7 staging journey result model for Athlete D.
enum S17JourneyResult { pass, fail, blocked, notRun }

extension S17JourneyResultLabel on S17JourneyResult {
  String get label {
    switch (this) {
      case S17JourneyResult.pass:
        return 'PASS';
      case S17JourneyResult.fail:
        return 'FAIL';
      case S17JourneyResult.blocked:
        return 'BLOCKED';
      case S17JourneyResult.notRun:
        return 'NOT RUN';
    }
  }

  static S17JourneyResult parse(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'PASS':
        return S17JourneyResult.pass;
      case 'FAIL':
        return S17JourneyResult.fail;
      case 'BLOCKED':
        return S17JourneyResult.blocked;
      case 'NOT RUN':
        return S17JourneyResult.notRun;
      default:
        throw FormatException('Unknown journey result: $raw');
    }
  }
}

class S17JourneySpec {
  const S17JourneySpec({
    required this.code,
    required this.title,
    required this.requiredAssertions,
  });

  final String code;
  final String title;
  final List<String> requiredAssertions;
}

/// Canonical A–K matrix required by Release Gate B4.
class S17StagingJourneyMatrix {
  static const journeys = <S17JourneySpec>[
    S17JourneySpec(
      code: 'A',
      title: 'Identity and isolation',
      requiredAssertions: [
        'authenticate_athlete_d',
        'sees_only_own_assignment',
        'no_foreign_athlete_data',
        'unsupported_identifier_denied',
      ],
    ),
    S17JourneySpec(
      code: 'B',
      title: 'Catalogue, assignment and prepared execution',
      requiredAssertions: [
        'catalogue_access',
        'correct_version_assigned',
        'ordered_slots_resolve',
        'prepared_execution_identity',
        'refresh_retains_session',
        'no_template_mutation',
      ],
    ),
    S17JourneySpec(
      code: 'C',
      title: 'Previous-performance reference',
      requiredAssertions: [
        'complete_with_entered_value',
        'reference_shown_next_like',
        'reference_athlete_d_only',
        'unlike_identity_no_surface',
        'reference_does_not_rewrite_prescription',
      ],
    ),
    S17JourneySpec(
      code: 'D',
      title: 'Phase 1.6 adaptation',
      requiredAssertions: [
        'suggestion_only_when_policy_allows',
        'authored_authority_unchanged_pre_accept',
        'not_applied_automatically',
        'reject_leaves_unchanged',
        'accept_requires_explicit_action',
        'accepted_within_policy',
        'refresh_retains_accepted',
        'no_other_athlete_mutation',
      ],
    ),
    S17JourneySpec(
      code: 'E',
      title: 'Initial schedule projection',
      requiredAssertions: [
        'projection_matches_assignment',
        'deterministic_across_refresh',
        'no_duplicate_or_missing',
        'lineage_revision_stable',
      ],
    ),
    S17JourneySpec(
      code: 'F',
      title: 'Move plus invalid Move',
      requiredAssertions: [
        'valid_move_updates_projection',
        'valid_move_no_dup_or_loss',
        'valid_move_survives_refresh',
        'invalid_move_rejected_atomically',
      ],
    ),
    S17JourneySpec(
      code: 'G',
      title: 'Swap plus invalid Swap',
      requiredAssertions: [
        'valid_swap_exchanges_positions',
        'identities_follow_sessions',
        'valid_swap_survives_refresh',
        'invalid_swap_rejected_atomically',
      ],
    ),
    S17JourneySpec(
      code: 'H',
      title: 'Push plus invalid Push',
      requiredAssertions: [
        'valid_push_preserves_order',
        'horizon_rule_respected',
        'unrelated_sessions_unchanged',
        'invalid_push_rejected_atomically',
      ],
    ),
    S17JourneySpec(
      code: 'I',
      title: 'Skip',
      requiredAssertions: [
        'explicit_skip_confirmation',
        'skipped_state_recorded',
        'authored_content_unchanged',
        'skip_survives_refresh',
      ],
    ),
    S17JourneySpec(
      code: 'J',
      title: 'Undo and horizon enforcement',
      requiredAssertions: [
        'undo_restores_prior_state',
        'identities_dates_order_match_snapshot',
        'replay_does_not_repeat_mutation',
        'undo_outside_horizon_rejected',
        'failed_undo_no_partial_change',
      ],
    ),
    S17JourneySpec(
      code: 'K',
      title: 'Completion and advancement',
      requiredAssertions: [
        'complete_eligible_session',
        'completion_bound_to_package_session',
        'entered_results_persist',
        'advancement_selects_next_eligible',
        'schedule_changes_respected',
        'duplicate_completion_idempotent',
      ],
    ),
  ];

  static List<String> get codes =>
      journeys.map((j) => j.code).toList(growable: false);

  static Map<String, S17JourneyResult> allNotRun() {
    return {for (final j in journeys) j.code: S17JourneyResult.notRun};
  }
}

class S17JourneyReport {
  S17JourneyReport({required this.results, required this.details});

  final Map<String, S17JourneyResult> results;
  final Map<String, String> details;

  bool get allPass =>
      results.isNotEmpty &&
      results.values.every((r) => r == S17JourneyResult.pass);

  Map<String, dynamic> toJson() {
    return {
      'ok': allPass,
      'journeys': {
        for (final e in results.entries)
          e.key: {
            'title': S17StagingJourneyMatrix.journeys
                .firstWhere((j) => j.code == e.key)
                .title,
            'result': e.value.label,
            'detail': details[e.key],
          },
      },
    };
  }
}
