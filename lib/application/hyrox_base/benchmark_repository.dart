import '../../core/services/supabase_service.dart';
import '../../domain/hyrox_base/base_personalisation.dart';

/// RPC transport for the independent declared-evidence store. Authentication is
/// supplied by the established Supabase session, never by a payload athlete ID.
typedef BaseBenchmarkRpc =
    Future<Object?> Function(String name, Map<String, Object?> parameters);

/// Declared benchmark entry shared by independent previews and programme review.
/// Preview selection is not programme consent; programme review deliberately
/// names retained revisions. This repository cannot admit v3 or start a session.
class BaseBenchmarkRepository {
  BaseBenchmarkRepository({BaseBenchmarkRpc? rpc}) : _rpc = rpc ?? _supabase;

  final BaseBenchmarkRpc _rpc;

  static Future<Object?> _supabase(
    String name,
    Map<String, Object?> parameters,
  ) => SupabaseService.client.rpc(name, params: parameters);

  Future<Map<String, Object?>> record({
    required String commandId,
    required BaseMetric metric,
    required String value,
    required BaseInputUnit unit,
    required String testDate,
    required BaseSourceType sourceType,
    required String sourceReference,
    String? previousRevisionId,
    String? correctionReason,
  }) {
    if (sourceType == BaseSourceType.syntheticExample) {
      throw const FormatException(
        'Synthetic examples are not stored evidence.',
      );
    }
    // Early input feedback only. The SQL boundary repeats validation and exact
    // conversion, derives ownership and computes its own retained digest.
    BaseBenchmark.enter(
      id: commandId,
      athleteId: 'authenticated_transport',
      metric: metric,
      value: value,
      unit: unit,
      testDate: testDate,
      sourceType: sourceType,
      sourceReference: sourceReference,
    );
    return _call('record_hyrox_base_benchmark', {
      'payload': {
        'command_id': commandId,
        'metric': metric.name,
        'value': value,
        'unit': unit.name,
        'test_date': testDate,
        'source_type': sourceType.name,
        'source_reference': sourceReference,
        'previous_revision_id': previousRevisionId,
        'correction_reason': correctionReason,
      },
    });
  }

  /// An explicit user action must call this; recording never selects evidence.
  /// Null [revisionId] records withdrawal. [expectedSelectionId] is a CAS token
  /// from the last read/acceptance; a stale token cannot replace newer consent.
  Future<Map<String, Object?>> selectForFuturePreviews({
    required String commandId,
    required BaseMetric metric,
    required String? revisionId,
    required String? expectedSelectionId,
  }) => _call('select_hyrox_base_benchmark', {
    'payload': {
      'command_id': commandId,
      'metric': metric.name,
      'selected_revision_id': revisionId,
      'expected_selection_id': expectedSelectionId,
      'consent': 'use_declared_benchmark_for_future_previews_only',
    },
  });

  /// Includes explicit stale/withdrawn states. A retained selection is never
  /// inferred to remain usable after its evidence revision is corrected.
  Future<Map<String, Object?>> readSelections() =>
      _call('read_hyrox_base_selections', const {});

  Future<Map<String, Object?>> _call(
    String name,
    Map<String, Object?> parameters,
  ) async {
    final response = await _rpc(name, parameters);
    if (response is! Map || response['status'] is! String) {
      throw StateError('Malformed Base benchmark persistence response.');
    }
    return Map<String, Object?>.from(response);
  }
}
