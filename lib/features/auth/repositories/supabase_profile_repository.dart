import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../data/repositories/programme_store_exception.dart';
import '../models/user_profile.dart';
import 'profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository({this.client});
  final SupabaseClient? client;
  SupabaseClient get _resolvedClient => client ?? SupabaseService.client;

  static const _tableName = 'profiles';

  @override
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response = await _resolvedClient
          .from(_tableName)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      return UserProfile.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to load profile',
        operation: 'getProfile',
        tableName: _tableName,
      );
    }
  }

  @override
  Future<UserProfile> createProfile(UserProfile profile) async {
    try {
      final response = await _resolvedClient
          .from(_tableName)
          .insert(profile.toInsertMap())
          .select()
          .single();

      return UserProfile.fromMap(Map<String, dynamic>.from(response));
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        final existing = await getProfile(profile.id);
        if (existing != null) return existing;
      }
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to create profile',
        operation: 'createProfile',
        tableName: _tableName,
      );
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to create profile',
        operation: 'createProfile',
        tableName: _tableName,
      );
    }
  }
}
