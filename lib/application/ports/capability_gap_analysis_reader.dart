import 'package:cohort_platform/knowledge/gap_analysis/capability_evidence_models.dart';

/// Read-only capability gap analysis (no Coach Brain, no exercise selection).
abstract interface class CapabilityGapAnalysisReader {
  CapabilityGapAnalysisResult analyseGoal({
    required String goalId,
    required AthleteCapabilityEvidenceProfile evidenceProfile,
    DateTime? analysedAt,
  });

  List<CapabilityGap> identifyCapabilityGaps({
    required String goalId,
    required AthleteCapabilityEvidenceProfile evidenceProfile,
  });

  List<CapabilityGap> rankTrainingPriorities({
    required String goalId,
    required AthleteCapabilityEvidenceProfile evidenceProfile,
  });
}
