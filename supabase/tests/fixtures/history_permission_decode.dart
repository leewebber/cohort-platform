// Decode actual loopback RPC responses from synthetic disposable data only.
import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/application/performance_tracking/coherent_history_rpc_reader.dart';
import 'package:cohort_platform/application/performance_tracking/distance_observations_profile.dart';
import 'package:cohort_platform/application/performance_tracking/history_tracking_adapter.dart';
import 'package:cohort_platform/application/performance_tracking/profile_tracking_evaluator.dart';

final class WireClient implements HistoryTrackingRpcClient {
  WireClient(this.wires);
  final Map<String, Object?> wires;
  @override
  String get authenticatedAthleteId => 'c2000000-0000-4000-8000-000000000001';
  @override
  Future<Object?> readTrackingHistory({
    required String recordId,
    required Map<String, Object?>? programmeClaim,
  }) async => wires[recordId];
}

Future<void> main(List<String> args) async {
  final wires = (jsonDecode(File(args.single).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final client = WireClient({
    for (final wire in wires)
      (wire['record'] as Map)['record_id'] as String: wire,
  });
  final adapter = HistoryTrackingAdapter(
    reader: CoherentHistoryRpcReader(client),
    definitions: DistanceObservationsProfile.definitions,
  );
  final inputs = <TrackingEvaluationInput>[];
  for (var i = 0; i < wires.length; i++) {
    final wire = wires[i];
    final block = (wire['blocks'] as List).single as Map;
    final query = HistoryTrackingQuery(
      athleteId: client.authenticatedAthleteId,
      metric: DistanceObservationsProfile.metric.reference,
      field: HistoryFieldSelection(
        recordId: (wire['record'] as Map)['record_id'] as String,
        blockResultId: block['block_result_id'] as String,
        sourceBlockId: 'permission.distance',
        fieldPath: const ['result_data', 'distance'],
      ),
    );
    final result = await adapter.read(query);
    if (result is! HistoryTrackingObservation ||
        !result.trackingEligible ||
        result.value != '$i' ||
        result.grantsPrescriptionEligibility) {
      throw StateError('Exact owned kilometre RPC decode failed');
    }
    inputs.add(
      TrackingEvaluationInput(id: 'operand$i', query: query, result: result),
    );
  }
  final evaluation =
      ProfileTrackingEvaluator(
        definitions: DistanceObservationsProfile.definitions,
      ).evaluate(
        athleteId: client.authenticatedAthleteId,
        profiles: [
          TrackingProfileRequest(
            profile: DistanceObservationsProfile.profile.reference,
          ),
        ],
        inputs: inputs,
        comparisons: [
          TrackingComparisonRequest(
            id: 'explicit-pair',
            metric: DistanceObservationsProfile.metric.reference,
            policy: TrackingComparabilityPolicy.reference,
            leftInputId: 'operand0',
            rightInputId: 'operand1',
          ),
        ],
      );
  final pair = (evaluation.content['comparisons'] as List).single as Map;
  if (evaluation.isFailure ||
      jsonEncode(pair['reasons']) !=
          '["context_unavailable:comparison_family"]') {
    throw StateError('Missing comparison context must prevent comparison');
  }
  stdout.writeln('HISTORY_PERMISSION_ACTUAL_C2_C3_DISTANCE_DECODE=PASS');
}
