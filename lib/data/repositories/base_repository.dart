import '../../core/services/supabase_service.dart';

abstract class BaseRepository<T> {
  const BaseRepository();

  String get tableName;

  T fromMap(Map<String, dynamic> map);

  Future<List<T>> getAll({
    String? orderBy,
    bool ascending = true,
  }) async {
    var query = SupabaseService.client.from(tableName).select();

    if (orderBy != null) {
      final response = await query.order(
        orderBy,
        ascending: ascending,
      );

      return response
          .map<T>((row) => fromMap(row))
          .toList();
    }

    final response = await query;

    return response
        .map<T>((row) => fromMap(row))
        .toList();
  }

  Future<List<T>> getWhere({
    required String column,
    required dynamic value,
    String? orderBy,
    bool ascending = true,
  }) async {
    var query = SupabaseService.client
        .from(tableName)
        .select()
        .eq(column, value);

    if (orderBy != null) {
      final response = await query.order(
        orderBy,
        ascending: ascending,
      );

      return response
          .map<T>((row) => fromMap(row))
          .toList();
    }

    final response = await query;

    return response
        .map<T>((row) => fromMap(row))
        .toList();
  }
}