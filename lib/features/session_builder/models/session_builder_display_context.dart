import 'session_builder_host_mode.dart';

/// Terminology and visibility configuration for [SessionBuilderView].
class SessionBuilderDisplayContext {
  const SessionBuilderDisplayContext({
    required this.mode,
    required this.title,
    this.subtitle,
    this.programmeLocationLabel,
    this.detailsSectionTitle = 'Details',
    this.stepsSectionTitle = 'Steps',
    this.nameFieldLabel = 'Name',
    this.sessionFormatFieldLabel = 'Session format',
    this.durationFieldLabel = 'Duration (min)',
    this.addStepLabel = 'Add step',
    this.showProtocolCode = true,
    this.showCohortMetadataFields = true,
    this.useCoachFacingTerminology = false,
  });

  final SessionBuilderHostMode mode;
  final String title;
  final String? subtitle;
  final String? programmeLocationLabel;
  final String detailsSectionTitle;
  final String stepsSectionTitle;
  final String nameFieldLabel;
  final String sessionFormatFieldLabel;
  final String durationFieldLabel;
  final String addStepLabel;
  final bool showProtocolCode;
  final bool showCohortMetadataFields;
  final bool useCoachFacingTerminology;

  factory SessionBuilderDisplayContext.cohortProtocolAdmin({
    String? subtitle,
  }) {
    return SessionBuilderDisplayContext(
      mode: SessionBuilderHostMode.cohortProtocolAdmin,
      title: 'Protocol Builder',
      subtitle: subtitle,
      detailsSectionTitle: 'Protocol Details',
      stepsSectionTitle: 'Session Steps',
      nameFieldLabel: 'name',
      sessionFormatFieldLabel: 'session_format',
      durationFieldLabel: 'duration_min',
      addStepLabel: 'Add Step',
      showProtocolCode: true,
      showCohortMetadataFields: true,
      useCoachFacingTerminology: false,
    );
  }

  factory SessionBuilderDisplayContext.embeddedProgrammeSession({
    required String programmeLocationLabel,
  }) {
    return SessionBuilderDisplayContext(
      mode: SessionBuilderHostMode.embeddedProgrammeSession,
      title: 'Session Builder',
      programmeLocationLabel: programmeLocationLabel,
      detailsSectionTitle: 'Session',
      stepsSectionTitle: 'Blocks',
      nameFieldLabel: 'Session name',
      sessionFormatFieldLabel: 'Session type',
      durationFieldLabel: 'Estimated duration (min)',
      addStepLabel: 'Add exercise',
      showProtocolCode: false,
      showCohortMetadataFields: false,
      useCoachFacingTerminology: true,
    );
  }

  factory SessionBuilderDisplayContext.librarySession() {
    return const SessionBuilderDisplayContext(
      mode: SessionBuilderHostMode.librarySession,
      title: 'Session Builder',
      detailsSectionTitle: 'Session',
      stepsSectionTitle: 'Blocks',
      nameFieldLabel: 'Session name',
      sessionFormatFieldLabel: 'Session type',
      durationFieldLabel: 'Estimated duration (min)',
      addStepLabel: 'Add exercise',
      showProtocolCode: false,
      showCohortMetadataFields: false,
      useCoachFacingTerminology: true,
    );
  }
}

/// Feature flags for shared editing widgets.
class SessionBuilderCapabilities {
  const SessionBuilderCapabilities({
    this.allowProtocolIdEdit = true,
    this.showProtocolIdField = true,
    this.showCohortMetadataFields = true,
    this.useCoachFieldLabels = false,
  });

  final bool allowProtocolIdEdit;
  final bool showProtocolIdField;
  final bool showCohortMetadataFields;
  final bool useCoachFieldLabels;

  factory SessionBuilderCapabilities.cohortProtocolAdmin({
    required bool protocolIdLocked,
  }) {
    return SessionBuilderCapabilities(
      allowProtocolIdEdit: !protocolIdLocked,
      showProtocolIdField: true,
      showCohortMetadataFields: true,
      useCoachFieldLabels: false,
    );
  }

  factory SessionBuilderCapabilities.embeddedCoachSession() {
    return const SessionBuilderCapabilities(
      allowProtocolIdEdit: false,
      showProtocolIdField: false,
      showCohortMetadataFields: false,
      useCoachFieldLabels: true,
    );
  }

  factory SessionBuilderCapabilities.librarySession() {
    return const SessionBuilderCapabilities(
      allowProtocolIdEdit: false,
      showProtocolIdField: false,
      showCohortMetadataFields: false,
      useCoachFieldLabels: true,
    );
  }
}
