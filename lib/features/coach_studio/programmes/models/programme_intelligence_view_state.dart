import '../../../../models/programme_version.dart';
import '../../../programme_comparison/models/programme_version_comparison_models.dart';
import '../../../programme_impact/models/programme_version_impact_models.dart';
import '../../../programme_migration/models/programme_migration_plan_models.dart';

/// Per-card load status for Programme Intelligence (M10.4).
enum ProgrammeIntelligenceCardStatus {
  idle,
  loading,
  ready,
  error,
  empty,
}

class ProgrammeIntelligenceViewState {
  const ProgrammeIntelligenceViewState({
    required this.impactStatus,
    required this.comparisonStatus,
    required this.migrationStatus,
    this.impactSummary,
    this.impactError,
    this.comparisonSummary,
    this.comparisonError,
    this.comparisonPartial = false,
    this.migrationPlan,
    this.migrationError,
    this.migrationPartial = false,
    this.lineageVersions = const [],
    this.selectedComparisonTargetVersionId,
  });

  factory ProgrammeIntelligenceViewState.initial() {
    return const ProgrammeIntelligenceViewState(
      impactStatus: ProgrammeIntelligenceCardStatus.loading,
      comparisonStatus: ProgrammeIntelligenceCardStatus.idle,
      migrationStatus: ProgrammeIntelligenceCardStatus.idle,
    );
  }

  final ProgrammeIntelligenceCardStatus impactStatus;
  final ProgrammeIntelligenceCardStatus comparisonStatus;
  final ProgrammeIntelligenceCardStatus migrationStatus;
  final ProgrammeVersionImpactSummary? impactSummary;
  final String? impactError;
  final ProgrammeVersionComparisonSummary? comparisonSummary;
  final String? comparisonError;
  final bool comparisonPartial;
  final ProgrammeMigrationPlan? migrationPlan;
  final String? migrationError;
  final bool migrationPartial;
  final List<ProgrammeVersion> lineageVersions;
  final String? selectedComparisonTargetVersionId;

  bool get hasComparisonTarget =>
      selectedComparisonTargetVersionId != null &&
      selectedComparisonTargetVersionId!.isNotEmpty;

  ProgrammeIntelligenceViewState copyWith({
    ProgrammeIntelligenceCardStatus? impactStatus,
    ProgrammeIntelligenceCardStatus? comparisonStatus,
    ProgrammeIntelligenceCardStatus? migrationStatus,
    ProgrammeVersionImpactSummary? impactSummary,
    String? impactError,
    bool clearImpactError = false,
    ProgrammeVersionComparisonSummary? comparisonSummary,
    String? comparisonError,
    bool clearComparisonError = false,
    bool? comparisonPartial,
    ProgrammeMigrationPlan? migrationPlan,
    String? migrationError,
    bool clearMigrationError = false,
    bool? migrationPartial,
    List<ProgrammeVersion>? lineageVersions,
    String? selectedComparisonTargetVersionId,
    bool clearComparisonTarget = false,
    bool clearComparisonSummary = false,
    bool clearMigrationPlan = false,
  }) {
    return ProgrammeIntelligenceViewState(
      impactStatus: impactStatus ?? this.impactStatus,
      comparisonStatus: comparisonStatus ?? this.comparisonStatus,
      migrationStatus: migrationStatus ?? this.migrationStatus,
      impactSummary: impactSummary ?? this.impactSummary,
      impactError: clearImpactError ? null : (impactError ?? this.impactError),
      comparisonSummary: clearComparisonSummary
          ? null
          : (comparisonSummary ?? this.comparisonSummary),
      comparisonError:
          clearComparisonError ? null : (comparisonError ?? this.comparisonError),
      comparisonPartial: comparisonPartial ?? this.comparisonPartial,
      migrationPlan:
          clearMigrationPlan ? null : (migrationPlan ?? this.migrationPlan),
      migrationError:
          clearMigrationError ? null : (migrationError ?? this.migrationError),
      migrationPartial: migrationPartial ?? this.migrationPartial,
      lineageVersions: lineageVersions ?? this.lineageVersions,
      selectedComparisonTargetVersionId: clearComparisonTarget
          ? null
          : (selectedComparisonTargetVersionId ??
              this.selectedComparisonTargetVersionId),
    );
  }
}
