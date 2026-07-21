import '../../../core/services/supabase_service.dart';
import '../../../data/repositories/programme_store_exception.dart';
import '../models/coach_athlete_invite.dart';
import '../models/coach_athlete_relationship.dart';
import '../models/coach_athlete_roster_entry.dart';
import 'coach_athlete_repository.dart';

class SupabaseCoachAthleteRelationshipRepository
    implements CoachAthleteRelationshipRepository {
  const SupabaseCoachAthleteRelationshipRepository();

  static const _tableName = 'coach_athlete_relationships';

  @override
  Future<List<CoachAthleteRelationship>> listActiveForCoach(
    String coachId,
  ) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('coach_id', coachId.trim())
          .eq('status', 'active')
          .order('created_at', ascending: false);

      return (response as List)
          .map(
            (row) => CoachAthleteRelationship.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to load athlete relationships',
        operation: 'listActiveForCoach',
        tableName: _tableName,
      );
    }
  }

  @override
  Future<CoachAthleteRelationship?> getActiveForAthlete(
    String athleteId,
  ) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('athlete_id', athleteId.trim())
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return null;

      return CoachAthleteRelationship.fromMap(
        Map<String, dynamic>.from(response),
      );
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to load coach relationship',
        operation: 'getActiveForAthlete',
        tableName: _tableName,
      );
    }
  }

  @override
  Future<bool> hasActiveRelationship({
    required String coachId,
    required String athleteId,
  }) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select('id')
          .eq('coach_id', coachId.trim())
          .eq('athlete_id', athleteId.trim())
          .eq('status', 'active')
          .maybeSingle();

      return response != null;
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to verify athlete relationship',
        operation: 'hasActiveRelationship',
        tableName: _tableName,
      );
    }
  }
}

class SupabaseCoachAthleteInviteRepository implements CoachAthleteInviteRepository {
  const SupabaseCoachAthleteInviteRepository();

  static const _tableName = 'coach_athlete_invites';

  @override
  Future<CoachAthleteInvite> createInvite(CoachAthleteInvite invite) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .insert(
            invite.toInsertMap(
              coachId: invite.coachId,
              code: invite.code,
              expiresAt: invite.expiresAt,
            ),
          )
          .select()
          .single();

      return CoachAthleteInvite.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to create invitation',
        operation: 'createInvite',
        tableName: _tableName,
      );
    }
  }

  @override
  Future<List<CoachAthleteInvite>> listPendingForCoach(String coachId) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('coach_id', coachId.trim())
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List)
          .map(
            (row) => CoachAthleteInvite.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .where((invite) => invite.isUsable)
          .toList();
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to load pending invitations',
        operation: 'listPendingForCoach',
        tableName: _tableName,
      );
    }
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    try {
      await SupabaseService.client
          .from(_tableName)
          .update({'status': 'revoked'})
          .eq('id', inviteId.trim())
          .eq('status', 'pending');
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to revoke invitation',
        operation: 'revokeInvite',
        tableName: _tableName,
      );
    }
  }

  @override
  Future<CoachAthleteAcceptInviteResult> acceptInvite(String code) async {
    try {
      final response = await SupabaseService.client.rpc(
        'accept_coach_athlete_invite',
        params: {'p_code': code.trim()},
      );

      final map = Map<String, dynamic>.from(response as Map);
      return CoachAthleteAcceptInviteResult(
        coachDisplayName: map['coachDisplayName'] as String? ?? 'Your coach',
        coachId: map['coachId'] as String,
      );
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to accept invitation',
        operation: 'acceptInvite',
        tableName: _tableName,
      );
    }
  }
}
