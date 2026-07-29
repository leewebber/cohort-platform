import 'dart:io';

import 'package:cohort_platform/knowledge/gap_analysis/capability_evidence_models.dart';
import 'package:cohort_platform/knowledge/gap_analysis/capability_gap_analysis_service.dart';
import 'package:cohort_platform/knowledge/gap_analysis/gap_analysis_scenario_loader.dart';
import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String knowledgeRoot;
  late CapabilityGapAnalysisService analysis;

  setUpAll(() async {
    knowledgeRoot = _findKnowledgeRoot(Directory.current);
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      knowledgeRoot,
    );
    analysis = CapabilityGapAnalysisService(
      InMemoryKnowledgeGraphReader(bundle),
    );
  });

  test('general fat loss with complete evidence produces no gaps', () async {
    final scenarios = await const GapAnalysisScenarioLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final scenario = scenarios.firstWhere(
      (s) => s.id == 'cohort.scenario.general_fat_loss_a',
    );
    final gaps = analysis.identifyCapabilityGaps(
      goalId: scenario.goalId,
      evidenceProfile: scenario.evidenceProfile,
    );
    expect(gaps, isEmpty);
  });

  test('HYROX athlete prioritises grip and burpee efficiency', () async {
    final scenarios = await const GapAnalysisScenarioLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final scenario = scenarios.firstWhere(
      (s) => s.id == 'cohort.scenario.hyrox_athlete_a',
    );
    final ranked = analysis.rankTrainingPriorities(
      goalId: scenario.goalId,
      evidenceProfile: scenario.evidenceProfile,
    );
    expect(ranked, isNotEmpty);
    final topIds = ranked.take(3).map((g) => g.capabilityId).toList();
    expect(topIds, contains('cohort.capability.grip_strength'));
    expect(
      topIds.any(
        (id) =>
            id == 'cohort.capability.burpee_efficiency' ||
            id == 'cohort.capability.work_capacity',
      ),
      isTrue,
    );
  });

  test(
    'military selection surfaces unknown carry and resilience gaps',
    () async {
      final scenarios = await const GapAnalysisScenarioLoader()
          .loadFromDirectory(knowledgeRoot);
      final scenario = scenarios.firstWhere(
        (s) => s.id == 'cohort.scenario.military_selection_a',
      );
      final ranked = analysis.rankTrainingPriorities(
        goalId: scenario.goalId,
        evidenceProfile: scenario.evidenceProfile,
      );
      final ids = ranked.map((g) => g.capabilityId).toSet();
      expect(ids, contains('cohort.capability.loaded_carry_capacity'));
      expect(ids, contains('cohort.capability.resilience'));
      expect(
        ranked
            .firstWhere(
              (g) =>
                  g.capabilityId == 'cohort.capability.loaded_carry_capacity',
            )
            .evidenceState,
        CapabilityEvidenceState.unknown,
      );
    },
  );

  test(
    'prerequisite chain flags threshold when aerobic base is weak',
    () async {
      final scenarios = await const GapAnalysisScenarioLoader()
          .loadFromDirectory(knowledgeRoot);
      final scenario = scenarios.firstWhere(
        (s) => s.id == 'cohort.scenario.hyrox_prerequisite_chain',
      );
      final gaps = analysis.identifyCapabilityGaps(
        goalId: scenario.goalId,
        evidenceProfile: scenario.evidenceProfile,
      );
      final threshold = gaps.firstWhere(
        (g) => g.capabilityId == 'cohort.capability.threshold',
      );
      expect(
        threshold.blockerCapabilityIds,
        contains('cohort.capability.aerobic_capacity'),
      );
      expect(threshold.severity, CapabilityGapSeverity.critical);
    },
  );

  test('ranking is deterministic', () async {
    final scenarios = await const GapAnalysisScenarioLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final scenario = scenarios.firstWhere(
      (s) => s.id == 'cohort.scenario.hyrox_athlete_a',
    );
    final first = analysis.rankTrainingPriorities(
      goalId: scenario.goalId,
      evidenceProfile: scenario.evidenceProfile,
    );
    final second = analysis.rankTrainingPriorities(
      goalId: scenario.goalId,
      evidenceProfile: scenario.evidenceProfile,
    );
    expect(
      first.map((g) => (g.capabilityId, g.priorityScore)).toList(),
      second.map((g) => (g.capabilityId, g.priorityScore)).toList(),
    );
  });

  test('partial evidence produces moderate gaps with rationale', () async {
    final profile = AthleteCapabilityEvidenceProfile.fromItems([
      const CapabilityEvidenceItem(
        capabilityId: 'cohort.capability.relative_strength',
        state: CapabilityEvidenceState.estimated,
        confidence: 0.55,
        source: 'proxy_test',
      ),
    ]);
    final gaps = analysis.identifyCapabilityGaps(
      goalId: 'cohort.goal.general_fat_loss',
      evidenceProfile: profile,
    );
    expect(gaps.length, greaterThan(2));
    expect(gaps.every((g) => g.rationale.isNotEmpty), isTrue);
  });
}

String _findKnowledgeRoot(Directory start) {
  var dir = start;
  while (true) {
    final manifest = File('${dir.path}/knowledge/manifest.yaml');
    if (manifest.existsSync()) {
      return '${dir.path}/knowledge';
    }
    if (dir.parent.path == dir.path) {
      fail('Could not locate knowledge/manifest.yaml from ${start.path}');
    }
    dir = dir.parent;
  }
}
