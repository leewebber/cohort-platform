import 'coach_decision_context.dart';
import '../vocabulary/coach_decision_type.dart';

/// Immutable input to the Coach Brain router and decision handlers.
///
/// Carries stable reference identifiers only — no programme or adaptation models.
class CoachDecisionRequest {
  const CoachDecisionRequest({
    required this.decisionType,
    required this.requestId,
    required this.athleteId,
    this.context,
    this.referenceIds = const {},
  });

  final CoachDecisionType decisionType;
  final String requestId;
  final String athleteId;

  /// Decision-specific immutable context (e.g. [SessionAdaptationCoachDecisionContext]).
  final CoachDecisionContext? context;

  /// Opaque correlation ids (e.g. assignment, slot, session occurrence).
  final Map<String, String> referenceIds;

  bool get hasValidIdentity =>
      requestId.trim().isNotEmpty && athleteId.trim().isNotEmpty;
}
