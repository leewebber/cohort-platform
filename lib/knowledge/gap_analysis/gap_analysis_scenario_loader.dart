import 'dart:io';

import 'package:yaml/yaml.dart';

import 'capability_evidence_models.dart';

/// Reference scenario for gap analysis demos and tests (not athlete persistence).
class GapAnalysisScenario {
  const GapAnalysisScenario({
    required this.id,
    required this.goalId,
    required this.label,
    required this.description,
    required this.evidenceProfile,
  });

  final String id;
  final String goalId;
  final String label;
  final String description;
  final AthleteCapabilityEvidenceProfile evidenceProfile;
}

class GapAnalysisScenarioLoader {
  const GapAnalysisScenarioLoader();

  Future<List<GapAnalysisScenario>> loadFromDirectory(
    String knowledgeRoot,
  ) async {
    final file = File('$knowledgeRoot/reference/gap_analysis_scenarios.yaml');
    if (!file.existsSync()) {
      throw GapAnalysisScenarioLoadException(
        'Missing gap_analysis_scenarios.yaml',
      );
    }
    final doc = loadYaml(await file.readAsString());
    if (doc is! YamlMap || doc['scenarios'] is! YamlList) {
      throw GapAnalysisScenarioLoadException('Invalid scenarios file');
    }

    final scenarios = <GapAnalysisScenario>[];
    for (final raw in doc['scenarios'] as YamlList) {
      if (raw is! YamlMap) continue;
      scenarios.add(_parseScenario(raw));
    }
    return scenarios;
  }

  GapAnalysisScenario _parseScenario(YamlMap raw) {
    final id = raw['id']?.toString();
    final goalId = raw['goal_id']?.toString();
    final label = raw['label']?.toString() ?? id ?? 'scenario';
    final description = raw['description']?.toString() ?? '';
    if (id == null || goalId == null) {
      throw GapAnalysisScenarioLoadException('Scenario missing id or goal_id');
    }

    final items = <CapabilityEvidenceItem>[];
    final evidence = raw['evidence'];
    if (evidence is YamlList) {
      for (final entry in evidence) {
        if (entry is! YamlMap) continue;
        items.add(_parseEvidence(entry));
      }
    }

    return GapAnalysisScenario(
      id: id,
      goalId: goalId,
      label: label,
      description: description,
      evidenceProfile: AthleteCapabilityEvidenceProfile.fromItems(items),
    );
  }

  CapabilityEvidenceItem _parseEvidence(YamlMap raw) {
    final capabilityId = raw['capability_id']?.toString();
    final stateRaw = raw['state']?.toString();
    if (capabilityId == null || stateRaw == null) {
      throw GapAnalysisScenarioLoadException(
        'Evidence missing capability_id or state',
      );
    }
    return CapabilityEvidenceItem(
      capabilityId: capabilityId,
      state: _parseState(stateRaw),
      confidence: (raw['confidence'] is num)
          ? (raw['confidence'] as num).toDouble()
          : 0.5,
      source: raw['source']?.toString(),
      recordedAt: raw['recorded_at'] != null
          ? DateTime.tryParse(raw['recorded_at'].toString())
          : null,
      notes: raw['notes']?.toString(),
    );
  }

  CapabilityEvidenceState _parseState(String value) {
    return switch (value.trim().toLowerCase()) {
      'assessed' => CapabilityEvidenceState.assessed,
      'estimated' => CapabilityEvidenceState.estimated,
      'inferred' => CapabilityEvidenceState.inferred,
      'coach_observation' ||
      'coachobservation' => CapabilityEvidenceState.coachObservation,
      'unknown' => CapabilityEvidenceState.unknown,
      _ => throw GapAnalysisScenarioLoadException(
        'Unknown evidence state: $value',
      ),
    };
  }
}

class GapAnalysisScenarioLoadException implements Exception {
  GapAnalysisScenarioLoadException(this.message);
  final String message;
  @override
  String toString() => 'GapAnalysisScenarioLoadException: $message';
}
